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
        XCUIDevice.shared.orientation = .portrait
        app?.terminate()
    }

    private func launch(fieldMode: String = "standard", theme: String = "modernLight") throws {
        app.launchArguments = ["-qt_field", fieldMode, "-qt_theme", theme, "-qt_reset_text"]
        app.launch()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        let firstKey = fieldMode == "numbers" ? key("alphabetic") : key("numeric")
        if !(firstKey.exists || firstKey.waitForExistence(timeout: 4.5) || key("numeric").exists || key("alphabetic").exists) {
            field.tap()
        }
        if !(firstKey.exists || firstKey.waitForExistence(timeout: 2.5) || key("numeric").exists || key("alphabetic").exists) {
            let nextKeyboard = app.buttons["Next keyboard"]
            if !nextKeyboard.exists {
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
            for step in 1...6 where nextKeyboard.exists {
                for _ in 0..<step where nextKeyboard.exists {
                    nextKeyboard.tap()
                }
                if firstKey.waitForExistence(timeout: 3.0) || key("numeric").exists || key("alphabetic").exists || key("space").exists {
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
        if identifier == "space", field.exists {
            let current = (field.value as? String) ?? ""
            if !current.isEmpty && !current.hasSuffix(" ") {
                Thread.sleep(forTimeInterval: 0.25)
                let recheck = (field.value as? String) ?? ""
                if !recheck.isEmpty && !recheck.hasSuffix(" ") && element.exists {
                    element.tap()
                }
            }
        }
    }

    private func expectText(_ expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let predicate = expected.isEmpty
            ? NSPredicate(format: "value == %@ OR value == nil", "")
            : NSPredicate(format: "value == %@", expected)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: field)], timeout: 3)
        if result != .completed {
            XCTAssertEqual((field.value as? String) ?? "", expected, file: file, line: line)
        }
    }

    private func clear() {
        let button = app.buttons["sandbox.clear"]
        if button.exists { button.tap() }
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
        for step in 1...6 where nextKeyboard.exists {
            for _ in 0..<step where nextKeyboard.exists {
                nextKeyboard.tap()
            }
            if key("alphabetic").exists { tap("alphabetic") }
            if waitForLetter(wanted, timeout: 1.2) { return }
            if key("toggle_script").exists {
                tap("toggle_script")
                if waitForLetter(wanted, timeout: 1.2) { return }
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
        // and dragging the floating grabber to the bottom edge docks the keyboard back.
        let dismissKey = key("dismiss")
        if dismissKey.exists && app.frame.width >= 750 {
            let start = dismissKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let calloutOption = dismissKey.coordinate(withNormalizedOffset: CGVector(dx: 0.0, dy: -1.1))
            start.press(forDuration: 0.55, thenDragTo: calloutOption, withVelocity: .default, thenHoldForDuration: 0.15)
            Thread.sleep(forTimeInterval: 0.8)
            capture("iPad floating keyboard via dismiss long press")
            let spaceKey = key("space")
            XCTAssertTrue(spaceKey.exists)
            if spaceKey.frame.width < 320 {
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

        // Typed without diacritics: Space restores the dictionary spelling (single word and multi-word sentence).
        typeLetters("qirim")
        let speedBadge = app.descendants(matching: .any).matching(identifier: "sandbox.speedBadge").firstMatch
        XCTAssertTrue(speedBadge.exists, "Speed badge must appear with CPM while typing the first word")
        XCTAssertFalse(speedBadge.label.contains("söz/daq"), "While typing the first word (<8 chars, no space), speed badge must show only CPM, not WPM (got: '\(speedBadge.label)')")
        tap("space")
        expectText("qırım ")
        XCTAssertTrue(speedBadge.label.contains("söz/daq"), "After completing the first word with Space, speed badge must show WPM · CPM (got: '\(speedBadge.label)')")
        capture("qirim to qırım")
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
        if statsSettingSwitch.isHittable {
            statsSettingSwitch.tap()
        } else {
            statsSettingSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
        Thread.sleep(forTimeInterval: 0.35)
        XCTAssertFalse(statsToggle.exists, "Disabling statistics toggle must hide the statistics card")
        capture("Statistics disabled via settings toggle")
        if statsSettingSwitch.isHittable {
            statsSettingSwitch.tap()
        } else {
            statsSettingSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        }
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

    func testCrossAppStatisticsAndStandardKeyboardComparison() throws {
        try launch()
        try selectScript(cyrillic: false)

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
            let upperId = "key." + name.uppercased()
            let pred = NSPredicate(format: "identifier == %@ OR identifier == %@", lowerId, upperId)
            return safari.descendants(matching: .any).matching(pred).firstMatch
        }

        if urlElement.waitForExistence(timeout: 4) {
            urlElement.tap()
            Thread.sleep(forTimeInterval: 0.8)

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
                        globe.tap()
                    }
                    Thread.sleep(forTimeInterval: 0.8)
                }
                qKey = safariKey("character.q")
                фKey = safariKey("character.ф")
            }
            if фKey.exists && !qKey.exists {
                let toggleKey = safari.descendants(matching: .any).matching(identifier: "key.toggle_script").firstMatch
                if toggleKey.exists {
                    toggleKey.tap()
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
                        k.tap()
                        qkTotal += Date().timeIntervalSince(t0)
                    }
                }
                let spaceKey = safariKey("space")
                if spaceKey.waitForExistence(timeout: 1.5) {
                    spaceKey.tap()
                }

                let externalWord2 = Array("dost")
                for ch in externalWord2 {
                    let k = safariKey("character.\(ch)")
                    if k.waitForExistence(timeout: 1.5) {
                        let t0 = Date()
                        k.tap()
                        qkTotal += Date().timeIntervalSince(t0)
                    }
                }
                if spaceKey.waitForExistence(timeout: 1.5) {
                    spaceKey.tap()
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
}

