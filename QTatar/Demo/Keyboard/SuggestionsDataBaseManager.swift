//
//  SuggestionsDataBaseManager.swift
//  Keyboard
//
//  Copyright © 2024 Daniel Saidi. All rights reserved.
//

import Foundation
import KeyboardKit
import SQLite3

final class SuggestionsDataBaseManager {
    
    static let shared = SuggestionsDataBaseManager()
    
    private var db: OpaquePointer?
    private let databaseQueue = DispatchQueue(label: "crh.keyboard.databaseQueue")
    private static let crimeanLocale = Locale(identifier: "crh")
    /// i/ı/İ/I casing for Crimean Tatar Latin (same rules as Turkish script).
    private static let casingLocale = Locale(identifier: "tr")
    /// Ignore low-confidence synthetic bigrams for next-word prediction.
    private static let minimumNextWordFrequency = 200
    private static let genericNextWordBlocklist: Set<String> = [
        "ve", "bir", "bu", "o", "de", "da", "edi", "men", "onıñ", "dep"
    ]
    
    /// Opens the dictionary on a background queue before the first autocomplete query.
    func prepareAsync() {
        databaseQueue.async { [weak self] in
            self?.ensureDB()
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
        guard let dbURL = Bundle.main.url(forResource: "qırım_tatar", withExtension: "db") else {
            debugPrint("Cant open DB")
            return
        }
        
        guard sqlite3_open(dbURL.path, &db) == SQLITE_OK else {
            debugPrint("Failed to open SQLite database")
            return
        }
        debugPrint("Successfully opened SQLite database at \(dbURL.path)")
        if sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil) != SQLITE_OK {
            debugPrint("Failed to enable WAL mode: \(String(cString: sqlite3_errmsg(db)!))")
        }
    }
    
    private func ensureDB() {
        if db != nil { return }
        openDB()
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
            return candidates.prefix(3).map {
                Autocomplete.Suggestion(text: formatWord($0, capitalize: shouldCapitalize))
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
            
            let matches = fetchWordsStartingWith(prefix: text, limit: 8)
            let queryLower = text.lowercased(with: Self.casingLocale)
            
            guard let best = matches.first else {
                return [Autocomplete.Suggestion(text: text, isUnknown: true)]
            }
            
            let bestFormatted = formatWord(best, capitalize: shouldCapitalize)
            let bestLower = best.lowercased(with: Self.casingLocale)
            var result: [Autocomplete.Suggestion] = []
            
            if bestLower == queryLower {
                if text != bestFormatted {
                    result.append(.init(text: bestFormatted, isAutocorrect: true))
                    result.insert(.init(text: text, isUnknown: true), at: 0)
                } else {
                    result.append(.init(text: bestFormatted))
                }
            } else if bestLower.hasPrefix(queryLower) {
                result.append(.init(text: bestFormatted, isAutocorrect: true))
                if text != bestFormatted {
                    result.insert(.init(text: text, isUnknown: true), at: 0)
                }
            } else {
                result.append(.init(text: text, isUnknown: true))
                result.append(.init(text: bestFormatted, isAutocorrect: true))
            }
            
            let used = Set(result.map { $0.text.lowercased(with: Self.casingLocale) })
            for match in matches.dropFirst() {
                guard result.count < 3 else { break }
                let formatted = formatWord(match, capitalize: shouldCapitalize)
                let key = formatted.lowercased(with: Self.casingLocale)
                guard !used.contains(key) else { continue }
                result.append(.init(text: formatted))
            }
            
            return Array(result.prefix(3))
        }
    }
    
