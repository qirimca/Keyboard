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
    
    var db: OpaquePointer?
    private let databaseQueue = DispatchQueue(label: "crh.keyboard.databaseQueue")
    
    init() {
        Task(priority: .background) {
            await asyncOpenDB()
        }
    }
    
    private func asyncOpenDB() async {
        databaseQueue.sync { [weak self] in
            self?.openDB()
        }
    }
    
    private func openDB() {
        guard let csvURL = Bundle.main.url(forResource: "qırım_tatar", withExtension: "db") else {
            debugPrint("Cant open DB")
            return
        }
        
        // Открытие базы данных
        guard sqlite3_open(csvURL.absoluteString, &db) == SQLITE_OK else {
            debugPrint("Failed to open SQLite database")
            return
        }
        debugPrint("Successfully opened SQLite database at \(csvURL.absoluteString)")
        if sqlite3_exec(db, "PRAGMA journal_mode=WAL;", nil, nil, nil) != SQLITE_OK {
            debugPrint("Failed to enable WAL mode: \(String(cString: sqlite3_errmsg(db)!))")
        }
    }
    
    func top3(for text: String) -> [Autocomplete.Suggestion] {
        databaseQueue.sync {
            let isUppercased = text.first?.isUppercase ?? false
            var array = fetchWordsStartingWith(prefix: text)
            var result: [Autocomplete.Suggestion] = []
            
            // Check if the input is the same as the first word in the list
            array = array.filter { $0.lowercased() != text.lowercased() } // Remove exact match
            
            let count = array.count
            
            // If there is no match for the input text, create an unknown suggestion
            if count == array.count {
                result = [Autocomplete.Suggestion(text: text, isUnknown: true)]
            } else {
                result = [Autocomplete.Suggestion(text: text, isUnknown: false)]
            }
            
            // If the first word exists in the array, modify the result list
            if let first = array.first {
                array.removeFirst()
                result.append(.init(text: first, isAutocorrect: false))
                
                if let second = array.first {
                    // Apply the capitalization based on whether the input is uppercased
                    if isUppercased {
                        result.append(.init(text: second.capitalizeFirstLetter(), isAutocorrect: false))
                    } else {
                        result.append(.init(text: second, isAutocorrect: false))
                    }
                }
            }
            
            return result
        }
    }
    
    private func fetchWordsStartingWith(prefix: String) -> [String] {
        guard let db = db else { return [] }
        var results: [String] = []
        
        var stmt: OpaquePointer?
        let lowercasePrefix = prefix.lowercased() + "%"
        let query = "SELECT word FROM words WHERE LOWER(word) LIKE '\(lowercasePrefix)' ORDER BY freq DESC LIMIT 3;"
        
        if sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK {
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let word = sqlite3_column_text(stmt, 0) {
                    results.append(String(cString: word))
                    debugPrint(String(cString: word))
                }
            }
        } else {
            debugPrint("Failed to prepare query")
        }
        
        sqlite3_finalize(stmt)
        return results
    }
    
    func checkDatabaseContents(db: OpaquePointer?) {
        guard let db = db else { return }
        
        // Подсчёт строк
        let countQuery = "SELECT COUNT(*) FROM words;"
        var stmt: OpaquePointer?
        if sqlite3_prepare_v2(db, countQuery, -1, &stmt, nil) == SQLITE_OK {
            if sqlite3_step(stmt) == SQLITE_ROW {
                let count = sqlite3_column_int(stmt, 0)
                debugPrint("Number of rows: \(count)")
            }
        }
        sqlite3_finalize(stmt)
        
        // Проверка конкретного значения
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
        
        // Печать всех данных
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
        // Путь к файлу базы данных в контейнере клавиатуры
        let fileManager = FileManager.default
        let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.crh.key.boardplus")!
        let dbPath = containerURL.appendingPathComponent("words.db").path // TODO: это для создания новой базы данных и импорта данных из `qırım_tatar.csv`
        
        // Открытие базы данных
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
        guard let db = db else { return }
        
        let insertQuery = "INSERT INTO words (word, freq) VALUES (?, ?);"
        var stmt: OpaquePointer?
        
        sqlite3_prepare_v2(db, insertQuery, -1, &stmt, nil)
        
        do {
            let rawData = try String(contentsOf: csvURL, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedData = rawData.replacingOccurrences(of: "\u{FEFF}", with: "") // Убираем BOM
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
            .replacingOccurrences(of: "\"", with: "") // Убираем кавычки
            .components(separatedBy: ";")            // Разделяем по запятой
    }
}

extension String {
    func capitalizeFirstLetter() -> String {
        return prefix(1).uppercased() + dropFirst()
    }
}
