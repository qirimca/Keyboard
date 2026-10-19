//
//  SuggestionsDataBaseManager.swift
//  Keyboard
//
//  Copyright © 2024 Daniel Saidi. All rights reserved.
//

import Foundation
import KeyboardKit
import SQLite3
import os

final class SuggestionsDataBaseManager {

    static let shared = SuggestionsDataBaseManager()
    static let signposter = OSSignposter(subsystem: "crh.key.perf", category: "Autocomplete")

    private var db: OpaquePointer?
    private let databaseQueue = DispatchQueue(label: "crh.keyboard.databaseQueue")
    private static let crimeanLocale = Locale(identifier: "crh")
    /// i/ı/İ/I casing for Crimean Tatar Latin (same rules as Turkish script).
    private static let casingLocale = Locale(identifier: "tr")
    /// Minimum bigram frequency to consider for next-word prediction.
    private static let minimumNextWordFrequency = 1

    private var cachedPhrases: [(phrase: String, freq: Int)]?

    /// Opens the dictionary on a background queue before the first autocomplete query.
    func prepareAsync() {
        databaseQueue.async { [weak self] in
            self?.ensureDB()
            self?.ensurePhrasesLoaded()
        }
    }

    deinit {
        databaseQueue.sync {
            if let db {
                sqlite3_close(db)
                self.db = nil
            }
        }
    }

    private func openDB() {
        let state = Self.signposter.beginInterval("openDB")
        defer { Self.signposter.endInterval("openDB", state) }
        guard let dbURL = Bundle.main.url(forResource: "qırım_tatar", withExtension: "db") else {
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

    private func ensureDB() {
        if db != nil { return }
        openDB()
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
                // or when its diacritic form is overwhelmingly more common (qirim → qırım).
                let knownFormatted = formatWord(known, capitalize: shouldCapitalize, isAllCaps: isAllCaps)
                if let dominant = diacriticCorrection(for: queryLower, over: frequency(of: queryLower)) {
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

    private func frequency(of word: String) -> Int32 {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT MAX(freq) FROM words WHERE word = ?1;", -1, &stmt, nil) == SQLITE_OK,
              bindText(stmt, index: 1, value: word),
              sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int(stmt, 0)
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
        guard let db else { return [] }
        var results: [String] = []

        var stmt: OpaquePointer?
        let query = "SELECT word FROM words WHERE word >= ?1 AND word < ?2 AND instr(word, ' ') = 0 ORDER BY (word = ?1) DESC, freq DESC LIMIT ?3;"
        let lowercasePrefix = prefix.lowercased(with: Self.casingLocale)

        defer { sqlite3_finalize(stmt) }

        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            debugPrint("Failed to prepare query")
            return []
        }

        guard bindText(stmt, index: 1, value: lowercasePrefix) else {
            debugPrint("Failed to bind query parameter")
            return []
        }

        guard bindText(stmt, index: 2, value: lowercasePrefix + "\u{FFFF}"),
              sqlite3_bind_int(stmt, 3, Int32(limit)) == SQLITE_OK else {
            return []
        }

        while sqlite3_step(stmt) == SQLITE_ROW {
            if let word = sqlite3_column_text(stmt, 0) {
                results.append(String(cString: word))
            }
        }

        return results
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
