//
//  SuggestionsDataBaseManager.swift
//  Keyboard
//
//  Copyright © 2024 Daniel Saidi. All rights reserved.
//

import Foundation
import KeyboardKit
import SQLite3
import UIKit
import os

final class SuggestionsDataBaseManager {

    static let shared = SuggestionsDataBaseManager()
    static let signposter = OSSignposter(subsystem: "crh.key.perf", category: "Autocomplete")

    private var db: OpaquePointer?
    private var userDB: OpaquePointer?
    private let databaseQueue = DispatchQueue(label: "crh.keyboard.databaseQueue")
    private static let crimeanLocale = Locale(identifier: "crh")
    /// i/ı/İ/I casing for Crimean Tatar Latin (same rules as Turkish script).
    private static let casingLocale = Locale(identifier: "tr")
    /// Minimum bigram frequency to consider for next-word prediction.
    private static let minimumNextWordFrequency = 1

    private var cachedPhrases: [(phrase: String, freq: Int)]?

    init() {
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    SuggestionsDataBaseManager.shared.clearUserLexicon()
                }
            },
            KeyboardUsageStats.statsResetNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    /// Opens the dictionary on a background queue before the first autocomplete query.
    func prepareAsync() {
        databaseQueue.async { [weak self] in
            guard let self else { return }
            self.ensureDB()
            self.ensureUserDB()
            let learnedCount = self.countUserUnigrams()
            if learnedCount > 0 {
                KeyboardUsageStats.updateLearnedWordsCount(learnedCount)
            }
            self.ensurePhrasesLoaded()
        }
    }

    deinit {
        databaseQueue.sync {
            if let db {
                sqlite3_close(db)
                self.db = nil
            }
            if let userDB {
                sqlite3_close(userDB)
                self.userDB = nil
            }
        }
    }

    private func openDB() {
        let state = Self.signposter.beginInterval("openDB")
        defer { Self.signposter.endInterval("openDB", state) }
        let siblingURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("Keyboard.appex/qırım_tatar.db")
        let resolvedURL = Bundle.main.url(forResource: "qırım_tatar", withExtension: "db")
            ?? (FileManager.default.fileExists(atPath: siblingURL.path) ? siblingURL : nil)
        guard let dbURL = resolvedURL else {
            debugPrint("Cant open DB")
            return
        }

        guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
            if let db, let errMsg = sqlite3_errmsg(db) {
                debugPrint("Failed to open SQLite database: \(String(cString: errMsg))")
            } else {
                debugPrint("Failed to open SQLite database at \(dbURL.path)")
            }
            return
        }

        sqlite3_exec(db, "PRAGMA cache_size = -2000;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA mmap_size = 16777216;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA temp_store = MEMORY;", nil, nil, nil)
        debugPrint("Successfully opened SQLite database (readonly, optimized) at \(dbURL.path)")
    }

    private func openUserDB() {
        let containerDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfiguration.appGroupID)
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        try? FileManager.default.createDirectory(at: containerDir, withIntermediateDirectories: true)
        let userDBURL = containerDir.appendingPathComponent("user_lexicon.sqlite")

        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(userDBURL.path, &userDB, flags, nil) == SQLITE_OK else {
            userDB = nil
            return
        }
        sqlite3_busy_timeout(userDB, 2000)
        let schema = """
        PRAGMA journal_mode = WAL;
        PRAGMA synchronous = NORMAL;
        CREATE TABLE IF NOT EXISTS user_unigrams (
            word TEXT PRIMARY KEY,
            freq INTEGER NOT NULL DEFAULT 1,
            last_used INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_user_unigrams_freq ON user_unigrams(freq DESC, last_used DESC);
        CREATE TABLE IF NOT EXISTS user_bigrams (
            word1 TEXT NOT NULL,
            word2 TEXT NOT NULL,
            freq INTEGER NOT NULL DEFAULT 1,
            last_used INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (word1, word2)
        );
        CREATE INDEX IF NOT EXISTS idx_user_bigrams_word1 ON user_bigrams(word1, freq DESC, last_used DESC);
        """
        sqlite3_exec(userDB, schema, nil, nil, nil)
    }

    private func ensureDB() {
        if db != nil { return }
        openDB()
    }

    private func ensureUserDB() {
        if userDB != nil { return }
        openUserDB()
    }

    // MARK: - Personalized Word & Bigram Learning

    private static let excludedURLTokens: Set<String> = ["http", "https", "www"]
    private var sessionLearnedWords = Set<String>()

    static func isValidLearnableWord(_ rawWord: String) -> Bool {
        let trimmed = rawWord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2, trimmed.count <= 32 else { return false }
        if excludedURLTokens.contains(trimmed.lowercased()) { return false }
        var letterCount = 0
        for ch in trimmed {
            if ch.isLetter {
                letterCount += 1
            } else if ch == "'" || ch == "’" || ch == "-" {
                continue
            } else {
                return false
            }
        }
        return letterCount >= 2
    }

    static func shouldLearn(word: String, proxy: UITextDocumentProxy?) -> Bool {
        guard KeyboardPreferences.wordLearningEnabled else { return false }
        if let proxy {
            if proxy.isSecureTextEntry == true { return false }
            if let kbType = proxy.keyboardType {
                switch kbType {
                case .emailAddress, .numberPad, .decimalPad, .phonePad, .asciiCapableNumberPad, .numbersAndPunctuation:
                    return false
                default:
                    break
                }
            }
            if let contentType = proxy.textContentType ?? nil {
                let blocked: Set<UITextContentType> = [
                    .password, .newPassword, .oneTimeCode, .creditCardNumber,
                    .emailAddress, .telephoneNumber
                ]
                if blocked.contains(contentType) { return false }
            }
        }
        return isValidLearnableWord(word)
    }

    func learnWordIfPermitted(
        _ word: String,
        previousWord: String? = nil,
        proxy: UITextDocumentProxy? = nil,
        explicitlyConfirmed: Bool = false
    ) {
        guard Self.shouldLearn(word: word, proxy: proxy) else { return }
        let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Self.casingLocale)
        let normalizedPrev: String? = {
            guard let prev = previousWord?.trimmingCharacters(in: .whitespacesAndNewlines),
                  Self.isValidLearnableWord(prev) else { return nil }
            return prev.lowercased(with: Self.casingLocale)
        }()
        let now = Int64(Date().timeIntervalSince1970)
        databaseQueue.async { [weak self] in
            guard let self else { return }
            self.ensureDB()
            self.ensureUserDB()
            let baseFreq = self.bundledFrequency(of: normalizedWord)
            let effectiveWord: String
            if !explicitlyConfirmed,
               let canonical = self.diacriticCorrection(for: normalizedWord, over: baseFreq > 0 ? baseFreq : nil) {
                effectiveWord = canonical.lowercased(with: Self.casingLocale)
            } else if !explicitlyConfirmed, baseFreq == 0, self.typoCorrection(for: normalizedWord) != nil {
                return
            } else {
                effectiveWord = normalizedWord
            }
            let effectivePrev: String? = {
                guard let normalizedPrev else { return nil }
                let prevBaseFreq = self.bundledFrequency(of: normalizedPrev)
                if let canonicalPrev = self.diacriticCorrection(for: normalizedPrev, over: prevBaseFreq > 0 ? prevBaseFreq : nil) {
                    return canonicalPrev.lowercased(with: Self.casingLocale)
                }
                return normalizedPrev
            }()
            let isNewUserWord = (self.userFrequency(of: effectiveWord) == 0)
            self.recordLearnedEntry(word: effectiveWord, previousWord: effectivePrev, timestamp: now)
            let totalLearned = self.countUserUnigrams()
            if totalLearned > 0 {
                KeyboardUsageStats.updateLearnedWordsCount(totalLearned)
            } else if isNewUserWord {
                KeyboardUsageStats.recordWordLearned()
            }
        }
    }

    func learnWordSynchronously(_ word: String, previousWord: String? = nil) {
        guard Self.isValidLearnableWord(word) else { return }
        let normalizedWord = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Self.casingLocale)
        let normalizedPrev: String? = {
            guard let prev = previousWord?.trimmingCharacters(in: .whitespacesAndNewlines),
                  Self.isValidLearnableWord(prev) else { return nil }
            return prev.lowercased(with: Self.casingLocale)
        }()
        let now = Int64(Date().timeIntervalSince1970)
        databaseQueue.sync {
            ensureDB()
            ensureUserDB()
            let isNewUserWord = (userFrequency(of: normalizedWord) == 0)
            recordLearnedEntry(word: normalizedWord, previousWord: normalizedPrev, timestamp: now)
            let totalLearned = countUserUnigrams()
            if totalLearned > 0 {
                KeyboardUsageStats.updateLearnedWordsCount(totalLearned)
            } else if isNewUserWord {
                KeyboardUsageStats.recordWordLearned()
            }
        }
    }

    private func countUserUnigrams() -> Int {
        ensureUserDB()
        guard let userDB else { return 0 }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(userDB, "SELECT COUNT(*) FROM user_unigrams;", -1, &stmt, nil) == SQLITE_OK,
              sqlite3_step(stmt) == SQLITE_ROW else {
            return 0
        }
        return Int(sqlite3_column_int(stmt, 0))
    }

    func hasLearnedWord(_ word: String) -> Bool {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Self.casingLocale)
        return databaseQueue.sync {
            ensureUserDB()
            return userFrequency(of: normalized) > 0
        }
    }

    func unlearnWord(_ word: String) {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Self.casingLocale)
        sessionLearnedWords.remove(normalized)
        databaseQueue.sync {
            ensureUserDB()
            guard let userDB else { return }
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            if sqlite3_prepare_v2(userDB, "DELETE FROM user_unigrams WHERE word = ?1;", -1, &stmt, nil) == SQLITE_OK,
               bindText(stmt, index: 1, value: normalized) {
                sqlite3_step(stmt)
            }
        }
    }

    func clearUserLexicon() {
        sessionLearnedWords.removeAll()
        databaseQueue.async { [weak self] in
            guard let self else { return }
            self.ensureUserDB()
            if let userDB = self.userDB {
                sqlite3_exec(userDB, "DELETE FROM user_unigrams; DELETE FROM user_bigrams;", nil, nil, nil)
                sqlite3_close(userDB)
                self.userDB = nil
            }
        }
    }

    private func recordLearnedEntry(word: String, previousWord: String?, timestamp: Int64) {
        ensureUserDB()
        guard let userDB else { return }
        do {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = """
            INSERT INTO user_unigrams(word, freq, last_used)
            VALUES (?1, 1, ?2)
            ON CONFLICT(word) DO UPDATE SET
                freq = MIN(freq + 1, 10000),
                last_used = excluded.last_used;
            """
            if sqlite3_prepare_v2(userDB, sql, -1, &stmt, nil) == SQLITE_OK,
               bindText(stmt, index: 1, value: word),
               sqlite3_bind_int64(stmt, 2, timestamp) == SQLITE_OK {
                sqlite3_step(stmt)
            }
        }
        if let previousWord, previousWord != word {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = """
            INSERT INTO user_bigrams(word1, word2, freq, last_used)
            VALUES (?1, ?2, 1, ?3)
            ON CONFLICT(word1, word2) DO UPDATE SET
                freq = MIN(freq + 1, 10000),
                last_used = excluded.last_used;
            """
            if sqlite3_prepare_v2(userDB, sql, -1, &stmt, nil) == SQLITE_OK,
               bindText(stmt, index: 1, value: previousWord),
               bindText(stmt, index: 2, value: word),
               sqlite3_bind_int64(stmt, 3, timestamp) == SQLITE_OK {
                sqlite3_step(stmt)
            }
        }
    }

    private func userFrequency(of word: String) -> Int32 {
        guard KeyboardPreferences.wordLearningEnabled else { return 0 }
        ensureUserDB()
        guard let userDB else { return 0 }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(userDB, "SELECT freq FROM user_unigrams WHERE word = ?1;", -1, &stmt, nil) == SQLITE_OK,
              bindText(stmt, index: 1, value: word),
              sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int(stmt, 0)
    }

    private func fetchUserWordsStartingWith(prefix: String, limit: Int) -> [(word: String, freq: Int)] {
        guard KeyboardPreferences.wordLearningEnabled else { return [] }
        ensureUserDB()
        guard let userDB else { return [] }
        var results: [(String, Int)] = []
        var stmt: OpaquePointer?
        let query = """
        SELECT word, freq FROM user_unigrams
        WHERE word >= ?1 AND word < ?2
        ORDER BY (word = ?1) DESC, freq DESC, last_used DESC
        LIMIT ?3;
        """
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(userDB, query, -1, &stmt, nil) == SQLITE_OK,
              bindText(stmt, index: 1, value: prefix),
              bindText(stmt, index: 2, value: prefix + "\u{FFFF}"),
              sqlite3_bind_int(stmt, 3, Int32(limit)) == SQLITE_OK else { return [] }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let wordPtr = sqlite3_column_text(stmt, 0) {
                results.append((String(cString: wordPtr), Int(sqlite3_column_int(stmt, 1))))
            }
        }
        return results
    }

    private func fetchUserBigrams(after word1: String, limit: Int) -> [(word2: String, freq: Int)] {
        guard KeyboardPreferences.wordLearningEnabled else { return [] }
        ensureUserDB()
        guard let userDB else { return [] }
        var results: [(String, Int)] = []
        var stmt: OpaquePointer?
        let query = """
        SELECT word2, freq FROM user_bigrams
        WHERE word1 = ?1
        ORDER BY freq DESC, last_used DESC
        LIMIT ?2;
        """
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(userDB, query, -1, &stmt, nil) == SQLITE_OK,
              bindText(stmt, index: 1, value: word1),
              sqlite3_bind_int(stmt, 2, Int32(limit)) == SQLITE_OK else { return [] }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let wordPtr = sqlite3_column_text(stmt, 0) {
                results.append((String(cString: wordPtr), Int(sqlite3_column_int(stmt, 1))))
            }
        }
        return results
    }

    private func ensurePhrasesLoaded() {
        if cachedPhrases != nil { return }
        guard let db else { return }
        var results: [(String, Int)] = []
        var stmt: OpaquePointer?
        let query = "SELECT word, freq FROM words WHERE instr(word, ' ') > 0 ORDER BY freq DESC;"
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let word = sqlite3_column_text(stmt, 0) {
                let freq = Int(sqlite3_column_int(stmt, 1))
                results.append((String(cString: word).lowercased(with: Self.casingLocale), freq))
            }
        }
        cachedPhrases = results
    }

    func starterSuggestions(shouldCapitalize: Bool) -> [Autocomplete.Suggestion] {
        databaseQueue.sync {
            ensureDB()
            return fetchPopularWords(limit: 3).map {
                Autocomplete.Suggestion(text: formatWord($0, capitalize: shouldCapitalize))
            }
        }
    }

    func nextWordSuggestions(
        contextWords: [String],
        shouldCapitalize: Bool
    ) -> [Autocomplete.Suggestion] {
        databaseQueue.sync {
            ensureDB()
            let candidates = rankNextWordCandidates(contextWords: contextWords)
            let lastContext = contextWords.last ?? ""
            let isAllCaps = lastContext.count > 1 && lastContext == lastContext.uppercased(with: Self.casingLocale)
            return candidates.prefix(3).map {
                Autocomplete.Suggestion(text: formatWord($0, capitalize: shouldCapitalize, isAllCaps: isAllCaps))
            }
        }
    }

    func suggestions(
        for text: String,
        shouldCapitalize: Bool
    ) -> [Autocomplete.Suggestion] {
        databaseQueue.sync {
            ensureDB()

            if text.isEmpty {
                return fetchPopularWords(limit: 3).map {
                    Autocomplete.Suggestion(text: formatWord($0, capitalize: shouldCapitalize))
                }
            }

            let isAllCaps = text.count > 1 && text == text.uppercased(with: Self.casingLocale)
            let matches = fetchWordsStartingWith(prefix: text, limit: 8)
            let queryLower = text.lowercased(with: Self.casingLocale)
            let isKnownWord = matches.first.map { $0.lowercased(with: Self.casingLocale) == queryLower } ?? false

            var result: [Autocomplete.Suggestion] = []

            if isKnownWord, let known = matches.first {
                // A valid word is not replaced, except for a casing fix (shift state / sentence start)
                // or when its diacritic form in the bundled dictionary is overwhelmingly more common (qirim → qırım).
                let knownFormatted = formatWord(known, capitalize: shouldCapitalize, isAllCaps: isAllCaps)
                let baseFreq = bundledFrequency(of: queryLower)
                if let dominant = diacriticCorrection(for: queryLower, over: baseFreq > 0 ? baseFreq : nil) {
                    result.append(.init(text: text, isUnknown: true))
                    result.append(.init(
                        text: formatWord(dominant, capitalize: shouldCapitalize, isAllCaps: isAllCaps),
                        isAutocorrect: true
                    ))
                } else if text != knownFormatted {
                    result.append(.init(text: text, isUnknown: true))
                    result.append(.init(text: knownFormatted, isAutocorrect: true))
                } else {
                    result.append(.init(text: knownFormatted))
                }
            } else {
                // Unknown word: pick what Space should replace it with, like the system keyboard.
                // 1. same letters with diacritics restored, 2. a short completion, 3. a one-letter typo fix.
                let correction = diacriticCorrection(for: queryLower)
                    ?? shortCompletion(for: queryLower, in: matches)
                    ?? (matches.isEmpty ? typoCorrection(for: queryLower) : nil)
                result.append(.init(text: text, isUnknown: true))
                if let correction {
                    result.append(.init(
                        text: formatWord(correction, capitalize: shouldCapitalize, isAllCaps: isAllCaps),
                        isAutocorrect: true
                    ))
                }
            }

            let used = Set(result.map { $0.text.lowercased(with: Self.casingLocale) })
            var usedKeys = used
            for match in matches {
                guard result.count < 3 else { break }
                let formatted = formatWord(match, capitalize: shouldCapitalize, isAllCaps: isAllCaps)
                let key = formatted.lowercased(with: Self.casingLocale)
                guard !usedKeys.contains(key) else { continue }
                usedKeys.insert(key)
                result.append(.init(text: formatted))
            }

            return Array(result.prefix(3))
        }
    }

    // MARK: - Autocorrect candidates

    private static let lettersForTypos = Array("abcçdefgğhıijklmnñoöpqrsştuüvwxyzâîû")
    private static let diacriticForms: [Character: [Character]] = [
        "a": ["â"], "c": ["ç"], "g": ["ğ"], "i": ["ı"], "n": ["ñ"],
        "o": ["ö"], "s": ["ş"], "u": ["ü", "û"]
    ]

    /// A completion is auto-applied only if it adds at most two letters to a word of 3+ letters.
    private func shortCompletion(for queryLower: String, in matches: [String]) -> String? {
        guard queryLower.count >= 3, let best = matches.first else { return nil }
        let bestLower = best.lowercased(with: Self.casingLocale)
        guard bestLower.hasPrefix(queryLower), bestLower.count - queryLower.count <= 2 else { return nil }
        return best
    }

    /// Most frequent dictionary word that differs from the typed text only by diacritics (i→ı, s→ş, …).
    /// With `knownFrequency`, the variant must also be at least 20x more frequent than the typed word.
    private func diacriticCorrection(for queryLower: String, over knownFrequency: Int32? = nil) -> String? {
        let chars = Array(queryLower)
        let positions = chars.indices.filter { Self.diacriticForms[chars[$0]] != nil }
        guard !positions.isEmpty, positions.count <= 8, chars.count <= 20 else { return nil }
        var variants: [[Character]] = [chars]
        for position in positions {
            var next: [[Character]] = []
            for variant in variants {
                next.append(variant)
                for replacement in Self.diacriticForms[chars[position]] ?? [] {
                    var changed = variant
                    changed[position] = replacement
                    next.append(changed)
                }
            }
            variants = next
        }
        guard let best = bestKnownWord(among: variants.dropFirst().map { String($0) }) else { return nil }
        if let knownFrequency, best.freq < knownFrequency * 20 { return nil }
        return best.word
    }

    private func bundledFrequency(of word: String) -> Int32 {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT MAX(freq) FROM words WHERE word = ?1;", -1, &stmt, nil) == SQLITE_OK,
              bindText(stmt, index: 1, value: word),
              sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int(stmt, 0)
    }

    private func frequency(of word: String) -> Int32 {
        let userBoost = userFrequency(of: word) * 500
        return bundledFrequency(of: word) + userBoost
    }

    /// Most frequent dictionary word one edit away (delete / transpose / replace / insert).
    private func typoCorrection(for queryLower: String) -> String? {
        let chars = Array(queryLower)
        guard chars.count >= 3, chars.count <= 14, chars.allSatisfy({ $0.isLetter }) else { return nil }
        var candidates = Set<String>()
        for index in chars.indices {
            var deleted = chars
            deleted.remove(at: index)
            candidates.insert(String(deleted))
            if index + 1 < chars.count {
                var swapped = chars
                swapped.swapAt(index, index + 1)
                candidates.insert(String(swapped))
            }
            for letter in Self.lettersForTypos where letter != chars[index] {
                var replaced = chars
                replaced[index] = letter
                candidates.insert(String(replaced))
            }
        }
        for index in 0...chars.count {
            for letter in Self.lettersForTypos {
                var inserted = chars
                inserted.insert(letter, at: index)
                candidates.insert(String(inserted))
            }
        }
        candidates.remove(queryLower)
        guard let best = bestKnownWord(among: Array(candidates)), best.freq >= 10 else { return nil }
        return best.word
    }

    private func bestKnownWord(among candidates: [String]) -> (word: String, freq: Int32)? {
        guard let db, !candidates.isEmpty else { return nil }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT freq FROM words WHERE word = ?1 ORDER BY freq DESC LIMIT 1;", -1, &stmt, nil) == SQLITE_OK else {
            return nil
        }
        var best: (word: String, freq: Int32)?
        for candidate in candidates {
            sqlite3_reset(stmt)
            guard bindText(stmt, index: 1, value: candidate) else { continue }
            if sqlite3_step(stmt) == SQLITE_ROW {
                let freq = sqlite3_column_int(stmt, 0)
                if best == nil || freq > best!.freq { best = (candidate, freq) }
            }
        }
        return best
    }

    private func formatWord(_ word: String, capitalize: Bool, isAllCaps: Bool = false) -> String {
        if isAllCaps {
            return word.uppercased(with: Self.casingLocale)
        }
        if capitalize {
            guard let first = word.first else { return word }
            let firstChar = String(first).uppercased(with: Self.casingLocale)
            let rest = String(word.dropFirst()).lowercased(with: Self.casingLocale)
            return firstChar + rest
        }
        return word.lowercased(with: Self.casingLocale)
    }

    private func rankNextWordCandidates(contextWords: [String]) -> [String] {
        let normalized = contextWords.map { $0.lowercased(with: Self.casingLocale) }
        guard !normalized.isEmpty else { return [] }

        var scores: [String: Int] = [:]

        // 0. Personalized user bigrams get top priority
        if let lastWord = normalized.last {
            for (nextWord, freq) in fetchUserBigrams(after: lastWord, limit: 6) {
                let key = nextWord.lowercased(with: Self.casingLocale)
                scores[key] = max(scores[key] ?? 0, freq * 2500)
            }
        }

        // 1. Trigrams for rich 2-word context
        if normalized.count >= 2 {
            addTrigramContinuations(
                word1: normalized[normalized.count - 2],
                word2: normalized[normalized.count - 1],
                into: &scores
            )
        }

        // 2. Multi-word phrase continuations (uses in-memory cache)
        if scores.count < 3 {
            for length in stride(from: min(3, normalized.count), through: 1, by: -1) {
                let prefix = normalized.suffix(length).joined(separator: " ")
                addPhraseContinuations(prefix: prefix, into: &scores)
                if scores.count >= 3 { break }
            }
        }

        // 3. Bigrams for the last typed word
        if scores.count < 3, let lastWord = normalized.last {
            addBigramContinuations(after: lastWord, minFrequency: Self.minimumNextWordFrequency, into: &scores)
        }

        // 4. Fallback to general popular words to guarantee 3 suggestions
        if scores.count < 3 {
            let lastWord = normalized.last ?? ""
            for word in fetchPopularWords(limit: 10) {
                let key = word.lowercased(with: Self.casingLocale)
                if key != lastWord && scores[key] == nil {
                    scores[key] = max(1, 10 - scores.count)
                    if scores.count >= 3 { break }
                }
            }
        }

        return scores
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .map(\.key)
    }

    private func addTrigramContinuations(
        word1: String,
        word2: String,
        into scores: inout [String: Int]
    ) {
        for (nextWord, frequency) in fetchTrigramContinuations(
            after: word1,
            and: word2,
            limit: 8
        ) {
            let key = nextWord.lowercased(with: Self.casingLocale)
            scores[key] = max(scores[key] ?? 0, frequency * 10)
        }
    }

    private func addPhraseContinuations(
        prefix: String,
        into scores: inout [String: Int]
    ) {
        for (phrase, frequency) in fetchPhrases(startingWith: prefix, limit: 24) {
            guard let nextWord = nextToken(in: phrase, afterPrefix: prefix) else { continue }
            let key = nextWord.lowercased(with: Self.casingLocale)
            scores[key] = max(scores[key] ?? 0, frequency)
        }
    }

    private func addBigramContinuations(
        after word: String,
        minFrequency: Int,
        into scores: inout [String: Int]
    ) {
        for (nextWord, frequency) in fetchNextWordsWithFrequency(
            after: word,
            minFrequency: minFrequency,
            limit: 8
        ) {
            let key = nextWord.lowercased(with: Self.casingLocale)
            scores[key] = max(scores[key] ?? 0, frequency)
        }
    }

    private func nextToken(in phrase: String, afterPrefix prefix: String) -> String? {
        let parts = phrase.split(separator: " ").map(String.init)
        let prefixParts = prefix.split(separator: " ").map(String.init)
        guard parts.count > prefixParts.count else { return nil }

        let leading = parts.prefix(prefixParts.count)
            .map { $0.lowercased(with: Self.casingLocale) }
        let expected = prefixParts.map { $0.lowercased(with: Self.casingLocale) }
        guard leading == expected else { return nil }

        return parts[prefixParts.count]
    }

    private func fetchPhrases(
        startingWith prefix: String,
        limit: Int
    ) -> [(String, Int)] {
        ensurePhrasesLoaded()
        guard let phrases = cachedPhrases else { return [] }
        let pattern = prefix.lowercased(with: Self.casingLocale) + " "
        var matching: [(String, Int)] = []
        for item in phrases {
            if item.phrase.hasPrefix(pattern) {
                matching.append((item.phrase, item.freq))
                if matching.count >= limit { break }
            }
        }
        return matching
    }

    private func fetchTrigramContinuations(
        after word1: String,
        and word2: String,
        limit: Int
    ) -> [(String, Int)] {
        guard let db else { return [] }

        var results: [(String, Int)] = []
        var stmt: OpaquePointer?
        let query = """
            SELECT word3, freq FROM trigrams
            WHERE word1 = ? AND word2 = ?
            ORDER BY freq DESC
            LIMIT ?;
            """

        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }

        guard bindText(stmt, index: 1, value: word1) else {
            return []
        }

        guard bindText(stmt, index: 2, value: word2) else {
            return []
        }

        guard sqlite3_bind_int(stmt, 3, Int32(limit)) == SQLITE_OK else {
            return []
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let word = sqlite3_column_text(stmt, 0) else { continue }
            let frequency = Int(sqlite3_column_int(stmt, 1))
            results.append((String(cString: word), frequency))
        }

        return results
    }

    private func fetchNextWordsWithFrequency(
        after previousWord: String,
        minFrequency: Int,
        limit: Int
    ) -> [(String, Int)] {
        guard let db else { return [] }

        var results: [(String, Int)] = []
        var stmt: OpaquePointer?
        let query = """
            SELECT word2, freq FROM bigrams
            WHERE word1 = ? AND freq >= ?
            ORDER BY freq DESC
            LIMIT ?;
            """

        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }

        guard bindText(stmt, index: 1, value: previousWord) else {
            return []
        }

        guard sqlite3_bind_int(stmt, 2, Int32(minFrequency)) == SQLITE_OK else {
            return []
        }

        guard sqlite3_bind_int(stmt, 3, Int32(limit)) == SQLITE_OK else {
            return []
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let word = sqlite3_column_text(stmt, 0) else { continue }
            let frequency = Int(sqlite3_column_int(stmt, 1))
            results.append((String(cString: word), frequency))
        }

        return results
    }

    private func fetchNextWords(after previousWord: String, limit: Int) -> [String] {
        guard let db else { return [] }
        var results: [String] = []
        var stmt: OpaquePointer?
        let query = """
            SELECT word2 FROM bigrams
            WHERE word1 = ? AND freq >= ?
            ORDER BY freq DESC
            LIMIT ?;
            """

        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }

        guard bindText(stmt, index: 1, value: previousWord) else {
            return []
        }

        guard sqlite3_bind_int(stmt, 2, Int32(Self.minimumNextWordFrequency)) == SQLITE_OK else {
            return []
        }

        guard sqlite3_bind_int(stmt, 3, Int32(limit)) == SQLITE_OK else {
            return []
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let word = sqlite3_column_text(stmt, 0) {
                results.append(String(cString: word))
            }
        }

        return results
    }

    private func fetchPopularWords(limit: Int) -> [String] {
        guard let db else { return [] }
        var results: [String] = []
        var stmt: OpaquePointer?
        let query = "SELECT word FROM words ORDER BY freq DESC LIMIT ?;"

        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }

        guard sqlite3_bind_int(stmt, 1, Int32(limit)) == SQLITE_OK else {
            return []
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let word = sqlite3_column_text(stmt, 0) {
                results.append(String(cString: word))
            }
        }

        return results
    }

    private func fetchWordsStartingWith(prefix: String, limit: Int) -> [String] {
        let lowercasePrefix = prefix.lowercased(with: Self.casingLocale)
        let userMatches = fetchUserWordsStartingWith(prefix: lowercasePrefix, limit: limit)

        guard let db else {
            return userMatches.map(\.word)
        }
        var scored: [String: Int] = [:]
        var ordered: [String] = []

        for (word, freq) in userMatches {
            scored[word] = freq * 500
            ordered.append(word)
        }

        var stmt: OpaquePointer?
        let query = "SELECT word, freq FROM words WHERE word >= ?1 AND word < ?2 AND instr(word, ' ') = 0 ORDER BY (word = ?1) DESC, freq DESC LIMIT ?3;"

        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK,
              bindText(stmt, index: 1, value: lowercasePrefix),
              bindText(stmt, index: 2, value: lowercasePrefix + "\u{FFFF}"),
              sqlite3_bind_int(stmt, 3, Int32(limit)) == SQLITE_OK else {
            return ordered
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let wordPtr = sqlite3_column_text(stmt, 0) {
                let word = String(cString: wordPtr)
                let freq = Int(sqlite3_column_int(stmt, 1))
                let key = word.lowercased(with: Self.casingLocale)
                if scored[key] == nil {
                    ordered.append(word)
                }
                scored[key, default: 0] += freq
            }
        }

        let sorted = ordered.sorted { lhs, rhs in
            let lKey = lhs.lowercased(with: Self.casingLocale)
            let rKey = rhs.lowercased(with: Self.casingLocale)
            let lExact = (lKey == lowercasePrefix)
            let rExact = (rKey == lowercasePrefix)
            if lExact != rExact { return lExact }
            let lScore = scored[lKey] ?? 0
            let rScore = scored[rKey] ?? 0
            if lScore != rScore { return lScore > rScore }
            return lKey < rKey
        }
        return Array(sorted.prefix(limit))
    }

    private func bindText(
        _ statement: OpaquePointer?,
        index: Int32,
        value: String
    ) -> Bool {
        value.withCString { pointer in
            sqlite3_bind_text(
                statement,
                index,
                pointer,
                -1,
                Self.sqliteTransientDestructor
            )
        } == SQLITE_OK
    }

    private static let sqliteTransientDestructor = unsafeBitCast(
        -1,
        to: sqlite3_destructor_type.self
    )
}
