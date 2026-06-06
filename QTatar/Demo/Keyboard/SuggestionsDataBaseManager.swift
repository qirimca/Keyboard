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
    
    private var db: OpaquePointer?
    private let databaseQueue = DispatchQueue(label: "crh.keyboard.databaseQueue")
    private static let crimeanLocale = Locale(identifier: "crh")
    /// i/ı/İ/I casing for Crimean Tatar Latin (same rules as Turkish script).
    private static let casingLocale = Locale(identifier: "tr")
    
    init() {
        prepare()
    }
    
    /// Opens the dictionary before the first autocomplete query.
    func prepare() {
        databaseQueue.sync {
            ensureDB()
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
        
        guard sqlite3_bind_text(stmt, 1, lowercasePrefix, -1, nil) == SQLITE_OK else {
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
}
