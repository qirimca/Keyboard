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

    private var isPrepareScheduled = false
    private var isSuspended = false
    private var lifecycleObservers: [NSObjectProtocol] = []
    private let supplementaryLock = NSLock()
    private var supplementaryLexicon: [String: String] = [:]

    func updateSupplementaryLexicon(_ entries: [String: String]) {
        supplementaryLock.lock()
        var normalized: [String: String] = [:]
        for (key, value) in entries {
            let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
            let k = trimmedKey.lowercased(with: Self.casingLocale)
            let v = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !k.isEmpty && !v.isEmpty && trimmedKey != v {
                normalized[k] = v
            }
        }
        supplementaryLexicon = normalized
        supplementaryLock.unlock()
    }

    func shortcutReplacement(for query: String) -> String? {
        let key = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(with: Self.casingLocale)
        guard !key.isEmpty else { return nil }
        supplementaryLock.lock()
        let match = supplementaryLexicon[key]
        supplementaryLock.unlock()
        if let match { return match }
        if let customDict = KeyboardPreferences.defaults.dictionary(forKey: "crh.key.test.textReplacements") as? [String: String],
           let testMatch = customDict[key], !testMatch.isEmpty {
            return testMatch
        }
        return nil
    }

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
        let nc = NotificationCenter.default
        let suspendNames: [Notification.Name] = [
            .NSExtensionHostWillResignActive,
            .NSExtensionHostDidEnterBackground,
            UIApplication.willResignActiveNotification,
            UIApplication.didEnterBackgroundNotification
        ]
        for name in suspendNames {
            lifecycleObservers.append(nc.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                self?.suspendAccess()
            })
        }
        let resumeNames: [Notification.Name] = [
            .NSExtensionHostDidBecomeActive,
            .NSExtensionHostWillEnterForeground,
            UIApplication.didBecomeActiveNotification,
            UIApplication.willEnterForegroundNotification
        ]
        for name in resumeNames {
            lifecycleObservers.append(nc.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                self?.resumeAccess()
            })
        }
    }

    /// Synchronously closes the writable App Group SQLite database (`user_lexicon.sqlite`) before process suspension
    /// to prevent RunningBoard `0xdead10cc` termination.
    func suspendAccess() {
        databaseQueue.sync {
            isSuspended = true
            if let userDB {
                sqlite3_close_v2(userDB)
                self.userDB = nil
            }
        }
    }

    /// Re-enables access to `user_lexicon.sqlite` when the keyboard extension becomes active.
    func resumeAccess() {
        databaseQueue.async { [weak self] in
            self?.isSuspended = false
        }
    }

    /// Opens the dictionary on a background queue before the first autocomplete query.
    func prepareAsync() {
        databaseQueue.async { [weak self] in
            guard let self else { return }
            self.isSuspended = false
            guard self.db == nil || self.userDB == nil || !self.isPrepareScheduled else { return }
            self.isPrepareScheduled = true
            self.ensureDB()
            self.ensureUserDB()
            let learnedCount = self.countUserUnigrams()
            if learnedCount > 0 {
                KeyboardUsageStats.updateLearnedWordsCount(learnedCount)
            }
        }
    }

    deinit {
        for observer in lifecycleObservers {
            NotificationCenter.default.removeObserver(observer)
        }
        databaseQueue.sync {
            if let db {
                sqlite3_close(db)
                self.db = nil
            }
            if let userDB {
                sqlite3_close_v2(userDB)
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
        PRAGMA journal_mode = DELETE;
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
        guard !isSuspended else { return }
        if userDB != nil { return }
        openUserDB()
    }

    // MARK: - Personalized Word & Bigram Learning

    private static let excludedURLTokens: Set<String> = ["http", "https", "www"]
    private var sessionUnconfirmedOOVCounts: [String: Int] = [:]

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
            let existingUserFreq = self.userFrequency(of: normalizedWord)

            if !explicitlyConfirmed {
                // Never learn an unconfirmed word that has a dominant diacritic autocorrection (e.g. "qirim" -> "qırım").
                if self.diacriticCorrection(for: normalizedWord, over: baseFreq > 0 ? baseFreq : nil) != nil {
                    return
                }
                if baseFreq == 0 {
                    // Never learn an unconfirmed prefix fragment or 1-edit typo that has an isAutocorrect suggestion.
                    let prefixMatches = self.fetchWordsStartingWith(prefix: normalizedWord, limit: 8)
                    if self.shortCompletion(for: normalizedWord, in: prefixMatches) != nil {
                        return
                    }
                    if prefixMatches.isEmpty, self.typoCorrection(for: normalizedWord) != nil {
                        return
                    }
                    // Out-of-vocabulary words (!isKnownInBundledDB) require either explicit confirmation
                    // or repeated input (newCount >= 2) before entering user_unigrams.
                    if existingUserFreq == 0 {
                        let newCount = (self.sessionUnconfirmedOOVCounts[normalizedWord] ?? 0) + 1
                        self.sessionUnconfirmedOOVCounts[normalizedWord] = newCount
                        guard newCount >= 2 else { return }
                    }
                }
            }

            let effectivePrev: String? = {
                guard let normalizedPrev else { return nil }
                let prevBaseFreq = self.bundledFrequency(of: normalizedPrev)
                if prevBaseFreq > 0 || self.userFrequency(of: normalizedPrev) > 0 {
                    return normalizedPrev
                }
                if let canonicalPrev = self.diacriticCorrection(for: normalizedPrev, over: nil) {
                    return canonicalPrev.lowercased(with: Self.casingLocale)
                }
                return nil
            }()
            let isNewUserWord = (existingUserFreq == 0)
            self.recordLearnedEntry(word: normalizedWord, previousWord: effectivePrev, timestamp: now)
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
        databaseQueue.sync {
            sessionUnconfirmedOOVCounts.removeValue(forKey: normalized)
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
        databaseQueue.async { [weak self] in
            guard let self else { return }
            self.sessionUnconfirmedOOVCounts.removeAll()
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
                Autocomplete.Suggestion(
                    text: formatWord(
                        $0,
                        capitalize: shouldCapitalize,
                        isAllCaps: isAllCaps,
                        contextWords: contextWords
                    )
                )
            }
        }
    }

    func suggestions(
        for text: String,
        shouldCapitalize: Bool,
        contextWords: [String] = []
    ) -> [Autocomplete.Suggestion] {
        databaseQueue.sync {
            ensureDB()

            if text.isEmpty {
                return fetchPopularWords(limit: 3).map {
                    Autocomplete.Suggestion(text: formatWord($0, capitalize: shouldCapitalize))
                }
            }

            let effectiveQuery: String = {
                if text.unicodeScalars.contains(where: { (0x0400...0x04FF).contains($0.value) }) {
                    let transliterated = CrimeanTatarTransliterator.transliterate(
                        text,
                        ukrainianLayout: KeyboardPreferences.ukrainianCyrillicLayoutEnabled
                    )
                    return transliterated.isEmpty ? text : transliterated
                }
                return text
            }()

            let isAllCaps = effectiveQuery.count > 1 && effectiveQuery == effectiveQuery.uppercased(with: Self.casingLocale)
            var matches = fetchWordsStartingWith(prefix: effectiveQuery, limit: 12)
            let queryLower = effectiveQuery.lowercased(with: Self.casingLocale)
            let prevWordRaw = contextWords.last
            let prevLower = prevWordRaw?.lowercased(with: Self.casingLocale)

            // Contextual multi-token replacements (question particle -mı/-mi and space-separated hyphenated words)
            if let prevRaw = prevWordRaw, let prevLower, prevLower.count >= 2 {
                if ["mı", "mi", "mu", "mü"].contains(queryLower),
                   !["ve", "da", "de", "ki", "ya", "hem", "amma", "lâkin"].contains(prevLower),
                   !prevLower.hasSuffix("mı"), !prevLower.hasSuffix("mi") {
                    let isBack = lastVowelIsBack(in: prevLower) ?? true
                    let particle = isBack ? "mı" : "mi"
                    let joinedSuffix = isAllCaps ? particle.uppercased(with: Self.casingLocale) : particle
                    let joinedWord = prevRaw + joinedSuffix
                    let replaceCount = prevRaw.count + 1 + text.count
                    var particleResult: [Autocomplete.Suggestion] = [
                        .init(text: text, isUnknown: true),
                        .init(
                            text: joinedWord,
                            title: joinedWord,
                            isAutocorrect: true,
                            additionalInfo: ["replaceCharCount": replaceCount]
                        )
                    ]
                    if let thirdMatch = matches.first(where: { $0.lowercased(with: Self.casingLocale) != queryLower }) {
                        particleResult.append(.init(text: formatWord(thirdMatch, capitalize: shouldCapitalize, isAllCaps: isAllCaps)))
                    }
                    return particleResult
                }

                if !queryLower.contains("-"), queryLower.count >= 2, prevLower != "bir" {
                    let hyphenPrefix = "\(prevLower)-\(queryLower)"
                    let hyphenMatches = fetchWordsStartingWith(prefix: hyphenPrefix, limit: 1)
                    if let matchedHyphen = hyphenMatches.first {
                        let mhLower = matchedHyphen.lowercased(with: Self.casingLocale)
                        if mhLower == hyphenPrefix || (queryLower.count >= 3 && mhLower.hasPrefix(hyphenPrefix)) {
                            let capFirst = prevRaw.first?.isUppercase == true || shouldCapitalize
                            let formattedHyphen = formatWord(matchedHyphen, capitalize: capFirst, isAllCaps: isAllCaps)
                            let replaceCount = prevRaw.count + 1 + text.count
                            var hyphenResult: [Autocomplete.Suggestion] = [
                                .init(text: text, isUnknown: true),
                                .init(
                                    text: formattedHyphen,
                                    title: formattedHyphen,
                                    isAutocorrect: true,
                                    additionalInfo: ["replaceCharCount": replaceCount]
                                )
                            ]
                            if let thirdMatch = matches.first {
                                hyphenResult.append(.init(text: formatWord(thirdMatch, capitalize: shouldCapitalize, isAllCaps: isAllCaps)))
                            }
                            return hyphenResult
                        }
                    }
                }
            }

            if let prevWord = prevLower, !prevWord.isEmpty {
                var bigramMap: [String: Int] = [:]
                for (w2, f) in fetchUserBigrams(after: prevWord, limit: 8) {
                    bigramMap[w2.lowercased(with: Self.casingLocale)] = f * 2500
                }
                for (w2, f) in fetchNextWordsWithFrequency(after: prevWord, minFrequency: 1, limit: 16) {
                    let k = w2.lowercased(with: Self.casingLocale)
                    bigramMap[k] = max(bigramMap[k] ?? 0, f * 20)
                }
                applyGrammaticalReranking(lastWord: prevWord, into: &bigramMap)
                if !bigramMap.isEmpty {
                    matches.sort { lhs, rhs in
                        let lKey = lhs.lowercased(with: Self.casingLocale)
                        let rKey = rhs.lowercased(with: Self.casingLocale)
                        if lKey == queryLower { return true }
                        if rKey == queryLower { return false }
                        let lBi = bigramMap[lKey] ?? 0
                        let rBi = bigramMap[rKey] ?? 0
                        if lBi != rBi { return lBi > rBi }
                        return false
                    }
                }
            }
            matches = Array(matches.prefix(8))

            let isKnownWord = matches.first.map { $0.lowercased(with: Self.casingLocale) == queryLower } ?? false
            let explicitFix = typoCorrectionFromDB(for: queryLower)
                ?? pronounVerbAgreementCorrection(for: queryLower, previousWord: prevLower)
                ?? (!isKnownWord ? harmonyOrGrammarCorrection(for: queryLower) : nil)

            var result: [Autocomplete.Suggestion] = []

            if let explicitFix, explicitFix != queryLower {
                result.append(.init(text: text, isUnknown: true))
                result.append(.init(
                    text: formatWord(explicitFix, capitalize: shouldCapitalize, isAllCaps: isAllCaps, contextWords: contextWords),
                    isAutocorrect: true
                ))
            } else if isKnownWord, let known = matches.first {
                // A valid word is not replaced, except for a casing fix (shift state / sentence start)
                // or when its diacritic form in the bundled dictionary is overwhelmingly more common (qirim → qırım).
                let knownFormatted = formatWord(known, capitalize: shouldCapitalize, isAllCaps: isAllCaps, contextWords: contextWords)
                let baseFreq = bundledFrequency(of: queryLower)
                if let dominant = diacriticCorrection(for: queryLower, over: baseFreq > 0 ? baseFreq : nil) {
                    result.append(.init(text: text, isUnknown: true))
                    result.append(.init(
                        text: formatWord(dominant, capitalize: shouldCapitalize, isAllCaps: isAllCaps, contextWords: contextWords),
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
                // Compare frequency of diacritics-restored candidate vs short prefix completion so high-frequency
                // completions (e.g. "nasıl" for "nası") are not shadowed by rare diacritic variants ("naşı").
                let diacritic = diacriticCorrection(for: queryLower)
                let completion = shortCompletion(for: queryLower, in: matches)
                let correction: String? = {
                    if let d = diacritic, let c = completion {
                        let dFreq = frequency(of: d.lowercased(with: Self.casingLocale))
                        let cFreq = frequency(of: c.lowercased(with: Self.casingLocale))
                        return (cFreq > dFreq) ? c : d
                    }
                    return diacritic ?? completion ?? (matches.isEmpty ? typoCorrection(for: queryLower) : nil)
                }()
                result.append(.init(text: text, isUnknown: true))
                if let correction {
                    result.append(.init(
                        text: formatWord(correction, capitalize: shouldCapitalize, isAllCaps: isAllCaps, contextWords: contextWords),
                        isAutocorrect: true
                    ))
                }
            }

            let used = Set(result.map { $0.text.lowercased(with: Self.casingLocale) })
            var usedKeys = used
            for match in matches {
                guard result.count < 3 else { break }
                let formatted = formatWord(match, capitalize: shouldCapitalize, isAllCaps: isAllCaps, contextWords: contextWords)
                let key = formatted.lowercased(with: Self.casingLocale)
                guard !usedKeys.contains(key) else { continue }
                usedKeys.insert(key)
                result.append(.init(text: formatted))
            }

            return Array(result.prefix(3))
        }
    }

    // MARK: - Swipe-to-Type (Glide Typing)

    private static let baseCharacterMap: [Character: Character] = [
        "â": "a", "ç": "c", "ğ": "g", "ı": "i", "î": "i",
        "ñ": "n", "ö": "o", "ş": "s", "ü": "u", "û": "u"
    ]

    private static let cyrillicToLatinSwipeMap: [Character: [Character]] = [
        "а": ["a"], "б": ["b"], "в": ["v"], "г": ["g", "ğ"], "ґ": ["g", "ğ"], "д": ["d"],
        "е": ["e"], "є": ["e"], "ё": ["o"], "ж": ["j", "c"], "з": ["z"], "и": ["i"],
        "і": ["i"], "ї": ["y", "i"], "й": ["y"], "к": ["q", "k"], "л": ["l"], "м": ["m"],
        "н": ["n"], "о": ["o"], "п": ["p"], "р": ["r"], "с": ["s"], "т": ["t"],
        "у": ["u"], "ф": ["f"], "х": ["h"], "ц": ["s", "t"], "ч": ["c"],
        "ш": ["s"], "щ": ["s"], "ы": ["i"], "э": ["e"], "ю": ["u"],
        "я": ["a"]
    ]

    private static let cyrillicVowelOrSign: Set<Character> = [
        "а", "е", "є", "ё", "и", "і", "ї", "о", "у", "ы", "э", "ю", "я", "ъ", "ь"
    ]

    private static let qwertyNeighbors: [Character: Set<Character>] = [
        "q": ["w", "a"],
        "w": ["q", "e", "a", "s"],
        "e": ["w", "r", "s", "d"],
        "r": ["e", "t", "d", "f"],
        "t": ["r", "y", "f", "g"],
        "y": ["t", "u", "g", "h"],
        "u": ["y", "i", "h", "j"],
        "i": ["u", "o", "j", "k"],
        "o": ["i", "p", "k", "l"],
        "p": ["o", "l"],
        "a": ["q", "w", "s", "z"],
        "s": ["w", "e", "a", "d", "z", "x"],
        "d": ["e", "r", "s", "f", "x", "c"],
        "f": ["r", "t", "d", "g", "c", "v"],
        "g": ["t", "y", "f", "h", "v", "b"],
        "h": ["y", "u", "g", "j", "b", "n"],
        "j": ["u", "i", "h", "k", "n", "m"],
        "k": ["i", "o", "j", "l", "m"],
        "l": ["o", "p", "k"],
        "z": ["a", "s", "x"],
        "x": ["s", "d", "z", "c"],
        "c": ["d", "f", "x", "v"],
        "v": ["f", "g", "c", "b"],
        "b": ["g", "h", "v", "n"],
        "n": ["h", "j", "b", "m"],
        "m": ["j", "k", "n"]
    ]

    private static func normalizeBaseChar(_ ch: Character) -> Character {
        baseCharacterMap[ch] ?? ch
    }

    /// Matches a swipe key sequence (from iPhone or iPad Floating keyboard) to top dictionary candidates.
    func matchSwipePath(
        keySequence: [String],
        isCyrillic: Bool = false,
        shouldCapitalize: Bool = false,
        contextWords: [String] = []
    ) -> [Autocomplete.Suggestion] {
        databaseQueue.sync {
            ensureDB()
            var basePath: [Character] = []
            var startCandidates: [Character] = []
            var endCandidates = Set<Character>()
            let lowerKeys: [Character] = keySequence.compactMap {
                $0.lowercased(with: Self.casingLocale).first
            }

            if isCyrillic, lowerKeys.first == "д", lowerKeys.prefix(3).contains("ж") {
                startCandidates.append("c")
            }

            var prevCyrChar: Character?
            for (idx, ch) in lowerKeys.enumerated() {
                if isCyrillic {
                    if ch == "ъ" || ch == "ь" {
                        prevCyrChar = ch
                        continue
                    }
                    if ch == "д", idx == 0, lowerKeys.dropFirst().prefix(2).contains("ж") {
                        prevCyrChar = ch
                        continue
                    }
                    var mapped = Self.cyrillicToLatinSwipeMap[ch] ?? []
                    let isWordStartOrAfterVowel = basePath.isEmpty || (prevCyrChar.map { Self.cyrillicVowelOrSign.contains($0) } ?? false)
                    if isWordStartOrAfterVowel {
                        if ch == "ё" { mapped = ["y", "o"] }
                        else if ch == "ю" { mapped = ["y", "u"] }
                        else if ch == "я" { mapped = ["y", "a"] }
                    }
                    if !mapped.isEmpty {
                        if startCandidates.isEmpty {
                            startCandidates = mapped
                        } else if basePath.isEmpty {
                            for m in mapped where !startCandidates.contains(m) {
                                startCandidates.append(m)
                            }
                        }
                        endCandidates = Set(mapped.map { Self.normalizeBaseChar($0) })
                        for m in mapped {
                            let b = Self.normalizeBaseChar(m)
                            if basePath.last != b {
                                basePath.append(b)
                            }
                        }
                    }
                    prevCyrChar = ch
                } else if ch.isLetter {
                    let b = Self.normalizeBaseChar(ch)
                    if startCandidates.isEmpty {
                        startCandidates = [ch, b]
                    }
                    endCandidates = [b]
                    if basePath.last != b {
                        basePath.append(b)
                    }
                }
            }

            guard basePath.count >= 2, let firstBase = basePath.first, let lastBase = basePath.last else {
                return []
            }
            if endCandidates.isEmpty {
                endCandidates.insert(lastBase)
            }

            var prefixes = Set<String>()
            for sc in startCandidates {
                let b = Self.normalizeBaseChar(sc)
                prefixes.insert(String(b))
                for variant in Self.diacriticForms[b] ?? [] {
                    prefixes.insert(String(variant))
                }
            }
            prefixes.insert(String(firstBase))
            for variant in Self.diacriticForms[firstBase] ?? [] {
                prefixes.insert(String(variant))
            }

            let minLen = max(2, min(4, basePath.count - 1))
            let maxLen = min(22, basePath.count + 5)
            var lastNeighbors = Set<Character>()
            for ec in endCandidates {
                lastNeighbors.formUnion(Self.qwertyNeighbors[ec] ?? [])
            }

            var bigramBoosts: [String: Int] = [:]
            if let prev = contextWords.last?.lowercased(with: Self.casingLocale), !prev.isEmpty {
                for (w2, freq) in fetchUserBigrams(after: prev, limit: 12) {
                    bigramBoosts[w2.lowercased(with: Self.casingLocale)] = freq * 2500
                }
                for (w2, freq) in fetchNextWordsWithFrequency(after: prev, minFrequency: 1, limit: 24) {
                    let k = w2.lowercased(with: Self.casingLocale)
                    bigramBoosts[k] = max(bigramBoosts[k] ?? 0, freq * 20)
                }
                applyGrammaticalReranking(lastWord: prev, into: &bigramBoosts)
            }

            var candidatePool: [(word: String, freq: Int)] = []
            var seenWords = Set<String>()
            for prefix in prefixes {
                for (uw, ufreq) in fetchUserWordsStartingWith(prefix: prefix, limit: 60) {
                    let k = uw.lowercased(with: Self.casingLocale)
                    if seenWords.insert(k).inserted {
                        candidatePool.append((uw, ufreq * 600))
                    }
                }
                for (bw, bfreq) in fetchSwipeCandidatesStartingWith(
                    prefix: prefix,
                    minLen: minLen,
                    maxLen: maxLen,
                    limit: 320
                ) {
                    let k = bw.lowercased(with: Self.casingLocale)
                    if seenWords.insert(k).inserted {
                        candidatePool.append((bw, bfreq))
                    }
                }
            }

            var scoredCandidates: [(word: String, score: Double)] = []
            for (word, freq) in candidatePool {
                let lower = word.lowercased(with: Self.casingLocale)
                guard !lower.contains(" ") else { continue }
                var wordBase: [Character] = []
                for ch in lower {
                    if ch == "-" { continue }
                    let b = Self.normalizeBaseChar(ch)
                    if wordBase.last != b {
                        wordBase.append(b)
                    }
                }
                guard wordBase.count >= 2, let wordLast = wordBase.last else { continue }

                let exactLast = endCandidates.contains(wordLast)
                let neighborLast = !exactLast && lastNeighbors.contains(wordLast)
                guard exactLast || neighborLast else { continue }

                // Check ordered subsequence match of inner characters along basePath (allowing up to 1 neighbor/skipped char)
                var pathIdx = 0
                var exactHits = 0
                var neighborHits = 0
                var misses = 0

                for (i, targetChar) in wordBase.enumerated() {
                    if i == 0 {
                        exactHits += 1
                        pathIdx = 1
                        continue
                    }
                    if i == wordBase.count - 1 {
                        if exactLast { exactHits += 1 } else { neighborHits += 1 }
                        continue
                    }
                    var foundExact = false
                    var searchIdx = pathIdx
                    while searchIdx < basePath.count {
                        if basePath[searchIdx] == targetChar {
                            foundExact = true
                            pathIdx = searchIdx + 1
                            exactHits += 1
                            break
                        }
                        searchIdx += 1
                    }
                    if !foundExact {
                        let targetNeighbors = Self.qwertyNeighbors[targetChar] ?? []
                        var foundNeighbor = false
                        var nIdx = pathIdx
                        while nIdx < basePath.count {
                            if targetNeighbors.contains(basePath[nIdx]) {
                                foundNeighbor = true
                                pathIdx = nIdx + 1
                                neighborHits += 1
                                break
                            }
                            nIdx += 1
                        }
                        if !foundNeighbor {
                            misses += 1
                            let maxAllowedMisses = wordBase.count <= 3 ? 0 : max(1, (wordBase.count - 1) / 2)
                            if misses > maxAllowedMisses {
                                break
                            }
                        }
                    }
                }

                let maxAllowedMisses = wordBase.count <= 3 ? 0 : max(1, (wordBase.count - 1) / 2)
                guard misses <= maxAllowedMisses else { continue }

                let coverage = Double(exactHits) + Double(neighborHits) * 0.65 - Double(misses) * 1.65
                let coverageRatio = coverage / Double(max(1, wordBase.count))
                let matchedKeyBonus = min(Double(exactHits) * 0.95 + Double(neighborHits) * 0.40, 7.5)
                let shortWordDetourPenalty: Double = (basePath.count >= 4 && wordBase.count <= 2) ? 2.5 : 0.0
                let lengthPenalty = Double(max(0, wordBase.count - basePath.count)) * 0.55
                    + Double(max(0, basePath.count - wordBase.count)) * 0.02
                let endBonus = exactLast ? 2.5 : 0.4
                let contextFreq = bigramBoosts[lower] ?? 0
                let freqScore = log10(Double(max(1, freq + contextFreq)) + 1.35) * 1.35
                let totalScore = (coverageRatio * 6.0) + matchedKeyBonus + endBonus + freqScore - lengthPenalty - shortWordDetourPenalty
                scoredCandidates.append((word, totalScore))
            }

            scoredCandidates.sort { lhs, rhs in
                if abs(lhs.score - rhs.score) > 0.001 {
                    return lhs.score > rhs.score
                }
                return lhs.word < rhs.word
            }

            return scoredCandidates.prefix(3).enumerated().map { idx, item in
                Autocomplete.Suggestion(
                    text: formatWord(item.word, capitalize: shouldCapitalize, contextWords: contextWords),
                    isAutocorrect: idx == 0
                )
            }
        }
    }

    private func fetchSwipeCandidatesStartingWith(
        prefix: String,
        minLen: Int,
        maxLen: Int,
        limit: Int
    ) -> [(String, Int)] {
        guard let db else { return [] }
        var results: [(String, Int)] = []
        var stmt: OpaquePointer?
        let query = """
        SELECT word, freq FROM words
        WHERE word >= ?1 AND word < ?2
          AND freq >= 3
          AND length(word) BETWEEN ?3 AND ?4
          AND instr(word, ' ') = 0
        ORDER BY freq DESC
        LIMIT ?5;
        """
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK,
              bindText(stmt, index: 1, value: prefix),
              bindText(stmt, index: 2, value: prefix + "\u{FFFF}"),
              sqlite3_bind_int(stmt, 3, Int32(minLen)) == SQLITE_OK,
              sqlite3_bind_int(stmt, 4, Int32(maxLen)) == SQLITE_OK,
              sqlite3_bind_int(stmt, 5, Int32(limit)) == SQLITE_OK else {
            return []
        }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let wordPtr = sqlite3_column_text(stmt, 0) {
                results.append((String(cString: wordPtr), Int(sqlite3_column_int(stmt, 1))))
            }
        }
        return results
    }

    // MARK: - Autocorrect & Crimean Tatar Grammar / Harmony Rules

    private static let lettersForTypos = Array("abcçdefgğhıijklmnñoöpqrsştuüvwxyzâîû")
    private static let diacriticForms: [Character: [Character]] = [
        "a": ["â"], "c": ["ç"], "g": ["ğ"], "i": ["ı"], "n": ["ñ"],
        "o": ["ö"], "s": ["ş"], "u": ["ü", "û"]
    ]
    private static let backVowels: Set<Character> = ["a", "ı", "o", "u", "â", "û"]
    private static let frontVowels: Set<Character> = ["e", "i", "ö", "ü", "î"]
    private static let voicelessConsonants: Set<Character> = ["p", "f", "k", "ç", "t", "ş", "s", "h", "q"]
    private static let frontHarmonyLoanStems: Set<String> = [
        "teatr", "qalb", "vals", "harf", "iştirak", "kontrol", "misal",
        "rol", "bahar", "lager", "parol", "ansambl", "festival",
        "sentâbr", "oktâbr", "noyabr", "dekabr", "kemal", "hal", "emal"
    ]
    private static let nonVoicingStems: Set<String> = [
        "halq", "sepet", "ağaç", "bulut", "oyun", "torun", "huquq",
        "ittifaq", "ahlâq", "şarq", "garb", "millet", "devlet", "saat",
        "sanat", "sıfat", "edebiyat", "malümat", "tabiat", "cemaat", "hayat"
    ]
    private static let voicingMonosyllabicPStems: Set<String> = [
        "cep", "tüp", "qap", "köp"
    ]

    /// Instant lookup in `typo_corrections` table populated from NKKM `lat_diff.csv` and `grammar.xml` syncope rules.
    private func typoCorrectionFromDB(for queryLower: String) -> String? {
        guard let db, queryLower.count >= 3 else { return nil }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "SELECT correction FROM typo_corrections WHERE typo = ?1 LIMIT 1;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              bindText(stmt, index: 1, value: queryLower),
              sqlite3_step(stmt) == SQLITE_ROW,
              let ptr = sqlite3_column_text(stmt, 0) else {
            return nil
        }
        return String(cString: ptr)
    }

    /// Pronoun + personal verb agreement (e.g., `men yaptı -> men yaptım`, `sen yaptı -> sen yaptıñ`, `biz yaptı -> biz yaptıq`, `siz yaptı -> siz yaptıñız`).
    private func pronounVerbAgreementCorrection(for queryLower: String, previousWord: String?) -> String? {
        guard let prev = previousWord,
              ["men", "sen", "biz", "siz"].contains(prev),
              queryLower.count >= 4 else {
            return nil
        }
        let nonVerbExcluded: Set<String> = ["altı", "yedi", "endı", "indi", "yahşı", "kibi", "vaqtı", "ağzı"]
        if nonVerbExcluded.contains(queryLower) { return nil }

        for pastSuffix in ["dı", "di", "tı", "ti"] where queryLower.hasSuffix(pastSuffix) {
            let stem = String(queryLower.dropLast(2))
            guard stem.count >= 2 else { break }
            let isBack = pastSuffix.contains("ı")
            let candidate: String
            switch prev {
            case "men": candidate = queryLower + "m"
            case "sen": candidate = queryLower + "ñ"
            case "biz": candidate = queryLower + (isBack ? "q" : "k")
            case "siz": candidate = queryLower + (isBack ? "ñız" : "ñiz")
            default: return nil
            }
            let inf = stem + (isBack ? "maq" : "mek")
            if frequency(of: candidate) > 0 || bundledFrequency(of: inf) > 0 {
                return candidate
            }
            break
        }
        return nil
    }

    /// Applies official Crimean Tatar morphological & phonological rules from NKKM `Language Tools/grammar.xml`
    /// and online `community.languagetool.org/rule/list?lang=crh` (`LanguageTool 6.8-SNAPSHOT`):
    /// 0. `TOPONOMY_TYPOS` (`Qrım*` -> `Qırım*`)
    /// 1. `PLURAL_AFFIX_CONFUSION` (`-lar` vs `-ler` vowel harmony)
    /// 2. `DATIVE_AFFIX_CONFUSION` (`-ğa/-ge/-qa/-ke` vowel + consonant voicing harmony)
    /// 3. `CONFIRMATION_AFFIX_CONFUSION` (`-dır/-dir/-tır/-tir` consonant voicing harmony)
    /// 4. `LASTING_ADVERB_AFFIX` (`-ğanca/-gence/-qanca/-kence` vowel + consonant voicing harmony)
    /// 5. `MISSVOCALIZATION` (`q->ğ`, `k->g`, `p->b` voicing before possessive & case vowel suffixes)
    private func harmonyOrGrammarCorrection(for queryLower: String) -> String? {
        guard queryLower.count >= 4 else { return nil }

        // 0. TOPONOMY_TYPOS (Qrım* -> Qırım*)
        if queryLower.hasPrefix("qrım") {
            return "qırım" + String(queryLower.dropFirst(4))
        }

        // Dictionary protection: never overwrite a word already verified in the bundled dictionary (freq >= 2)
        if bundledFrequency(of: queryLower) >= 2 {
            return nil
        }

        // 0b. Attached rounded question particle (-mu / -mü -> -mı / -mi, § 2 п. 1, § 67 п. 3.1)
        if queryLower.count >= 5 && (queryLower.hasSuffix("mu") || queryLower.hasSuffix("mü")) {
            let stem = String(queryLower.dropLast(2))
            if let isBack = lastVowelIsBack(in: stem), frequency(of: stem) >= 5 {
                return stem + (isBack ? "mı" : "mi")
            }
        }

        // 1. Plural suffix vowel harmony (-lar <-> -ler)
        if queryLower.count >= 5 && (queryLower.hasSuffix("lar") || queryLower.hasSuffix("ler")) {
            let stem = String(queryLower.dropLast(3))
            if let isBack = lastVowelIsBack(in: stem) {
                let expected = isBack ? "lar" : "ler"
                if !queryLower.hasSuffix(expected) {
                    let candidate = stem + expected
                    if frequency(of: candidate) > 0 || frequency(of: stem) >= 5 {
                        return candidate
                    }
                }
            }
        }

        // 2. Dative suffix harmony (-ğa / -ge / -qa / -ke)
        for suffix in ["ğa", "ge", "qa", "ke"] where queryLower.hasSuffix(suffix) {
            let stem = String(queryLower.dropLast(2))
            guard stem.count >= 2, let lastChar = stem.last, let isBack = lastVowelIsBack(in: stem) else { break }
            let isVoiceless = Self.voicelessConsonants.contains(lastChar)
            let expected: String
            switch (isBack, isVoiceless) {
            case (true, true): expected = "qa"
            case (false, true): expected = "ke"
            case (true, false): expected = "ğa"
            case (false, false): expected = "ge"
            }
            if suffix != expected {
                let candidate = stem + expected
                if frequency(of: candidate) > 0 || frequency(of: stem) >= 5 {
                    return candidate
                }
            }
            break
        }

        // 3. Confirmation suffix harmony (-dır / -dir / -tır / -tir)
        if queryLower.count >= 5 {
            for suffix in ["dır", "dir", "tır", "tir"] where queryLower.hasSuffix(suffix) {
                let stem = String(queryLower.dropLast(3))
                guard stem.count >= 2, let lastChar = stem.last, let isBack = lastVowelIsBack(in: stem) else { break }
                let isVoiceless = Self.voicelessConsonants.contains(lastChar)
                let expected: String
                switch (isBack, isVoiceless) {
                case (true, true): expected = "tır"
                case (false, true): expected = "tir"
                case (true, false): expected = "dır"
                case (false, false): expected = "dir"
                }
                if suffix != expected {
                    let candidate = stem + expected
                    if frequency(of: candidate) > 0 || frequency(of: stem) >= 5 {
                        return candidate
                    }
                }
                break
            }
        }

        // 4. LASTING_ADVERB_AFFIX (-ğanca / -gence / -qanca / -kence)
        if queryLower.count >= 7 {
            for suffix in ["ğanca", "gence", "qanca", "kence"] where queryLower.hasSuffix(suffix) {
                let stem = String(queryLower.dropLast(5))
                guard stem.count >= 2, let lastChar = stem.last, let isBack = lastVowelIsBack(in: stem) else { break }
                let isVoiceless = Self.voicelessConsonants.contains(lastChar)
                let expected: String
                switch (isBack, isVoiceless) {
                case (true, true): expected = "qanca"
                case (false, true): expected = "kence"
                case (true, false): expected = "ğanca"
                case (false, false): expected = "gence"
                }
                if suffix != expected {
                    return stem + expected
                }
                break
            }
        }

        // 5. MISSVOCALIZATION: Voicing of stem-final q/k/p before possessive & case vowel suffixes (q->ğ, k->g, p->b)
        let missvocalizationSuffixes = [
            "ımızda", "imizde", "umızda", "ümizde",
            "ıñnıñ", "iñniñ",
            "ından", "inden", "undan", "ünden",
            "ımız", "imiz", "umız", "ümiz",
            "ıñız", "iñiz", "uñız", "üñiz",
            "ında", "inde", "unda", "ünde",
            "ına", "ine", "una", "üne",
            "ını", "ini", "unı", "ünü",
            "ım", "im", "um", "üm",
            "ıñ", "iñ", "uñ", "üñ",
            "ı", "i", "u", "ü"
        ]
        for possSuffix in missvocalizationSuffixes {
            if queryLower.hasSuffix(possSuffix) {
                let stem = String(queryLower.dropLast(possSuffix.count))
                guard stem.count >= 3, !Self.nonVoicingStems.contains(stem), let stemLast = stem.last else { continue }
                if stemLast == "p" && stem.count == 3 && !Self.voicingMonosyllabicPStems.contains(stem) {
                    continue
                }
                let voicedChar: Character? = {
                    switch stemLast {
                    case "q": return "ğ"
                    case "k": return "g"
                    case "p": return "b"
                    default: return nil
                    }
                }()
                if let voicedChar {
                    let candidate = String(stem.dropLast()) + String(voicedChar) + possSuffix
                    if (frequency(of: candidate) > frequency(of: queryLower) * 3 && frequency(of: candidate) >= 5)
                        || (possSuffix.count >= 3 && frequency(of: stem) >= 5) {
                        return candidate
                    }
                }
            }
        }

        return nil
    }

    private func lastVowelIsBack(in stem: String) -> Bool? {
        if Self.frontHarmonyLoanStems.contains(stem) {
            return false
        }
        for ch in stem.reversed() {
            if Self.backVowels.contains(ch) { return true }
            if Self.frontVowels.contains(ch) { return false }
        }
        return nil
    }

    /// A completion is auto-applied only if it adds at most two letters to a word of 3+ letters,
    /// or completes a hyphenated word stem (e.g. `gece-` -> `gece-kündüz`).
    private func shortCompletion(for queryLower: String, in matches: [String]) -> String? {
        guard queryLower.count >= 3, let best = matches.first else { return nil }
        let bestLower = best.lowercased(with: Self.casingLocale)
        guard bestLower.hasPrefix(queryLower) else { return nil }
        let maxExtra = queryLower.contains("-") ? 12 : 2
        guard bestLower.count - queryLower.count <= maxExtra else { return nil }
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
        guard sqlite3_prepare_v2(db, "SELECT freq FROM words WHERE word = ?1 LIMIT 1;", -1, &stmt, nil) == SQLITE_OK else {
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

    private static let properCollocationSecondWord: [String: [String: String]] = [
        "qırım": [
            "musulman": "Musulman",
            "muhtar": "Muhtar",
            "hanlığı": "Hanlığı",
            "yarımadası": "Yarımadası",
            "devlet": "Devlet"
        ],
        "ukrayina": [
            "nazirler": "Nazirler",
            "cumhuriyeti": "Cumhuriyeti"
        ],
        "ğafur": [
            "ğulam": "Ğulam"
        ],
        "ismail": [
            "gasprinskiy": "Gasprinskiy"
        ],
        "noman": [
            "çelebicihan": "Çelebicihan"
        ],
        "bekir": [
            "çobanzade": "Çobanzade"
        ]
    ]

    private static let properCollocationThirdWord: [String: [String: String]] = [
        "qırım musulman": [
            "icra": "İcra",
            "komiteti": "Komiteti"
        ],
        "musulman icra": [
            "komiteti": "Komiteti"
        ],
        "qırım muhtar": [
            "cumhuriyeti": "Cumhuriyeti"
        ],
        "ukrayina nazirler": [
            "kabineti": "Kabineti"
        ]
    ]

    private func properNounCasing(for wordLower: String, contextWords: [String]) -> String? {
        guard !contextWords.isEmpty else { return nil }
        let normalizedContext = contextWords.map { $0.lowercased(with: Self.casingLocale) }
        if normalizedContext.count >= 2 {
            let lastTwo = "\(normalizedContext[normalizedContext.count - 2]) \(normalizedContext[normalizedContext.count - 1])"
            if let match = Self.properCollocationThirdWord[lastTwo]?[wordLower] {
                return match
            }
        }
        if let lastOne = normalizedContext.last,
           let match = Self.properCollocationSecondWord[lastOne]?[wordLower] {
            return match
        }
        return nil
    }

    private func formatWord(
        _ word: String,
        capitalize: Bool,
        isAllCaps: Bool = false,
        contextWords: [String] = []
    ) -> String {
        if isAllCaps {
            return word.uppercased(with: Self.casingLocale)
        }
        let lower = word.lowercased(with: Self.casingLocale)
        if let proper = properNounCasing(for: lower, contextWords: contextWords) {
            return proper
        }
        if capitalize {
            guard let first = word.first else { return word }
            let firstChar = String(first).uppercased(with: Self.casingLocale)
            let rest = String(word.dropFirst()).lowercased(with: Self.casingLocale)
            return firstChar + rest
        }
        return lower
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
        if scores.count < 6, let lastWord = normalized.last {
            addBigramContinuations(after: lastWord, minFrequency: Self.minimumNextWordFrequency, into: &scores)
        }

        // 3.5. Apply Crimean Tatar grammatical reranking & collocation rules (from NKKM grammar.xml)
        if let lastWord = normalized.last {
            applyGrammaticalReranking(lastWord: lastWord, into: &scores)
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

    private static let cardinalNumerals: Set<String> = [
        "eki", "üç", "dört", "beş", "altı", "yedi", "sekiz", "doquz",
        "on", "yigirmi", "otuz", "qırq", "elli", "altmış", "yetmiş",
        "seksen", "doqsan", "yüz", "biñ", "qaç"
    ]

    /// Reranks and enriches next-word candidates using Crimean Tatar grammar rules (`Language Tools/grammar.xml` & `community.languagetool.org`).
    private func applyGrammaticalReranking(lastWord: String, into scores: inout [String: Int]) {
        // A. Pronoun-Possessive Agreement (PERSON_COORDINATION & GENITIVE_CASE_COLLOCATION)
        let isGenitivePronoun = ["menim", "seniñ", "onıñ", "bunıñ", "şunıñ", "bizim", "siziñ", "olarnıñ"].contains(lastWord)
        if isGenitivePronoun {
            for ppos in ["içün", "kibi", "ile", "aqqında"] {
                if let existing = scores[ppos] {
                    scores[ppos] = existing * 2 + 40
                }
            }
        }
        switch lastWord {
        case "menim":
            for (cand, val) in scores {
                if cand.hasSuffix("ım") || cand.hasSuffix("im") || cand.hasSuffix("um") || cand.hasSuffix("üm") || cand.hasSuffix("m") {
                    scores[cand] = val * 3
                } else if cand.hasSuffix("ıñ") || cand.hasSuffix("iñ") || cand.hasSuffix("ıñız") || cand.hasSuffix("iñiz") {
                    scores[cand] = max(1, val / 4)
                }
            }
        case "bizim":
            for (cand, val) in scores {
                if cand.hasSuffix("ımız") || cand.hasSuffix("imiz") || cand.hasSuffix("umız") || cand.hasSuffix("ümiz") || cand.hasSuffix("mız") || cand.hasSuffix("miz") {
                    scores[cand] = val * 3
                }
            }
        case "seniñ":
            for (cand, val) in scores {
                if cand.hasSuffix("ıñ") || cand.hasSuffix("iñ") || cand.hasSuffix("uñ") || cand.hasSuffix("üñ") || cand.hasSuffix("ñ") {
                    scores[cand] = val * 3
                } else if cand.hasSuffix("ım") || cand.hasSuffix("im") {
                    scores[cand] = max(1, val / 4)
                }
            }
        case "siziñ":
            for (cand, val) in scores {
                if cand.hasSuffix("ıñız") || cand.hasSuffix("iñiz") || cand.hasSuffix("uñız") || cand.hasSuffix("üñiz") || cand.hasSuffix("ñız") || cand.hasSuffix("ñiz") {
                    scores[cand] = val * 3
                }
            }
        default:
            if lastWord == "onıñ" || lastWord == "olarnıñ" || lastWord.hasSuffix("nıñ") || lastWord.hasSuffix("niñ") {
                for (cand, val) in scores {
                    if cand.hasSuffix("sı") || cand.hasSuffix("si") || cand.hasSuffix("ı") || cand.hasSuffix("i") || cand.hasSuffix("u") || cand.hasSuffix("ü") {
                        scores[cand] = val * 2
                    }
                    if cand == "evel" {
                        scores.removeValue(forKey: cand) // grammar.xml TENSE_PARTICLE_CASE_COLLOCATION: genitive + evel is invalid
                    }
                }
            }
        }

        // B. Postposition & Verb Case Government (POSTPOSITION_CASE_COLLOCATION & VERB_CASE_COLLOCATION)
        let isDative = lastWord.count >= 4 && (
            lastWord.hasSuffix("ğa") || lastWord.hasSuffix("ge") ||
            lastWord.hasSuffix("qa") || lastWord.hasSuffix("ke") ||
            ["maña", "saña", "oña", "buna", "şuña"].contains(lastWord)
        )
        let isAblative = lastWord.count >= 4 && (
            lastWord.hasSuffix("dan") || lastWord.hasSuffix("den") ||
            lastWord.hasSuffix("tan") || lastWord.hasSuffix("ten") ||
            ["menden", "senden", "ondan", "bundan", "şundan"].contains(lastWord)
        )
        let isAccusative = lastWord.count >= 4 && (
            lastWord.hasSuffix("nı") || lastWord.hasSuffix("ni") ||
            ["meni", "seni", "onı", "bunı", "şunı"].contains(lastWord)
        )
        let isInfinitive = lastWord.count >= 5 && (lastWord.hasSuffix("maq") || lastWord.hasSuffix("mek"))

        if isDative {
            for ppos in ["qadar", "qarşı", "köre", "doğru", "taba"] {
                if let existing = scores[ppos] {
                    scores[ppos] = existing * 2 + 50
                }
            }
            for (cand, val) in scores where cand.hasPrefix("evlen") {
                scores[cand] = val * 2 + 40
            }
            for invalidPpos in ["içün", "ile", "dayın", "kibi", "aqqında"] {
                scores.removeValue(forKey: invalidPpos)
            }
        } else if isAblative {
            for ppos in ["soñ", "berli", "evel", "başqa", "ğayrı", "sebep", "burun", "ögüne"] {
                if let existing = scores[ppos] {
                    scores[ppos] = existing * 2 + 50
                }
            }
            for (cand, val) in scores where cand.hasPrefix("sora") {
                scores[cand] = val * 2 + 40
            }
            for invalidPpos in ["içün", "ile", "dayın", "kibi", "aqqında"] {
                scores.removeValue(forKey: invalidPpos)
            }
        } else if isAccusative {
            for invalidPpos in ["içün", "ile", "dayın", "kibi", "aqqında"] {
                scores.removeValue(forKey: invalidPpos)
            }
        } else if isInfinitive {
            for modal in ["kerek", "içün", "mümkün"] {
                scores[modal] = max(scores[modal] ?? 0, 120)
            }
        }

        // C. PERCENTAGE_COORDINATION (yüzde + cardinal numeral)
        if lastWord == "yüzde" {
            for num in Self.cardinalNumerals {
                if let existing = scores[num] {
                    scores[num] = existing * 3 + 60
                }
            }
        }

        // D. Cardinal Numeral + Singular Noun (NUMERAL_PLURAL_COLLOCATION)
        if Self.cardinalNumerals.contains(lastWord) {
            for (cand, val) in scores {
                if cand.count >= 5 && (cand.hasSuffix("lar") || cand.hasSuffix("ler")) {
                    scores[cand] = max(1, val / 6)
                }
            }
        }
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
        guard let db else { return [] }
        let lowerPrefix = prefix.lowercased(with: Self.casingLocale) + " "
        let upperBound = lowerPrefix + "\u{FFFF}"
        var results: [(String, Int)] = []
        var stmt: OpaquePointer?
        let query = """
            SELECT word, freq FROM words
            WHERE word >= ?1 AND word < ?2
            ORDER BY freq DESC
            LIMIT ?3;
            """
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK,
              bindText(stmt, index: 1, value: lowerPrefix),
              bindText(stmt, index: 2, value: upperBound),
              sqlite3_bind_int(stmt, 3, Int32(limit)) == SQLITE_OK else {
            return []
        }
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let wordPtr = sqlite3_column_text(stmt, 0) {
                let freq = Int(sqlite3_column_int(stmt, 1))
                results.append((String(cString: wordPtr).lowercased(with: Self.casingLocale), freq))
            }
        }
        return results
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
                let boost = (!lowercasePrefix.contains("-") && key.hasPrefix(lowercasePrefix + "-")) ? (freq * 2 + 120) : freq
                scored[key, default: 0] += boost
            }
        }

        if lowercasePrefix.count >= 3 && !lowercasePrefix.contains("-") {
            var hStmt: OpaquePointer?
            let hPrefix = lowercasePrefix + "-"
            let hQuery = "SELECT word, freq FROM words WHERE word >= ?1 AND word < ?2 AND instr(word, ' ') = 0 ORDER BY freq DESC LIMIT 2;"
            defer { sqlite3_finalize(hStmt) }
            if sqlite3_prepare_v2(db, hQuery, -1, &hStmt, nil) == SQLITE_OK,
               bindText(hStmt, index: 1, value: hPrefix),
               bindText(hStmt, index: 2, value: hPrefix + "\u{FFFF}") {
                while sqlite3_step(hStmt) == SQLITE_ROW {
                    if let wordPtr = sqlite3_column_text(hStmt, 0) {
                        let word = String(cString: wordPtr)
                        let freq = Int(sqlite3_column_int(hStmt, 1))
                        let key = word.lowercased(with: Self.casingLocale)
                        if scored[key] == nil {
                            ordered.append(word)
                            scored[key] = freq * 2 + 120
                        }
                    }
                }
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
