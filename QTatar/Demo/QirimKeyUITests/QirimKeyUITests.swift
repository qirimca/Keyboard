import XCTest
import XCUIAutomation

@MainActor
final class QirimKeyUITests: XCTestCase {
    private var app: XCUIApplication!
    private var field: XCUIElement { app.textViews["sandbox.input"] }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
        app = XCUIApplication(bundleIdentifier: "crh.key.keyboard")
    }

    override func tearDownWithError() throws {
        if let testRun, testRun.hasSucceeded == false {
            capture("Failure")
        }
        app?.terminate()
        XCUIDevice.shared.orientation = .portrait
    }

    private func launch(fieldMode: String = "standard", theme: String = "modernLight") throws {
        app.launchArguments = ["-qt_field", fieldMode, "-qt_theme", theme, "-crh.key.text", ""]
        app.launch()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        field.tap()
        XCTAssertTrue(key("numeric").waitForExistence(timeout: 10) ||
                      key("alphabetic").exists,
                      "Enable and select Qırımtatarca in Settings before running keyboard tests.")
    }

    private func key(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "key." + identifier).firstMatch
    }

    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = key(identifier)
        XCTAssertTrue(element.waitForExistence(timeout: 3), "Missing key: " + identifier, file: file, line: line)
        element.tap()
    }

    private func expectText(_ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "value == %@", expected)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: field)], timeout: 3)
        XCTAssertEqual(result, .completed, file: file, line: line)
    }

    private func clear() {
        let button = app.buttons["sandbox.clear"]
        if button.exists { button.tap() }
        expectText("")
    }

    private func selectScript(cyrillic: Bool) throws {
        if key("alphabetic").exists { tap("alphabetic") }
        let wanted = cyrillic ? "ф" : "q"
        if key("character." + wanted).exists || key("character." + wanted.uppercased()).exists { return }
        guard key("toggle_script").exists else {
            throw XCTSkip("Select the other extension with the system globe on iPhone before this test.")
        }
        tap("toggle_script")
    }

    private func typeLetters(_ letters: String) {
        for character in letters {
            let id = "character." + String(character)
            if !key(id).exists { tap("shift") }
            tap(id)
        }
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testNumericFieldCanStayAlphabetic() throws {
        try launch(fieldMode: "numbers")
        tap("alphabetic")
        try selectScript(cyrillic: false)
        typeLetters("ab")
        expectText("ab")
        XCTAssertTrue(key("character.c").exists)
        tap("numeric")
        tap("symbolic")
        XCTAssertTrue(key("character.€").exists || key("character.[").exists)
        tap("alphabetic")
        typeLetters("c")
        expectText("abc")
        capture("Numbers to ABC to symbols")
    }

    func testLatinAlphabetByTapping() throws {
        try launch()
        try selectScript(cyrillic: false)
        let alphabet = "qwertyuıopğüâasdfghjklşizxcvbnmöçñ"
        typeLetters(alphabet)
        expectText(alphabet)
        capture("Latin alphabet")
    }

    func testCyrillicDigraphsAndBackspace() throws {
        try launch()
        try selectScript(cyrillic: true)
        for (source, expected) in [("гъ", "ğ"), ("къ", "q"), ("нъ", "ñ"), ("дж", "c"), ("юз", "yüz"), ("любов", "lübov"), ("люди", "lüdi"), ("бюро", "büro")] {
            clear()
            typeLetters(source)
            expectText(expected)
            capture(source + " to " + expected)
        }
        clear()
        typeLetters("гъ")
        tap("backspace")
        expectText("g")
        tap("backspace")
        expectText("")
    }

    func testPortraitLandscapeKeepTextAndFocus() throws {
        try launch()
        try selectScript(cyrillic: false)
        typeLetters("q")
        expectText("q")
        capture("Portrait with keyboard")
        XCUIDevice.shared.orientation = .landscapeLeft
        typeLetters("a")
        expectText("qa")
        capture("Landscape with keyboard")
        XCUIDevice.shared.orientation = .portrait
        typeLetters("z")
        expectText("qaz")
        capture("Portrait after rotation")
    }

    func testFieldAndThemeMatrix() throws {
        for theme in ["modernLight", "classicLight", "modernDark", "classicDark"] {
            for mode in ["standard", "search", "email", "url", "numbers"] {
                try launch(fieldMode: mode, theme: theme)
                if mode == "numbers" {
                    XCTAssertTrue(key("alphabetic").exists)
                } else if mode == "url" {
                    XCTAssertFalse(key("space").exists)
                    XCTAssertTrue(key("character./").exists)
                    XCTAssertTrue(key("url_domain").exists)
                } else {
                    XCTAssertTrue(key("space").exists)
                }
                capture(mode + "-" + theme)
                app.terminate()
            }
        }
    }
}