    private func formatWord(_ word: String, capitalize: Bool) -> String {
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
        
        if normalized.count >= 2 {
            addTrigramContinuations(
                word1: normalized[normalized.count - 2],
                word2: normalized[normalized.count - 1],
                into: &scores
            )
        }
        
        if scores.count < 3 {
            for length in stride(from: min(3, normalized.count), through: 1, by: -1) {
                let prefix = normalized.suffix(length).joined(separator: " ")
                addPhraseContinuations(prefix: prefix, into: &scores)
                if scores.count >= 3 { break }
            }
        }
        
        if scores.count < 3, let lastWord = normalized.last {
            addMorphologicalContinuations(after: lastWord, into: &scores)
        }
        
        if scores.count < 3, let lastWord = normalized.last {
            addBigramContinuations(after: lastWord, minFrequency: Self.minimumNextWordFrequency, into: &scores)
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
            guard !Self.genericNextWordBlocklist.contains(key) else { continue }
            scores[key] = max(scores[key] ?? 0, frequency)
        }
    }
    
    private func addPhraseContinuations(
        prefix: String,
        into scores: inout [String: Int]
    ) {
        for (phrase, frequency) in fetchPhrases(startingWith: prefix, limit: 24) {
            guard let nextWord = nextToken(in: phrase, afterPrefix: prefix) else { continue }
            let key = nextWord.lowercased(with: Self.casingLocale)
            guard !Self.genericNextWordBlocklist.contains(key) else { continue }
            scores[key] = max(scores[key] ?? 0, frequency)
        }
    }
    
    private func addMorphologicalContinuations(
        after word: String,
        into scores: inout [String: Int]
    ) {
        let wordLower = word.lowercased(with: Self.casingLocale)
        for (phrase, frequency) in fetchPhrases(containingTokenPrefix: wordLower, limit: 32) {
            for token in phrase.split(separator: " ").map(String.init) {
                let tokenLower = token.lowercased(with: Self.casingLocale)
                guard tokenLower.hasPrefix(wordLower), tokenLower.count > wordLower.count else { continue }
                scores[tokenLower] = max(scores[tokenLower] ?? 0, frequency)
            }
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
            guard !Self.genericNextWordBlocklist.contains(key) else { continue }
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
        fetchPhrases(
            matching: prefix.lowercased(with: Self.casingLocale) + " %",
            limit: limit
        )
    }
    
    private func fetchPhrases(
        containingTokenPrefix tokenPrefix: String,
        limit: Int
    ) -> [(String, Int)] {
        fetchPhrases(
            matching: "% \(tokenPrefix)%",
            limit: limit
        )
    }
    
    private func fetchPhrases(
        matching pattern: String,
        limit: Int
    ) -> [(String, Int)] {
        guard let db else { return [] }
        
        var results: [(String, Int)] = []
        var stmt: OpaquePointer?
        let query = """
            SELECT word, freq FROM words
            WHERE instr(word, ' ') > 0 AND LOWER(word) LIKE ?
            ORDER BY freq DESC
            LIMIT ?;
            """
        
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            return []
        }
        
        guard bindText(stmt, index: 1, value: pattern) else {
            return []
        }
        
        guard sqlite3_bind_int(stmt, 2, Int32(limit)) == SQLITE_OK else {
            return []
        }
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            guard let word = sqlite3_column_text(stmt, 0) else { continue }
            let frequency = Int(sqlite3_column_int(stmt, 1))
            results.append((String(cString: word), frequency))
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
            WHERE LOWER(word1) = ? AND LOWER(word2) = ?
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
            WHERE LOWER(word1) = ? AND freq >= ?
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
            WHERE LOWER(word1) = ? AND freq >= ?
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
        let query = "SELECT word FROM words WHERE LOWER(word) LIKE ? ORDER BY freq DESC LIMIT ?;"
        let lowercasePrefix = prefix.lowercased(with: Self.casingLocale) + "%"
        
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            debugPrint("Failed to prepare query")
            return []
        }
        
        guard bindText(stmt, index: 1, value: lowercasePrefix) else {
            debugPrint("Failed to bind query parameter")
            return []
        }
        
        guard sqlite3_bind_int(stmt, 2, Int32(limit)) == SQLITE_OK else {
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
