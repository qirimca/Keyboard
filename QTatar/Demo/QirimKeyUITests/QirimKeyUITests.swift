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
        app.launchArguments = ["-qt_field", fieldMode, "-qt_theme", theme, "-qt_reset_text"]
        app.launch()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let firstKey = fieldMode == "numbers" ? key("alphabetic") : key("numeric")
        if !firstKey.waitForExistence(timeout: 2) {
            field.tap()
        }
        if !(firstKey.exists || firstKey.waitForExistence(timeout: 2) || key("numeric").exists || key("alphabetic").exists) {
            let nextKeyboard = app.buttons["Next keyboard"]
            for _ in 0..<6 where nextKeyboard.exists {
                nextKeyboard.tap()
                if firstKey.waitForExistence(timeout: 1.5) || key("numeric").exists || key("alphabetic").exists {
                    break
                }
            }
        }
        XCTAssertTrue(firstKey.exists ||
                      firstKey.waitForExistence(timeout: 6) ||
                      key("numeric").exists ||
                      key("alphabetic").exists,
                      "Enable and select Qırımtatarca in Settings before running keyboard tests.")
    }

    private func key(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "key." + identifier).firstMatch
    }

    private func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let element = key(identifier)
        if !element.exists {
            XCTAssertTrue(element.waitForExistence(timeout: 3), "Missing key: " + identifier, file: file, line: line)
        }
        element.tap()
    }

    private func expectText(_ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = NSPredicate(format: "value == %@", expected)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: field)], timeout: 3)
        if result != .completed {
            XCTAssertEqual(field.value as? String, expected, file: file, line: line)
        }
    }

    private func clear() {
        let button = app.buttons["sandbox.clear"]
        if button.exists { button.tap() }
        expectText("")
    }

    private func hasLetter(_ value: String) -> Bool {
        key("character." + value).exists || key("character." + value.uppercased()).exists
    }

    private func waitForLetter(_ value: String, timeout: TimeInterval = 4) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hasLetter(value) { return true }
            Thread.sleep(forTimeInterval: 0.15)
        }
        return hasLetter(value)
    }

    private func selectScript(cyrillic: Bool) throws {
        if key("alphabetic").exists { tap("alphabetic") }
        let wanted = cyrillic ? "ф" : "q"
        if waitForLetter(wanted, timeout: 1) { return }
        if key("toggle_script").exists {
            tap("toggle_script")
            XCTAssertTrue(waitForLetter(wanted), "script did not switch to cyrillic=\(cyrillic)")
            return
        }
        let nextKeyboard = app.buttons["Next keyboard"]
        for _ in 0..<8 where nextKeyboard.exists {
            nextKeyboard.tap()
            if key("alphabetic").exists { tap("alphabetic") }
            if waitForLetter(wanted, timeout: 1.5) { return }
        }
        throw XCTSkip("Select the other extension with the system globe on iPhone before this test.")
    }

    private func typeLetters(_ letters: String) {
        var didCheckInitialCase = false
        for character in letters {
            let id = "character." + String(character)
            if !didCheckInitialCase {
                didCheckInitialCase = true
                if !key(id).exists { tap("shift") }
            }
            key(id).tap()
        }
    }

    private func capture(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let directory = "/tmp/qk_shots"
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let safe = name.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: " ", with: "_")
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: directory + "/" + safe + ".png"))
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
        try launch()
        XCTAssertFalse(app.buttons["theme.classic"].exists, "Classic mode pill must be removed")
        for (theme, isDark) in [
            ("modernLight", false),
            ("modernDark", true)
        ] {
            let appearancePill = app.buttons[isDark ? "theme.dark" : "theme.light"]
            if appearancePill.exists { appearancePill.tap() }
            for mode in ["standard", "search", "email", "url", "numbers"] {
                app.buttons["field." + mode].tap()
                if mode == "numbers" {
                    XCTAssertTrue(key("alphabetic").exists || key("alphabetic").waitForExistence(timeout: 3))
                } else if mode == "url" {
                    XCTAssertTrue(key("url_domain").exists || key("url_domain").waitForExistence(timeout: 3))
                    XCTAssertFalse(key("space").exists)
                    XCTAssertTrue(key("character./").exists)
                } else {
                    XCTAssertTrue(key("space").exists || key("space").waitForExistence(timeout: 3))
                }
            }
            capture(theme)
        }
        // Switching interface language must keep the Try Keyboard section expanded.
        for code in ["uk", "en", "crh"] {
            let langButton = app.buttons["settings.lang." + code]
            if langButton.exists {
                langButton.tap()
                XCTAssertTrue(field.exists, "Try Keyboard section must stay expanded after switching to \(code)")
            }
        }
    }

    // MARK: - Layout geometry

    /// Row 2 must sit half a key right of row 1 and row 3 half a key right of row 2 (Cyrillic and Latin).
    func testDockedRowsAreStaggeredByHalfAKey() throws {
        try launch()
        for (cyrillic, first, second, third, after) in [
            (true, "й", "ф", "я", "ц"),
            (false, "q", "a", "z", "w")
        ] {
            try selectScript(cyrillic: cyrillic)
            func letter(_ value: String) -> XCUIElement {
                let lower = key("character." + value)
                return lower.exists ? lower : key("character." + value.uppercased())
            }
            let row1 = letter(first)
            let row2 = letter(second)
            let row3 = letter(third)
            let next = letter(after)
            XCTAssertTrue(row1.exists && row2.exists && row3.exists && next.exists, "keys missing for cyrillic=\(cyrillic)")
            let pitch = next.frame.midX - row1.frame.midX
            XCTAssertGreaterThan(pitch, 40)
            let step12 = row2.frame.midX - row1.frame.midX
            let step23 = row3.frame.midX - row2.frame.midX
            capture("Stagger cyrillic=\(cyrillic) pitch=\(pitch) step12=\(step12) step23=\(step23)")
            XCTAssertEqual(step12, pitch / 2, accuracy: 3, "row2 vs row1, cyrillic=\(cyrillic)")
            XCTAssertEqual(step23, pitch / 2, accuracy: 3, "row3 vs row2, cyrillic=\(cyrillic)")
            XCTAssertEqual(row1.frame.height, row2.frame.height, accuracy: 1)

            // Verify side-key widths remain invariant across ABC, .?123, and #+= on iPad.
            let alphaBackspaceWidth = key("backspace").frame.width
            let alphaShiftWidth = key("shift").frame.width
            tap("numeric")
            XCTAssertTrue(key("symbolic").waitForExistence(timeout: 3))
            XCTAssertEqual(key("backspace").frame.width, alphaBackspaceWidth, accuracy: 2.0, "backspace width in numeric mode, cyrillic=\(cyrillic)")
            XCTAssertEqual(key("symbolic").frame.width, alphaShiftWidth, accuracy: 2.0, "symbolic key width in numeric mode, cyrillic=\(cyrillic)")
            capture("Numeric mode cyrillic=\(cyrillic)")
            tap("symbolic")
            XCTAssertTrue(key("numeric").waitForExistence(timeout: 3))
            XCTAssertEqual(key("backspace").frame.width, alphaBackspaceWidth, accuracy: 2.0, "backspace width in symbolic mode, cyrillic=\(cyrillic)")
            XCTAssertEqual(key("numeric").frame.width, alphaShiftWidth, accuracy: 2.0, "numeric key width in symbolic mode, cyrillic=\(cyrillic)")
            capture("Symbolic mode cyrillic=\(cyrillic)")
            tap("alphabetic")
            XCTAssertTrue(waitForLetter(first, timeout: 3))
        }

        // Verify downward flick gesture on iPad key 'q' -> '1' and 'w' -> '2'.
        try selectScript(cyrillic: false)
        clear()
        for ch in ["q", "w"] {
            let lower = key("character." + ch)
            let element = lower.exists ? lower : key("character." + ch.uppercased())
            let start = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let end = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.95))
            start.press(forDuration: 0.04, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.25)
        }
        expectText("12")
        capture("iPad flick down q and w to 12")
        clear()

        let cyrillicToggle = app.switches["settings.cyrillic.toggle"].exists
            ? app.switches["settings.cyrillic.toggle"]
            : app.descendants(matching: .any).matching(identifier: "settings.cyrillic.toggle").firstMatch
        if cyrillicToggle.exists {
            let toggleCyrillicSwitch = {
                let before = cyrillicToggle.value as? String
                cyrillicToggle.tap()
                if (cyrillicToggle.value as? String) == before {
                    cyrillicToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
                }
            }
            toggleCyrillicSwitch()
            XCTAssertTrue(key("capsLock").waitForExistence(timeout: 3), "Caps Lock must replace toggle_script when Cyrillic is disabled on iPad")
            XCTAssertFalse(key("toggle_script").exists)
            clear()
            tap("capsLock")
            key("character.A").tap()
            key("character.B").tap()
            expectText("AB")
            tap("capsLock")
            key("character.c").tap()
            expectText("ABc")
            capture("iPad Caps Lock when Cyrillic disabled")
            clear()
            toggleCyrillicSwitch()
            XCTAssertTrue(key("toggle_script").waitForExistence(timeout: 3))
        }

        // Verify long-pressing the bottom-right dismiss key triggers the Floating callout and switches to floating mode,
        // and dragging the floating grabber to the bottom edge docks the keyboard back.
        let dismissKey = key("dismiss")
        if dismissKey.exists {
            let start = dismissKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let calloutOption = dismissKey.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: -1.1))
            start.press(forDuration: 0.55, thenDragTo: calloutOption, withVelocity: .default, thenHoldForDuration: 0.15)
            Thread.sleep(forTimeInterval: 0.8)
            capture("iPad floating keyboard via dismiss long press")
            let spaceKey = key("space")
            XCTAssertTrue(spaceKey.exists)
            XCTAssertLessThan(spaceKey.frame.width, 320, "Keyboard should be in compact floating width after selecting Floating from dismiss key callout")

            // Drag the floating keyboard's bottom grabber bar down to the bottom edge of the screen to re-dock.
            let grabberX = spaceKey.frame.midX
            let grabberY = spaceKey.frame.maxY + 18
            let root = app.coordinate(withNormalizedOffset: .zero)
            let dragStart = root.withOffset(CGVector(dx: grabberX, dy: grabberY))
            let screenHeight = app.frame.height
            let dragEnd = root.withOffset(CGVector(dx: app.frame.midX, dy: screenHeight - 4))
            dragStart.press(forDuration: 0.15, thenDragTo: dragEnd, withVelocity: .slow, thenHoldForDuration: 0.35)
            XCTAssertTrue(dismissKey.waitForExistence(timeout: 3), "Dragging floating keyboard grabber to bottom edge must re-dock the keyboard")
            capture("iPad docked keyboard after dragging floating grabber to bottom")
        }
    }

    // MARK: - Space / autocorrect

    func testSpaceAutocorrectRules() throws {
        try launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "settings.wordLearning.toggle").firstMatch.exists)
        try selectScript(cyrillic: false)
        // Typed without diacritics: Space restores the dictionary spelling.
        typeLetters("qirim")
        tap("space")
        expectText("qırım ")
        capture("qirim to qırım")
        clear()
        typeLetters("selam")
        tap("space")
        expectText("selâm ")
        capture("selam to selâm")
        clear()
        // A valid word is left alone.
        typeLetters("bir")
        tap("space")
        expectText("bir ")
        clear()
        // An unknown short fragment is not forced into a different word.
        typeLetters("xq")
        tap("space")
        expectText("xq ")
    }

    // MARK: - Latency

    func testTypingLatency() throws {
        try launch()
        try selectScript(cyrillic: false)
        var worst: TimeInterval = 0
        var total: TimeInterval = 0
        let letters = Array("qwertyuiopasdfghjkl")
        for character in letters {
            let lower = key("character." + String(character))
            let element = lower.exists ? lower : key("character." + String(character).uppercased())
            element.tap()
            let started = Date()
            let predicate = NSPredicate(format: "value ENDSWITH[c] %@", String(character))
            _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: field)], timeout: 3)
            let elapsed = Date().timeIntervalSince(started)
            worst = max(worst, elapsed)
            total += elapsed
        }
        let average = total / Double(letters.count)
        capture(String(format: "typing latency avg=%.3fs worst=%.3fs", average, worst))
        print(String(format: "QK_METRIC typing avg=%.3f worst=%.3f", average, worst))
        XCTAssertLessThan(worst, 1.5)
    }

    func testScriptToggleLatency() throws {
        try launch()
        try selectScript(cyrillic: false)
        var worst: TimeInterval = 0
        for index in 0..<6 {
            let marker = index % 2 == 0 ? "ф" : "q"
            tap("toggle_script")
            let started = Date()
            XCTAssertTrue(waitForLetter(marker, timeout: 3), "toggle \(index) did not reach \(marker)")
            worst = max(worst, Date().timeIntervalSince(started))
        }
        capture(String(format: "script toggle worst=%.3fs", worst))
        print(String(format: "QK_METRIC toggle worst=%.3f", worst))
        XCTAssertLessThan(worst, 1.5)
    }
}
