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
    
    init() {
        databaseQueue.sync {
            openDB()
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
    
    func top3(for text: String) -> [Autocomplete.Suggestion] {
        databaseQueue.sync {
            guard !text.isEmpty else { return [] }
            
            let isUppercased = text.first?.isUppercase ?? false
            var matches = fetchWordsStartingWith(prefix: text)
            let hasMatches = !matches.isEmpty
            
            var result: [Autocomplete.Suggestion] = [
                Autocomplete.Suggestion(text: text, isUnknown: !hasMatches)
            ]
            
            matches = matches.filter { $0.lowercased() != text.lowercased() }
            
            if let first = matches.first {
                matches.removeFirst()
                result.append(.init(text: first, isAutocorrect: false))
                
                if let second = matches.first {
                    let displayText = isUppercased ? second.capitalizeFirstLetter() : second
                    result.append(.init(text: displayText, isAutocorrect: false))
                }
            }
            
            return result
        }
    }
    
    private func fetchWordsStartingWith(prefix: String) -> [String] {
        guard let db else { return [] }
        var results: [String] = []
        
        var stmt: OpaquePointer?
        let query = "SELECT word FROM words WHERE LOWER(word) LIKE ? ORDER BY freq DESC LIMIT 3;"
        let lowercasePrefix = prefix.lowercased() + "%"
        
        defer { sqlite3_finalize(stmt) }
        
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else {
            debugPrint("Failed to prepare query")
            return []
        }
        
        guard sqlite3_bind_text(stmt, 1, lowercasePrefix, -1, nil) == SQLITE_OK else {
            debugPrint("Failed to bind query parameter")
            return []
        }
        
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let word = sqlite3_column_text(stmt, 0) {
                results.append(String(cString: word))
            }
        }
        
        return results
    }
    
    func checkDatabaseContents(db: OpaquePointer?) {
        guard let db else { return }
        
        let countQuery = "SELECT COUNT(*) FROM words;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, countQuery, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let count = sqlite3_column_int(stmt, 0)
                debugPrint("Number of rows: \(count)")
            }
        }
        sqlite3_finalize(stmt)
        
        let existsQuery = "SELECT EXISTS(SELECT 1 FROM words WHERE word = ?);"
        if sqlite3_prepare_v2(db, existsQuery, -1, &stmt, nil) == SQLITE_OK {
            sqlite3_bind_text(stmt, 1, "men", -1, nil)
            if sqlite3_step(stmt) == SQLITE_ROW {
                let exists = sqlite3_column_int(stmt, 0)
                debugPrint(exists == 1 ? "The word exists." : "The word does not exist.")
            }
        }
        sqlite3_finalize(stmt)
        
        let pragmaQuery = "PRAGMA table_info(words);"
        if sqlite3_prepare_v2(db, pragmaQuery, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                let columnName = String(cString: sqlite3_column_text(stmt, 1))
                debugPrint("Column: \(columnName)")
            }
        } else {
            debugPrint("Failed to fetch table info: \(String(cString: sqlite3_errmsg(db)!))")
        }
        sqlite3_finalize(stmt)
        
        let fetchQuery = "SELECT word, freq FROM words LIMIT 10;"
        if sqlite3_prepare_v2(db, fetchQuery, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let wordPointer = sqlite3_column_text(stmt, 0) {
                    let word = String(cString: wordPointer)
                    let frequency = sqlite3_column_int(stmt, 1)
                    debugPrint("Word: \(word), Frequency: \(frequency)")
                } else {
                    debugPrint("Empty row")
                }
            }
        }
        sqlite3_finalize(stmt)
    }
    
    
    // MARK: Creation from words-tatar.csv
    
    func createDB() {
        setupDatabase()
        if let csvURL = Bundle.main.url(forResource: "qırım_tatar", withExtension: "csv") {
            importCSVToSQLite(csvURL: csvURL)
        }
    }
    
    private func setupDatabase() {
        let fileManager = FileManager.default
        let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.crh.key.boardplus")!
        let dbPath = containerURL.appendingPathComponent("words.db").path
        
        if sqlite3_open(dbPath, &db) == SQLITE_OK {
            print("Successfully opened SQLite database at \(dbPath)")
            createTable()
        } else {
            print("Failed to open SQLite database")
        }
    }
    
    private func createTable() {
        let createTableQuery = """
CREATE TABLE IF NOT EXISTS words (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    word TEXT,
    freq INTEGER
);
"""
        if sqlite3_exec(db, createTableQuery, nil, nil, nil) == SQLITE_OK {
            print("Table created successfully")
        } else {
            print("Failed to create table")
        }
    }
    
    
    /// Does not work!!!
    private func importCSVToSQLite(csvURL: URL) {
        guard let db else { return }
        
        let insertQuery = "INSERT INTO words (word, freq) VALUES (?, ?);"
        var stmt: OpaquePointer?
        
        sqlite3_prepare_v2(db, insertQuery, -1, &stmt, nil)
        
        do {
            let rawData = try String(contentsOf: csvURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedData = rawData.replacingOccurrences(of: "\u{FEFF}", with: "")
            let rows = cleanedData.components(separatedBy: .newlines)
            
            var i = 0
            for row in rows {
                let columns = parseCSVLine(row)
                if columns.count == 2, let frequency = Int32(columns[1]) {
                    let word = columns[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    if sqlite3_bind_text(stmt, 1, word.cString(using: .utf8), -1, nil) != SQLITE_OK {
                        debugPrint("Error binding word: \(String(cString: sqlite3_errmsg(db)!))")
                    }
                    if sqlite3_bind_int(stmt, 2, frequency) != SQLITE_OK {
                        debugPrint("Error binding frequency: \(String(cString: sqlite3_errmsg(db)!))")
                    }
                    
                    if sqlite3_step(stmt) == SQLITE_DONE {
                        debugPrint(i)
                    } else {
                        debugPrint("Error inserting \(word): \(String(cString: sqlite3_errmsg(db)!))")
                    }
                    i += 1
                    sqlite3_reset(stmt)
                }
            }
            
            sqlite3_finalize(stmt)
            debugPrint("CSV data imported into SQLite successfully!")
        } catch {
            debugPrint("Error importing CSV: \(error)")
        }
    }
    
    private func parseCSVLine(_ line: String) -> [String] {
        line
            .replacingOccurrences(of: "\"", with: "")
            .components(separatedBy: ";")
    }
}

extension String {
    func capitalizeFirstLetter() -> String {
        return prefix(1).uppercased() + dropFirst()
    }
}
