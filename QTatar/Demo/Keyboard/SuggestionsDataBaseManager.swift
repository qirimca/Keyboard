//
//  SuggestionsDataBaseManager.swift
//  Keyboard
//
//  Copyright © 2024 Daniel Saidi. All rights reserved.
//

import Foundation
#if canImport(KeyboardKit)
import KeyboardKit
#endif
#if canImport(Transliteration)
@testable import Transliteration
#endif
import SQLite3
#if canImport(UIKit)
import UIKit
#else
import CoreGraphics
#endif
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
                sqlite3_close_v2(db)
                self.db = nil
            }
            if let userDB {
                sqlite3_close_v2(userDB)
                self.userDB = nil
            }
        }
    }

    /// Releases non-essential SQLite page cache memory under iOS Jetsam pressure (`didReceiveMemoryWarning`).
    func releaseMemory() {
        databaseQueue.async { [weak self] in
            guard let self else { return }
            if let db = self.db {
                sqlite3_db_release_memory(db)
            }
            if let userDB = self.userDB {
                sqlite3_db_release_memory(userDB)
            }
        }
    }

    private func openDB() {
        let state = Self.signposter.beginInterval("openDB")
        defer { Self.signposter.endInterval("openDB", state) }
        let siblingURL = Bundle.main.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("Keyboard.appex/qırım_tatar.db")
        let sourceDirURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let directSiblingDB = sourceDirURL.appendingPathComponent("qırım_tatar.db")
        let testRelativeDB = sourceDirURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Keyboard/qırım_tatar.db")
        let resolvedURL = Bundle.main.url(forResource: "qırım_tatar", withExtension: "db")
            ?? (FileManager.default.fileExists(atPath: siblingURL.path) ? siblingURL : nil)
            ?? (FileManager.default.fileExists(atPath: directSiblingDB.path) ? directSiblingDB : nil)
            ?? (FileManager.default.fileExists(atPath: testRelativeDB.path) ? testRelativeDB : nil)
        guard let dbURL = resolvedURL else {
            debugPrint("Cant open DB")
            return
        }

        let immutableURI = "file:\(dbURL.path)?immutable=1"
        let uriFlags = SQLITE_OPEN_READONLY | SQLITE_OPEN_URI | SQLITE_OPEN_NOMUTEX
        let openedImmutable = (sqlite3_open_v2(immutableURI, &db, uriFlags, nil) == SQLITE_OK)
        if !openedImmutable {
            if let staleDB = db {
                sqlite3_close_v2(staleDB)
                db = nil
            }
            guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
                if let failedDB = db {
                    if let errMsg = sqlite3_errmsg(failedDB) {
                        debugPrint("Failed to open SQLite database: \(String(cString: errMsg))")
                    }
                    sqlite3_close_v2(failedDB)
                    db = nil
                } else {
                    debugPrint("Failed to open SQLite database at \(dbURL.path)")
                }
                return
            }
        }

        sqlite3_exec(db, "PRAGMA mmap_size = 25165824;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA cache_size = -256;", nil, nil, nil)
        sqlite3_exec(db, "PRAGMA temp_store = MEMORY;", nil, nil, nil)
        debugPrint("Successfully opened SQLite database (readonly, immutable, optimized) at \(dbURL.path)")
    }

    private func openUserDB() {
        let fm = FileManager.default
        let fallbackDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let containerDir: URL = {
            if let groupDir = fm.containerURL(forSecurityApplicationGroupIdentifier: AppConfiguration.appGroupID) {
                try? fm.createDirectory(at: groupDir, withIntermediateDirectories: true)
                if fm.isWritableFile(atPath: groupDir.path) {
                    return groupDir
                }
            }
            try? fm.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
            return fallbackDir
        }()
        let userDBURL = containerDir.appendingPathComponent("user_lexicon.sqlite")

        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        if sqlite3_open_v2(userDBURL.path, &userDB, flags, nil) != SQLITE_OK {
            if let failedDB = userDB {
                sqlite3_close_v2(failedDB)
                userDB = nil
            }
            if containerDir != fallbackDir {
                try? fm.createDirectory(at: fallbackDir, withIntermediateDirectories: true)
                let fallbackDBURL = fallbackDir.appendingPathComponent("user_lexicon.sqlite")
                if sqlite3_open_v2(fallbackDBURL.path, &userDB, flags, nil) != SQLITE_OK {
                    if let failedFallbackDB = userDB {
                        sqlite3_close_v2(failedFallbackDB)
                        userDB = nil
                    }
                    return
                }
            } else {
                return
            }
        }
        sqlite3_busy_timeout(userDB, 150)
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

        var userVersion: Int32 = 0
        var versionStmt: OpaquePointer?
        if sqlite3_prepare_v2(userDB, "PRAGMA user_version;", -1, &versionStmt, nil) == SQLITE_OK {
            if sqlite3_step(versionStmt) == SQLITE_ROW {
                userVersion = sqlite3_column_int(versionStmt, 0)
            }
        }
        sqlite3_finalize(versionStmt)

        if userVersion < 2 {
            let migrationSQL = """
            DELETE FROM user_bigrams WHERE word1 = word2 OR (word1 = 'ne' AND word2 = 'sen');
            DELETE FROM user_unigrams WHERE word IN ('krım', 'kırım', 'kırımda', 'kırımğa', 'kırımnıñ', 'qirim', 'qrım', 'krim', 'kirim');
            PRAGMA user_version = 2;
            """
            sqlite3_exec(userDB, migrationSQL, nil, nil, nil)
        }
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
                if self.toponymyTypoCorrection(for: normalizedWord) != nil {
                    return
                }
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
            guard !self.isSuspended else { return }
            self.ensureUserDB()
            if let userDB = self.userDB {
                sqlite3_exec(userDB, "DELETE FROM user_unigrams; DELETE FROM user_bigrams;", nil, nil, nil)
                sqlite3_close_v2(userDB)
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
                if text.unicodeScalars.contains(where: { (0x0400...0x04FF).contains($0.value) || $0.value == 0x02BC }) {
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
                let prevPrev = contextWords.count >= 2 ? contextWords[contextWords.count - 2].lowercased(with: Self.casingLocale) : nil
                applyGrammaticalReranking(previousWord: prevPrev, lastWord: prevWord, into: &bigramMap)
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
            let explicitFix = toponymyTypoCorrection(for: queryLower)
                ?? typoCorrectionFromDB(for: queryLower)
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
        "а": ["a"], "б": ["b"], "в": ["v"], "г": ["g", "ğ"], "ґ": ["g"], "д": ["d"],
        "е": ["e"], "є": ["y", "e"], "ё": ["o"], "ж": ["j", "c"], "з": ["z"], "и": ["i"],
        "і": ["i"], "ї": ["y", "i"], "й": ["y"], "к": ["q", "k"], "л": ["l"], "м": ["m"],
        "н": ["n"], "о": ["o"], "п": ["p"], "р": ["r"], "с": ["s"], "т": ["t"],
        "у": ["u"], "ф": ["f"], "х": ["h"], "ц": ["s", "t"], "ч": ["c"],
        "ш": ["s"], "щ": ["s"], "ы": ["i"], "э": ["e"], "ю": ["u"],
        "я": ["a"]
    ]

    private static let cyrillicVowelOrSign: Set<Character> = [
        "а", "е", "є", "ё", "и", "і", "ї", "о", "у", "ы", "э", "ю", "я", "ъ", "ь", "\u{02BC}", "'", "’"
    ]

    private static let baseVowels: Set<Character> = ["a", "e", "i", "o", "u"]

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

    /// Physical key adjacency on Cyrillic (`ЙЦУКЕН` / `ФІВА`) layouts projected to normalized Latin base characters.
    private static let cyrillicBaseNeighbors: [Character: Set<Character>] = [
        "a": ["v", "p", "u", "q", "k", "c", "s", "m"],
        "b": ["t", "u", "o", "l", "d"],
        "c": ["a", "s", "v", "f", "i", "d", "l", "e", "z", "h"],
        "d": ["l", "j", "c", "s", "z", "b", "u"],
        "e": ["q", "k", "n", "p", "r", "j", "c", "h"],
        "f": ["i", "y", "c"],
        "g": ["n", "s", "r", "o", "a", "f"],
        "h": ["z", "d", "j", "c", "e"],
        "i": ["f", "v", "y", "s", "t", "m", "p", "r"],
        "j": ["d", "e", "z", "h", "u"],
        "k": ["u", "e", "v", "a", "p"],
        "l": ["o", "d", "s", "b", "u"],
        "m": ["s", "i", "a", "p"],
        "n": ["e", "g", "p", "r"],
        "o": ["r", "l", "g", "s", "t", "b"],
        "p": ["a", "r", "k", "q", "e", "m", "i"],
        "q": ["u", "e", "v", "a", "p"],
        "r": ["p", "o", "e", "n", "g", "i", "t"],
        "s": ["c", "m", "v", "a", "g", "z", "o", "l", "d", "y", "u"],
        "t": ["i", "b", "r", "o", "y", "u", "v"],
        "u": ["s", "t", "q", "k", "v", "a", "b", "d", "j"],
        "v": ["i", "a", "u", "q", "k", "c", "s"],
        "y": ["s", "t", "f", "i"],
        "z": ["s", "h", "l", "d", "j", "c"]
    ]

    private static func normalizeBaseChar(_ ch: Character) -> Character {
        baseCharacterMap[ch] ?? ch
    }

    private static let cyrillicRow0RightCorridor: Set<Character> = [
        "у", "к", "е", "н", "г", "ш", "щ", "з", "х"
    ]
    private static let cyrillicRow0ReturnTransit: Set<Character> = [
        "х", "з", "щ", "ш", "г", "н", "е"
    ]
    private static let cyrillicSignChars: Set<Character> = [
        "ъ", "ь", "\u{02BC}", "'", "’"
    ]
    private static let cyrillicDigraphTriggers: Set<Character> = [
        "к", "г", "н"
    ]

    /// Canonical 12-column physical key centers (`keyWidth = 32 pt`, `rowHeight = 52 pt`) for `crh-Latn`, `ФЫВА`, and `ФІВА`,
    /// overlaid with live `keyFrames` when available from `SwipeTypingState`.
    private static func resolveKeyCenters(
        isCyrillic: Bool,
        isUkrainianCyrillic: Bool,
        keyFrames: [String: CGRect]
    ) -> (centers: [Character: CGPoint], keyWidth: CGFloat) {
        let w: CGFloat = 32.0
        let h: CGFloat = 52.0
        var centers: [Character: CGPoint] = [:]
        if !isCyrillic {
            let row0 = Array("qwertyuıopğü")
            let row1 = Array("âasdfghjklşi")
            let row2 = Array("zxcvbnmöçñ")
            for (c, ch) in row0.enumerated() { centers[ch] = CGPoint(x: (CGFloat(c) + 0.5) * w, y: 0.5 * h) }
            for (c, ch) in row1.enumerated() { centers[ch] = CGPoint(x: (CGFloat(c) + 0.5) * w, y: 1.5 * h) }
            for (c, ch) in row2.enumerated() { centers[ch] = CGPoint(x: (CGFloat(c) + 1.5) * w, y: 2.5 * h) }
        } else if isUkrainianCyrillic {
            let row0 = Array("йцукенгшщзхʼ")
            let row1 = Array("фівапролджє")
            let row2 = Array("ячсмитьбюґ")
            for (c, ch) in row0.enumerated() { centers[ch] = CGPoint(x: (CGFloat(c) + 0.5) * w, y: 0.5 * h) }
            for (c, ch) in row1.enumerated() { centers[ch] = CGPoint(x: (CGFloat(c) + 1.0) * w, y: 1.5 * h) }
            for (c, ch) in row2.enumerated() { centers[ch] = CGPoint(x: (CGFloat(c) + 1.5) * w, y: 2.5 * h) }
            centers["ъ"] = centers["ʼ"]
            centers["ы"] = centers["и"]
            centers["э"] = centers["є"]
            centers["ї"] = CGPoint(x: 11.5 * w, y: 1.5 * h)
            centers["ё"] = centers["о"]
        } else {
            let row0 = Array("йцукенгшщзхъ")
            let row1 = Array("фывапролджэ")
            let row2 = Array("ячсмитьбюё")
            for (c, ch) in row0.enumerated() { centers[ch] = CGPoint(x: (CGFloat(c) + 0.5) * w, y: 0.5 * h) }
            for (c, ch) in row1.enumerated() { centers[ch] = CGPoint(x: (CGFloat(c) + 1.0) * w, y: 1.5 * h) }
            for (c, ch) in row2.enumerated() { centers[ch] = CGPoint(x: (CGFloat(c) + 1.5) * w, y: 2.5 * h) }
            centers["ʼ"] = centers["ъ"]
            centers["і"] = centers["и"]
            centers["є"] = centers["э"]
            centers["ґ"] = centers["г"]
        }

        var widths: [CGFloat] = []
        for (k, rect) in keyFrames where rect.width > 4 && rect.height > 4 {
            if let ch = k.lowercased(with: Self.casingLocale).first {
                centers[ch] = CGPoint(x: rect.midX, y: rect.midY)
                widths.append(rect.width)
            }
        }
        let resolvedWidth: CGFloat = {
            guard !widths.isEmpty else { return w }
            let sorted = widths.sorted()
            return max(18.0, sorted[sorted.count / 2])
        }()
        return (centers, resolvedWidth)
    }

    private static func targetWordCharCenter(
        for ch: Character,
        centers: [Character: CGPoint],
        isCyrillic: Bool,
        isUkrainianCyrillic: Bool
    ) -> CGPoint? {
        if !isCyrillic {
            return centers[ch] ?? centers[normalizeBaseChar(ch)]
        }
        switch ch {
        case "a", "â": return centers["а"]
        case "b": return centers["б"]
        case "c": return centers["д"] ?? centers["ж"]
        case "ç": return centers["ч"]
        case "d": return centers["д"]
        case "e": return centers["е"]
        case "f": return centers["ф"]
        case "g": return isUkrainianCyrillic ? (centers["ґ"] ?? centers["г"]) : centers["г"]
        case "ğ": return centers["г"]
        case "h": return centers["х"]
        case "ı": return isUkrainianCyrillic ? (centers["и"] ?? centers["ы"]) : (centers["ы"] ?? centers["и"])
        case "i", "î": return isUkrainianCyrillic ? (centers["і"] ?? centers["и"]) : (centers["и"] ?? centers["ы"])
        case "j": return centers["ж"]
        case "k", "q": return centers["к"]
        case "l": return centers["л"]
        case "m": return centers["м"]
        case "n", "ñ": return centers["н"]
        case "o", "ö": return centers["о"]
        case "p": return centers["п"]
        case "r": return centers["р"]
        case "s": return centers["с"]
        case "ş": return centers["ш"]
        case "t": return centers["т"]
        case "u", "ü", "û": return centers["у"]
        case "v": return centers["в"]
        case "y": return centers["й"]
        case "z": return centers["з"]
        default: return nil
        }
    }

    private static let cyrillicRow0ColIndex: [Character: Int] = [
        "й": 0, "ц": 1, "у": 2, "к": 3, "е": 4, "н": 5, "г": 6, "ш": 7, "щ": 8, "з": 9, "х": 10
    ]

    /// Strips Row-0 transit keys (`е, н, г, ш, щ, з, х`) crossed when swiping from `к/г/н` to `ъ/ʼ` at `(Row 0, Col 11)`
    /// and records explicit digraph diacritics (`q`, `ğ`, `ñ`) so `endCandidates` and `rawKeySet` are never polluted.
    private static func cleanCyrillicSwipeSequence(
        _ rawKeys: [Character]
    ) -> (cleanedKeys: [Character], explicitDiacritics: Set<Character>, softEndBases: Set<Character>) {
        guard !rawKeys.isEmpty else { return ([], [], []) }
        var removedIndices = Set<Int>()
        var explicitDiacritics = Set<Character>()
        var softEndBases = Set<Character>()

        func recordTrigger(_ trigger: Character, isWordEnd: Bool) {
            if trigger == "к" {
                explicitDiacritics.insert("q")
                if isWordEnd { softEndBases.formUnion(["q", "k"]) }
            } else if trigger == "г" {
                explicitDiacritics.insert("ğ")
                if isWordEnd { softEndBases.insert("g") }
            } else if trigger == "н" {
                explicitDiacritics.insert("ñ")
                if isWordEnd { softEndBases.insert("n") }
            }
        }

        for (idx, ch) in rawKeys.enumerated() where cyrillicSignChars.contains(ch) {
            removedIndices.insert(idx)
            var corridorStart = idx
            var scan = idx - 1
            while scan >= 0 {
                let c = rawKeys[scan]
                if cyrillicRow0RightCorridor.contains(c) || cyrillicSignChars.contains(c) {
                    corridorStart = scan
                    scan -= 1
                } else {
                    break
                }
            }

            let isWordEnd = (idx == rawKeys.count - 1)
            let triggerIndices = (corridorStart..<idx).filter { cyrillicDigraphTriggers.contains(rawKeys[$0]) }

            if let firstTrig = triggerIndices.first {
                if corridorStart == 0 && firstTrig == 0 {
                    // Case 1: Word-initial `къ-`, `гъ-`, `нъ-` (`къар`, `къоя`, `къайдан`)
                    recordTrigger(rawKeys[0], isWordEnd: isWordEnd)
                    if idx > 1 {
                        for k in 1..<idx { removedIndices.insert(k) }
                    }
                } else {
                    // Check if the finger moved leftward inside the corridor to a turnaround trigger (e.g. `чокъ`: `о -> н -> е -> к -> е -> н -> г ... -> ъ`)
                    let startCol = cyrillicRow0ColIndex[rawKeys[corridorStart]] ?? 99
                    var minCol = startCol
                    var minTriggerIdx: Int? = nil
                    for tPos in triggerIndices {
                        let cCol = cyrillicRow0ColIndex[rawKeys[tPos]] ?? 99
                        if cCol < minCol {
                            minCol = cCol
                            minTriggerIdx = tPos
                        }
                    }

                    if let turnIdx = minTriggerIdx {
                        // Case 2: Leftward turnaround at `turnIdx` before sweeping right to `ъ`/`ʼ`
                        recordTrigger(rawKeys[turnIdx], isWordEnd: isWordEnd)
                        for k in corridorStart..<idx where k != turnIdx {
                            removedIndices.insert(k)
                        }
                    } else if rawKeys[corridorStart] == "у" {
                        // Case 3: Entered Row 0 from far-left (`ы`/`и` -> `у-к-е-н-г-ш-щ-з-х-ъ`, e.g. `онынъ`, `буларнынъ`)
                        for tPos in triggerIndices {
                            recordTrigger(rawKeys[tPos], isWordEnd: isWordEnd)
                        }
                        for k in corridorStart..<idx {
                            let kc = rawKeys[k]
                            if ["у", "е", "ш", "щ", "з", "х"].contains(kc) {
                                removedIndices.insert(k)
                            } else if kc == "г", k > corridorStart, rawKeys[corridorStart..<k].contains("н") {
                                removedIndices.insert(k)
                            }
                        }
                    } else if isWordEnd {
                        // Case 4a: Word-final monotonic rightward sweep starting at trigger `firstTrig` (`алмакъ`, `сонъ`, `топракъ`, `байракъ`)
                        recordTrigger(rawKeys[firstTrig], isWordEnd: true)
                        for k in corridorStart..<idx where k != firstTrig {
                            removedIndices.insert(k)
                        }
                    } else {
                        // Case 4b: Word-interior digraph (`янгъын`): preserve triggers (`н`, `г`, `к`), strip non-trigger transit
                        for tPos in triggerIndices {
                            recordTrigger(rawKeys[tPos], isWordEnd: false)
                        }
                        for k in corridorStart..<idx where ["у", "е", "ш", "щ", "з", "х"].contains(rawKeys[k]) {
                            removedIndices.insert(k)
                        }
                    }
                }

                // Strip return transit keys after `ъ`/`ʼ` when returning left across Row 0 to the next vowel/consonant
                var fwd = idx + 1
                while fwd < rawKeys.count {
                    let fc = rawKeys[fwd]
                    if ["х", "з", "щ", "ш"].contains(fc) {
                        removedIndices.insert(fwd)
                        fwd += 1
                    } else if (cyrillicRow0ReturnTransit.contains(fc) || fc == "к" || fc == "у"), fwd + 1 < rawKeys.count {
                        removedIndices.insert(fwd)
                        fwd += 1
                    } else {
                        break
                    }
                }
            }
        }

        // Also handle swipes that aimed for `ъ`/`ʼ` at Col 11 after `к/г/н` and lifted slightly short on `х` or `з`
        if let lastCh = rawKeys.last, ["х", "з"].contains(lastCh), rawKeys.count >= 4 {
            var scan = rawKeys.count - 1
            var transitCount = 0
            while scan >= 0 && ["г", "ш", "щ", "з", "х", "е", "н"].contains(rawKeys[scan]) {
                if cyrillicDigraphTriggers.contains(rawKeys[scan]) && transitCount >= 2 {
                    let trigger = rawKeys[scan]
                    if trigger == "к" { softEndBases.formUnion(["q", "k"]); explicitDiacritics.insert("q") }
                    else if trigger == "г" { softEndBases.insert("g"); explicitDiacritics.insert("ğ") }
                    else if trigger == "н" { softEndBases.insert("n"); explicitDiacritics.insert("ñ") }
                    break
                }
                transitCount += 1
                scan -= 1
            }
        }

        var cleaned: [Character] = []
        for (idx, ch) in rawKeys.enumerated() where !removedIndices.contains(idx) {
            if cleaned.last != ch {
                cleaned.append(ch)
            }
        }
        return (cleaned.isEmpty ? rawKeys : cleaned, explicitDiacritics, softEndBases)
    }

    private static func resamplePolyline(_ points: [CGPoint], count: Int = 16) -> [CGPoint] {
        guard !points.isEmpty else { return [] }
        if points.count == 1 || count <= 1 {
            return Array(repeating: points[0], count: max(1, count))
        }
        var cumulative: [CGFloat] = [0]
        var totalLen: CGFloat = 0
        for i in 1..<points.count {
            let d = hypot(points[i].x - points[i - 1].x, points[i].y - points[i - 1].y)
            totalLen += d
            cumulative.append(totalLen)
        }
        guard totalLen > 0.001 else {
            return Array(repeating: points[0], count: count)
        }
        var result: [CGPoint] = []
        result.reserveCapacity(count)
        var segIdx = 0
        for k in 0..<count {
            let targetDist = totalLen * CGFloat(k) / CGFloat(count - 1)
            while segIdx + 1 < cumulative.count - 1 && cumulative[segIdx + 1] < targetDist {
                segIdx += 1
            }
            let segStart = cumulative[segIdx]
            let segEnd = cumulative[segIdx + 1]
            let segLen = segEnd - segStart
            let t = segLen > 0.0001 ? min(1.0, max(0.0, (targetDist - segStart) / segLen)) : 0.0
            let p0 = points[segIdx]
            let p1 = points[segIdx + 1]
            result.append(CGPoint(
                x: p0.x + (p1.x - p0.x) * t,
                y: p0.y + (p1.y - p0.y) * t
            ))
        }
        return result
    }

    /// Matches a swipe key sequence (from iPhone or iPad Floating keyboard) to top dictionary candidates
    /// using the QırımKey Swipe v2 hybrid decoder (12-column physical layout geometry, `Δθ >= 22°` curvature
    /// and local velocity `v_t` slowdown anchor weighting, 16-point resampled SHARK2 trajectory comparison,
    /// `ъ`/`ʼ` corridor cleaning, and two-sided `(prefix, allowedEndBaseChars)` candidate retrieval).
    func matchSwipePath(
        keySequence: [String],
        isCyrillic: Bool = false,
        shouldCapitalize: Bool = false,
        contextWords: [String] = [],
        trailPoints: [CGPoint] = [],
        timestamps: [TimeInterval] = [],
        keyFrames: [String: CGRect] = [:]
    ) -> [Autocomplete.Suggestion] {
        databaseQueue.sync {
            ensureDB()
            let isUkrainianCyr = isCyrillic && KeyboardPreferences.ukrainianCyrillicLayoutEnabled
            let (keyCenters, keyWidth) = Self.resolveKeyCenters(
                isCyrillic: isCyrillic,
                isUkrainianCyrillic: isUkrainianCyr,
                keyFrames: keyFrames
            )

            let rawLowerKeys: [Character] = keySequence.compactMap {
                $0.lowercased(with: Self.casingLocale).first
            }
            let (lowerKeys, explicitCyrDiacritics, softEndBases): ([Character], Set<Character>, Set<Character>) = isCyrillic
                ? Self.cleanCyrillicSwipeSequence(rawLowerKeys)
                : (rawLowerKeys, [], [])
            let rawKeySet = Set(lowerKeys)

            var basePath: [Character] = []
            var basePathKeyPoints: [CGPoint] = []
            var startCandidates: [Character] = []
            var endCandidates = softEndBases

            if isCyrillic, lowerKeys.first == "д", lowerKeys.prefix(3).contains("ж") {
                startCandidates.append("c")
            }

            var prevCyrChar: Character?
            for (idx, ch) in lowerKeys.enumerated() {
                let pt = keyCenters[ch]
                if isCyrillic {
                    if Self.cyrillicSignChars.contains(ch) {
                        prevCyrChar = ch
                        continue
                    }
                    if ch == "д", idx == 0, lowerKeys.dropFirst().prefix(2).contains("ж") {
                        prevCyrChar = ch
                        continue
                    }
                    // Fold interior `дж` digraph so `ж` right after `д` adds `c` instead of spurious `j`
                    if ch == "ж", prevCyrChar == "д" {
                        prevCyrChar = ch
                        continue
                    }
                    var mapped = Self.cyrillicToLatinSwipeMap[ch] ?? []
                    if ch == "д", idx + 1 < lowerKeys.count, lowerKeys[idx + 1] == "ж" {
                        mapped = ["c", "d"]
                    }
                    let isWordStartOrAfterVowel = basePath.isEmpty || (prevCyrChar.map { Self.cyrillicVowelOrSign.contains($0) } ?? false)
                    if isWordStartOrAfterVowel {
                        if ch == "ё" { mapped = ["y", "o"] }
                        else if ch == "ю" { mapped = ["y", "u"] }
                        else if ch == "я" { mapped = ["y", "a"] }
                        else if ch == "е", !isUkrainianCyr { mapped = ["y", "e"] }
                    }
                    if !mapped.isEmpty {
                        let isIotatedPair = isWordStartOrAfterVowel && ["ё", "ю", "я", "є", "ї", "е"].contains(ch) && mapped.count == 2
                        if startCandidates.isEmpty {
                            startCandidates = isIotatedPair ? [mapped[0]] : mapped
                        } else if basePath.isEmpty {
                            for m in (isIotatedPair ? [mapped[0]] : mapped) where !startCandidates.contains(m) {
                                startCandidates.append(m)
                            }
                        }
                        if isIotatedPair, let lastM = mapped.last {
                            endCandidates = Set([Self.normalizeBaseChar(lastM)]).union(softEndBases)
                        } else {
                            endCandidates = Set(mapped.map { Self.normalizeBaseChar($0) }).union(softEndBases)
                        }
                        let pathChars = isIotatedPair ? mapped : [mapped[0]]
                        for m in pathChars {
                            let b = Self.normalizeBaseChar(m)
                            if basePath.last != b {
                                basePath.append(b)
                                if let pt { basePathKeyPoints.append(pt) }
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
                        if let pt { basePathKeyPoints.append(pt) }
                    }
                }
            }

            guard basePath.count >= 2, let firstBase = basePath.first, let lastBase = basePath.last else {
                return []
            }
            if endCandidates.isEmpty {
                endCandidates.insert(lastBase)
            }

            // Compute per-sample instantaneous velocity `v_t` when timestamps are provided
            var sampleVelocities: [Double] = []
            var medianVelocity: Double = 0
            if trailPoints.count == timestamps.count && trailPoints.count >= 3 {
                sampleVelocities = Array(repeating: 0.0, count: trailPoints.count)
                for sIdx in 1..<(trailPoints.count - 1) {
                    let dt = max(0.001, timestamps[sIdx + 1] - timestamps[sIdx - 1])
                    let ds = Double(hypot(
                        trailPoints[sIdx + 1].x - trailPoints[sIdx - 1].x,
                        trailPoints[sIdx + 1].y - trailPoints[sIdx - 1].y
                    ))
                    sampleVelocities[sIdx] = ds / dt
                }
                sampleVelocities[0] = sampleVelocities[1]
                sampleVelocities[trailPoints.count - 1] = sampleVelocities[trailPoints.count - 2]
                let sortedVel = sampleVelocities.filter { $0 > 1.0 }.sorted()
                if !sortedVel.isEmpty {
                    medianVelocity = sortedVel[sortedVel.count / 2]
                }
            }

            // Compute per-key curvature turn angles (`Δθ >= 22°` = anchor/inflection; `< 22°` = collinear transit key)
            // and local finger slowdown (`v_local < 0.55 * v_median`)
            var isPathAnchor = Array(repeating: true, count: basePath.count)
            var pathKeyWeights = Array(repeating: 1.0, count: basePath.count)
            var pathTurnAngles = Array(repeating: 180.0, count: basePath.count)
            if basePathKeyPoints.count == basePath.count && basePath.count >= 3 {
                for idx in 1..<(basePath.count - 1) {
                    let pPrev = basePathKeyPoints[idx - 1]
                    let pCurr = basePathKeyPoints[idx]
                    let pNext = basePathKeyPoints[idx + 1]
                    let v1x = pCurr.x - pPrev.x
                    let v1y = pCurr.y - pPrev.y
                    let v2x = pNext.x - pCurr.x
                    let v2y = pNext.y - pCurr.y
                    let n1 = hypot(v1x, v1y)
                    let n2 = hypot(v2x, v2y)
                    if n1 > 1.0 && n2 > 1.0 {
                        let cosTheta = min(1.0, max(-1.0, (v1x * v2x + v1y * v2y) / (n1 * n2)))
                        let angleDeg = Double(acos(cosTheta) * 180.0 / .pi)
                        pathTurnAngles[idx] = angleDeg
                        let isLocalPassThrough = (n1 <= 2.4 * keyWidth && n2 <= 2.4 * keyWidth)
                        let isShortWordPreFinalConsonant = (basePath.count <= 4 && idx == basePath.count - 2 && !Self.baseVowels.contains(basePath[idx]))

                        var isVelocitySlowdown = false
                        if medianVelocity > 10.0 && !sampleVelocities.isEmpty {
                            let radius = max(16.0, keyWidth * 0.65)
                            var minLocalVel = Double.greatestFiniteMagnitude
                            for (sIdx, tPt) in trailPoints.enumerated() {
                                if hypot(tPt.x - pCurr.x, tPt.y - pCurr.y) <= radius {
                                    minLocalVel = min(minLocalVel, sampleVelocities[sIdx])
                                }
                            }
                            if minLocalVel < medianVelocity * 0.55 {
                                isVelocitySlowdown = true
                            }
                        }

                        if angleDeg < 22.0 && isLocalPassThrough && !isShortWordPreFinalConsonant && !isVelocitySlowdown {
                            isPathAnchor[idx] = false
                            pathKeyWeights[idx] = 0.20 + (angleDeg / 22.0) * 0.18
                        } else {
                            isPathAnchor[idx] = true
                            let baseWeight = min(1.0, 0.70 + (max(22.0, angleDeg) - 22.0) / 90.0 * 0.30)
                            pathKeyWeights[idx] = isVelocitySlowdown ? max(baseWeight, 0.85) : baseWeight
                        }
                    }
                }
            }
            let anchorCount = max(2, isPathAnchor.filter { $0 }.count)
            var interiorAnchorPoints: [CGPoint] = []
            var sharpTurnaroundBases = Set<Character>()
            if basePathKeyPoints.count == basePath.count && basePath.count >= 3 {
                for idx in 1..<(basePath.count - 1) where isPathAnchor[idx] {
                    interiorAnchorPoints.append(basePathKeyPoints[idx])
                    if pathTurnAngles[idx] >= 135.0 {
                        sharpTurnaroundBases.insert(basePath[idx])
                    }
                }
            }
            let hasCyrillicSignInRaw = isCyrillic && rawLowerKeys.contains(where: { Self.cyrillicSignChars.contains($0) })
            let effectiveSwipePoints: [CGPoint] = {
                if !hasCyrillicSignInRaw && trailPoints.count >= 2 {
                    return trailPoints
                }
                return basePathKeyPoints
            }()
            let resampledSwipePoints = Self.resamplePolyline(effectiveSwipePoints, count: 16)
            let startTouchPoint: CGPoint? = effectiveSwipePoints.first ?? (lowerKeys.first.flatMap { keyCenters[$0] })

            var prefixes = Set<String>()
            if !isCyrillic, let firstRaw = lowerKeys.first {
                prefixes.insert(String(firstRaw))
                let b = Self.normalizeBaseChar(firstRaw)
                if firstRaw != "q" && firstRaw != "ş" {
                    prefixes.insert(String(b))
                }
                for variant in Self.diacriticForms[b] ?? [] {
                    // On 12-column Latin (`crh-Latn`), `k <-> q` and `s <-> ş` are distinct physical keys 8 columns apart
                    if (firstRaw == "k" && variant == "q") || (firstRaw == "s" && variant == "ş") { continue }
                    if firstRaw == "q" || firstRaw == "ş" { continue }
                    prefixes.insert(String(variant))
                }
            } else {
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
            }

            let minLen = 2
            let maxLen = min(22, basePath.count + 5)
            let neighborMap = isCyrillic ? Self.cyrillicBaseNeighbors : Self.qwertyNeighbors
            var lastNeighbors = Set<Character>()
            for ec in endCandidates {
                lastNeighbors.formUnion(neighborMap[ec] ?? [])
            }
            lastNeighbors.subtract(endCandidates)

            var bigramBoosts: [String: Int] = [:]
            if let prev = contextWords.last?.lowercased(with: Self.casingLocale), !prev.isEmpty {
                for (w2, freq) in fetchUserBigrams(after: prev, limit: 12) {
                    bigramBoosts[w2.lowercased(with: Self.casingLocale)] = freq * 2500
                }
                for (w2, freq) in fetchNextWordsWithFrequency(after: prev, minFrequency: 1, limit: 24) {
                    let k = w2.lowercased(with: Self.casingLocale)
                    bigramBoosts[k] = max(bigramBoosts[k] ?? 0, freq * 20)
                }
                let prevPrev = contextWords.count >= 2 ? contextWords[contextWords.count - 2].lowercased(with: Self.casingLocale) : nil
                applyGrammaticalReranking(previousWord: prevPrev, lastWord: prev, into: &bigramBoosts)
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
                    exactEndBaseChars: endCandidates,
                    neighborEndBaseChars: lastNeighbors,
                    exactLimit: 320,
                    neighborLimit: 140
                ) {
                    let k = bw.lowercased(with: Self.casingLocale)
                    if seenWords.insert(k).inserted {
                        candidatePool.append((bw, bfreq))
                    }
                }
            }

            let innerUpperBound = max(1, basePath.count - 1)
            var scoredCandidates: [(word: String, score: Double)] = []
            for (word, freq) in candidatePool {
                let lower = word.lowercased(with: Self.casingLocale)
                guard !lower.contains(" "), !lower.isEmpty else { continue }
                var wordBase: [Character] = []
                var wordOrigChars: [Character] = []
                var wordCharCenters: [CGPoint?] = []
                for ch in lower {
                    if ch == "-" { continue }
                    let b = Self.normalizeBaseChar(ch)
                    if wordBase.last != b {
                        wordBase.append(b)
                        wordOrigChars.append(ch)
                        wordCharCenters.append(Self.targetWordCharCenter(
                            for: ch,
                            centers: keyCenters,
                            isCyrillic: isCyrillic,
                            isUkrainianCyrillic: isUkrainianCyr
                        ))
                    }
                }
                guard wordBase.count >= 2,
                      wordBase.contains(where: { Self.baseVowels.contains($0) }),
                      let wordLast = wordBase.last else { continue }

                let exactLast = endCandidates.contains(wordLast)
                let neighborLast = !exactLast && lastNeighbors.contains(wordLast)
                guard exactLast || neighborLast else { continue }

                var pathIdx = 0
                var exactHits = 0
                var weightedExactHits: Double = 0.0
                var matchedAnchors = 0
                var transitOnlyHits = 0
                var neighborHits = 0
                var misses = 0
                var repeatedVowelMisses = 0
                var matchedVowels = Set<Character>()
                var startDistanceBonus: Double = 0.0
                var matchedWordCenters: [CGPoint] = []
                var hasMatchedTurnaround = false

                for (i, targetChar) in wordBase.enumerated() {
                    if i == 0 {
                        if let cPt = wordCharCenters[0] { matchedWordCenters.append(cPt) }
                        if let u1 = startTouchPoint,
                           let k1 = wordCharCenters[0] {
                            let d0 = Double(hypot(u1.x - k1.x, u1.y - k1.y) / max(1.0, keyWidth))
                            if d0 <= 0.75 {
                                exactHits += 1
                                weightedExactHits += 1.0
                                matchedAnchors += 1
                                startDistanceBonus = 1.65
                            } else if d0 <= 1.75 {
                                neighborHits += 1
                                weightedExactHits += 0.65
                                startDistanceBonus = 0.25
                            } else {
                                // Distant diacritic prefix (e.g. `ş` vs `s` or `q` vs `k`, 256+ pt apart on Latin)
                                neighborHits += 1
                                weightedExactHits += 0.30
                                startDistanceBonus = -min(2.6, d0 * 0.42)
                            }
                        } else {
                            exactHits += 1
                            weightedExactHits += 1.0
                            matchedAnchors += 1
                        }
                        if Self.baseVowels.contains(targetChar) { matchedVowels.insert(targetChar) }
                        pathIdx = 1
                        continue
                    }
                    if i == wordBase.count - 1 {
                        if let cPt = wordCharCenters[i] { matchedWordCenters.append(cPt) }
                        if exactLast {
                            exactHits += 1
                            weightedExactHits += 1.0
                            matchedAnchors += 1
                        } else {
                            neighborHits += 1
                        }
                        continue
                    }
                    // If targetChar is a vowel and the next char in wordBase is a consonant that appears earlier in basePath,
                    // do not let this vowel search jump past the next consonant's last occurrence in the path.
                    var searchLimit = innerUpperBound
                    if Self.baseVowels.contains(targetChar), i + 1 < wordBase.count - 1 {
                        let nextChar = wordBase[i + 1]
                        if !Self.baseVowels.contains(nextChar) {
                            if let nextPos = basePath[pathIdx..<innerUpperBound].lastIndex(of: nextChar),
                               !basePath[pathIdx..<nextPos].contains(targetChar) {
                                searchLimit = nextPos
                            }
                        }
                    }

                    var foundExact = false
                    var searchIdx = pathIdx
                    while searchIdx < searchLimit {
                        let pb = basePath[searchIdx]
                        let isCharMatch = (pb == targetChar) || (isCyrillic && ((pb == "q" && targetChar == "k") || (pb == "k" && targetChar == "q")))
                        if isCharMatch {
                            var chosenIdx = searchIdx
                            // If this match is a collinear transit key, prefer a later anchor occurrence if subsequent consonants still fit after it
                            if !isPathAnchor[searchIdx] && (searchIdx + 1) < searchLimit {
                                let nextConsonant: Character? = {
                                    for remIdx in (i + 1)..<(wordBase.count - 1) {
                                        let rc = wordBase[remIdx]
                                        if !Self.baseVowels.contains(rc) { return rc }
                                    }
                                    return nil
                                }()
                                for altIdx in (searchIdx + 1)..<searchLimit where isPathAnchor[altIdx] {
                                    let altPb = basePath[altIdx]
                                    let altMatch = (altPb == targetChar) || (isCyrillic && ((altPb == "q" && targetChar == "k") || (altPb == "k" && targetChar == "q")))
                                    guard altMatch else { continue }
                                    if let nc = nextConsonant {
                                        if (altIdx + 1) < innerUpperBound, basePath[(altIdx + 1)..<innerUpperBound].contains(nc) {
                                            chosenIdx = altIdx
                                            break
                                        }
                                    } else {
                                        chosenIdx = altIdx
                                        break
                                    }
                                }
                            }
                            foundExact = true
                            pathIdx = chosenIdx + 1
                            exactHits += 1
                            if let cPt = wordCharCenters[i] { matchedWordCenters.append(cPt) }
                            let isPostTurnReturnConsonant = hasMatchedTurnaround && i == wordBase.count - 2 && !Self.baseVowels.contains(targetChar)
                            let nearInteriorAnchor: Bool = {
                                if isPostTurnReturnConsonant { return true }
                                guard !isPathAnchor[chosenIdx],
                                      wordOrigChars[i] != targetChar,
                                      let cPt = wordCharCenters[i] else { return false }
                                return interiorAnchorPoints.contains { hypot($0.x - cPt.x, $0.y - cPt.y) <= 1.35 * keyWidth }
                            }()
                            let isDistantLatinDiacriticSubstitute: Bool = {
                                guard !isCyrillic,
                                      wordOrigChars[i] != targetChar,
                                      !nearInteriorAnchor,
                                      chosenIdx < basePathKeyPoints.count,
                                      let cPt = wordCharCenters[i] else { return false }
                                let pPt = basePathKeyPoints[chosenIdx]
                                return hypot(pPt.x - cPt.x, pPt.y - cPt.y) > 2.5 * keyWidth
                            }()
                            let w: Double
                            if isDistantLatinDiacriticSubstitute {
                                w = min(0.25, pathKeyWeights[chosenIdx] * 0.45)
                            } else if nearInteriorAnchor {
                                w = max(0.85, pathKeyWeights[chosenIdx])
                            } else {
                                w = pathKeyWeights[chosenIdx]
                            }
                            weightedExactHits += w
                            if !isDistantLatinDiacriticSubstitute && (isPathAnchor[chosenIdx] || nearInteriorAnchor) {
                                matchedAnchors += 1
                            } else {
                                transitOnlyHits += 1
                            }
                            if pathTurnAngles[chosenIdx] >= 135.0 { hasMatchedTurnaround = true }
                            if Self.baseVowels.contains(targetChar) { matchedVowels.insert(targetChar) }
                            break
                        }
                        searchIdx += 1
                    }
                    if !foundExact {
                        let targetNeighbors = neighborMap[targetChar] ?? []
                        var foundNeighbor = false
                        var nIdx = pathIdx
                        while nIdx < searchLimit {
                            if targetNeighbors.contains(basePath[nIdx]) {
                                foundNeighbor = true
                                pathIdx = nIdx + 1
                                neighborHits += 1
                                if let cPt = wordCharCenters[i] { matchedWordCenters.append(cPt) }
                                break
                            }
                            nIdx += 1
                        }
                        if !foundNeighbor {
                            misses += 1
                            let isRepVowelMiss = (Self.baseVowels.contains(targetChar) && (matchedVowels.contains(targetChar) || wordLast == targetChar))
                                || (wordBase.count >= 5 && (targetChar == wordBase.first || targetChar == wordLast))
                            if isRepVowelMiss {
                                repeatedVowelMisses += 1
                            } else if let cPt = wordCharCenters[i] {
                                matchedWordCenters.append(cPt)
                            }
                            let maxAllowedMisses = wordBase.count <= 3 ? 0 : max(1, (wordBase.count - 1) / 2)
                            if misses > maxAllowedMisses {
                                break
                            }
                        }
                    }
                }

                let maxAllowedMisses = wordBase.count <= 3 ? 0 : max(1, (wordBase.count - 1) / 2)
                guard misses <= maxAllowedMisses else { continue }

                var specificCharBonus: Double = startDistanceBonus
                if isCyrillic {
                    if rawKeySet.contains("ш") || rawKeySet.contains("щ") {
                        if lower.contains("ş") { specificCharBonus += 1.8 }
                        else if lower.contains("s") && !rawKeySet.contains("с") { specificCharBonus -= 1.2 }
                    }
                    if rawKeySet.contains("с") && lower.contains("s") { specificCharBonus += 0.8 }
                    if rawKeySet.contains("ч") && lower.contains("ç") { specificCharBonus += 1.6 }
                    if rawKeySet.contains("ґ") && lower.contains("g") { specificCharBonus += 1.4 }
                    for expDia in explicitCyrDiacritics where lower.contains(expDia) {
                        specificCharBonus += 1.8
                    }
                } else {
                    if rawKeySet.contains("ş") && lower.contains("ş") { specificCharBonus += 1.6 }
                    if rawKeySet.contains("ç") && lower.contains("ç") { specificCharBonus += 1.6 }
                    if rawKeySet.contains("ğ") && lower.contains("ğ") { specificCharBonus += 1.6 }
                    if rawKeySet.contains("ñ") && lower.contains("ñ") { specificCharBonus += 1.6 }
                }

                // 16-point resampled SHARK2 geometric trajectory similarity
                var geometricBonus: Double = 0.0
                if resampledSwipePoints.count == 16 && matchedWordCenters.count >= 2 {
                    let resampledWord = Self.resamplePolyline(matchedWordCenters, count: 16)
                    var distSum: CGFloat = 0
                    for k in 0..<16 {
                        distSum += hypot(
                            resampledSwipePoints[k].x - resampledWord[k].x,
                            resampledSwipePoints[k].y - resampledWord[k].y
                        )
                    }
                    let meanKeyDist = Double((distSum / 16.0) / max(1.0, keyWidth))
                    geometricBonus = max(-2.6, (1.20 - meanKeyDist) * 1.95)
                }

                var missedTurnaroundPenalty: Double = 0.0
                if !sharpTurnaroundBases.isEmpty {
                    let wordBaseSet = Set(wordBase)
                    for tb in sharpTurnaroundBases where !wordBaseSet.contains(tb) {
                        missedTurnaroundPenalty += 1.85
                    }
                }

                let regularMisses = max(0, misses - repeatedVowelMisses)
                let missPenalty = Double(regularMisses) * 1.65 + Double(repeatedVowelMisses) * 0.35
                let coverage = weightedExactHits + Double(neighborHits) * 0.55 - missPenalty
                let effectiveWordLen = max(2.0, Double(wordBase.count) - Double(repeatedVowelMisses) * 0.5)
                let coverageRatio = coverage / effectiveWordLen
                let matchedKeyBonus = min(weightedExactHits * 0.95 + Double(neighborHits) * 0.35, 7.5)
                let allExactBonus: Double = (exactHits == wordBase.count && misses == 0 && neighborHits == 0) ? 1.8 : 0.0
                let anchorExactMatchBonus: Double = (matchedAnchors >= anchorCount && regularMisses == 0 && neighborHits == 0 && (wordBase.count == anchorCount || exactHits == anchorCount)) ? 2.1 : 0.0
                let unanchoredComplexityPenalty: Double = Double(max(0, transitOnlyHits)) * 0.55
                let shortWordDetourPenalty: Double = (anchorCount >= 4 && wordBase.count <= 2) ? 2.5 : 0.0
                let geminateShortWordPenalty: Double = (wordBase.count <= 3 && lower.count > wordBase.count) ? 0.35 : 0.0
                let lengthPenalty = Double(max(0, wordBase.count - basePath.count)) * 0.55
                    + Double(max(0, basePath.count - wordBase.count)) * 0.02
                let endBonus = (wordLast == lastBase) ? 2.9 : (exactLast ? 2.2 : 0.4)
                let contextFreq = bigramBoosts[lower] ?? 0
                let freqScore = log10(Double(max(1, freq + contextFreq)) + 1.35) * 1.35
                let totalScore = (coverageRatio * 6.0)
                    + matchedKeyBonus
                    + allExactBonus
                    + anchorExactMatchBonus
                    + geometricBonus
                    + endBonus
                    + freqScore
                    + specificCharBonus
                    - lengthPenalty
                    - unanchoredComplexityPenalty
                    - shortWordDetourPenalty
                    - geminateShortWordPenalty
                    - missedTurnaroundPenalty
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

    private static let surfaceEndVariantsByBase: [Character: [String]] = [
        "a": ["a", "â"],
        "c": ["c", "ç"],
        "g": ["g", "ğ"],
        "i": ["i", "ı", "î"],
        "n": ["n", "ñ"],
        "o": ["o", "ö"],
        "s": ["s", "ş"],
        "u": ["u", "ü", "û"]
    ]

    private static func expandSurfaceEndChars(_ baseChars: Set<Character>) -> [String] {
        var out: [String] = []
        var seen = Set<String>()
        for b in baseChars {
            let variants = surfaceEndVariantsByBase[b] ?? [String(b)]
            for v in variants where seen.insert(v).inserted {
                out.append(v)
            }
        }
        return out
    }

    private func fetchSwipeCandidatesStartingWith(
        prefix: String,
        minLen: Int,
        maxLen: Int,
        exactEndBaseChars: Set<Character>,
        neighborEndBaseChars: Set<Character>,
        exactLimit: Int,
        neighborLimit: Int
    ) -> [(String, Int)] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        let query = """
        SELECT word, freq FROM words
        WHERE substr(word, 1, 1) = ?1
          AND substr(word, -1, 1) = ?2
          AND freq >= 2
          AND length(word) BETWEEN ?3 AND ?4
          AND instr(word, ' ') = 0
        ORDER BY freq DESC
        LIMIT ?5;
        """
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }

        func fetchForEndSurfaces(_ endSurfaces: [String], totalLimit: Int) -> [(String, Int)] {
            guard !endSurfaces.isEmpty, totalLimit > 0 else { return [] }
            var pool: [(String, Int)] = []
            for endSurf in endSurfaces {
                sqlite3_reset(stmt)
                sqlite3_clear_bindings(stmt)
                guard bindText(stmt, index: 1, value: prefix),
                      bindText(stmt, index: 2, value: endSurf),
                      sqlite3_bind_int(stmt, 3, Int32(minLen)) == SQLITE_OK,
                      sqlite3_bind_int(stmt, 4, Int32(maxLen)) == SQLITE_OK,
                      sqlite3_bind_int(stmt, 5, Int32(totalLimit)) == SQLITE_OK else {
                    continue
                }
                while sqlite3_step(stmt) == SQLITE_ROW {
                    if let wordPtr = sqlite3_column_text(stmt, 0) {
                        pool.append((String(cString: wordPtr), Int(sqlite3_column_int(stmt, 1))))
                    }
                }
            }
            if endSurfaces.count > 1 && pool.count > 1 {
                pool.sort { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }
            }
            return pool.count > totalLimit ? Array(pool.prefix(totalLimit)) : pool
        }

        let exactSurfaces = Self.expandSurfaceEndChars(exactEndBaseChars)
        let neighborSurfaces = Self.expandSurfaceEndChars(neighborEndBaseChars)
        var results = fetchForEndSurfaces(exactSurfaces, totalLimit: exactLimit)
        results.append(contentsOf: fetchForEndSurfaces(neighborSurfaces, totalLimit: neighborLimit))
        return results
    }

    // MARK: - Autocorrect & Crimean Tatar Grammar / Harmony Rules

    private static let lettersForTypos = Array("abcçdefgğhıijklmnñoöpqrsştuüvwxyzâîû")
    private static let diacriticForms: [Character: [Character]] = [
        "a": ["â"], "c": ["ç"], "g": ["ğ"], "i": ["ı"], "k": ["q"], "n": ["ñ"],
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

    /// Corrects common toponymy typos (`qrım*`, `kırım*`, `kirim*`, `krım*`, `krim*`, `qirim*` -> `qırım*`)
    /// even when low-frequency typo forms exist in the raw corpus.
    private func toponymyTypoCorrection(for queryLower: String) -> String? {
        guard queryLower.count >= 4 else { return nil }
        let prefixes: [(typo: String, canonical: String)] = [
            ("qrım", "qırım"),
            ("qrim", "qırım"),
            ("qirim", "qırım"),
            ("kırım", "qırım"),
            ("kirim", "qırım"),
            ("krım", "qırım"),
            ("krim", "qırım")
        ]
        for (typo, canonical) in prefixes where queryLower.hasPrefix(typo) {
            let suffix = String(queryLower.dropFirst(typo.count))
            if suffix.isEmpty
                || Self.properNounInflectionSuffixes.contains(suffix)
                || suffix.hasPrefix("tatar")
                || suffix.hasPrefix("lı") {
                return canonical + suffix
            }
        }
        return nil
    }

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
        "or": [
            "qapı": "Qapı",
            "qapıda": "Qapıda",
            "qapığa": "Qapığa",
            "qapıdan": "Qapıdan",
            "qapınıñ": "Qapınıñ"
        ],
        "eski": [
            "qırım": "Qırım",
            "qırımda": "Qırımda",
            "qırımğa": "Qırımğa",
            "qırımdan": "Qırımdan",
            "qırımnıñ": "Qırımnıñ"
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

    private static let unambiguousProperNounStems: Set<String> = [
        // Crimea & Crimean cities / historical toponyms (2024/2025 Orthography § 52)
        "qırım", "aqmescit", "aqyar", "bağçasaray", "kefe", "kezlev",
        "yalta", "aluşta", "canköy", "qarasuvbazar", "sudaq", "kerç",
        "çonğar", "balıqlava", "gurzuf", "foros", "inkerman", "koktebel", "partenit",
        "simeiz", "koreiz", "masandra", "livadiya", "oreanda", "alupka",
        "inkirmen", "çufut-qale", "manğup", "manğup-qale", "eski-qırım",
        "salğır", "çatırtav", "ay-petri", "simferopol", "sevastopol",
        "feodosiya", "yevpatoriya",
        // Countries, regions, capitals & major cities
        "ukrayina", "ukraina", "ukrayına", "ukrayna",
        "türkiye", "istanbul", "ankara", "kiyev", "kyiv",
        "avropa", "rusiye", "moskva", "berlin", "london", "parij", "vaşington",
        "özbekistan", "özbekstan", "qazaqstan", "qazaqıstan", "azerbaycan",
        "gürcistan", "lehistan", "romaniya", "bulğaristan",
        // Sacred & historical single-token proper names
        "allah", "islâm", "quran", "ramazan", "navrez", "hıdırlez", "derviza",
        "çelebicihan", "gasprinskiy", "çobanzade", "çoban-zade", "şemi-zade",
        "amet-han", "tohtarğazı", "camanaqlı", "qırımtayev"
    ]

    private static let properNounInflectionSuffixes: Set<String> = [
        "",
        "da", "de", "ta", "te",
        "daki", "deki", "taki", "teki", "dakiler", "dekiler", "takiler", "tekiler",
        "dan", "den", "tan", "ten", "dandır", "dendir", "tandır", "tendir",
        "ğa", "ge", "qa", "ke", "ğadır", "gedir", "qadır", "kedir", "ğamı", "gemi", "qamı", "kemi", "ğaca", "gece", "qaca", "kece",
        "nıñ", "niñ", "nin", "nıñki", "niñki", "nıñdır", "niñdir",
        "nı", "ni",
        "nen", "man", "men",
        "mı", "mi", "dır", "dir", "tır", "tir",
        "sız", "siz", "suz", "süz",
        "ım", "im", "um", "üm", "m", "ıma", "ime", "ımda", "imde", "ımdan", "imden", "ımnı", "imni", "ımnıñ", "imniñ",
        "ıñ", "iñ", "uñ", "üñ", "ñ", "ıña", "iñe", "ıñda", "iñde", "ıñnı", "iñni",
        "ı", "i", "u", "ü", "sı", "si", "su", "sü",
        "ında", "inde", "ına", "ine", "ından", "inden", "ını", "ini", "ınıñ", "iniñ",
        "sında", "sinde", "sına", "sine", "sından", "sinden", "sını", "sini", "sınıñ", "siniñ",
        "ımız", "imiz", "umız", "ümiz", "mız", "miz",
        "ımızda", "imizde", "ımızğa", "imizge", "ımıznı", "imizni", "ımıznıñ", "imizniñ", "ımızdan", "imizden",
        "ıñız", "iñiz", "uñız", "üñiz", "ñız", "ñiz", "ıñızda", "iñizde", "ıñızğa", "iñizge",
        "lar", "ler", "larda", "lerde", "larğa", "lerge", "lardan", "lerden", "larnı", "lerni", "larnıñ", "lerniñ"
    ]

    private static func capitalizeProperToken(_ wordLower: String) -> String {
        if wordLower.contains("-") {
            return wordLower
                .split(separator: "-", omittingEmptySubsequences: false)
                .map { part -> String in
                    let p = String(part)
                    if p.hasPrefix("zade") { return p }
                    guard let first = p.first else { return p }
                    return String(first).uppercased(with: casingLocale) + String(p.dropFirst())
                }
                .joined(separator: "-")
        }
        guard let first = wordLower.first else { return wordLower }
        return String(first).uppercased(with: casingLocale) + String(wordLower.dropFirst())
    }

    private static func standaloneProperNounCasing(for wordLower: String) -> String? {
        guard wordLower.count >= 4 else { return nil }
        if unambiguousProperNounStems.contains(wordLower) {
            return capitalizeProperToken(wordLower)
        }
        for stem in unambiguousProperNounStems where wordLower.hasPrefix(stem) {
            let suffix = String(wordLower.dropFirst(stem.count))
            if properNounInflectionSuffixes.contains(suffix) {
                return capitalizeProperToken(wordLower)
            }
        }
        return nil
    }

    private func properNounCasing(for wordLower: String, contextWords: [String]) -> String? {
        if !contextWords.isEmpty {
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
        }
        return Self.standaloneProperNounCasing(for: wordLower)
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
            let prevWord = normalized.count >= 2 ? normalized[normalized.count - 2] : nil
            applyGrammaticalReranking(previousWord: prevWord, lastWord: lastWord, into: &scores)
        }

        // 4. Fallback to general popular words to guarantee 3 suggestions
        if scores.count < 3 {
            let recentWords = Set(normalized.suffix(2))
            for word in fetchPopularWords(limit: 10) {
                let key = word.lowercased(with: Self.casingLocale)
                if !recentWords.contains(key) && scores[key] == nil {
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
    private func applyGrammaticalReranking(
        previousWord: String? = nil,
        lastWord: String,
        into scores: inout [String: Int]
    ) {
        // 0. Never suggest immediate repetition of the current or preceding word in the clause (e.g., "sen" after "Sen ne ")
        scores.removeValue(forKey: lastWord)
        if let previousWord {
            scores.removeValue(forKey: previousWord)
        }

        // 0b. Subject Pronoun + Interrogative ("Sen ne ...", "Men ne ...", "Siz ne ...", "Biz ne ...", "O ne ...")
        if let prev = previousWord,
           ["men", "sen", "o", "biz", "siz", "olar"].contains(prev),
           ["ne", "qayda", "nasıl", "niçün", "qaçan"].contains(lastWord) {
            if lastWord == "ne" {
                for nonVerb in ["qadar", "içün", "kibi", "zaman", "vaqıt", "de", "da", "ise", "bar"] {
                    scores.removeValue(forKey: nonVerb)
                }
                let agreedVerbs: [(String, Int)]
                switch prev {
                case "sen":
                    agreedVerbs = [("aytasıñ", 6500), ("yapasıñ", 6000), ("deysiñ", 5500), ("yaptıñ", 5000), ("isteysiñ", 4500)]
                case "men":
                    agreedVerbs = [("yapayım", 6500), ("yaparım", 6000), ("aytayım", 5500), ("dedim", 5000), ("yaptım", 4500)]
                case "siz":
                    agreedVerbs = [("aytasıñız", 6500), ("yapasıñız", 6000), ("deysiñiz", 5500), ("isteysiñiz", 5000)]
                case "biz":
                    agreedVerbs = [("yapamız", 6500), ("yapayıq", 6000), ("yaptıq", 5500), ("deymiz", 5000)]
                default:
                    agreedVerbs = [("yapa", 6500), ("ayta", 6000), ("dedi", 5500), ("yaptı", 5000)]
                }
                for (verb, boost) in agreedVerbs {
                    scores[verb] = max(scores[verb] ?? 0, boost)
                }
            }
        }

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
            scores[key] = max(scores[key] ?? 0, frequency * 150 + 500)
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
