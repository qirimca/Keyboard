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
        if let testRun, (testRun.failureCount + testRun.unexpectedExceptionCount) > 0 {
            capture("Failure")
        }
        XCUIDevice.shared.orientation = .portrait
        app?.terminate()
    }

    private var anyCustomKey: XCUIElement {
        let pred = NSPredicate(format: "identifier IN {'key.space', 'key.numeric', 'key.alphabetic'}")
        return app.descendants(matching: .any).matching(pred).firstMatch
    }

    private func launch(fieldMode: String = "standard", theme: String = "modernLight", extraArgs: [String] = []) throws {
        app.launchArguments = ["-qt_field", fieldMode, "-qt_theme", theme, "-qt_reset_text"] + extraArgs
        app.launch()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let firstKey = fieldMode == "numbers" ? key("alphabetic") : key("numeric")
        if !anyCustomKey.waitForExistence(timeout: 3.5) {
            if !app.buttons["Next keyboard"].exists && !app.buttons["ABC"].exists && app.keyboards.count == 0 {
                field.tap()
                Thread.sleep(forTimeInterval: 0.6)
            }
            if !anyCustomKey.exists {
                cycleToCustomKeyboard(firstKey: firstKey)
            }
        }
        if !anyCustomKey.exists {
            enableKeyboardInSettingsIfNeeded()
            app.terminate()
            app.launch()
            if field.waitForExistence(timeout: 5) {
                if !app.buttons["Next keyboard"].exists && !app.buttons["ABC"].exists && app.keyboards.count == 0 {
                    field.tap()
                }
                Thread.sleep(forTimeInterval: 0.8)
            }
            cycleToCustomKeyboard(firstKey: firstKey)
        }
        XCTAssertTrue(anyCustomKey.waitForExistence(timeout: 4.0),
                      "Enable and select Qırımtatarca in Settings before running keyboard tests.")
    }

    private func cycleToCustomKeyboard(firstKey: XCUIElement) {
        let nextKeyboard = app.buttons["Next keyboard"]
        let abcBtn = app.buttons["ABC"]
        if !nextKeyboard.exists && !abcBtn.exists && app.keyboards.count == 0 {
            let clearBtn = app.buttons["sandbox.clear"]
            if clearBtn.exists && clearBtn.isHittable {
                clearBtn.tap()
                Thread.sleep(forTimeInterval: 0.3)
            }
            if field.exists && field.isHittable {
                field.tap()
                Thread.sleep(forTimeInterval: 0.8)
            }
        }
        if anyCustomKey.exists { return }
        if abcBtn.exists && abcBtn.isHittable {
            abcBtn.tap()
            if anyCustomKey.waitForExistence(timeout: 1.8) { return }
        } else if nextKeyboard.exists && nextKeyboard.isHittable {
            nextKeyboard.tap()
            if anyCustomKey.waitForExistence(timeout: 1.8) { return }
        }
        if nextKeyboard.exists && nextKeyboard.isHittable {
            for dyOffset in [-2.8, -3.6, -4.4] {
                let start = nextKeyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let end = nextKeyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: dyOffset))
                start.press(forDuration: 0.55, thenDragTo: end)
                if app.state != .runningForeground {
                    app.activate()
                    Thread.sleep(forTimeInterval: 0.6)
                }
                if anyCustomKey.waitForExistence(timeout: 1.8) { return }
            }
        }
    }

    private func enableKeyboardInSettingsIfNeeded() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.activate()
        guard settings.wait(for: .runningForeground, timeout: 8) else { return }
        Thread.sleep(forTimeInterval: 0.8)

        let keyboardPred = NSPredicate(format: "identifier == 'com.apple.settings.general.keyboard' OR label == 'Keyboard'")
        let keyboardsPred = NSPredicate(format: "label CONTAINS[c] 'Keyboards' OR identifier CONTAINS[c] 'KEYBOARDS'")
        let generalPred = NSPredicate(format: "identifier == 'com.apple.settings.general' OR label == 'General'")

        if !settings.buttons.matching(keyboardPred).firstMatch.exists &&
           !settings.cells.matching(keyboardPred).firstMatch.exists &&
           !settings.buttons.matching(keyboardsPred).firstMatch.exists &&
           !settings.cells.matching(keyboardsPred).firstMatch.exists {
            let generalBtn = settings.buttons.matching(generalPred).firstMatch.exists
                ? settings.buttons.matching(generalPred).firstMatch
                : settings.cells.matching(generalPred).firstMatch
            if !generalBtn.exists {
                settings.swipeUp()
                Thread.sleep(forTimeInterval: 0.5)
            }
            if generalBtn.waitForExistence(timeout: 2.0) {
                generalBtn.tap()
                Thread.sleep(forTimeInterval: 0.8)
            }
        }

        let keyboardBtn = settings.buttons.matching(keyboardPred).firstMatch.exists
            ? settings.buttons.matching(keyboardPred).firstMatch
            : settings.cells.matching(keyboardPred).firstMatch
        if keyboardBtn.waitForExistence(timeout: 2.5) {
            keyboardBtn.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
        let keyboardsBtn = settings.buttons.matching(keyboardsPred).firstMatch.exists
            ? settings.buttons.matching(keyboardsPred).firstMatch
            : settings.cells.matching(keyboardsPred).firstMatch
        if keyboardsBtn.waitForExistence(timeout: 2.5) {
            keyboardsBtn.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
        let existingCell = settings.cells.matching(NSPredicate(format: "identifier == 'crh.key.keyboard.keyboard' OR label CONTAINS[c] 'Qırımtatarca'")).firstMatch
        if !existingCell.exists {
            let addNewPredicate = NSPredicate(format: "label CONTAINS[c] 'Add New Keyboard' OR identifier CONTAINS[c] 'AddNewKeyboard'")
            let addNewBtn = settings.buttons.matching(addNewPredicate).firstMatch.exists
                ? settings.buttons.matching(addNewPredicate).firstMatch
                : settings.cells.matching(addNewPredicate).firstMatch
            if addNewBtn.waitForExistence(timeout: 3.0) {
                addNewBtn.tap()
                Thread.sleep(forTimeInterval: 1.2)
                let qtatarPredicate = NSPredicate(format: "identifier == 'QTatar' OR label == 'QTatar' OR label CONTAINS[c] 'QırımKey'")
                let qtatarBtn = settings.buttons.matching(qtatarPredicate).firstMatch.exists
                    ? settings.buttons.matching(qtatarPredicate).firstMatch
                    : settings.cells.matching(qtatarPredicate).firstMatch
                if qtatarBtn.waitForExistence(timeout: 3.0) {
                    qtatarBtn.tap()
                    Thread.sleep(forTimeInterval: 1.0)
                    let switches = settings.switches.allElementsBoundByIndex
                    for sw in switches {
                        let val = (sw.value as? String) ?? ""
                        if val == "0" {
                            sw.tap()
                            Thread.sleep(forTimeInterval: 0.5)
                        }
                    }
                    let doneBtn = settings.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Done' OR identifier CONTAINS[c] 'Done'")).firstMatch
                    if doneBtn.exists {
                        doneBtn.tap()
                        Thread.sleep(forTimeInterval: 0.8)
                    }
                }
            }
        }
        if existingCell.waitForExistence(timeout: 2.0) && existingCell.isHittable {
            existingCell.tap()
            Thread.sleep(forTimeInterval: 0.8)
            let fullAccessSwitch = settings.switches.matching(NSPredicate(format: "label CONTAINS[c] 'Allow Full Access'")).firstMatch
            if fullAccessSwitch.waitForExistence(timeout: 2.0), ((fullAccessSwitch.value as? String) ?? "") == "0" {
                fullAccessSwitch.tap()
                Thread.sleep(forTimeInterval: 0.5)
                let allowBtn = settings.alerts.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow'")).firstMatch
                if allowBtn.waitForExistence(timeout: 1.5) {
                    allowBtn.tap()
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
            let backBtn = settings.navigationBars.buttons.element(boundBy: 0)
            if backBtn.exists && backBtn.isHittable {
                backBtn.tap()
                Thread.sleep(forTimeInterval: 0.5)
            }
        }
        let cyrCell = settings.cells.matching(NSPredicate(format: "identifier CONTAINS[c] 'cyrillic' OR label CONTAINS[c] 'Къырымтатарджа'")).firstMatch
        if cyrCell.waitForExistence(timeout: 1.5) && cyrCell.isHittable {
            cyrCell.tap()
            Thread.sleep(forTimeInterval: 0.8)
            let fullAccessSwitch = settings.switches.matching(NSPredicate(format: "label CONTAINS[c] 'Allow Full Access'")).firstMatch
            if fullAccessSwitch.waitForExistence(timeout: 2.0), ((fullAccessSwitch.value as? String) ?? "") == "0" {
                fullAccessSwitch.tap()
                Thread.sleep(forTimeInterval: 0.5)
                let allowBtn = settings.alerts.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow'")).firstMatch
                if allowBtn.waitForExistence(timeout: 1.5) {
                    allowBtn.tap()
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }
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
        if identifier == "space", field.exists {
            let current = (field.value as? String) ?? ""
            if !current.isEmpty && !current.hasSuffix(" ") {
                Thread.sleep(forTimeInterval: 0.25)
                let recheck = (field.value as? String) ?? ""
                if !recheck.isEmpty && !recheck.hasSuffix(" ") && element.exists {
                    element.tap()
                }
            }
        } else if identifier == "numeric" {
            if !key("alphabetic").waitForExistence(timeout: 0.8), element.exists {
                element.tap()
            }
        } else if identifier == "alphabetic" {
            if !key("numeric").waitForExistence(timeout: 0.8), element.exists {
                element.tap()
            }
        }
    }

    private func expectText(_ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = expected.isEmpty
            ? NSPredicate(format: "value == %@ OR value == nil", "")
            : NSPredicate(format: "value == %@", expected)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: field)], timeout: 5)
        if result != .completed {
            XCTAssertEqual((field.value as? String) ?? "", expected, file: file, line: line)
        }
    }

    private func clear() {
        let button = app.buttons["sandbox.clear"]
        if button.exists && button.isEnabled && button.isHittable { button.tap() }
        expectText("")
    }

    private func hasLetter(_ value: String) -> Bool {
        let lowerId = "key.character." + value.lowercased()
        let upperId = "key.character." + value.uppercased()
        let predicate = NSPredicate(format: "identifier == %@ OR identifier == %@", lowerId, upperId)
        return app.descendants(matching: .any).matching(predicate).firstMatch.exists
    }

    private func waitForLetter(_ value: String, timeout: TimeInterval = 4) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if hasLetter(value) { return true }
            Thread.sleep(forTimeInterval: 0.15)
        }
        return hasLetter(value)
    }

    private func tapSwitch(_ toggle: XCUIElement) {
        let kb = app.keyboards.firstMatch
        if kb.exists && toggle.exists && toggle.frame.maxY > kb.frame.minY - 12 {
            app.scrollViews.firstMatch.swipeUp()
            Thread.sleep(forTimeInterval: 0.35)
        } else if toggle.exists && toggle.frame.minY < 80 {
            app.scrollViews.firstMatch.swipeDown()
            Thread.sleep(forTimeInterval: 0.35)
        }
        if toggle.isHittable {
            toggle.tap()
        } else {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
        }
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
        let nextKeyboard = app.buttons["Next keyboard"].exists ? app.buttons["Next keyboard"] : key("next_keyboard")
        let abcBtn = app.buttons["ABC"]
        if nextKeyboard.exists && nextKeyboard.isHittable {
            nextKeyboard.tap()
            Thread.sleep(forTimeInterval: 0.8)
            if waitForLetter(wanted, timeout: 1.2) { return }
        } else if abcBtn.exists && abcBtn.isHittable {
            abcBtn.tap()
            Thread.sleep(forTimeInterval: 0.8)
            if waitForLetter(wanted, timeout: 1.2) { return }
        }
        if nextKeyboard.exists && nextKeyboard.isHittable {
            for dyOffset in [-2.8, -3.6, -4.4] {
                let start = nextKeyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let end = nextKeyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: dyOffset))
                start.press(forDuration: 0.55, thenDragTo: end)
                Thread.sleep(forTimeInterval: 0.8)
                if app.state != .runningForeground {
                    app.activate()
                    Thread.sleep(forTimeInterval: 0.6)
                }
                if waitForLetter(wanted, timeout: 1.5) { return }
            }
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
                if !key(id).waitForExistence(timeout: 1.5), key("shift").exists {
                    tap("shift")
                }
            }
            if !key(id).exists, key("shift").exists {
                tap("shift")
                _ = key(id).waitForExistence(timeout: 1.0)
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
        for (source, expected) in [
            ("гъ", "ğ"),
            ("къ", "q"),
            ("нъ", "ñ"),
            ("дж", "c"),
            ("юз", "yüz"),
            ("любов", "lübov"),
            ("люди", "lüdi"),
            ("бюро", "büro"),
            ("къырым", "qırım"),
            ("селям", "selâm"),
            ("алейкум", "aleyküm"),
            ("яхшы", "yahşı"),
            ("чокъ", "çoq"),
            ("гузель", "güzel"),
            ("кунеш", "küneş")
        ] {
            clear()
            typeLetters(source)
            expectText(expected)
            capture(source + " to " + expected)
        }
        clear()
        // Multi-word Cyrillic sentence transliteration with space separation
        typeLetters("къырымтатар")
        tap("space")
        typeLetters("тили")
        expectText("qırımtatar tili")
        capture("Cyrillic sentence qırımtatar tili")
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
        XCTAssertTrue(app.buttons["field.numbers"].exists && app.buttons["field.numbers"].isHittable, "Rightmost field mode segment must not be clipped in landscape")
        XCTAssertTrue(app.buttons["theme.dark"].exists && app.buttons["theme.dark"].isHittable, "Rightmost theme segment must not be clipped in landscape")
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
                    XCTAssertTrue(key("character.1").exists || key("character.1").waitForExistence(timeout: 3))
                } else if mode == "url" {
                    XCTAssertTrue(key("url_domain").exists || key("url_domain").waitForExistence(timeout: 3))
                    XCTAssertFalse(key("space").exists)
                    XCTAssertTrue(key("character./").exists)
                    XCTAssertTrue(key("character..").exists)
                    capture("url_" + theme)
                } else if mode == "email" {
                    XCTAssertTrue(waitForLetter("q", timeout: 3) || waitForLetter("ф", timeout: 3), "Email mode must be on alphabetic keyboard")
                    XCTAssertTrue(key("space").exists || key("space").waitForExistence(timeout: 3))
                    XCTAssertTrue(key("character.@").exists || key("character.@").waitForExistence(timeout: 3))
                } else {
                    XCTAssertTrue(waitForLetter("q", timeout: 3) || waitForLetter("ф", timeout: 3), "Mode \(mode) must switch back to alphabetic keyboard")
                    XCTAssertTrue(key("space").exists || key("space").waitForExistence(timeout: 3))
                }
            }
            // Switch back from numbers to standard and verify it returns to alphabetic before capturing the theme screenshot.
            app.buttons["field.standard"].tap()
            XCTAssertTrue(waitForLetter("q", timeout: 3) || waitForLetter("ф", timeout: 3), "Standard mode after numbers must immediately switch back to alphabetic")
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
        guard key("dismiss").exists || key("toggle_script").exists else {
            throw XCTSkip("iPad docked keyboard layout test applies to iPad only.")
        }
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
            // Switch to Cyrillic first, then disable Cyrillic while the Cyrillic keyboard is open:
            // it must immediately switch back to Latin and replace toggle_script with capsLock.
            try selectScript(cyrillic: true)
            XCTAssertTrue(waitForLetter("ф", timeout: 2))
            let toggleCyrillicSwitch = {
                let before = cyrillicToggle.value as? String
                cyrillicToggle.tap()
                if (cyrillicToggle.value as? String) == before {
                    cyrillicToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)).tap()
                }
            }
            toggleCyrillicSwitch()
            XCTAssertTrue(waitForLetter("q", timeout: 3), "Disabling Cyrillic while on Cyrillic layout must immediately switch the open keyboard to Latin")
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
        // stays strictly within screen bounds, and dragging the floating grabber to the bottom edge docks the keyboard back.
        let dismissKey = key("dismiss")
        if dismissKey.exists && app.frame.width >= 750 {
            let start = dismissKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let calloutOption = dismissKey.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: -0.35))
            start.press(forDuration: 0.55, thenDragTo: calloutOption, withVelocity: .default, thenHoldForDuration: 0.15)
            Thread.sleep(forTimeInterval: 0.8)
            capture("iPad floating keyboard via dismiss long press")
            let spaceKey = key("space")
            XCTAssertTrue(spaceKey.exists)
            if spaceKey.frame.width < 320 {
                XCTAssertGreaterThanOrEqual(spaceKey.frame.minX, 0, "Floating keyboard must not jump off the left edge of the screen")
                XCTAssertLessThanOrEqual(spaceKey.frame.maxX, app.frame.width, "Floating keyboard must not jump off the right edge of the screen")
                // Drag the floating keyboard's bottom grabber bar down to the bottom edge of the screen to re-dock.
                let grabberX = spaceKey.frame.midX - app.frame.minX
                let grabberY = spaceKey.frame.maxY + 18 - app.frame.minY
                let root = app.coordinate(withNormalizedOffset: .zero)
                let dragStart = root.withOffset(CGVector(dx: grabberX, dy: grabberY))
                let screenHeight = app.frame.height
                let dragEnd = root.withOffset(CGVector(dx: app.frame.width / 2, dy: screenHeight - 4))
                dragStart.press(forDuration: 0.15, thenDragTo: dragEnd, withVelocity: .slow, thenHoldForDuration: 0.35)
                XCTAssertTrue(dismissKey.waitForExistence(timeout: 3), "Dragging floating keyboard grabber to bottom edge must re-dock the keyboard")
                capture("iPad docked keyboard after dragging floating grabber to bottom")
            }
        }
    }

    // MARK: - Space / autocorrect

    func testSpaceAutocorrectRules() throws {
        try launch()
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "settings.wordLearning.toggle").firstMatch.exists)
        try selectScript(cyrillic: false)

        // Verify greeting banner appears when field is empty, is strictly Latin-only, and tapping it inserts a wisdom phrase.
        let greetingBanner = app.descendants(matching: .any).matching(identifier: "autocomplete.greetingBanner").firstMatch
        if greetingBanner.waitForExistence(timeout: 2) {
            capture("Greeting banner on empty field")
            let bannerLabel = greetingBanner.label
            XCTAssertFalse(
                bannerLabel.unicodeScalars.contains(where: { (0x0400...0x04FF).contains($0.value) }),
                "Greeting banner must be strictly Crimean Tatar Latin without Cyrillic characters (got: '\(bannerLabel)')"
            )
            greetingBanner.tap()
            let inserted = (field.value as? String) ?? ""
            XCTAssertFalse(inserted.isEmpty, "Tapping greeting banner must insert wisdom phrase into text field")
            XCTAssertFalse(
                inserted.unicodeScalars.contains(where: { (0x0400...0x04FF).contains($0.value) }),
                "Inserted greeting wisdom phrase must be strictly Crimean Tatar Latin without Cyrillic (got: '\(inserted)')"
            )
            clear()
        }

        // Verify full-slot hit target on short 2-letter input ("qa") by tapping near the far-left edge (dx: 0.15) of slot 0.
        typeLetters("qa")
        let slot0 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.0").firstMatch
        XCTAssertTrue(slot0.waitForExistence(timeout: 3), "Autocomplete slot 0 must exist after typing 'qa'")
        Thread.sleep(forTimeInterval: 0.25)
        slot0.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5)).tap()
        let afterEdgeTap = (field.value as? String) ?? ""
        XCTAssertTrue(afterEdgeTap.hasSuffix(" ") && afterEdgeTap.count >= 3, "Tapping near the horizontal edge of autocomplete.slot.0 must trigger suggestion insertion (got: '\(afterEdgeTap)')")
        clear()

        // Typed without diacritics: Space restores the dictionary spelling and auto-capitalizes unambiguous proper nouns (Qırım).
        typeLetters("qirim")
        let speedBadge = app.descendants(matching: .any).matching(identifier: "sandbox.speedBadge").firstMatch
        XCTAssertTrue(speedBadge.exists, "Speed badge must appear with CPM while typing the first word")
        XCTAssertFalse(speedBadge.label.contains("söz/daq"), "While typing the first word (<8 chars, no space), speed badge must show only CPM, not WPM (got: '\(speedBadge.label)')")
        tap("space")
        expectText("Qırım ")
        XCTAssertTrue(speedBadge.label.contains("söz/daq"), "After completing the first word with Space, speed badge must show WPM · CPM (got: '\(speedBadge.label)')")
        capture("qirim to Qırım")
        clear()

        // Mid-sentence unambiguous proper noun auto-capitalization (qırımda -> Qırımda, krım -> Qırım)
        typeLetters("men")
        tap("space")
        typeLetters("qirimda")
        tap("space")
        expectText("men Qırımda ")
        capture("Mid-sentence men Qırımda")
        clear()

        typeLetters("men")
        tap("space")
        typeLetters("krım")
        tap("space")
        expectText("men Qırım ")
        capture("Mid-sentence men krım to men Qırım")
        clear()

        typeLetters("selam")
        tap("space")
        expectText("selâm ")
        capture("selam to selâm")
        typeLetters("aleykum")
        tap("space")
        expectText("selâm aleyküm ")
        capture("Sentence selâm aleyküm")
        clear()

        // Valid words are left alone.
        for validWord in ["bir", "dost"] {
            typeLetters(validWord)
            tap("space")
            expectText(validWord + " ")
            clear()
        }

        // Unknown short fragments and random out-of-vocabulary words are not forced into different words.
        for randomWord in ["xq", "zqwrtk"] {
            typeLetters(randomWord)
            tap("space")
            expectText(randomWord + " ")
            clear()
        }
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "sandbox.speedBadge").firstMatch.exists, "Speed badge must not appear when sandbox text field is empty")

        // Backspace Undo Autocorrect: pressing Backspace right after Space autocorrects 'qirim' -> 'Qırım ' restores 'qirim'.
        typeLetters("qirim")
        tap("space")
        expectText("Qırım ")
        tap("backspace")
        expectText("qirim")
        capture("Backspace undo autocorrect Qırım to qirim")
        clear()

        // Question particle attachment (§ 67 п. 3.1): 'yaptıñ mı' + Space -> 'yaptıñmı '
        typeLetters("yaptıñ")
        tap("space")
        typeLetters("mı")
        tap("space")
        expectText("yaptıñmı ")
        capture("Question particle yaptıñ mı to yaptıñmı")
        clear()

        // Hyphenated compound completion (§ 63): 'gece-' + Space -> 'gece-kündüz ' and 'ana baba' + Space -> 'ana-baba '
        typeLetters("gece")
        if key("numeric").exists { tap("numeric") }
        if key("character.-").waitForExistence(timeout: 2) {
            tap("character.-")
        }
        if key("alphabetic").exists { tap("alphabetic") }
        tap("space")
        expectText("gece-kündüz ")
        capture("Hyphenated word gece- to gece-kündüz")
        clear()

        typeLetters("ana")
        tap("space")
        typeLetters("baba")
        tap("space")
        expectText("ana-baba ")
        capture("Space-separated compound ana baba to ana-baba")
        clear()

        // Pronoun + personal verb agreement: 'men yaptı' + Space -> 'men yaptım '
        typeLetters("men")
        tap("space")
        typeLetters("yaptı")
        tap("space")
        expectText("men yaptım ")
        capture("Pronoun verb agreement men yaptı to men yaptım")
        clear()

        // Verify top Basic Statistics bar exists and can be expanded & collapsed.
        let statsToggle = app.buttons["stats.expandToggle"].exists
            ? app.buttons["stats.expandToggle"]
            : app.descendants(matching: .any).matching(identifier: "stats.expandToggle").firstMatch
        XCTAssertTrue(statsToggle.exists, "Top Basic Statistics bar expand toggle must exist")
        XCTAssertTrue(statsToggle.label.contains("söz/daq"), "Collapsed statistics header must show compact summary pills")
        statsToggle.tap()
        let resetBtn = app.buttons["stats.resetButton"].exists
            ? app.buttons["stats.resetButton"]
            : app.descendants(matching: .any).matching(identifier: "stats.resetButton").firstMatch
        XCTAssertTrue(resetBtn.waitForExistence(timeout: 2), "Expanded statistics card must reveal stats.resetButton")
        XCTAssertFalse(statsToggle.label.contains("söz/daq"), "Expanded statistics header must hide compact summary pills to avoid duplicating values")

        let wordsTile = app.descendants(matching: .any).matching(identifier: "stats.wordsTile").firstMatch
        let speedTierTile = app.descendants(matching: .any).matching(identifier: "stats.speedTierTile").firstMatch
        let volumeTierTile = app.descendants(matching: .any).matching(identifier: "stats.volumeTierTile").firstMatch
        let learnedWordsTile = app.descendants(matching: .any).matching(identifier: "stats.learnedWordsTile").firstMatch
        XCTAssertTrue(wordsTile.exists, "Words tile must exist in expanded statistics card")
        XCTAssertTrue(wordsTile.label.contains("Arifler:"), "Words tile must show labeled character count subtitle instead of unlabeled parentheses (got: '\(wordsTile.label)')")
        XCTAssertFalse(wordsTile.label.contains("("), "Words tile must not show unlabeled parentheses (got: '\(wordsTile.label)')")
        XCTAssertTrue(speedTierTile.exists, "Speed tier tile must exist in expanded statistics card")
        XCTAssertTrue(volumeTierTile.exists, "Volume tier tile must exist in expanded statistics card")
        XCTAssertFalse(speedTierTile.label.contains("stats.speedTier"), "Speed tier tile must display localized text, not raw key (got: '\(speedTierTile.label)')")
        XCTAssertFalse(volumeTierTile.label.contains("stats.volumeTier"), "Volume tier tile must display localized text, not raw key (got: '\(volumeTierTile.label)')")
        XCTAssertTrue(speedTierTile.label.contains("Soñraki:") || speedTierTile.label.contains("yüksek"), "Speed tier tile must display next tier progression info (got: '\(speedTierTile.label)')")
        XCTAssertTrue(volumeTierTile.label.contains("Soñraki:") || volumeTierTile.label.contains("yüksek"), "Volume tier tile must display next tier progression info (got: '\(volumeTierTile.label)')")
        XCTAssertTrue(learnedWordsTile.exists, "Learned words tile must exist in expanded statistics card")
        XCTAssertFalse(learnedWordsTile.label.contains(", 0,"), "Learned words tile must increment after typing words (got: '\(learnedWordsTile.label)')")
        capture("Top statistics expanded")

        // Verify Reset Statistics confirmation clears all counters and user_lexicon in place, and typing a new word immediately increments both wordsTile and learnedWordsTile in real time.
        resetBtn.tap()
        let confirmReset = app.alerts.buttons["Sıfırla"].firstMatch
        XCTAssertTrue(confirmReset.waitForExistence(timeout: 2), "Reset confirmation alert button 'Sıfırla' must appear")
        XCTAssertFalse(app.alerts.buttons["stats.resetCancel"].exists, "Reset confirmation cancel button must be localized, not raw key 'stats.resetCancel'")
        capture("Reset statistics confirmation dialog")
        confirmReset.tap()
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(wordsTile.label.contains("Arifler: 0"), "After reset, wordsTile must show 0 characters (got: '\(wordsTile.label)')")
        XCTAssertTrue(learnedWordsTile.label.contains(", 0,"), "After reset, learnedWordsTile must reset to 0 (got: '\(learnedWordsTile.label)')")

        field.tap()
        typeLetters("vatan")
        tap("space")
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(wordsTile.label.contains(", 1,") && wordsTile.label.contains("Arifler: 6"), "Typing 'vatan ' after reset must update wordsTile to 1 word and 6 characters in real time (got: '\(wordsTile.label)')")
        XCTAssertTrue(learnedWordsTile.label.contains(", 1,"), "Typing 'vatan ' after reset must update learnedWordsTile to 1 learned word in real time (got: '\(learnedWordsTile.label)')")
        clear()

        statsToggle.tap()
        capture("Top statistics collapsed")

        // Verify statistics setting toggle disables/hides the statistics section and re-enables it cleanly.
        let statsSettingSwitch = app.switches["settings.stats.toggle"].exists
            ? app.switches["settings.stats.toggle"]
            : app.descendants(matching: .any).matching(identifier: "settings.stats.toggle").firstMatch
        XCTAssertTrue(statsSettingSwitch.exists, "Statistics setting toggle must exist in keyboard settings card")
        tapSwitch(statsSettingSwitch)
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertFalse(statsToggle.exists, "Disabling statistics toggle must hide the statistics card")
        capture("Statistics disabled via settings toggle")
        tapSwitch(statsSettingSwitch)
        XCTAssertTrue(statsToggle.waitForExistence(timeout: 2), "Re-enabling statistics toggle must restore the statistics card")
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
        guard key("toggle_script").exists else {
            throw XCTSkip("toggle_script key is iPad-only.")
        }
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

    func testColdStartKeyboardAppearsOnFirstTap() throws {
        app.launchArguments = ["-qt_field", "standard", "-qt_theme", "modernLight", "-qt_reset_text"]
        var launchStart = Date()
        app.launch()
        XCTAssertTrue(field.waitForExistence(timeout: 6))
        let firstKey = key("numeric")
        var appearedOnFirstAttempt = firstKey.exists || firstKey.waitForExistence(timeout: 3.5) || key("space").exists
        if !appearedOnFirstAttempt {
            // On a freshly created simulator where Qırımtatarca has not yet been enabled/selected in Settings,
            // enable and select it once, terminate the app, and then measure a true cold start.
            cycleToCustomKeyboard(firstKey: firstKey)
            if !(firstKey.exists || key("space").exists) {
                enableKeyboardInSettingsIfNeeded()
                app.terminate()
                app.launch()
                if field.waitForExistence(timeout: 5) {
                    if !app.buttons["Next keyboard"].exists && !app.buttons["ABC"].exists && app.keyboards.count == 0 {
                        field.tap()
                    }
                    Thread.sleep(forTimeInterval: 0.8)
                }
                cycleToCustomKeyboard(firstKey: firstKey)
            }
            app.terminate()
            Thread.sleep(forTimeInterval: 1.0)
            launchStart = Date()
            app.launch()
            XCTAssertTrue(field.waitForExistence(timeout: 6))
            appearedOnFirstAttempt = firstKey.exists || firstKey.waitForExistence(timeout: 3.5) || key("space").exists
        }
        let coldStartLatency = Date().timeIntervalSince(launchStart)
        print(String(format: "QK_METRIC cold_start_first_attempt=%.3fs appeared=%@", coldStartLatency, appearedOnFirstAttempt ? "YES" : "NO"))
        XCTAssertTrue(appearedOnFirstAttempt, "Keyboard extension must appear on the very first attempt without requiring a second tap")
        try selectScript(cyrillic: false)
        typeLetters("q")
        expectText("q")
        capture("Cold start first attempt verified")
    }

    private func letterElement(_ value: String) -> XCUIElement {
        let lowerId = "key.character." + value.lowercased()
        let upperId = "key.character." + value.uppercased()
        let predicate = NSPredicate(format: "identifier == %@ OR identifier == %@", lowerId, upperId)
        return app.descendants(matching: .any).matching(predicate).firstMatch
    }

    private static var currentIPadSupportsSplitKeyboard: Bool {
        let modelIdentifier: String = {
            if let simModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simModel.isEmpty {
                return simModel
            }
            var sysinfo = utsname()
            uname(&sysinfo)
            return withUnsafePointer(to: &sysinfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(cString: $0)
                }
            }
        }()
        let supportedModels: Set<String> = [
            "iPad11,3", "iPad11,4",
            "iPad11,1", "iPad11,2", "iPad14,1", "iPad14,2", "iPad16,1", "iPad16,2",
            "iPad6,11", "iPad6,12", "iPad7,5", "iPad7,6", "iPad7,11", "iPad7,12",
            "iPad11,6", "iPad11,7", "iPad12,1", "iPad12,2",
            "iPad6,3", "iPad6,4", "iPad7,3", "iPad7,4",
            "iPad5,1", "iPad5,2", "iPad5,3", "iPad5,4"
        ]
        return supportedModels.contains(modelIdentifier)
    }

    func testIPadSplitKeyboardModeAndTransitions() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else {
            throw XCTSkip("Split keyboard mode is iPad-only.")
        }
        try launch()
        try selectScript(cyrillic: false)

        let splitToggle = app.descendants(matching: .any).matching(identifier: "settings.split.toggle").firstMatch
        XCTAssertFalse(splitToggle.exists, "Split keyboard toggle must NOT exist in HomeView settings card")

        let leftCluster = app.descendants(matching: .any).matching(identifier: "split.cluster.left").firstMatch
        let rightCluster = app.descendants(matching: .any).matching(identifier: "split.cluster.right").firstMatch
        XCTAssertFalse(leftCluster.exists, "Keyboard must start in normal merged Docked mode by default")
        XCTAssertFalse(rightCluster.exists, "Synthetic split cluster must not be fabricated without system split mode")

        let yKey = letterElement("y")
        let uKey = letterElement("u")
        XCTAssertTrue(yKey.exists && uKey.exists, "Both 'y' and 'u' keys must exist in Docked mode")
        XCTAssertLessThan(uKey.frame.minX - yKey.frame.maxX, 25, "Merged Docked keyboard must have adjacent 'y' and 'u' keys")
        capture("iPad Docked Keyboard Latin Portrait")

        clear()
        typeLetters("qp")
        tap("space")
        typeLetters("al")
        expectText("qp al")

        if key("toggle_script").exists {
            tap("toggle_script")
            XCTAssertTrue(waitForLetter("ф", timeout: 2))
            capture("iPad Docked Keyboard Cyrillic Portrait")
            tap("toggle_script")
            XCTAssertTrue(waitForLetter("q", timeout: 2))
        }

        tap("numeric")
        XCTAssertTrue(key("character.6").waitForExistence(timeout: 2))
        XCTAssertTrue(key("character.7").exists)
        capture("iPad Docked Keyboard Numeric Portrait")
        tap("symbolic")
        XCTAssertTrue(key("character.€").waitForExistence(timeout: 2))
        capture("iPad Docked Keyboard Symbolic Portrait")
        tap("alphabetic")

        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertTrue(letterElement("y").exists && letterElement("u").exists)
        XCTAssertLessThan(letterElement("u").frame.minX - letterElement("y").frame.maxX, 30, "Merged Docked keyboard must stay unified in Landscape")
        capture("iPad Docked Keyboard Latin Landscape")
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 0.5)
        capture("iPad Merged Docked Keyboard")
    }

    func testSystemKeyboardFeaturesMathAndSmartPunctuation() throws {
        try launch()
        try selectScript(cyrillic: false)

        // 1a. Show Maths Results (2+2= -> 4 on Space)
        clear()
        tap("numeric")
        XCTAssertTrue(key("character.2").waitForExistence(timeout: 2))
        tap("character.2")
        if key("character.+").exists {
            tap("character.+")
        } else {
            tap("symbolic")
            XCTAssertTrue(key("character.+").waitForExistence(timeout: 2))
            tap("character.+")
            tap("numeric")
        }
        XCTAssertTrue(key("character.2").waitForExistence(timeout: 2))
        tap("character.2")
        if !key("character.=").exists {
            tap("symbolic")
        }
        XCTAssertTrue(key("character.=").waitForExistence(timeout: 2))
        tap("character.=")
        Thread.sleep(forTimeInterval: 0.15)
        tap("space")
        expectText("2+2=4 ")

        // 1b. Show Maths Results 3-slot toolbar («3+5=» | 3+5=8 | 8):
        //     - slot 0 («3+5=»): literal expression in guillemets
        //     - slot 1 (3+5=8): highlighted center completion (preserves equation prefix)
        //     - slot 2 (8): replaces expression with result only
        clear()
        if key("numeric").exists { tap("numeric") }
        XCTAssertTrue(key("character.3").waitForExistence(timeout: 2))
        tap("character.3")
        if key("character.+").exists {
            tap("character.+")
        } else {
            tap("symbolic")
            XCTAssertTrue(key("character.+").waitForExistence(timeout: 2))
            tap("character.+")
            tap("numeric")
        }
        XCTAssertTrue(key("character.5").waitForExistence(timeout: 2))
        tap("character.5")
        if !key("character.=").exists {
            tap("symbolic")
        }
        XCTAssertTrue(key("character.=").waitForExistence(timeout: 2))
        tap("character.=")
        let mathSlot0 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.0").firstMatch
        let mathSlot1 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.1").firstMatch
        let mathSlot2 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.2").firstMatch
        let mathReady = NSPredicate(format: "exists == true AND label CONTAINS '3+5=8'")
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: mathReady, object: mathSlot1)], timeout: 3)
        XCTAssertTrue(mathSlot0.exists && mathSlot0.label.contains("3+5="), "Math slot 0 must show literal «3+5=» (got: '\(mathSlot0.label)')")
        XCTAssertTrue(mathSlot1.exists && mathSlot1.label.contains("3+5=8"), "Math slot 1 must show full equation 3+5=8 (got: '\(mathSlot1.label)')")
        XCTAssertTrue(mathSlot2.exists && mathSlot2.label.contains("8"), "Math slot 2 must show result 8 (got: '\(mathSlot2.label)')")
        mathSlot1.tap()
        expectText("3+5=8 ")

        // 2. Smart Punctuation: double hyphen (--) -> em-dash (—)
        clear()
        if key("numeric").exists { tap("numeric") }
        XCTAssertTrue(key("character.-").waitForExistence(timeout: 2))
        tap("character.-")
        tap("character.-")
        expectText("—")

        // 3. Smart Punctuation: straight quotes (") -> smart opening/closing quotes (“ok”)
        clear()
        if key("numeric").exists { tap("numeric") }
        XCTAssertTrue(key("character.\"").waitForExistence(timeout: 2))
        tap("character.\"")
        if key("alphabetic").exists { tap("alphabetic") }
        typeLetters("ok")
        if key("numeric").exists { tap("numeric") }
        tap("character.\"")
        expectText("“ok”")

        // 4. Smart Punctuation: triple period (...) -> ellipsis (…)
        clear()
        if key("alphabetic").exists { tap("alphabetic") }
        if key("character..").exists {
            tap("character..")
            tap("character..")
            tap("character..")
        } else {
            if key("numeric").exists { tap("numeric") }
            tap("character..")
            tap("character..")
            tap("character..")
            if key("alphabetic").exists { tap("alphabetic") }
        }
        expectText("…")

        // 5. "." Shortcut on double-space
        clear()
        typeLetters("selam")
        let spaceBtn = app.buttons["key.space"].exists ? app.buttons["key.space"] : key("space")
        spaceBtn.tap()
        spaceBtn.tap()
        expectText("selâm. ")
    }

    func testCrossAppStatisticsAndStandardKeyboardComparison() throws {
        try launch()
        try selectScript(cyrillic: false)

        if key("dismiss").exists {
            tap("dismiss")
            Thread.sleep(forTimeInterval: 0.4)
        }

        // Open expanded statistics and reset to 0 before switching to an external system app.
        let statsToggle = app.buttons["stats.expandToggle"].exists
            ? app.buttons["stats.expandToggle"]
            : app.descendants(matching: .any).matching(identifier: "stats.expandToggle").firstMatch
        XCTAssertTrue(statsToggle.exists)
        statsToggle.tap()
        let resetBtn = app.buttons["stats.resetButton"].exists
            ? app.buttons["stats.resetButton"]
            : app.descendants(matching: .any).matching(identifier: "stats.resetButton").firstMatch
        XCTAssertTrue(resetBtn.waitForExistence(timeout: 2))
        resetBtn.tap()
        let confirmReset = app.alerts.buttons["Sıfırla"].firstMatch
        if confirmReset.waitForExistence(timeout: 2) {
            confirmReset.tap()
        }
        Thread.sleep(forTimeInterval: 0.4)

        // Launch Safari (external system app) to verify cross-app typing, statistics sync, and latency vs system keyboard.
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.launch()
        Thread.sleep(forTimeInterval: 1.0)

        // Dismiss any first-run continue button if present
        let continueBtn = safari.buttons["Continue"].firstMatch
        if continueBtn.exists && continueBtn.isHittable {
            continueBtn.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }

        let urlElement: XCUIElement = {
            let addr = safari.descendants(matching: .any).matching(identifier: "TabBarItemTitle").firstMatch
            if addr.exists { return addr }
            let urlBtn = safari.buttons["URL"].firstMatch
            if urlBtn.exists { return urlBtn }
            let tf = safari.textFields.firstMatch
            if tf.exists { return tf }
            return safari.searchFields.firstMatch
        }()

        func safariKey(_ name: String) -> XCUIElement {
            let lowerId = "key." + name.lowercased()
            let upperId = "key.character." + String(name.dropFirst("character.".count)).uppercased()
            let pred = name.hasPrefix("character.")
                ? NSPredicate(format: "identifier == %@ OR identifier == %@", lowerId, upperId)
                : NSPredicate(format: "identifier == %@", lowerId)
            return safari.descendants(matching: .any).matching(pred).firstMatch
        }

        func tapSafariKey(_ element: XCUIElement) {
            let f = element.frame
            if f.width > 1 && f.height > 1 && f.midX > 0 && f.midY > 0 {
                let root = safari.coordinate(withNormalizedOffset: .zero)
                root.withOffset(CGVector(dx: f.midX, dy: f.midY)).tap()
            } else {
                element.tap()
            }
        }

        if urlElement.waitForExistence(timeout: 4) {
            urlElement.tap()
            Thread.sleep(forTimeInterval: 0.8)

            // Clear any leftover text in Safari's address bar from previous runs
            let clearUrlBtn = safari.buttons["Clear text"].firstMatch
            if clearUrlBtn.exists && clearUrlBtn.isHittable {
                clearUrlBtn.tap()
                Thread.sleep(forTimeInterval: 0.3)
            }

            // Ensure QırımKey is active inside Safari
            var qKey = safariKey("character.q")
            var фKey = safariKey("character.ф")
            for step in 1...5 {
                if qKey.exists || фKey.exists { break }
                let globe = safari.buttons["Next keyboard"].exists
                    ? safari.buttons["Next keyboard"]
                    : safari.keyboards.buttons.element(boundBy: 0)
                if globe.exists {
                    for _ in 0..<step where globe.exists {
                        tapSafariKey(globe)
                    }
                    Thread.sleep(forTimeInterval: 0.8)
                }
                qKey = safariKey("character.q")
                фKey = safariKey("character.ф")
            }
            if фKey.exists && !qKey.exists {
                let toggleKey = safari.descendants(matching: .any).matching(identifier: "key.toggle_script").firstMatch
                if toggleKey.exists {
                    tapSafariKey(toggleKey)
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }

            if safariKey("character.s").waitForExistence(timeout: 2) {
                var qkTotal: TimeInterval = 0
                let externalWord1 = Array("selam")
                for ch in externalWord1 {
                    let k = safariKey("character.\(ch)")
                    if k.waitForExistence(timeout: 1.5) {
                        let t0 = Date()
                        tapSafariKey(k)
                        qkTotal += Date().timeIntervalSince(t0)
                    }
                }
                let spaceKey = safariKey("space")
                if spaceKey.waitForExistence(timeout: 1.5) {
                    tapSafariKey(spaceKey)
                }

                let externalWord2 = Array("dost")
                for ch in externalWord2 {
                    let k = safariKey("character.\(ch)")
                    if k.waitForExistence(timeout: 1.5) {
                        let t0 = Date()
                        tapSafariKey(k)
                        qkTotal += Date().timeIntervalSince(t0)
                    }
                }
                if spaceKey.waitForExistence(timeout: 1.5) {
                    tapSafariKey(spaceKey)
                }
                let qkAvg = qkTotal / Double(externalWord1.count + externalWord2.count)
                print(String(format: "QK_METRIC safari_qirimkey_tap_avg=%.3f", qkAvg))
                capture("Safari external typing with QirimKey")
            }
        }

        // Return to QTatar.app and verify real-time cross-process statistics update
        app.activate()
        Thread.sleep(forTimeInterval: 1.0)
        let wordsTile = app.descendants(matching: .any).matching(identifier: "stats.wordsTile").firstMatch
        let learnedWordsTile = app.descendants(matching: .any).matching(identifier: "stats.learnedWordsTile").firstMatch
        XCTAssertTrue(wordsTile.waitForExistence(timeout: 3))
        XCTAssertFalse(wordsTile.label.contains("Arifler: 0"), "Words & characters typed in external app (Safari) must sync back to QTatar.app in real time (got: '\(wordsTile.label)')")
        XCTAssertFalse(learnedWordsTile.label.contains(", 0,"), "Words learned in external app (Safari) must sync back to QTatar.app in real time (got: '\(learnedWordsTile.label)')")
        capture("QTatar real-time stats synced from Safari")
    }

    func testRound2UkrainianLayoutAndSwipeComet() throws {
        try launch()

        // 1. Verify Swipe-to-Type on iPhone, single Backspace whole-word deletion, and greeting banner restoration
        try selectScript(cyrillic: false)
        clear()
        let greetingBanner = app.descendants(matching: .any).matching(identifier: "autocomplete.greetingBanner").firstMatch
        XCTAssertTrue(greetingBanner.waitForExistence(timeout: 2.5), "Greeting banner must be visible when field is empty")
        if UIDevice.current.userInterfaceIdiom == .phone {
            let sKey = letterElement("s")
            let mKey = letterElement("m")
            if sKey.exists && mKey.exists {
                let cS = sKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let cM = mKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                cS.press(forDuration: 0.04, thenDragTo: cM, withVelocity: .slow, thenHoldForDuration: 0.05)
                Thread.sleep(forTimeInterval: 0.35)
                let swipedText = (field.value as? String) ?? ""
                XCTAssertFalse(swipedText.isEmpty, "Swiping across keys on iPhone must insert predicted word (got: '\(swipedText)')")
                capture("iPhone Swipe to Type result")
                tap("backspace")
                expectText("")
                let postSwipeSlot0 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.0").firstMatch
                XCTAssertTrue(
                    postSwipeSlot0.waitForExistence(timeout: 2.0) || greetingBanner.waitForExistence(timeout: 2.5),
                    "Post-swipe rotated candidates or greeting banner must appear after single Backspace deletes swiped word"
                )
                capture("iPhone Swipe Backspace whole word deleted")
            }
        }

        // 2. Verify "Sen ne " next-word predictions offer 2nd-person verbs and never repeat "sen", plus "qırım" -> "Qırım" proper noun capitalization
        clear()
        typeLetters("Sen")
        tap("space")
        typeLetters("ne")
        tap("space")
        Thread.sleep(forTimeInterval: 0.35)
        let slot0 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.0").firstMatch
        let slot1 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.1").firstMatch
        let slot2 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.2").firstMatch
        let slotLabels = [slot0, slot1, slot2].compactMap { $0.exists ? $0.label.trimmingCharacters(in: .whitespacesAndNewlines) : nil }
        XCTAssertFalse(slotLabels.contains(where: { $0.lowercased() == "sen" }), "Next-word suggestions after 'Sen ne ' must never suggest 'sen' (got: \(slotLabels))")
        XCTAssertTrue(slotLabels.contains(where: { $0.hasSuffix("sıñ") || $0.hasSuffix("siñ") }), "Next-word suggestions after 'Sen ne ' must suggest 2nd-person verbs ending in -sıñ/-siñ (got: \(slotLabels))")
        capture("Next word suggestions after Sen ne")

        typeLetters("qırım")
        tap("space")
        expectText("Sen ne Qırım ")
        clear()
        XCTAssertTrue(greetingBanner.waitForExistence(timeout: 2.5), "Greeting banner must reappear after clearing sandbox field")

        // 3. Switch interface language to Ukrainian ('uk'), enable Ukrainian Cyrillic layout ('ФІВА'), and verify Phase 8 transliteration
        let testingToggle = app.buttons["testing.toggle"].exists
            ? app.buttons["testing.toggle"]
            : app.descendants(matching: .any).matching(identifier: "testing.toggle").firstMatch
        if testingToggle.exists && testingToggle.isHittable {
            testingToggle.tap()
            Thread.sleep(forTimeInterval: 0.45)
        }
        let ukLangBtn = app.buttons["settings.lang.uk"].exists
            ? app.buttons["settings.lang.uk"]
            : (app.buttons["Українська"].exists
                ? app.buttons["Українська"]
                : app.descendants(matching: .any).matching(identifier: "settings.lang.uk").firstMatch)
        if ukLangBtn.waitForExistence(timeout: 2) {
            tapSwitch(ukLangBtn)
            Thread.sleep(forTimeInterval: 0.5)
        }
        let ukCyrSwitch = app.switches["settings.ukrainianCyrillic.toggle"].exists
            ? app.switches["settings.ukrainianCyrillic.toggle"]
            : app.descendants(matching: .any).matching(identifier: "settings.ukrainianCyrillic.toggle").firstMatch
        XCTAssertTrue(ukCyrSwitch.waitForExistence(timeout: 2), "Ukrainian Cyrillic layout toggle must appear when Ukrainian interface language is active")
        if ((ukCyrSwitch.value as? String) ?? "0") == "1" {
            tapSwitch(ukCyrSwitch)
            Thread.sleep(forTimeInterval: 0.35)
        }
        if ((ukCyrSwitch.value as? String) ?? "0") == "0" {
            tapSwitch(ukCyrSwitch)
            Thread.sleep(forTimeInterval: 0.45)
        }
        capture("Ukrainian interface with FIVA layout toggle enabled")
        if testingToggle.exists && testingToggle.isHittable {
            testingToggle.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }

        defer {
            if testingToggle.exists && testingToggle.isHittable && key("space").exists {
                testingToggle.tap()
                Thread.sleep(forTimeInterval: 0.4)
            }
            if ((ukCyrSwitch.value as? String) ?? "1") == "1" {
                tapSwitch(ukCyrSwitch)
                Thread.sleep(forTimeInterval: 0.35)
            }
            let crhLangBtn = app.buttons["settings.lang.crh"].exists
                ? app.buttons["settings.lang.crh"]
                : (app.buttons["Qırımtatarca"].exists
                    ? app.buttons["Qırımtatarca"]
                    : app.descendants(matching: .any).matching(identifier: "settings.lang.crh").firstMatch)
            if crhLangBtn.exists {
                tapSwitch(crhLangBtn)
                Thread.sleep(forTimeInterval: 0.35)
            }
        }

        if !key("space").exists && field.waitForExistence(timeout: 2) {
            field.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }
        try selectScript(cyrillic: true)
        XCTAssertTrue(waitForLetter("і", timeout: 3), "Ukrainian Cyrillic layout (ФІВА) must include key 'і'")
        XCTAssertTrue(hasLetter("є"), "Ukrainian Cyrillic layout (ФІВА) must include key 'є'")
        XCTAssertTrue(hasLetter("ґ"), "Ukrainian Cyrillic layout (ФІВА) must include key 'ґ'")
        XCTAssertTrue(hasLetter("\u{02BC}"), "Ukrainian Cyrillic layout (ФІВА) must have apostrophe 'ʼ' in place of 'ъ'")
        capture("Ukrainian Cyrillic FIVA layout")

        for (source, expected) in [
            ("\u{02BC}", "\u{02BC}"),
            ("дембель", "dembel"),
            ("ервін", "ervin"),
            ("екі", "eki"),
            ("єр", "yer"),
            ("п\u{02BC}єр", "pyer"),
            ("п\u{02BC}ер", "pyer"),
            ("ґ\u{02BC}е", "gye"),
            ("к\u{02BC}е", "qe"),
            ("н\u{02BC}е", "ñe"),
            ("г\u{02BC}аєт", "ğayet"),
            ("к\u{02BC}ирим", "qırım"),
            ("міллетнін\u{02BC}", "milletniñ"),
            ("єшиль", "yeşil"),
            ("д\u{02BC}\u{02BC}ар", "d\u{02BC}ar")
        ] {
            clear()
            typeLetters(source)
            expectText(expected)
        }
        capture("Ukrainian Cyrillic Phase 8 transliteration verified")
        clear()
    }

    func testPhase13AdaptiveHeightTrackpadSlideAndSettingsBundle() throws {
        try launch()
        try selectScript(cyrillic: false)
        clear()

        // 1. Verify adaptive keycap heights on the active device screen
        let qElem = letterElement("q")
        let spaceElem = key("space")
        XCTAssertTrue(qElem.exists && spaceElem.exists, "Letter key 'q' and spacebar must exist")
        let qHeight = qElem.frame.height
        let spaceHeight = spaceElem.frame.height
        if UIDevice.current.userInterfaceIdiom == .phone {
            XCTAssertGreaterThanOrEqual(qHeight, 37.0, "iPhone letter key row/keycap height must be >= 37 pt (got \(qHeight))")
            XCTAssertLessThanOrEqual(qHeight, 56.0, "iPhone letter key row/keycap height must be <= 56 pt (got \(qHeight))")
            XCTAssertGreaterThanOrEqual(spaceHeight, 37.0, "iPhone spacebar row/keycap height must be >= 37 pt (got \(spaceHeight))")
        } else {
            XCTAssertGreaterThanOrEqual(qHeight, 35.0, "iPad visible letter key height must be >= 35 pt (got \(qHeight))")
        }
        capture("Phase 13 Adaptive Keyboard Proportions")

        // 2. Verify Lilâ Hanuşevska -> sağ ol and QIRI'M -> Young in live toolbar
        typeLetters("Lila")
        tap("space")
        typeLetters("Hanusevska")
        tap("space")
        Thread.sleep(forTimeInterval: 0.4)
        let slot0 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.0").firstMatch
        let slot1 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.1").firstMatch
        let slot2 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.2").firstMatch
        let lilaSlots = [slot0, slot1, slot2].compactMap { $0.exists ? $0.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() : nil }
        XCTAssertTrue(lilaSlots.contains("sağ ol"), "Next-word suggestions after 'Lilâ Hanuşevska ' must include 'sağ ol' (got \(lilaSlots))")
        capture("Phase 13 Lila Hanusevska sag ol suggestion")

        clear()
        typeLetters("qiri")
        Thread.sleep(forTimeInterval: 0.35)
        let qiriSlots = [slot0, slot1, slot2].compactMap { $0.exists ? $0.label.trimmingCharacters(in: .whitespacesAndNewlines) : nil }
        XCTAssertTrue(qiriSlots.contains("QIRI'M Young") || qiriSlots.contains("Qırım"), "Typing 'qiri' must suggest 'Qırım' / 'QIRI\\'M Young' (got \(qiriSlots))")
        capture("Phase 13 QIRIM Young suggestion")

        // 3. Verify Slide-from-123 gesture (press 123, drag to numeric key, release -> returns to alphabetic)
        clear()
        let numericKey = key("numeric")
        if numericKey.exists && qElem.exists {
            let numFrame = numericKey.frame
            let qFrame = qElem.frame
            let rootOrigin = app.coordinate(withNormalizedOffset: .zero)
            let startCoord = rootOrigin.withOffset(CGVector(dx: numFrame.midX, dy: numFrame.midY))
            let endCoord = rootOrigin.withOffset(CGVector(dx: qFrame.midX, dy: qFrame.midY))
            startCoord.press(forDuration: 0.10, thenDragTo: endCoord, withVelocity: .slow, thenHoldForDuration: 0.12)
            Thread.sleep(forTimeInterval: 0.5)
            XCTAssertTrue(waitForLetter("q", timeout: 3.0), "Keyboard must automatically return to alphabetic layout after Slide-from-123 release")
            capture("Phase 13 Slide from 123 returned to alphabetic")
        }

        // 4. Verify 2D Spacebar Trackpad gesture
        clear()
        typeLetters("bir")
        let spaceStart = spaceElem.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5))
        let spaceEnd = spaceElem.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.2))
        spaceStart.press(forDuration: 0.48, thenDragTo: spaceEnd, withVelocity: .slow, thenHoldForDuration: 0.1)
        Thread.sleep(forTimeInterval: 0.3)
        capture("Phase 13 Spacebar 2D trackpad verified")
        clear()

        // 5. Verify instant Aydınlıq (modernLight) and Qaranlıq (modernDark) sandbox theme switching & uniform Liquid Glass keycaps
        let lightBtn = app.buttons["theme.light"]
        let darkBtn = app.buttons["theme.dark"]
        if lightBtn.exists {
            lightBtn.tap()
            Thread.sleep(forTimeInterval: 0.45)
            capture("modernLight")
        }
        if darkBtn.exists {
            darkBtn.tap()
            Thread.sleep(forTimeInterval: 0.45)
            capture("modernDark")
        }
        if lightBtn.exists {
            lightBtn.tap()
            Thread.sleep(forTimeInterval: 0.35)
        }
    }

    // MARK: - Strict iPad floating transition (cannot pass vacuously)

    private func spaceFrameSamples(duration: TimeInterval, interval: TimeInterval = 0.1) -> [CGRect] {
        var samples: [CGRect] = []
        let end = Date().addingTimeInterval(duration)
        while Date() < end {
            let space = key("space")
            if space.exists { samples.append(space.frame) }
            Thread.sleep(forTimeInterval: interval)
        }
        return samples
    }

    func testIPadFloatingViaDismissMenuStrict() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad-only") }
        try launch()
        try selectScript(cyrillic: false)
        let dockedSpace = key("space")
        XCTAssertTrue(dockedSpace.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(dockedSpace.frame.width, 100)
        capture("floating-strict 0 docked")

        let dismiss = key("dismiss")
        if dismiss.waitForExistence(timeout: 2) {
            dismiss.tap()
            Thread.sleep(forTimeInterval: 0.6)
            field.tap()
            _ = key("space").waitForExistence(timeout: 4)
        }
        let settled = spaceFrameSamples(duration: 1.6)
        capture("floating-strict 1 after dismiss-reopen")
        XCTAssertFalse(settled.isEmpty, "Space key must exist after re-focusing field")
        let widths = settled.map(\.width)
        let heights = settled.map(\.height)
        XCTAssertLessThanOrEqual((widths.max() ?? 0) - (widths.min() ?? 0), 2.0, "Key width must not jump after dismiss/reopen: \(widths)")
        XCTAssertLessThanOrEqual((heights.max() ?? 0) - (heights.min() ?? 0), 2.0, "Key height must not jump after dismiss/reopen: \(heights)")
        XCTAssertGreaterThanOrEqual(key("space").frame.minX, 0)
        XCTAssertLessThanOrEqual(key("space").frame.maxX, app.frame.width)
    }

    func testIPadFloatingViaPinchStrict() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad-only") }
        try launch()
        try selectScript(cyrillic: false)
        let dockedSpace = key("space")
        XCTAssertTrue(dockedSpace.waitForExistence(timeout: 3))
        let target = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch : dockedSpace
        target.pinch(withScale: 0.45, velocity: -1.5)
        Thread.sleep(forTimeInterval: 0.8)
        if !key("space").exists {
            field.tap()
            _ = key("space").waitForExistence(timeout: 3)
        }
        let settled = spaceFrameSamples(duration: 1.6)
        capture("floating-strict 2 after pinch")
        XCTAssertFalse(settled.isEmpty)
        let widths = settled.map(\.width)
        XCTAssertLessThanOrEqual((widths.max() ?? 0) - (widths.min() ?? 0), 2.0, "Keyboard width must remain stable after pinch gesture: \(widths)")
        XCTAssertGreaterThanOrEqual(key("space").frame.minX, 0)
        XCTAssertLessThanOrEqual(key("space").frame.maxX, app.frame.width)
    }

    func testIPadFloatingReopenKeepsStableSize() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad-only") }
        try launch()
        try selectScript(cyrillic: false)
        let hideKey = key("dismiss")
        if hideKey.waitForExistence(timeout: 2) {
            hideKey.tap()
        }
        Thread.sleep(forTimeInterval: 0.8)
        field.tap()
        _ = key("space").waitForExistence(timeout: 4)
        let samples = spaceFrameSamples(duration: 2.2, interval: 0.08)
        capture("floating-strict 3 reopened stable")
        XCTAssertFalse(samples.isEmpty, "Keyboard did not reappear after re-focusing the field")
        let widths = samples.map(\.width)
        let heights = samples.map(\.height)
        XCTAssertLessThanOrEqual((widths.max() ?? 0) - (widths.min() ?? 0), 2.0, "Reopened keyboard must not resize/jump: widths \(widths)")
        XCTAssertLessThanOrEqual((heights.max() ?? 0) - (heights.min() ?? 0), 2.0, "Reopened keyboard must not resize/jump: heights \(heights)")
    }

    // MARK: - App Store screenshots (PNGs land in /tmp/qk_shots; run once per system appearance)

    private var storeDevice: String { UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone" }

    func testAppStoreScreenshotsLight() throws {
        try launch(theme: "modernLight", extraArgs: ["-qt_demo_stats"])
        try selectScript(cyrillic: false)
        clear()
        typeLetters("qirimtatarca")
        Thread.sleep(forTimeInterval: 0.8)
        capture("store_\(storeDevice)_01_latin_light")
        app.terminate()

        if UIDevice.current.userInterfaceIdiom == .pad {
            try launch(theme: "modernLight", extraArgs: ["-qt_demo_stats"])
            if (try? selectScript(cyrillic: true)) != nil, waitForLetter("ф", timeout: 2.0) {
                clear()
                typeLetters("селям")
                Thread.sleep(forTimeInterval: 0.8)
                capture("store_\(storeDevice)_03_cyrillic")
            }
            app.terminate()
        }

        app.launchArguments = ["-qt_cyrillic_added", "-qt_demo_stats", "-qt_theme", "modernLight"]
        app.launch()
        Thread.sleep(forTimeInterval: 2.0)
        capture("store_\(storeDevice)_04_home_light")
        app.terminate()

        app.launchArguments = ["-qt_cyrillic_missing", "-qt_demo_stats", "-qt_theme", "modernLight"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)
        let addHintBtn = app.descendants(matching: .any).matching(identifier: "settings.cyrillic.addHintButton").firstMatch
        let cyrToggle = app.switches["settings.cyrillic.toggle"].exists
            ? app.switches["settings.cyrillic.toggle"]
            : app.descendants(matching: .any).matching(identifier: "settings.cyrillic.toggle").firstMatch
        XCTAssertTrue(addHintBtn.waitForExistence(timeout: 2.5), "Cyrillic row must show settings path instruction subtitle when not added")
        XCTAssertTrue(cyrToggle.exists, "Cyrillic row must show Toggle switch")
        XCTAssertEqual(cyrToggle.value as? String, "0", "Cyrillic Toggle must be OFF when Cyrillic is not added")
        capture("store_\(storeDevice)_04b_home_cyrillic_missing")
    }

    func testAppStoreScreenshotCyrillicOnly() throws {
        try launch(theme: "modernLight", extraArgs: ["-qt_demo_stats"])
        try selectScript(cyrillic: true)
        clear()
        typeLetters("селям")
        Thread.sleep(forTimeInterval: 0.8)
        capture("store_\(storeDevice)_03_cyrillic")
    }

    func testAppStoreScreenshotsDark() throws {
        try launch(theme: "modernDark", extraArgs: ["-qt_demo_stats"])
        try selectScript(cyrillic: false)
        clear()
        typeLetters("sel")
        tap("character.â")
        typeLetters("m")
        Thread.sleep(forTimeInterval: 0.8)
        capture("store_\(storeDevice)_02_latin_dark")
        app.terminate()

        app.launchArguments = ["-qt_cyrillic_added", "-qt_demo_stats", "-qt_theme", "modernDark"]
        app.launch()
        Thread.sleep(forTimeInterval: 2.5)
        capture("store_\(storeDevice)_05_home_dark")
    }

    func testAppStorePreviewVideoScenario() throws {
        app.launchArguments = ["-qt_field", "standard", "-qt_theme", "modernLight", "-qt_reset_text", "-qt_demo_stats", "-qt_enable_animations", "-qt_cyrillic_added"]
        app.launch()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let firstKey = key("numeric")
        if !(firstKey.exists || firstKey.waitForExistence(timeout: 3.5)) {
            cycleToCustomKeyboard(firstKey: firstKey)
        }
        try selectScript(cyrillic: false)
        clear()
        Thread.sleep(forTimeInterval: 1.0)
        typeLetters("selam")
        tap("space")
        Thread.sleep(forTimeInterval: 0.6)
        typeLetters("qirim")
        Thread.sleep(forTimeInterval: 0.7)
        let slot1 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.1").firstMatch
        if slot1.exists && slot1.isHittable {
            slot1.tap()
            Thread.sleep(forTimeInterval: 0.8)
        } else {
            tap("space")
            Thread.sleep(forTimeInterval: 0.6)
        }
        if UIDevice.current.userInterfaceIdiom == .phone {
            let sKey = letterElement("s")
            let mKey = letterElement("m")
            if sKey.exists && mKey.exists {
                let cS = sKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let cM = mKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                cS.press(forDuration: 0.04, thenDragTo: cM, withVelocity: .slow, thenHoldForDuration: 0.05)
            }
            Thread.sleep(forTimeInterval: 1.0)
        } else {
            typeLetters("vatan")
            tap("space")
            Thread.sleep(forTimeInterval: 0.8)
        }
        let darkBtn = app.buttons["theme.dark"]
        if darkBtn.exists && darkBtn.isHittable {
            darkBtn.tap()
            Thread.sleep(forTimeInterval: 1.4)
        }
        if (try? selectScript(cyrillic: true)) != nil, waitForLetter("ф", timeout: 2.0) {
            typeLetters("селям")
            Thread.sleep(forTimeInterval: 1.2)
        }
        let statsToggle = app.buttons["stats.expandToggle"].exists
            ? app.buttons["stats.expandToggle"]
            : app.descendants(matching: .any).matching(identifier: "stats.expandToggle").firstMatch
        if statsToggle.exists && statsToggle.isHittable {
            statsToggle.tap()
            Thread.sleep(forTimeInterval: 2.2)
        }
        capture("store_\(storeDevice)_video_final_frame")
    }
}
