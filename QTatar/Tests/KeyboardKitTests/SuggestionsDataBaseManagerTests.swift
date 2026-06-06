import XCTest
@testable import KeyboardKit
import SQLite3

class SuggestionsDataBaseManagerTests: XCTestCase {

    var manager: SuggestionsDataBaseManager!
    var db: OpaquePointer?

    override func setUpWithError() throws {
        manager = SuggestionsDataBaseManager()
    }

    override func tearDownWithError() throws {
        if let db = db { sqlite3_close(db) }
        db = nil
        manager = nil
    }

    func createDB(records: [(String, Int32)]) {
        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        sqlite3_open(url.path, &db)
        sqlite3_exec(db, "CREATE TABLE words(word TEXT, freq INTEGER);", nil, nil, nil)
        for (word, freq) in records {
            sqlite3_exec(db, "INSERT INTO words (word, freq) VALUES ('\(word)', \(freq));", nil, nil, nil)
        }
        manager.db = db
    }

    func testTop3ReturnsUpToThreeSuggestionsSortedByFrequency() {
        createDB(records: [("apple", 100), ("ape", 50), ("app", 40), ("apex", 30)])
        let suggestions = manager.top3(for: "ap")
        let texts = suggestions.dropFirst().map { $0.text }
        XCTAssertEqual(texts, ["apple", "ape"])
    }

    func testOriginalInputIsExcludedFromResults() {
        createDB(records: [("ap", 1000), ("apple", 100), ("ape", 50)])
        let suggestions = manager.top3(for: "ap")
        let texts = suggestions.dropFirst().map { $0.text }
        XCTAssertFalse(texts.contains("ap"))
    }
}
