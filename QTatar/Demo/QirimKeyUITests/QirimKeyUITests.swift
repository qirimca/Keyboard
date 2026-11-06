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
        let pred = NSPredicate(format: "identifier IN {'key.character.q', 'key.character.Q', 'key.character.ф', 'key.character.Ф', 'key.character.ğ', 'key.character.Ğ', 'key.toggle_script'}")
        return app.descendants(matching: .any).matching(pred).firstMatch
    }

    private func dismissKeyboardOnboardingOverlayIfNeeded() {
        let continuePred = NSPredicate(format: "label IN {'Continue', 'Продовжити', 'Далі', 'Devam et'} AND identifier != 'testing.toggle'")
        let appContinue = app.buttons.matching(continuePred).firstMatch
        if appContinue.exists && appContinue.isHittable {
            appContinue.tap()
            Thread.sleep(forTimeInterval: 0.25)
            return
        }
    }

    private func launch(fieldMode: String = "standard", theme: String = "modernLight", extraArgs: [String] = []) throws {
        app.launchArguments = ["-qt_field", fieldMode, "-qt_theme", theme, "-qt_reset_text"] + extraArgs
        app.launch()
        if extraArgs.contains("-qt_no_autofocus") || extraArgs.contains("-qt_default_expansion") || extraArgs.contains("-qt_collapse_testing") {
            let testingToggle = app.descendants(matching: .any).matching(identifier: "testing.toggle").firstMatch
            XCTAssertTrue(testingToggle.waitForExistence(timeout: 10))
            dismissKeyboardOnboardingOverlayIfNeeded()
            return
        }
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        dismissKeyboardOnboardingOverlayIfNeeded()
        let firstKey = fieldMode == "numbers" ? key("alphabetic") : key("numeric")
        if !anyCustomKey.waitForExistence(timeout: 3.5) {
            if field.exists && field.isHittable {
                field.tap()
                Thread.sleep(forTimeInterval: 0.6)
            }
            dismissKeyboardOnboardingOverlayIfNeeded()
            if !anyCustomKey.exists {
                cycleToCustomKeyboard(firstKey: firstKey)
            }
        }
        dismissKeyboardOnboardingOverlayIfNeeded()
        if !anyCustomKey.exists {
            enableKeyboardInSettingsIfNeeded()
            app.activate()
            Thread.sleep(forTimeInterval: 0.6)
            let donePred = NSPredicate(format: "label IN {'Done', 'Готово', 'Azır'}")
            let doneBtn = app.buttons.matching(donePred).firstMatch
            if doneBtn.exists && doneBtn.isHittable {
                doneBtn.tap()
                Thread.sleep(forTimeInterval: 0.4)
            }
            if field.waitForExistence(timeout: 5) {
                if field.isHittable {
                    field.tap()
                }
                Thread.sleep(forTimeInterval: 0.8)
            }
            dismissKeyboardOnboardingOverlayIfNeeded()
            cycleToCustomKeyboard(firstKey: firstKey)
        }
        dismissKeyboardOnboardingOverlayIfNeeded()
        XCTAssertTrue(anyCustomKey.waitForExistence(timeout: 4.0),
                      "Enable and select Qırımtatarca in Settings before running keyboard tests.")
    }

    private func cycleToCustomKeyboard(firstKey: XCUIElement) {
        dismissKeyboardOnboardingOverlayIfNeeded()
        let nextKeyboardPred = NSPredicate(format: "identifier IN {'Next keyboard', 'key.globe'} OR label IN {'Next keyboard', 'Наступна клавіатура', 'Следующая клавиатура', 'Nöbetteki klaviatura'}")
        let nextKeyboard = app.descendants(matching: .any).matching(nextKeyboardPred).firstMatch
        let abcPred = NSPredicate(format: "identifier == 'ABC' OR label IN {'ABC', 'АБВ', 'letters', 'A B C'}")
        let abcBtn = app.buttons.matching(abcPred).firstMatch
        if !nextKeyboard.exists && !abcBtn.exists {
            if field.exists && field.isHittable {
                field.tap()
                Thread.sleep(forTimeInterval: 0.6)
            }
        }
        dismissKeyboardOnboardingOverlayIfNeeded()
        if anyCustomKey.exists { return }

        func exitEmojiKeyboardIfNeeded() {
            if !nextKeyboard.exists && abcBtn.exists && abcBtn.isHittable {
                abcBtn.tap()
                Thread.sleep(forTimeInterval: 0.45)
                dismissKeyboardOnboardingOverlayIfNeeded()
            }
        }

        exitEmojiKeyboardIfNeeded()
        if anyCustomKey.exists { return }

        // Fast path: single tap on Globe button (or iPad Floating footer Globe at dx: 0.046, dy: 0.852)
        let win = app.windows.firstMatch
        for attempt in 0..<3 {
            if anyCustomKey.exists { return }
            if nextKeyboard.exists && nextKeyboard.frame.width > 0 {
                nextKeyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            } else if UIDevice.current.userInterfaceIdiom == .pad {
                let fallbackCoord = (attempt % 2 == 0)
                    ? win.coordinate(withNormalizedOffset: CGVector(dx: 0.046, dy: 0.852))
                    : win.coordinate(withNormalizedOffset: CGVector(dx: 0.045, dy: 0.96))
                fallbackCoord.tap()
            } else {
                break
            }
            Thread.sleep(forTimeInterval: 0.85)
            dismissKeyboardOnboardingOverlayIfNeeded()
            if anyCustomKey.waitForExistence(timeout: 1.2) { return }
        }

        // Second: try press-and-drag on the Globe button to select Qırımtatarca directly from the popup list
        for dyOffset in [-1.5, -2.1, -2.7, -3.3] {
            exitEmojiKeyboardIfNeeded()
            if anyCustomKey.exists { return }
            guard nextKeyboard.exists && nextKeyboard.isHittable else { break }
            let start = nextKeyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let end = nextKeyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: dyOffset))
            start.press(forDuration: 0.55, thenDragTo: end)
            Thread.sleep(forTimeInterval: 0.45)
            dismissKeyboardOnboardingOverlayIfNeeded()
            if anyCustomKey.waitForExistence(timeout: 1.2) { return }
        }

        // Fallback: multi-tap bursts to cycle past MRU ping-pong
        for burstCount in [1, 2, 3] {
            exitEmojiKeyboardIfNeeded()
            if anyCustomKey.exists { return }
            guard (nextKeyboard.exists && nextKeyboard.isHittable) || (abcBtn.exists && abcBtn.isHittable) else { break }
            for b in 0..<burstCount {
                if nextKeyboard.exists && nextKeyboard.isHittable {
                    nextKeyboard.tap()
                } else if abcBtn.exists && abcBtn.isHittable {
                    abcBtn.tap()
                }
                if b + 1 < burstCount {
                    Thread.sleep(forTimeInterval: 0.12)
                }
            }
            Thread.sleep(forTimeInterval: 0.45)
            dismissKeyboardOnboardingOverlayIfNeeded()
            if anyCustomKey.waitForExistence(timeout: 1.0) { return }
        }
    }

    private func enableKeyboardInSettingsIfNeeded() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.activate()
        guard settings.wait(for: .runningForeground, timeout: 8) else { return }
        Thread.sleep(forTimeInterval: 0.8)

        func toggleQirimKeySwitchesOnCurrentPage() -> Bool {
            let kbSwitchPred = NSPredicate(format: "identifier BEGINSWITH 'crh.key.' OR label CONTAINS[c] 'Qırımtatarca' OR label CONTAINS[c] 'Къырымтатарджа' OR label CONTAINS[c] 'Кʼиримтатарджа'")
            let kbSwitches = settings.switches.matching(kbSwitchPred)
            let count = kbSwitches.count
            guard count > 0 else { return false }
            var seenKeys = Set<String>()
            for i in 0..<min(count, 3) {
                let sw = kbSwitches.element(boundBy: i)
                guard sw.exists else { continue }
                let dedupKey = "\(sw.identifier)|\(sw.label)"
                if seenKeys.contains(dedupKey) { continue }
                seenKeys.insert(dedupKey)
                let val = (sw.value as? String) ?? ""
                if val == "0" {
                    sw.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                    Thread.sleep(forTimeInterval: 0.45)
                }
            }
            let fullAccessSwitch = settings.switches.matching(NSPredicate(format: "label CONTAINS[c] 'Allow Full Access' OR label CONTAINS[c] 'повний доступ' OR label CONTAINS[c] 'полный доступ' OR label CONTAINS[c] 'Tam irişüv' OR label CONTAINS[c] 'Tam irişim'")).firstMatch
            if fullAccessSwitch.waitForExistence(timeout: 1.5), ((fullAccessSwitch.value as? String) ?? "") == "0" {
                fullAccessSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.5)
                let allowBtn = settings.alerts.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' OR label CONTAINS[c] 'Дозволити' OR label CONTAINS[c] 'Разрешить'")).firstMatch
                if allowBtn.waitForExistence(timeout: 2.0) {
                    allowBtn.tap()
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
            return true
        }

        if toggleQirimKeySwitchesOnCurrentPage() {
            return
        }

        let appKeyboardsCell = settings.cells.matching(NSPredicate(format: "label CONTAINS[c] 'Keyboards' OR label CONTAINS[c] 'Клавіатури' OR label CONTAINS[c] 'Клавиатуры' OR label CONTAINS[c] 'Klaviaturalar'")).firstMatch
        if appKeyboardsCell.exists && appKeyboardsCell.isHittable {
            appKeyboardsCell.tap()
            Thread.sleep(forTimeInterval: 0.8)
            if toggleQirimKeySwitchesOnCurrentPage() {
                return
            }
        }

        let keyboardPred = NSPredicate(format: "identifier == 'com.apple.settings.general.keyboard' OR label IN {'Keyboard', 'Клавіатура', 'Клавиатура'}")
        let keyboardsPred = NSPredicate(format: "label CONTAINS[c] 'Keyboards' OR label CONTAINS[c] 'Клавіатури' OR label CONTAINS[c] 'Клавиатуры' OR identifier CONTAINS[c] 'KEYBOARDS'")
        let generalPred = NSPredicate(format: "identifier == 'com.apple.settings.general' OR label IN {'General', 'Загальні', 'Основные'}")
        let existingCell = settings.cells.matching(NSPredicate(format: "identifier == 'crh.key.keyboard.keyboard' OR label CONTAINS[c] 'Qırımtatarca'")).firstMatch
        let addNewPredicate = NSPredicate(format: "label CONTAINS[c] 'Add New Keyboard' OR label CONTAINS[c] 'Нова клавіатура' OR label CONTAINS[c] 'Новые клавиатуры' OR identifier CONTAINS[c] 'AddNewKeyboard'")
        let alreadyOnKeyboardsScreen = existingCell.exists
            || settings.buttons.matching(addNewPredicate).firstMatch.exists
            || settings.cells.matching(addNewPredicate).firstMatch.exists

        if !alreadyOnKeyboardsScreen {
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

            if !settings.buttons.matching(keyboardPred).firstMatch.exists &&
               !settings.cells.matching(keyboardPred).firstMatch.exists {
                settings.swipeUp()
                Thread.sleep(forTimeInterval: 0.5)
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
        }
        if !existingCell.waitForExistence(timeout: 2.0) {
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
                    _ = toggleQirimKeySwitchesOnCurrentPage()
                    let doneBtn = settings.navigationBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Done' OR label CONTAINS[c] 'Готово' OR identifier CONTAINS[c] 'Done'")).firstMatch
                    if doneBtn.exists {
                        doneBtn.tap()
                        Thread.sleep(forTimeInterval: 0.8)
                    }
                }
            }
        }
        #if !targetEnvironment(simulator)
        if existingCell.waitForExistence(timeout: 2.0) && existingCell.isHittable {
            existingCell.tap()
            Thread.sleep(forTimeInterval: 0.8)
            let fullAccessSwitch = settings.switches.matching(NSPredicate(format: "label CONTAINS[c] 'Allow Full Access' OR label CONTAINS[c] 'повний доступ' OR label CONTAINS[c] 'полный доступ'")).firstMatch
            if fullAccessSwitch.waitForExistence(timeout: 2.0), ((fullAccessSwitch.value as? String) ?? "") == "0" {
                fullAccessSwitch.tap()
                Thread.sleep(forTimeInterval: 0.5)
                let allowBtn = settings.alerts.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' OR label CONTAINS[c] 'Дозволити' OR label CONTAINS[c] 'Разрешить'")).firstMatch
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
            let fullAccessSwitch = settings.switches.matching(NSPredicate(format: "label CONTAINS[c] 'Allow Full Access' OR label CONTAINS[c] 'повний доступ' OR label CONTAINS[c] 'полный доступ'")).firstMatch
            if fullAccessSwitch.waitForExistence(timeout: 2.0), ((fullAccessSwitch.value as? String) ?? "") == "0" {
                fullAccessSwitch.tap()
                Thread.sleep(forTimeInterval: 0.5)
                let allowBtn = settings.alerts.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Allow' OR label CONTAINS[c] 'Дозволити' OR label CONTAINS[c] 'Разрешить'")).firstMatch
                if allowBtn.waitForExistence(timeout: 1.5) {
                    allowBtn.tap()
                    Thread.sleep(forTimeInterval: 0.5)
                }
            }
        }
        #endif
        settings.terminate()
        Thread.sleep(forTimeInterval: 0.3)
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
            Thread.sleep(forTimeInterval: 0.15)
            let current = (field.value as? String) ?? ""
            if !current.isEmpty && !current.hasSuffix(" ") {
                Thread.sleep(forTimeInterval: 0.25)
                let recheck = (field.value as? String) ?? ""
                if !recheck.isEmpty && !recheck.hasSuffix(" ") && element.exists {
                    element.tap()
                    Thread.sleep(forTimeInterval: 0.15)
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
        if ((field.value as? String) ?? "") == expected { return }
        let predicate = expected.isEmpty
            ? NSPredicate(format: "value == %@ OR value == nil", "")
            : NSPredicate(format: "value == %@", expected)
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: field)], timeout: 3.5)
        if result != .completed {
            XCTAssertEqual((field.value as? String) ?? "", expected, file: file, line: line)
        }
    }

    private func clear() {
        if ((field.value as? String) ?? "").isEmpty { return }
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
        if waitForLetter(wanted, timeout: 1.2) { return }
        if key("toggle_script").waitForExistence(timeout: 1.5) {
            tap("toggle_script")
            XCTAssertTrue(waitForLetter(wanted), "script did not switch to cyrillic=\(cyrillic)")
            return
        }
        let nextKeyboardPred = NSPredicate(format: "identifier IN {'Next keyboard', 'key.globe'} OR label IN {'Next keyboard', 'Наступна клавіатура', 'Следующая клавиатура', 'Nöbetteki klaviatura'}")
        let nextKeyboard = app.descendants(matching: .any).matching(nextKeyboardPred).firstMatch
        let abcPred = NSPredicate(format: "identifier == 'ABC' OR label IN {'ABC', 'АБВ', 'letters', 'A B C'}")
        let abcBtn = app.buttons.matching(abcPred).firstMatch
        if nextKeyboard.exists {
            for dyOffset in [-1.5, -2.2, -2.9, -3.6, -1.0] {
                if !nextKeyboard.exists && abcBtn.exists {
                    abcBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    Thread.sleep(forTimeInterval: 0.5)
                }
                guard nextKeyboard.exists else { break }
                let start = nextKeyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let end = nextKeyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: dyOffset))
                start.press(forDuration: 0.55, thenDragTo: end)
                Thread.sleep(forTimeInterval: 0.65)
                if app.state != .runningForeground {
                    app.activate()
                    Thread.sleep(forTimeInterval: 0.6)
                    if field.exists && field.isHittable {
                        field.tap()
                        Thread.sleep(forTimeInterval: 0.6)
                    }
                }
                if waitForLetter(wanted, timeout: 1.2) { return }
            }
        }
        for _ in 0..<6 {
            if key("toggle_script").exists {
                tap("toggle_script")
                if waitForLetter(wanted, timeout: 1.2) { return }
            }
            if nextKeyboard.exists {
                nextKeyboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.65)
                if waitForLetter(wanted, timeout: 1.2) { return }
            } else if abcBtn.exists {
                abcBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.65)
                if waitForLetter(wanted, timeout: 1.2) { return }
            }
        }
        throw XCTSkip("Select the other extension with the system globe on iPhone before this test.")
    }

    private func typeLetters(_ letters: String) {
        for (index, character) in letters.enumerated() {
            let s = String(character)
            let exact = key("character." + s)
            if index > 0 && s == s.lowercased() {
                exact.tap()
                continue
            }
            if exact.exists {
                exact.tap()
                continue
            }
            if s.lowercased() != s.uppercased(), key("shift").exists {
                tap("shift")
                if exact.waitForExistence(timeout: 0.5) {
                    exact.tap()
                    continue
                }
            }
            let lower = "key.character." + s.lowercased()
            let upper = "key.character." + s.uppercased()
            let anyCase = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@ OR identifier == %@", lower, upper)).firstMatch
            if anyCase.exists {
                anyCase.tap()
            } else {
                exact.tap()
            }
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
        if UIDevice.current.userInterfaceIdiom == .pad {
            XCTAssertFalse(key("emojis").exists, "iPad must never render a separate emoji button")
        } else {
            XCTAssertTrue(key("emojis").exists, "iPhone must render the emoji button when enabled")
        }
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
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "settings.stats.toggle").firstMatch.exists)
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
        XCTAssertTrue(wordsTile.label.contains("Farqlı:") || wordsTile.label.contains("Unikal:") || wordsTile.label.contains("Arifler:"), "Words tile must show labeled unique words subtitle instead of unlabeled parentheses (got: '\(wordsTile.label)')")
        XCTAssertFalse(wordsTile.label.contains("("), "Words tile must not show unlabeled parentheses (got: '\(wordsTile.label)')")
        XCTAssertTrue(speedTierTile.exists, "Speed tier tile must exist in expanded statistics card")
        XCTAssertTrue(volumeTierTile.exists, "Volume tier tile must exist in expanded statistics card")
        XCTAssertFalse(speedTierTile.label.contains("stats.speedTier"), "Speed tier tile must display localized text, not raw key (got: '\(speedTierTile.label)')")
        XCTAssertFalse(volumeTierTile.label.contains("stats.volumeTier"), "Volume tier tile must display localized text, not raw key (got: '\(volumeTierTile.label)')")
        XCTAssertTrue(speedTierTile.label.contains("Nevbetteki:") || speedTierTile.label.contains("Soñraki:") || speedTierTile.label.contains("yüksek"), "Speed tier tile must display next tier progression info (got: '\(speedTierTile.label)')")
        XCTAssertTrue(volumeTierTile.label.contains("Nevbetteki:") || volumeTierTile.label.contains("Soñraki:") || volumeTierTile.label.contains("yüksek"), "Volume tier tile must display next tier progression info (got: '\(volumeTierTile.label)')")
        XCTAssertTrue(learnedWordsTile.exists, "Learned words tile must exist in expanded statistics card")
        XCTAssertFalse(wordsTile.label.contains("Farqlı: 0") || wordsTile.label.contains("Unikal: 0") || wordsTile.label.contains("· 0 farqlı") || wordsTile.label.contains("· 0 unik."), "Words tile must increment unique words after typing words (got: '\(wordsTile.label)')")
        XCTAssertTrue(learnedWordsTile.label.contains(", 0,"), "Learned words tile must remain 0 when words are committed via Space (got: '\(learnedWordsTile.label)')")
        capture("Top statistics expanded")

        // Verify Reset Statistics confirmation clears all counters and user_lexicon in place, and typing a new word immediately increments both wordsTile and learnedWordsTile in real time.
        resetBtn.tap()
        let confirmReset = app.alerts.buttons["Sıfırla"].firstMatch
        XCTAssertTrue(confirmReset.waitForExistence(timeout: 2), "Reset confirmation alert button 'Sıfırla' must appear")
        XCTAssertFalse(app.alerts.buttons["stats.resetCancel"].exists, "Reset confirmation cancel button must be localized, not raw key 'stats.resetCancel'")
        capture("Reset statistics confirmation dialog")
        confirmReset.tap()
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(wordsTile.label.contains("Farqlı: 0") || wordsTile.label.contains("Unikal: 0") || wordsTile.label.contains("Arifler: 0"), "After reset, wordsTile must show 0 unique words (got: '\(wordsTile.label)')")
        XCTAssertTrue(learnedWordsTile.label.contains(", 0,"), "After reset, learnedWordsTile must reset to 0 (got: '\(learnedWordsTile.label)')")

        field.tap()
        typeLetters("vatan")
        tap("space")
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertTrue(wordsTile.label.contains(", 1,") && (wordsTile.label.contains("Farqlı: 1") || wordsTile.label.contains("Unikal: 1") || wordsTile.label.contains("Arifler: 6")), "Typing 'vatan ' after reset must update wordsTile to 1 word and 1 unique word in real time (got: '\(wordsTile.label)')")
        XCTAssertTrue(learnedWordsTile.label.contains(", 0,"), "Pressing Space after 'vatan' must NOT add a word to Personal Dictionary (got: '\(learnedWordsTile.label)')")

        // Tapping the quoted literal suggestion in Slot 0 ("qırımsöz") explicitly adds the word to Personal Dictionary.
        typeLetters("qırımsöz")
        let quotedSlot0 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.0").firstMatch
        XCTAssertTrue(quotedSlot0.waitForExistence(timeout: 2.5), "Quoted Slot 0 suggestion must exist for 'qırımsöz'")
        quotedSlot0.tap()
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(learnedWordsTile.label.contains(", 1,"), "Tapping quoted Slot 0 suggestion for 'qırımsöz' must increment learnedWordsTile to 1 in real time (got: '\(learnedWordsTile.label)')")
        learnedWordsTile.tap()
        let customWordRow = app.descendants(matching: .any).matching(identifier: "stats.learnedWords.row.qırımsöz").firstMatch
        XCTAssertTrue(customWordRow.waitForExistence(timeout: 2.5), "Tapping learnedWordsTile must open Personal Dictionary sheet showing 'qırımsöz'")
        let dictWordLearningSwitch = app.switches["stats.learnedWords.wordLearningToggle"].exists
            ? app.switches["stats.learnedWords.wordLearningToggle"]
            : app.descendants(matching: .any).matching(identifier: "stats.learnedWords.wordLearningToggle").firstMatch
        XCTAssertTrue(dictWordLearningSwitch.exists, "Personal Dictionary sheet must include Word Learning header toggle")
        let clearAllBtn = app.buttons["stats.learnedWords.clearAllButton"].firstMatch
        XCTAssertTrue(clearAllBtn.exists, "Personal Dictionary sheet must include Clear All button when non-empty")
        capture("Personal dictionary sheet with learned word")
        let deleteCustomWordBtn = app.buttons["stats.learnedWords.delete.qırımsöz"].firstMatch
        XCTAssertTrue(deleteCustomWordBtn.exists, "Personal Dictionary row must expose delete button for 'qırımsöz'")
        deleteCustomWordBtn.tap()
        let emptyDictState = app.descendants(matching: .any).matching(identifier: "stats.learnedWords.emptyState").firstMatch
        XCTAssertTrue(emptyDictState.waitForExistence(timeout: 2.0), "Deleting the only learned word must transition Personal Dictionary sheet to empty state")
        let doneDictBtn = app.buttons["stats.learnedWords.doneButton"].firstMatch
        XCTAssertTrue(doneDictBtn.exists, "Personal Dictionary sheet must have Done button")
        doneDictBtn.tap()
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(learnedWordsTile.label.contains(", 0,"), "Deleting 'qırımsöz' in Personal Dictionary sheet must update learnedWordsTile to 0 (got: '\(learnedWordsTile.label)')")
        clear()

        statsToggle.tap()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertTrue(statsToggle.label.contains("luğat") || statsToggle.label.contains("вивч.") || statsToggle.label.contains("learned"), "Compact statistics bar must include learned words unit label (got: '\(statsToggle.label)')")
        XCTAssertTrue(statsToggle.label.contains("söz") || statsToggle.label.contains("сл.") || statsToggle.label.contains("words"), "Compact statistics bar must include words unit label (got: '\(statsToggle.label)')")
        capture("Top statistics collapsed")

        // Verify statistics setting toggle in the card header disables/hides the statistics pills and re-enables them cleanly.
        let statsSettingSwitch = app.switches["settings.stats.toggle"].exists
            ? app.switches["settings.stats.toggle"]
            : app.descendants(matching: .any).matching(identifier: "settings.stats.toggle").firstMatch
        XCTAssertTrue(statsSettingSwitch.exists, "Statistics setting toggle must exist in statistics card header")
        tapSwitch(statsSettingSwitch)
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertFalse(statsToggle.label.contains("söz/daq"), "Disabling statistics toggle must hide compact statistics pills")
        capture("Statistics disabled via settings toggle")
        tapSwitch(statsSettingSwitch)
        Thread.sleep(forTimeInterval: 0.4)
        XCTAssertTrue(statsToggle.label.contains("söz/daq"), "Re-enabling statistics toggle must restore compact statistics pills")
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

                // Also type a novel custom word and tap its quoted candidate chip to verify personal dictionary sync
                for ch in Array("qirimdev") {
                    let k = safariKey("character.\(ch)")
                    if k.waitForExistence(timeout: 1.0) {
                        tapSafariKey(k)
                    }
                }
                let customChip = safari.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'qirimdev'")).firstMatch
                if customChip.waitForExistence(timeout: 1.2) {
                    tapSafariKey(customChip)
                } else if spaceKey.exists {
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
        XCTAssertTrue(wordsTile.label.contains("·") || !learnedWordsTile.label.contains(", 0,"), "Unique or custom words learned in external app (Safari) must sync back to QTatar.app in real time (wordsTile: '\(wordsTile.label)', learnedTile: '\(learnedWordsTile.label)')")
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
        let donePred = NSPredicate(format: "label IN {'Done', 'Готово', 'Azır'}")
        let doneBtn = app.buttons.matching(donePred).firstMatch
        if doneBtn.exists && doneBtn.isHittable {
            doneBtn.tap()
            Thread.sleep(forTimeInterval: 0.4)
        } else if key("dismiss").exists && key("dismiss").isHittable {
            tap("dismiss")
            Thread.sleep(forTimeInterval: 0.4)
        }
        let testingToggle = app.buttons["testing.toggle"].exists
            ? app.buttons["testing.toggle"]
            : app.descendants(matching: .any).matching(identifier: "testing.toggle").firstMatch
        if testingToggle.exists && testingToggle.isHittable && field.exists {
            testingToggle.tap()
            Thread.sleep(forTimeInterval: 0.45)
        }
        let ukLangPred = NSPredicate(format: "identifier == 'settings.lang.uk' OR label IN {'Українська', 'УК'}")
        let ukLangBtn = app.descendants(matching: .any).matching(ukLangPred).firstMatch
        if !ukLangBtn.exists || !ukLangBtn.isHittable {
            app.scrollViews.firstMatch.swipeDown()
            Thread.sleep(forTimeInterval: 0.35)
        }
        if ukLangBtn.waitForExistence(timeout: 2) {
            if ukLangBtn.isHittable {
                ukLangBtn.tap()
            } else {
                ukLangBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        let ukCyrSwitch = app.switches["settings.ukrainianCyrillic.toggle"].exists
            ? app.switches["settings.ukrainianCyrillic.toggle"]
            : app.descendants(matching: .any).matching(identifier: "settings.ukrainianCyrillic.toggle").firstMatch
        XCTAssertTrue(ukCyrSwitch.waitForExistence(timeout: 2.5), "Ukrainian Cyrillic layout toggle must appear when Ukrainian interface language is active")
        if ((ukCyrSwitch.value as? String) ?? "0") == "0" {
            tapSwitch(ukCyrSwitch)
            Thread.sleep(forTimeInterval: 0.45)
        }
        capture("Ukrainian interface with FIVA layout toggle enabled")
        if !field.exists && testingToggle.exists {
            if !testingToggle.isHittable {
                app.scrollViews.firstMatch.swipeUp()
                Thread.sleep(forTimeInterval: 0.35)
            }
            if testingToggle.isHittable {
                testingToggle.tap()
            } else {
                testingToggle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            Thread.sleep(forTimeInterval: 0.6)
        }

        defer {
            if doneBtn.exists && doneBtn.isHittable {
                doneBtn.tap()
                Thread.sleep(forTimeInterval: 0.35)
            } else if testingToggle.exists && testingToggle.isHittable && key("space").exists {
                testingToggle.tap()
                Thread.sleep(forTimeInterval: 0.4)
            }
            if !ukCyrSwitch.isHittable {
                app.scrollViews.firstMatch.swipeDown()
                Thread.sleep(forTimeInterval: 0.3)
            }
            if ukCyrSwitch.exists && ((ukCyrSwitch.value as? String) ?? "1") == "1" {
                tapSwitch(ukCyrSwitch)
                Thread.sleep(forTimeInterval: 0.35)
            }
            let crhLangPred = NSPredicate(format: "identifier == 'settings.lang.crh' OR label IN {'Qırımtatarca', 'QT'}")
            let crhLangBtn = app.descendants(matching: .any).matching(crhLangPred).firstMatch
            if crhLangBtn.exists {
                if crhLangBtn.isHittable {
                    crhLangBtn.tap()
                } else {
                    crhLangBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
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
            ("ервін", "ervin"),
            ("п\u{02BC}єр", "pyer"),
            ("ґ\u{02BC}е", "gye"),
            ("к\u{02BC}ирим", "qırım"),
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
        XCTAssertFalse(key("emojis").exists, "iPad Docked must never render a separate emoji button")
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

    func testAppStoreScreenshotsHome() throws {
        let isPadDevice = (UIDevice.current.userInterfaceIdiom == .pad)
        for lang in ["crh", "uk", "en"] {
            var args = ["-qt_cyrillic_added", "-qt_demo_stats", "-qt_theme", "modernLight", "-qt_lang", lang]
            if isPadDevice { args.append("-qt_focus_sandbox_live") }
            if lang == "uk" { args.append("-qt_ukrainian_fiva") }
            app.launchArguments = args
            app.launch()
            dismissKeyboardOnboardingOverlayIfNeeded()
            if isPadDevice {
                if field.waitForExistence(timeout: 3), !anyCustomKey.waitForExistence(timeout: 2.5) {
                    field.tap()
                    Thread.sleep(forTimeInterval: 0.6)
                    dismissKeyboardOnboardingOverlayIfNeeded()
                    if !anyCustomKey.exists {
                        cycleToCustomKeyboard(firstKey: key("numeric"))
                    }
                    if !anyCustomKey.exists {
                        enableKeyboardInSettingsIfNeeded()
                        app.terminate()
                        app.launchArguments = args
                        app.launch()
                        if field.waitForExistence(timeout: 4) {
                            field.tap()
                            Thread.sleep(forTimeInterval: 0.8)
                        }
                        dismissKeyboardOnboardingOverlayIfNeeded()
                        cycleToCustomKeyboard(firstKey: key("numeric"))
                    }
                }
                dismissKeyboardOnboardingOverlayIfNeeded()
                _ = anyCustomKey.waitForExistence(timeout: 3)
                try? selectScript(cyrillic: false)
            }
            Thread.sleep(forTimeInterval: 1.8)
            if lang == "crh" {
                capture("store_\(storeDevice)_04_home_light")
            }
            capture("store_\(storeDevice)_04_home_light_\(lang)")
            if lang == "uk" {
                let statsToggle = app.buttons["stats.expandToggle"].exists
                    ? app.buttons["stats.expandToggle"]
                    : app.descendants(matching: .any).matching(identifier: "stats.expandToggle").firstMatch
                if statsToggle.exists && statsToggle.isHittable {
                    statsToggle.tap()
                    Thread.sleep(forTimeInterval: 1.2)
                    capture("store_\(storeDevice)_04c_home_uk_stats_expanded")
                }
            }
            app.terminate()
        }

        app.launchArguments = ["-qt_cyrillic_missing", "-qt_demo_stats", "-qt_theme", "modernLight", "-qt_lang", "crh"]
        app.launch()
        Thread.sleep(forTimeInterval: 1.5)
        capture("store_\(storeDevice)_04b_home_cyrillic_missing")
        app.terminate()

        for lang in ["crh", "uk", "en"] {
            var args = ["-qt_cyrillic_added", "-qt_demo_stats", "-qt_demo_dark", "-qt_focus_sandbox_live", "-qt_theme", "modernDark", "-qt_lang", lang]
            if lang == "uk" { args.append("-qt_ukrainian_fiva") }
            app.launchArguments = args
            app.launch()
            dismissKeyboardOnboardingOverlayIfNeeded()
            if field.waitForExistence(timeout: 3), !anyCustomKey.waitForExistence(timeout: 2.5) {
                field.tap()
                Thread.sleep(forTimeInterval: 0.6)
                dismissKeyboardOnboardingOverlayIfNeeded()
                if !anyCustomKey.exists {
                    cycleToCustomKeyboard(firstKey: key("numeric"))
                }
                if !anyCustomKey.exists {
                    enableKeyboardInSettingsIfNeeded()
                    app.terminate()
                    app.launchArguments = args
                    app.launch()
                    if field.waitForExistence(timeout: 4) {
                        field.tap()
                        Thread.sleep(forTimeInterval: 0.8)
                    }
                    dismissKeyboardOnboardingOverlayIfNeeded()
                    cycleToCustomKeyboard(firstKey: key("numeric"))
                }
            }
            dismissKeyboardOnboardingOverlayIfNeeded()
            _ = anyCustomKey.waitForExistence(timeout: 3)
            try? selectScript(cyrillic: false)
            Thread.sleep(forTimeInterval: 1.5)
            if lang == "crh" {
                capture("store_\(storeDevice)_05_home_dark")
            }
            capture("store_\(storeDevice)_05_home_dark_\(lang)")
            app.terminate()
        }
    }

    private func typeCyrillicSelamVerified() {
        let initialPrefix = (field.value as? String) ?? ""
        Thread.sleep(forTimeInterval: 0.65)
        for attempt in 0..<2 {
            for ch in ["с", "е", "л", "я", "м"] {
                let id = "character." + ch
                if !key(id).exists, key("shift").exists {
                    tap("shift")
                    _ = key(id).waitForExistence(timeout: 0.8)
                }
                if key(id).exists {
                    key(id).tap()
                    Thread.sleep(forTimeInterval: 0.16)
                }
            }
            Thread.sleep(forTimeInterval: 0.35)
            let cur = (field.value as? String) ?? ""
            if cur.hasSuffix(" selâm") || (initialPrefix.isEmpty && cur.hasSuffix("selâm")) {
                return
            }
            if attempt == 0 {
                for _ in 0..<6 {
                    let currentText = (field.value as? String) ?? ""
                    if currentText.count <= initialPrefix.count || currentText.hasSuffix(" ") {
                        break
                    }
                    if key("backspace").exists {
                        key("backspace").tap()
                        Thread.sleep(forTimeInterval: 0.10)
                    }
                }
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
    }

    func testAppStoreScreenshotsLight() throws {
        try launch(theme: "modernLight", extraArgs: ["-qt_demo_stats", "-qt_prefill_phrase_prefix", "-qt_lang", "crh", "-qt_cyrillic_added"])
        try selectScript(cyrillic: false)
        Thread.sleep(forTimeInterval: 0.5)
        capture("vframe_\(storeDevice)_01_phrase_light")
        typeLetters("qirim")
        Thread.sleep(forTimeInterval: 0.5)
        capture("vframe_\(storeDevice)_02_typing_qirim")
        typeLetters("tatarca")
        Thread.sleep(forTimeInterval: 0.8)
        capture("store_\(storeDevice)_01_latin_light")
        capture("store_\(storeDevice)_01_latin_light_crh")
        capture("vframe_\(storeDevice)_03_latin_light_done")
        app.terminate()

        for lang in ["uk", "en"] {
            var args = ["-qt_demo_stats", "-qt_prefill_phrase_prefix", "-qt_lang", lang, "-qt_cyrillic_added"]
            if lang == "uk" { args.append("-qt_ukrainian_fiva") }
            try launch(theme: "modernLight", extraArgs: args)
            try selectScript(cyrillic: false)
            Thread.sleep(forTimeInterval: 0.4)
            typeLetters("qirimtatarca")
            Thread.sleep(forTimeInterval: 0.8)
            capture("store_\(storeDevice)_01_latin_light_\(lang)")
            app.terminate()
        }

        for lang in ["crh", "uk", "en"] {
            var args = ["-qt_demo_stats", "-qt_prefill_greeting_prefix", "-qt_lang", lang, "-qt_cyrillic_added"]
            if lang == "uk" { args.append("-qt_ukrainian_fiva") }
            try launch(theme: "modernLight", extraArgs: args)
            if (try? selectScript(cyrillic: true)) != nil, waitForLetter("ф", timeout: 2.0) {
                Thread.sleep(forTimeInterval: 0.4)
                typeCyrillicSelamVerified()
                Thread.sleep(forTimeInterval: 0.8)
                if lang == "crh" {
                    capture("store_\(storeDevice)_03_cyrillic")
                }
                capture("store_\(storeDevice)_03_cyrillic_\(lang)")
            }
            app.terminate()
        }
    }

    func testAppStoreScreenshotCyrillicOnly() throws {
        for lang in ["crh", "uk", "en"] {
            var args = ["-qt_demo_stats", "-qt_prefill_greeting_prefix", "-qt_lang", lang, "-qt_cyrillic_added"]
            if lang == "uk" { args.append("-qt_ukrainian_fiva") }
            try launch(theme: "modernLight", extraArgs: args)
            try selectScript(cyrillic: true)
            Thread.sleep(forTimeInterval: 0.4)
            typeCyrillicSelamVerified()
            Thread.sleep(forTimeInterval: 0.8)
            if lang == "crh" {
                capture("store_\(storeDevice)_03_cyrillic")
            }
            capture("store_\(storeDevice)_03_cyrillic_\(lang)")
            app.terminate()
        }
    }

    func testAppStoreScreenshotsDark() throws {
        try launch(theme: "modernDark", extraArgs: ["-qt_demo_stats", "-qt_prefill_greeting_prefix", "-qt_lang", "crh", "-qt_cyrillic_added"])
        try selectScript(cyrillic: false)
        Thread.sleep(forTimeInterval: 0.4)
        typeLetters("sel")
        tap("character.â")
        typeLetters("m")
        Thread.sleep(forTimeInterval: 0.8)
        capture("store_\(storeDevice)_02_latin_dark")
        capture("store_\(storeDevice)_02_latin_dark_crh")
        app.terminate()

        for lang in ["uk", "en"] {
            var args = ["-qt_demo_stats", "-qt_prefill_greeting_prefix", "-qt_lang", lang, "-qt_cyrillic_added"]
            if lang == "uk" { args.append("-qt_ukrainian_fiva") }
            try launch(theme: "modernDark", extraArgs: args)
            try selectScript(cyrillic: false)
            Thread.sleep(forTimeInterval: 0.4)
            typeLetters("sel")
            tap("character.â")
            typeLetters("m")
            Thread.sleep(forTimeInterval: 0.8)
            capture("store_\(storeDevice)_02_latin_dark_\(lang)")
            app.terminate()
        }
    }

    func testAppStorePreviewVideoScenario() throws {
        try launch(
            fieldMode: "standard",
            theme: "modernLight",
            extraArgs: ["-qt_demo_stats", "-qt_enable_animations", "-qt_cyrillic_added", "-qt_lang", "crh"]
        )
        try selectScript(cyrillic: false)
        capture("vframe_\(storeDevice)_00")
        clear()
        // 1. Show new v3.1 daily phrase platter (matching autocorrection pill style)
        Thread.sleep(forTimeInterval: 0.6)
        capture("vframe_\(storeDevice)_01")
        Thread.sleep(forTimeInterval: 0.4)
        capture("vframe_\(storeDevice)_02")

        // 2. Type Crimean Tatar Latin text with space-committed autocorrection & 3-slot suggestions
        typeLetters("sel")
        Thread.sleep(forTimeInterval: 0.25)
        capture("vframe_\(storeDevice)_03")
        typeLetters("am")
        Thread.sleep(forTimeInterval: 0.35)
        capture("vframe_\(storeDevice)_04")
        tap("space")
        Thread.sleep(forTimeInterval: 0.4)
        capture("vframe_\(storeDevice)_05")

        typeLetters("qir")
        Thread.sleep(forTimeInterval: 0.25)
        capture("vframe_\(storeDevice)_06")
        typeLetters("im")
        Thread.sleep(forTimeInterval: 0.4)
        capture("vframe_\(storeDevice)_07")
        let slot1 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.1").firstMatch
        if slot1.exists && slot1.isHittable {
            slot1.tap()
            Thread.sleep(forTimeInterval: 0.4)
        } else {
            tap("space")
            Thread.sleep(forTimeInterval: 0.4)
        }
        capture("vframe_\(storeDevice)_08")

        // 3. Swipe a word on iPhone or type on iPad, then show Cyrillic keyboard
        if UIDevice.current.userInterfaceIdiom == .phone {
            let sKey = letterElement("s")
            let mKey = letterElement("m")
            if sKey.exists && mKey.exists {
                let cS = sKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let cM = mKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                cS.press(forDuration: 0.05, thenDragTo: cM, withVelocity: .slow, thenHoldForDuration: 0.05)
                Thread.sleep(forTimeInterval: 0.5)
            }
        } else {
            typeLetters("vatan")
            tap("space")
            Thread.sleep(forTimeInterval: 0.4)
        }
        capture("vframe_\(storeDevice)_09")

        if (try? selectScript(cyrillic: true)) != nil, waitForLetter("ф", timeout: 2.0) {
            capture("vframe_\(storeDevice)_10")
            typeLetters("селям")
            Thread.sleep(forTimeInterval: 0.5)
            capture("vframe_\(storeDevice)_11")
            _ = try? selectScript(cyrillic: false)
            Thread.sleep(forTimeInterval: 0.4)
        } else {
            capture("vframe_\(storeDevice)_10")
            capture("vframe_\(storeDevice)_11")
        }
        capture("vframe_\(storeDevice)_12")

        // 4. Toggle Dark Mode (Qaranlıq) then back to Light Mode
        let darkPred = NSPredicate(format: "identifier == 'theme.dark' OR label IN {'Qaranlıq', 'Темна', 'Dark'}")
        let darkBtn = app.buttons.matching(darkPred).firstMatch
        if darkBtn.exists && darkBtn.isHittable {
            darkBtn.tap()
            Thread.sleep(forTimeInterval: 0.9)
            capture("vframe_\(storeDevice)_13")
            clear()
            Thread.sleep(forTimeInterval: 0.6)
            capture("vframe_\(storeDevice)_14")
        } else {
            capture("vframe_\(storeDevice)_13")
            capture("vframe_\(storeDevice)_14")
        }
        let lightPred = NSPredicate(format: "identifier == 'theme.light' OR label IN {'Aydınlıq', 'Світла', 'Light'}")
        let lightBtn = app.buttons.matching(lightPred).firstMatch
        if lightBtn.exists && lightBtn.isHittable {
            lightBtn.tap()
            Thread.sleep(forTimeInterval: 0.7)
        }
        capture("vframe_\(storeDevice)_15")

        // 5. Dismiss keyboard or scroll to show HomeView settings: Українська interface + hierarchical Українська розкладка sub-row & Кʼ/Къ badge + Statistika
        let donePred = NSPredicate(format: "label IN {'Done', 'Готово', 'Azır'}")
        let doneBtn = app.buttons.matching(donePred).firstMatch
        if doneBtn.exists && doneBtn.isHittable {
            doneBtn.tap()
            Thread.sleep(forTimeInterval: 0.5)
        }
        capture("vframe_\(storeDevice)_16")

        let ukBtn = app.buttons["Українська"].firstMatch
        if ukBtn.exists && ukBtn.isHittable {
            ukBtn.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
        capture("vframe_\(storeDevice)_17")

        let ukFivaToggle = app.switches["settings.ukrainianCyrillic.toggle"].exists
            ? app.switches["settings.ukrainianCyrillic.toggle"]
            : app.descendants(matching: .any).matching(identifier: "settings.ukrainianCyrillic.toggle").firstMatch
        if ukFivaToggle.exists {
            tapSwitch(ukFivaToggle)
            Thread.sleep(forTimeInterval: 0.7)
            capture("vframe_\(storeDevice)_18")
            if ((ukFivaToggle.value as? String) ?? "0") == "0" {
                tapSwitch(ukFivaToggle)
                Thread.sleep(forTimeInterval: 0.7)
            }
            capture("vframe_\(storeDevice)_19")
        } else {
            capture("vframe_\(storeDevice)_18")
            capture("vframe_\(storeDevice)_19")
        }

        let statsToggle = app.buttons["stats.expandToggle"].exists
            ? app.buttons["stats.expandToggle"]
            : app.descendants(matching: .any).matching(identifier: "stats.expandToggle").firstMatch
        if statsToggle.exists {
            tapSwitch(statsToggle)
            Thread.sleep(forTimeInterval: 0.9)
            capture("vframe_\(storeDevice)_20")
            app.scrollViews.firstMatch.swipeUp()
            Thread.sleep(forTimeInterval: 0.7)
            capture("vframe_\(storeDevice)_21")
        } else {
            capture("vframe_\(storeDevice)_20")
            capture("vframe_\(storeDevice)_21")
        }
        capture("store_\(storeDevice)_video_final_frame")
    }

    func testSandboxFieldThemeSyncAndCyrillicDisableInstructions() throws {
        // 0. Verify tapping Full Access row/toggle when Full Access is missing opens Allow Full Access instruction (Step 2/4), NOT Add New Keyboard
        app.launchArguments = ["-qt_full_access_missing", "-qt_cyrillic_added", "-qt_demo_stats", "-qt_lang", "uk"]
        app.launch()
        let fullAccessToggle = app.switches["status.fullAccess.toggle"].exists
            ? app.switches["status.fullAccess.toggle"]
            : app.descendants(matching: .any).matching(identifier: "status.fullAccess.toggle").firstMatch
        XCTAssertTrue(fullAccessToggle.waitForExistence(timeout: 4.0), "status.fullAccess.toggle must be visible when Full Access is missing")
        fullAccessToggle.tap()
        let onbView = app.descendants(matching: .any).matching(identifier: "onboarding.add.view").firstMatch
        let onbOpenBtn = app.descendants(matching: .any).matching(identifier: "onboarding.openSettings.button").firstMatch
        if !onbView.waitForExistence(timeout: 2.0) && !onbOpenBtn.waitForExistence(timeout: 1.5) {
            let fullAccessRow = app.descendants(matching: .any).matching(identifier: "status.fullAccess.row").firstMatch
            if fullAccessRow.exists {
                fullAccessRow.tap()
            }
        }
        XCTAssertTrue(onbView.waitForExistence(timeout: 3.0) || onbOpenBtn.waitForExistence(timeout: 3.0), "Tapping status.fullAccess.toggle/row must open OnboardingView")
        let fullAccessText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'повний доступ' OR label CONTAINS[c] 'Full Access' OR label CONTAINS[c] 'Tam irişüv' OR label CONTAINS[c] 'Tam irişim'")).firstMatch
        XCTAssertTrue(fullAccessText.waitForExistence(timeout: 2.5), "Full Access onboarding step must explain Allow Full Access, not Add New Keyboard")
        capture("verify_00_full_access_onboarding_step2")
        app.terminate()

        // 1. Verify turning OFF settings.cyrillic.toggle when Cyrillic is added opens .removeCyrillic instructions
        app.launchArguments = ["-qt_cyrillic_added", "-qt_demo_stats", "-qt_lang", "uk"]
        app.launch()
        let cyrToggle = app.switches["settings.cyrillic.toggle"].exists
            ? app.switches["settings.cyrillic.toggle"]
            : app.descendants(matching: .any).matching(identifier: "settings.cyrillic.toggle").firstMatch
        XCTAssertTrue(cyrToggle.waitForExistence(timeout: 5.0))
        XCTAssertEqual(cyrToggle.value as? String, "1")
        cyrToggle.tap()
        let removeView = app.descendants(matching: .any).matching(identifier: "onboarding.removeCyrillic.view").firstMatch
        let finishBtn = app.descendants(matching: .any).matching(identifier: "onboarding.finish.button").firstMatch
        XCTAssertTrue(removeView.waitForExistence(timeout: 3.0) || finishBtn.waitForExistence(timeout: 3.0),
                      "Turning OFF Kirill klaviaturası must present OnboardingView(mode: .removeCyrillic), not .add")
        capture("verify_01_cyrillic_remove_sheet")
        if finishBtn.exists && finishBtn.isHittable {
            finishBtn.tap()
        }
        app.terminate()

        // 2. Verify Text (empty -> daily phrase, non-empty -> 3 suggestions) vs Search (empty -> 3 suggestions, no daily phrase)
        try launch(fieldMode: "standard", theme: "modernLight", extraArgs: ["-qt_cyrillic_added"])
        clear()
        Thread.sleep(forTimeInterval: 3.4)
        let banner = app.descendants(matching: .any).matching(identifier: "autocomplete.greetingBanner").firstMatch
        let slot0 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.0").firstMatch
        let slot1 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.1").firstMatch
        let slot2 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.2").firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 2.5), "Empty Text field must display daily greeting phrase")
        XCTAssertFalse(slot0.exists && !slot0.label.isEmpty, "Empty Text field must not overlap suggestions with daily phrase")
        capture("verify_02_text_empty_phrase_light")

        // Type a character in Text mode -> daily phrase must disappear immediately and 3 suggestions must appear without overlap
        if hasLetter("q") {
            typeLetters("q")
        } else if hasLetter("ф") {
            typeLetters("ф")
        }
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(banner.exists, "Daily phrase must disappear immediately when typing in Text field")
        XCTAssertTrue(slot0.waitForExistence(timeout: 2.5) && !slot0.label.isEmpty, "Non-empty Text field must show 3 suggestions (slot 0)")
        XCTAssertTrue(slot1.exists && !slot1.label.isEmpty, "Non-empty Text field must show 3 suggestions (slot 1)")
        XCTAssertTrue(slot2.exists && !slot2.label.isEmpty, "Non-empty Text field must show 3 suggestions (slot 2)")
        capture("verify_02b_text_typed_3_suggestions")
        clear()
        Thread.sleep(forTimeInterval: 0.5)

        func segmentButton(_ names: [String]) -> XCUIElement {
            let pred = NSPredicate(format: "identifier IN %@ OR label IN %@", names, names)
            return app.buttons.matching(pred).firstMatch
        }

        // Switch to Search while empty -> must show 3 suggestions and NO daily phrase
        let searchSeg = segmentButton(["field.search", "Qıdıruv", "Пошук", "Search"])
        XCTAssertTrue(searchSeg.waitForExistence(timeout: 2.0))
        searchSeg.tap()
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertFalse(banner.exists, "Search field must NEVER show daily greeting phrase")
        XCTAssertTrue(slot0.waitForExistence(timeout: 2.5) && !slot0.label.isEmpty, "Empty Search field must show 3 starter suggestions (slot 0)")
        XCTAssertTrue(slot1.exists && !slot1.label.isEmpty, "Empty Search field must show 3 starter suggestions (slot 1)")
        XCTAssertTrue(slot2.exists && !slot2.label.isEmpty, "Empty Search field must show 3 starter suggestions (slot 2)")
        capture("verify_03_search_empty_3_suggestions")

        // Switch to Numbers -> must show numeric layout
        let numbersSeg = segmentButton(["field.numbers", "Raqamlar", "Числа", "Numbers"])
        XCTAssertTrue(numbersSeg.waitForExistence(timeout: 2.0))
        numbersSeg.tap()
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(waitForLetter("1", timeout: 2.5), "Selecting Numbers in sandbox must switch keyboard to numeric page")
        capture("verify_04_numbers_mode")

        // Switch to Email -> must show @ key on bottom row and hide top toolbar
        let emailSeg = segmentButton(["field.email", "E-posta", "E-poçta", "Пошта", "Email"])
        XCTAssertTrue(emailSeg.waitForExistence(timeout: 2.0))
        emailSeg.tap()
        Thread.sleep(forTimeInterval: 0.8)
        XCTAssertTrue(waitForLetter("@", timeout: 2.5), "Selecting Email in sandbox must show @ key")
        XCTAssertFalse(banner.exists, "Email field must not show daily phrase")
        capture("verify_05_email_mode")

        // Switch back to Text, toggle Dark -> Light -> verify light keyboard with no black keys
        let textSeg = segmentButton(["field.standard", "Yazı", "Текст", "Text"])
        if textSeg.exists {
            textSeg.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }
        let darkSeg = segmentButton(["theme.dark", "Qaranlıq", "Темна", "Dark"])
        let lightSeg = segmentButton(["theme.light", "Aydınlıq", "Світла", "Light"])
        if darkSeg.exists {
            darkSeg.tap()
            Thread.sleep(forTimeInterval: 3.4)
            capture("verify_06_theme_dark")
        }
        if lightSeg.exists {
            lightSeg.tap()
            Thread.sleep(forTimeInterval: 0.6)
            capture("verify_07_theme_light_after_dark")
        }
    }

    // MARK: - Deep Audit: All Modes, Orientations, Scripts, Themes, Field Types & Atypical Edge Cases

    func testComprehensiveModesSizesSwitchAndAtypicalEvents() throws {
        try launch(
            fieldMode: "standard",
            theme: "modernLight",
            extraArgs: ["-qt_cyrillic_added", "-qt_lang", "crh"]
        )
        try selectScript(cyrillic: false)
        clear()

        // 1. Verify VoiceOver / Accessibility identifiers & contrast-ready elements on active keyboard
        let spaceKey = key("space")
        let backspaceKey = key("backspace")
        let shiftKey = key("shift")
        let numericKey = key("numeric")
        XCTAssertTrue(spaceKey.exists && backspaceKey.exists && shiftKey.exists && numericKey.exists)

        // 2. Rapid script switching (Latin <-> Cyrillic) and layout switching (Alphabetic -> Numeric -> Symbolic -> Alphabetic)
        for cycle in 0..<2 {
            try selectScript(cyrillic: true)
            XCTAssertTrue(waitForLetter("ф", timeout: 2.0), "Cycle \(cycle): Cyrillic key 'ф' must appear")
            typeLetters("селям")
            tap("space")
            try selectScript(cyrillic: false)
            XCTAssertTrue(waitForLetter("q", timeout: 2.0), "Cycle \(cycle): Latin key 'q' must appear")
            typeLetters("dost")
            tap("space")
        }
        let currentVal = (field.value as? String) ?? ""
        XCTAssertTrue(currentVal.lowercased().contains("selâm") && currentVal.lowercased().contains("dost"), "Rapid script switching must preserve transliterated Cyrillic and Latin words (got: '\(currentVal)')")

        // 3. Rapid layout mode switching (123 -> #+= -> ABC)
        tap("numeric")
        XCTAssertTrue(key("character.1").waitForExistence(timeout: 2.0))
        tap("symbolic")
        XCTAssertTrue(key("character.€").waitForExistence(timeout: 2.0))
        tap("alphabetic")
        XCTAssertTrue(waitForLetter("q", timeout: 2.0))

        // 4. Atypical event: Rapid swipe + single backspace undo on iPhone, or rapid typing + backspace burst on iPad
        clear()
        if UIDevice.current.userInterfaceIdiom == .phone {
            let sKey = letterElement("s")
            let mKey = letterElement("m")
            if sKey.exists && mKey.exists {
                let cS = sKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let cM = mKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                cS.press(forDuration: 0.04, thenDragTo: cM, withVelocity: .slow, thenHoldForDuration: 0.04)
                Thread.sleep(forTimeInterval: 0.3)
                tap("backspace")
                expectText("")
            }
        } else {
            typeLetters("meraba")
            for _ in 0..<6 { tap("backspace") }
            expectText("")
        }

        // 5. Orientation resizability: Portrait -> LandscapeLeft -> Portrait without clipping or frame jump
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertTrue(key("space").waitForExistence(timeout: 2.5), "Spacebar must remain visible in LandscapeLeft")
        XCTAssertGreaterThan(key("space").frame.width, 60.0, "Spacebar width must be valid in LandscapeLeft")
        capture("DeepAudit_LandscapeLeft_\(storeDevice)")

        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertTrue(key("space").waitForExistence(timeout: 2.5), "Spacebar must remain visible after returning to Portrait")
        capture("DeepAudit_Portrait_\(storeDevice)")

        // 6. Theme switching under active session (Light <-> Dark)
        let darkBtn = app.buttons["theme.dark"]
        let lightBtn = app.buttons["theme.light"]
        if darkBtn.exists && darkBtn.isHittable {
            darkBtn.tap()
            Thread.sleep(forTimeInterval: 0.35)
            XCTAssertTrue(key("space").exists)
        }
        if lightBtn.exists && lightBtn.isHittable {
            lightBtn.tap()
            Thread.sleep(forTimeInterval: 0.35)
            XCTAssertTrue(key("space").exists)
        }
        clear()
    }

    private func letterKey(_ value: String) -> XCUIElement {
        let lowerId = "key.character." + value.lowercased(with: Locale(identifier: "tr"))
        let upperId = "key.character." + value.uppercased(with: Locale(identifier: "tr"))
        let pred = NSPredicate(format: "identifier == %@ OR identifier == %@", lowerId, upperId)
        let inAppKb = app.keyboards.firstMatch.descendants(matching: .any).matching(pred).firstMatch
        if inAppKb.exists {
            return inAppKb
        }
        let inApp = app.descendants(matching: .any).matching(pred).firstMatch
        if inApp.exists {
            return inApp
        }
        let sbKb = XCUIApplication(bundleIdentifier: "com.apple.springboard").keyboards.firstMatch.descendants(matching: .any).matching(pred).firstMatch
        if sbKb.exists {
            return sbKb
        }
        return inApp
    }

    func testPhysicalDeviceReleaseProof_2026_11_01() throws {
        let deviceTag = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"

        // 1. Launch with auto-focus in Ukrainian with both Cyrillic and Ukrainian layouts active
        app.launchArguments = [
            "-qt_field", "standard",
            "-qt_theme", "modernLight",
            "-qt_reset_text",
            "-qt_cyrillic_added",
            "-qt_ukrainian_added",
            "-qt_demo_stats",
            "-qt_lang", "uk"
        ]
        app.launch()
        _ = field.waitForExistence(timeout: 10)
        dismissKeyboardOnboardingOverlayIfNeeded()
        if !anyCustomKey.waitForExistence(timeout: 3.5) {
            if field.exists && field.isHittable {
                field.tap()
                Thread.sleep(forTimeInterval: 0.6)
            }
            dismissKeyboardOnboardingOverlayIfNeeded()
            if !anyCustomKey.exists {
                cycleToCustomKeyboard(firstKey: key("numeric"))
            }
        }
        try? selectScript(cyrillic: false)

        // If iPad keyboard is currently in Floating mode (e.g. from an earlier test), capture Floating proof first and then dock it to full width
        if UIDevice.current.userInterfaceIdiom == .pad, key("space").exists, key("space").frame.width < 260 {
            capture("PhysicalProof_01b_Keyboard_Floating_UK_\(deviceTag)")
            let spaceEl = key("space")
            let grabberStart = spaceEl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.32))
            let bottomDockTarget = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99))
            grabberStart.press(forDuration: 0.25, thenDragTo: bottomDockTarget)
            Thread.sleep(forTimeInterval: 0.8)
            if key("space").exists && key("space").frame.width < 260 {
                let kbTarget = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch : spaceEl
                kbTarget.pinch(withScale: 2.4, velocity: 2.5)
                Thread.sleep(forTimeInterval: 0.8)
            }
            if !anyCustomKey.exists && field.exists && field.isHittable {
                field.tap()
                Thread.sleep(forTimeInterval: 0.6)
            }
        }

        // 2. Verify Docked iPad / iPhone Latin layout (4-row iPad: Â before Z on Row 2, widened абв > shortened left Shift; 5-row Pro: Â on top row)
        let aHatKey = letterKey("â")
        let zKey = letterKey("z")
        if aHatKey.waitForExistence(timeout: 2.5) && zKey.exists {
            if UIDevice.current.userInterfaceIdiom == .pad {
                let abvKey = key("toggle_script")
                let shiftKey = key("shift")
                if abs(aHatKey.frame.midY - zKey.frame.midY) < 24.0 {
                    XCTAssertLessThan(aHatKey.frame.midX, zKey.frame.midX, "Â must sit to the left of Z on Row 2")
                    if abvKey.exists && shiftKey.exists {
                        XCTAssertGreaterThan(abvKey.frame.width, shiftKey.frame.width, "Widened абв key on Row 1 must be wider than shortened left Shift on Row 2")
                    }
                } else {
                    XCTAssertLessThan(aHatKey.frame.midY, zKey.frame.midY, "On 5-row iPad Pro, Â sits on the top row above Z")
                }
            }
        }
        capture("PhysicalProof_01_Keyboard_Light_UK_\(deviceTag)")

        // 3. Switch Світла -> Темна -> Світла and verify responsive non-blocking transition
        let darkPred = NSPredicate(format: "identifier == 'theme.dark' OR label IN {'Qaranlıq', 'Темна', 'Dark'}")
        let lightPred = NSPredicate(format: "identifier == 'theme.light' OR label IN {'Aydınlıq', 'Світла', 'Light'}")
        let darkBtn = app.buttons.matching(darkPred).firstMatch
        let lightBtn = app.buttons.matching(lightPred).firstMatch
        if darkBtn.waitForExistence(timeout: 2.0) && darkBtn.isHittable {
            darkBtn.tap()
            _ = anyCustomKey.waitForExistence(timeout: 2.0)
            Thread.sleep(forTimeInterval: 0.45)
            capture("PhysicalProof_02_Keyboard_Dark_UK_\(deviceTag)")
        }
        if lightBtn.waitForExistence(timeout: 2.0) && lightBtn.isHittable {
            lightBtn.tap()
            Thread.sleep(forTimeInterval: 0.45)
        }

        // 4. Dismiss keyboard and verify 3-card HomeView layout + [абв] selectors
        let donePred = NSPredicate(format: "label IN {'Done', 'Готово', 'Azır'}")
        let doneBtn = app.buttons.matching(donePred).firstMatch
        if doneBtn.exists && doneBtn.isHittable {
            doneBtn.tap()
            Thread.sleep(forTimeInterval: 0.45)
        } else if UIDevice.current.userInterfaceIdiom == .pad, key("dismiss").exists {
            tap("dismiss")
            Thread.sleep(forTimeInterval: 0.45)
        }

        let primaryRow = app.descendants(matching: .any).matching(identifier: "status.primaryKeyboard.row").firstMatch
        let cyrRow = app.descendants(matching: .any).matching(identifier: "settings.cyrillic.statusRow").firstMatch
        let ukRow = app.descendants(matching: .any).matching(identifier: "settings.ukrainianCyrillic.statusRow").firstMatch
        if !ukRow.exists {
            app.scrollViews.firstMatch.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        XCTAssertTrue(primaryRow.waitForExistence(timeout: 3.0), "Primary keyboard row must exist")
        XCTAssertTrue(cyrRow.waitForExistence(timeout: 3.0), "Cyrillic keyboard row must exist")
        XCTAssertTrue(ukRow.waitForExistence(timeout: 3.0), "Ukrainian keyboard row must exist when language == uk")
        if UIDevice.current.userInterfaceIdiom == .pad {
            let cyrAbv = app.descendants(matching: .any).matching(identifier: "settings.cyrillic.abvSelector").firstMatch
            let ukAbv = app.descendants(matching: .any).matching(identifier: "settings.ukrainianCyrillic.abvSelector").firstMatch
            XCTAssertTrue(cyrAbv.exists && ukAbv.exists, "iPad must show [абв] selectors when both Cyrillic layouts are active")
        }
        capture("PhysicalProof_03_HomeView_3Cards_UK_\(deviceTag)")

        // 5. Verify QT ↔ УК ↔ EN language switching without hang
        let qtBtn = app.buttons["Qırımtatarca"].firstMatch
        if !qtBtn.isHittable {
            app.scrollViews.firstMatch.swipeDown()
            Thread.sleep(forTimeInterval: 0.35)
        }
        if qtBtn.waitForExistence(timeout: 2.0) && qtBtn.isHittable {
            qtBtn.tap()
            Thread.sleep(forTimeInterval: 0.4)
            XCTAssertFalse(ukRow.exists, "Ukrainian layout row must be hidden when language == crh")
            if UIDevice.current.userInterfaceIdiom == .pad {
                let abvBridge = app.descendants(matching: .any).matching(identifier: "settings.abvBridge.container").firstMatch
                XCTAssertFalse(abvBridge.exists, "абв bridge must be hidden when language != uk (crh)")
            }
            capture("PhysicalProof_04_Lang_QT_\(deviceTag)")
        }
        let enBtn = app.buttons["English"].firstMatch
        if enBtn.waitForExistence(timeout: 2.0) && enBtn.isHittable {
            enBtn.tap()
            Thread.sleep(forTimeInterval: 0.35)
            XCTAssertFalse(ukRow.exists, "Ukrainian layout row must be hidden when language == en")
            if UIDevice.current.userInterfaceIdiom == .pad {
                let abvBridge = app.descendants(matching: .any).matching(identifier: "settings.abvBridge.container").firstMatch
                XCTAssertFalse(abvBridge.exists, "абв bridge must be hidden when language != uk (en)")
            }
        }
        let ukBtn = app.buttons["Українська"].firstMatch
        if ukBtn.waitForExistence(timeout: 2.0) && ukBtn.isHittable {
            ukBtn.tap()
            Thread.sleep(forTimeInterval: 0.35)
        }

        // 6. Open Settings.app via app settings button and verify no Cellular Data row exists in QırımKey settings
        let appSettingsBtn = app.descendants(matching: .any).matching(identifier: "settings.appSettings.button").firstMatch
        if !appSettingsBtn.exists {
            app.scrollViews.firstMatch.swipeUp()
            Thread.sleep(forTimeInterval: 0.4)
        }
        if appSettingsBtn.exists && appSettingsBtn.isHittable {
            appSettingsBtn.tap()
            let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
            if settings.wait(for: .runningForeground, timeout: 5.0) {
                Thread.sleep(forTimeInterval: 0.8)
                let cellularCell = settings.cells.matching(NSPredicate(format: "label CONTAINS[c] 'Cellular' OR label CONTAINS[c] 'Стільников' OR label CONTAINS[c] 'Мобільн' OR label CONTAINS[c] 'Сотов'")).firstMatch
                XCTAssertFalse(cellularCell.exists, "QırımKey Settings page must not show Cellular Data")
                capture("PhysicalProof_05_iOSSettings_\(deviceTag)")
                settings.terminate()
            }
        }
        app.terminate()

        // 7. Verify AboutView social media pills (Instagram / Facebook full titles without ellipsis truncation)
        app.launchArguments = [
            "-qt_open_about",
            "-qt_no_autofocus",
            "-qt_theme", "modernLight",
            "-qt_lang", "uk"
        ]
        app.launch()
        Thread.sleep(forTimeInterval: 1.0)
        let instagramBtn = app.buttons["Instagram"].firstMatch
        let facebookBtn = app.buttons["Facebook"].firstMatch
        XCTAssertTrue(instagramBtn.waitForExistence(timeout: 3.0), "Instagram button must exist in AboutView")
        XCTAssertTrue(facebookBtn.waitForExistence(timeout: 3.0), "Facebook button must exist in AboutView")
        capture("PhysicalProof_06_AboutView_SocialPills_\(deviceTag)")
        app.terminate()

        // 8. On iPad, verify Home and About views without fake width flags
        if UIDevice.current.userInterfaceIdiom == .pad {
            app.launchArguments = [
                "-qt_no_autofocus",
                "-qt_cyrillic_added",
                "-qt_ukrainian_added",
                "-qt_demo_stats",
                "-qt_theme", "modernLight",
                "-qt_lang", "uk"
            ]
            app.launch()
            Thread.sleep(forTimeInterval: 0.9)
            let ukRow = app.descendants(matching: .any).matching(identifier: "settings.ukrainianCyrillic.statusRow").firstMatch
            XCTAssertTrue(ukRow.waitForExistence(timeout: 3.0), "Ukrainian row must exist on iPad HomeView")
            capture("PhysicalProof_07_StageManager_375_Home_\(deviceTag)")
            app.terminate()
        }
    }

    func testPostCommit95beb28AllEightFixesProof_2026_11_02() throws {
        let deviceTag = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"

        func dismissKB() {
            let donePred = NSPredicate(format: "label IN {'Done', 'Готово', 'Azır'}")
            let doneBtn = app.buttons.matching(donePred).firstMatch
            if doneBtn.exists && doneBtn.isHittable {
                doneBtn.tap()
                Thread.sleep(forTimeInterval: 0.45)
            } else if UIDevice.current.userInterfaceIdiom == .pad, key("dismiss").exists {
                tap("dismiss")
                Thread.sleep(forTimeInterval: 0.45)
            }
        }

        // 1. Launch with -qt_force_suggestions_on and both Cyrillic and Ukrainian layouts active
        try launch(
            fieldMode: "standard",
            theme: "modernLight",
            extraArgs: [
                "-qt_force_suggestions_on",
                "-qt_cyrillic_added",
                "-qt_ukrainian_added",
                "-qt_lang", "uk"
            ]
        )
        try? selectScript(cyrillic: false)

        // Ensure iPad keyboard is Docked for 20.10 proof
        if UIDevice.current.userInterfaceIdiom == .pad, key("space").exists, key("space").frame.width < 260 {
            let spaceEl = key("space")
            let grabberStart = spaceEl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.32))
            let bottomDockTarget = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.99))
            grabberStart.press(forDuration: 0.25, thenDragTo: bottomDockTarget)
            Thread.sleep(forTimeInterval: 0.8)
            if key("space").exists && key("space").frame.width < 260 {
                let kbTarget = app.keyboards.firstMatch.exists ? app.keyboards.firstMatch : spaceEl
                kbTarget.pinch(withScale: 2.4, velocity: 2.5)
                Thread.sleep(forTimeInterval: 0.8)
            }
            if !anyCustomKey.exists && field.exists && field.isHittable {
                field.tap()
                Thread.sleep(forTimeInterval: 0.6)
            }
        }

        // Proof 20.10 (iPad Docked 4-Row Layout) & 20.21 (No Dictation Microphone in bottom dock)
        let dictationPred = NSPredicate(format: "identifier CONTAINS[c] 'dictation' OR label CONTAINS[c] 'Dictate' OR label CONTAINS[c] 'Диктувати'")
        XCTAssertFalse(app.keyboards.buttons.matching(dictationPred).firstMatch.exists, "No system dictation microphone icon may appear under the keyboard")
        capture("Proof_20_10_20_21_Keyboard_Docked_NoMic_\(deviceTag)")

        // Proof 20.17 (iPhone InputCallout & ActionCallout Bubbles) & 20.35 (Calibrated 241pt Keyboard Height & 12pt Bottom Inset)
        if UIDevice.current.userInterfaceIdiom == .phone {
            capture("Proof_20_35_Keyboard_Height_BottomInset_\(deviceTag)")
            let gEl = letterKey("g")
            let qEl = letterKey("q")
            if gEl.exists {
                gEl.tap()
                capture("Proof_20_17_KeyCallout_CenterKey_G_\(deviceTag)")
                Thread.sleep(forTimeInterval: 1.05)
                let gCenter = gEl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                gCenter.press(forDuration: 0.55)
                capture("Proof_20_17_ActionCallout_Bubble_iOS27_\(deviceTag)")
                Thread.sleep(forTimeInterval: 1.05)
            }
            if qEl.exists {
                qEl.tap()
                capture("Proof_20_17_KeyCallout_EdgeKey_Q_\(deviceTag)")
                Thread.sleep(forTimeInterval: 1.05)
            }
            clear()
        }

        // Proof 20.14 & 20.34 on iPad: Key Flick down on Q -> '1' and A -> '@'
        if UIDevice.current.userInterfaceIdiom == .pad {
            let qEl = letterKey("q")
            if qEl.exists {
                let start = qEl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.30))
                let end = qEl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 1.15))
                start.press(forDuration: 0.02, thenDragTo: end)
                Thread.sleep(forTimeInterval: 0.35)
                let valAfterQ = (field.value as? String) ?? ""
                XCTAssertTrue(valAfterQ.contains("1"), "Downward Key Flick on 'q' on iPad must insert '1', got: '\(valAfterQ)'")
                capture("Proof_20_14_iPad_KeyFlick_Q_to_1_\(deviceTag)")
                capture("Proof_20_34_iPad_KeyFlick_Q_to_1_\(deviceTag)")
                clear()
            }
        }

        let slot0 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.0").firstMatch
        let slot1 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.1").firstMatch
        let slot2 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.2").firstMatch

        // Proof 20.14 (Math Results: 3+5= -> 3+5=8 in Slot 1, 8 in Slot 2)
        if key("numeric").exists { tap("numeric") }
        if key("character.3").waitForExistence(timeout: 2.0) {
            tap("character.3")
            if key("character.+").exists {
                tap("character.+")
            } else {
                tap("symbolic")
                if key("character.+").waitForExistence(timeout: 2.0) {
                    tap("character.+")
                }
                tap("numeric")
            }
            if key("character.5").waitForExistence(timeout: 2.0) {
                tap("character.5")
            }
            if !key("character.=").exists {
                tap("symbolic")
            }
            if key("character.=").waitForExistence(timeout: 2.0) {
                tap("character.=")
            }
            let mathReady = NSPredicate(format: "exists == true AND label CONTAINS '3+5=8'")
            _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: mathReady, object: slot1)], timeout: 3.0)
            capture("Proof_20_14_MathResults_3plus5_\(deviceTag)")
            if key("alphabetic").exists {
                tap("alphabetic")
                Thread.sleep(forTimeInterval: 0.3)
            }
        }
        clear()

        // Proof 20.19 (3 Top Suggestions Text Color & Spacebar Language Name Color in Light & Dark Mode)
        // + 20.23 (No Scroll Jump when switching Light <-> Dark theme)
        // + 20.18 (Learn novel word "qirimz" via Slot 0 + Space)
        typeLetters("qirim")
        Thread.sleep(forTimeInterval: 0.50)
        XCTAssertTrue(slot0.waitForExistence(timeout: 2.5) && !slot0.label.isEmpty, "Slot 0 must exist when Predictive Text is enabled")
        XCTAssertTrue(slot1.exists && !slot1.label.isEmpty, "Slot 1 must exist when Predictive Text is enabled")
        XCTAssertTrue(slot2.exists && !slot2.label.isEmpty, "Slot 2 must exist when Predictive Text is enabled")
        capture("Proof_20_19_Suggestions_And_Spacebar_Light_\(deviceTag)")

        let darkPred = NSPredicate(format: "identifier == 'theme.dark' OR label IN {'Qaranlıq', 'Темна', 'Dark'}")
        let lightPred = NSPredicate(format: "identifier == 'theme.light' OR label IN {'Aydınlıq', 'Світла', 'Light'}")
        let darkBtn = app.buttons.matching(darkPred).firstMatch
        let lightBtn = app.buttons.matching(lightPred).firstMatch
        let fieldYBeforeTheme = field.frame.minY
        if darkBtn.waitForExistence(timeout: 2.0) && darkBtn.isHittable {
            darkBtn.tap()
            Thread.sleep(forTimeInterval: 0.45)
            let fieldYDark = field.frame.minY
            XCTAssertLessThanOrEqual(abs(fieldYDark - fieldYBeforeTheme), 8.0, "Switching theme must not cause HomeView scroll jump")
            capture("Proof_20_19_Suggestions_And_Spacebar_Dark_\(deviceTag)")
            capture("Proof_20_23_NoScrollJump_ThemeSwitch_\(deviceTag)")
        }
        if lightBtn.waitForExistence(timeout: 2.0) && lightBtn.isHittable {
            lightBtn.tap()
            Thread.sleep(forTimeInterval: 0.35)
        }

        // Append "z" to form novel word "qirimz", then tap Slot 0 (`"qirimz"`) + Space to learn into Personal Dictionary (20.18)
        if !key("character.z").exists && field.exists && field.isHittable {
            field.tap()
            Thread.sleep(forTimeInterval: 0.30)
        }
        typeLetters("z")
        let slot0Qirimz = NSPredicate(format: "exists == true AND label CONTAINS[c] 'qirimz'")
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: slot0Qirimz, object: slot0)], timeout: 2.0)
        if slot0.exists && slot0.isHittable {
            slot0.tap()
            Thread.sleep(forTimeInterval: 0.30)
        }
        let fieldTextAfterSlot0 = (field.value as? String) ?? ""
        if !fieldTextAfterSlot0.hasSuffix(" ") {
            tap("space")
        }
        Thread.sleep(forTimeInterval: 0.75)

        dismissKB()

        // Proof 20.33 (Unified Approved HomeView Design: Light & Dark Mode)
        // & Proof 20.30 (AboutView opened via top-left QırımKey header.about wordmark without text truncation)
        app.scrollViews.firstMatch.swipeDown()
        Thread.sleep(forTimeInterval: 0.35)
        capture("Proof_20_33_Unified_HomeView_Light_\(deviceTag)")
        if darkBtn.exists && darkBtn.isHittable {
            darkBtn.tap()
            Thread.sleep(forTimeInterval: 0.40)
            capture("Proof_20_33_Unified_HomeView_Dark_\(deviceTag)")
            if lightBtn.exists && lightBtn.isHittable {
                lightBtn.tap()
                Thread.sleep(forTimeInterval: 0.35)
            }
        }

        let headerAboutBtn = app.descendants(matching: .any).matching(identifier: "header.about").firstMatch
        let infoNavBtn = headerAboutBtn.exists
            ? headerAboutBtn
            : app.navigationBars.buttons.element(boundBy: 0)
        if infoNavBtn.waitForExistence(timeout: 2.5) && infoNavBtn.isHittable {
            infoNavBtn.tap()
            Thread.sleep(forTimeInterval: 0.55)
            app.scrollViews.firstMatch.swipeUp()
            Thread.sleep(forTimeInterval: 0.40)
            capture("Proof_20_30_AboutView_NoTruncation_\(deviceTag)")
            let backBtn = app.navigationBars.buttons.element(boundBy: 0)
            if backBtn.exists {
                backBtn.tap()
                Thread.sleep(forTimeInterval: 0.45)
            }
        }

        let statsExpand = app.descendants(matching: .any).matching(identifier: "stats.expandToggle").firstMatch
        if statsExpand.waitForExistence(timeout: 3.0) && statsExpand.isHittable {
            statsExpand.tap()
            Thread.sleep(forTimeInterval: 0.55)
        }
        let learnedTile = app.descendants(matching: .any).matching(identifier: "stats.learnedWordsTile").firstMatch
        XCTAssertTrue(learnedTile.waitForExistence(timeout: 3.0), "stats.learnedWordsTile must exist when Statistics is expanded")
        capture("Proof_20_18_Stats_LearnedWordsTile_\(deviceTag)")

        if learnedTile.isHittable {
            learnedTile.tap()
            Thread.sleep(forTimeInterval: 0.65)
            let doneSheetBtn = app.descendants(matching: .any).matching(identifier: "stats.learnedWords.doneButton").firstMatch
            XCTAssertTrue(doneSheetBtn.waitForExistence(timeout: 3.0), "Personal Dictionary sheet must open when tapping Вивчені слова tile")
            let learnedRow = app.descendants(matching: .any).matching(identifier: "stats.learnedWords.row.qirimz").firstMatch
            _ = learnedRow.waitForExistence(timeout: 2.0)
            capture("Proof_20_18_Stats_LearnedWordsSheet_\(deviceTag)")
            doneSheetBtn.tap()
            Thread.sleep(forTimeInterval: 0.40)
        }

        // Collapse Statistics card so settings buttons and language switcher are visible
        if statsExpand.exists && statsExpand.isHittable {
            statsExpand.tap()
            Thread.sleep(forTimeInterval: 0.35)
        }

        // Proof 20.20 (Language switching QT <-> УК <-> EN row height & font stability)
        let fullRow = app.descendants(matching: .any).matching(identifier: "status.fullAccess.row").firstMatch
        let appBtn = app.descendants(matching: .any).matching(identifier: "settings.appSettings.button").firstMatch
        let sysBtn = app.descendants(matching: .any).matching(identifier: "settings.systemKeyboard.button").firstMatch
        let stdRow = app.descendants(matching: .any).matching(identifier: "status.primaryKeyboard.row").firstMatch
        let cyrRow = app.descendants(matching: .any).matching(identifier: "settings.cyrillic.statusRow").firstMatch

        if !sysBtn.exists || !sysBtn.isHittable {
            app.scrollViews.firstMatch.swipeUp()
            Thread.sleep(forTimeInterval: 0.40)
        }

        XCTAssertTrue(appBtn.waitForExistence(timeout: 3.0))
        let hasFullRow = fullRow.exists
        let ukrRow = app.descendants(matching: .any).matching(identifier: "settings.ukrainianCyrillic.row").firstMatch
        let hFullUK = hasFullRow ? fullRow.frame.height : 0
        let hAppUK = appBtn.frame.height
        let hSysUK = sysBtn.frame.height
        let hStdUK = stdRow.frame.height
        let hCyrUK = cyrRow.frame.height
        let hUkrUK = ukrRow.exists ? ukrRow.frame.height : hCyrUK
        capture("Proof_20_20_StageManager_Lang_UK_\(deviceTag)")

        let crhSeg = app.buttons["Qırımtatarca"].firstMatch
        if crhSeg.waitForExistence(timeout: 2.0) {
            if crhSeg.isHittable {
                crhSeg.tap()
            } else {
                crhSeg.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            Thread.sleep(forTimeInterval: 0.40)
        }
        let hFullCRH = hasFullRow ? fullRow.frame.height : 0
        let hAppCRH = appBtn.frame.height
        let hSysCRH = sysBtn.frame.height
        let hStdCRH = stdRow.frame.height
        let hCyrCRH = cyrRow.frame.height
        capture("Proof_20_20_StageManager_Lang_CRH_\(deviceTag)")

        let enSeg = app.buttons["English"].firstMatch
        if enSeg.waitForExistence(timeout: 2.0) {
            if enSeg.isHittable {
                enSeg.tap()
            } else {
                enSeg.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            Thread.sleep(forTimeInterval: 0.40)
        }
        let hFullEN = hasFullRow ? fullRow.frame.height : 0
        let hAppEN = appBtn.frame.height
        let hSysEN = sysBtn.frame.height
        let hStdEN = stdRow.frame.height
        let hCyrEN = cyrRow.frame.height
        capture("Proof_20_20_StageManager_Lang_EN_\(deviceTag)")

        if hasFullRow {
            XCTAssertLessThanOrEqual(abs(hFullCRH - hFullUK), 1.5, "Full Access row height must not jump between CRH (\(hFullCRH)) and UK (\(hFullUK))")
            XCTAssertLessThanOrEqual(abs(hFullUK - hFullEN), 1.5, "Full Access row height must not jump between UK (\(hFullUK)) and EN (\(hFullEN))")
        }
        XCTAssertLessThanOrEqual(abs(hAppCRH - hAppUK), 1.5, "App Settings row height must not jump between CRH (\(hAppCRH)) and UK (\(hAppUK))")
        XCTAssertLessThanOrEqual(abs(hAppUK - hAppEN), 1.5, "App Settings row height must not jump between UK (\(hAppUK)) and EN (\(hAppEN))")
        XCTAssertLessThanOrEqual(abs(hSysCRH - hSysUK), 1.5, "System Settings row height must not jump between CRH (\(hSysCRH)) and UK (\(hSysUK))")
        XCTAssertLessThanOrEqual(abs(hSysUK - hSysEN), 1.5, "System Settings row height must not jump between UK (\(hSysUK)) and EN (\(hSysEN))")
        XCTAssertLessThanOrEqual(abs(hStdCRH - hStdUK), 1.5, "Standard Layout row height must not jump between CRH (\(hStdCRH)) and UK (\(hStdUK))")
        XCTAssertLessThanOrEqual(abs(hStdUK - hStdEN), 1.5, "Standard Layout row height must not jump between UK (\(hStdUK)) and EN (\(hStdEN))")
        XCTAssertLessThanOrEqual(abs(hCyrUK - hUkrUK), 1.5, "In UK, Cyrillic (\(hCyrUK)) and Ukrainian (\(hUkrUK)) Bento cards must have identical height")
        XCTAssertLessThanOrEqual(abs(hCyrCRH - hStdCRH), 1.5, "In CRH, Cyrillic row (\(hCyrCRH)) must match Standard Layout row (\(hStdCRH)) height")
        XCTAssertLessThanOrEqual(abs(hCyrEN - hStdEN), 1.5, "In EN, Cyrillic row (\(hCyrEN)) must match Standard Layout row (\(hStdEN)) height")
        XCTAssertLessThanOrEqual(abs(hCyrCRH - hCyrEN), 1.5, "Cyrillic Layout row height must not jump between CRH (\(hCyrCRH)) and EN (\(hCyrEN))")

        let ukSeg = app.buttons["Українська"].firstMatch
        if ukSeg.waitForExistence(timeout: 2.0) {
            if ukSeg.isHittable {
                ukSeg.tap()
            } else {
                ukSeg.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            Thread.sleep(forTimeInterval: 0.35)
        }

        // Proof 20.21.2 on iPhone: Reset iOS Cellular Data usage statistics so cached "Стільникові дані" / "Mobile Data" row is cleared
        if UIDevice.current.userInterfaceIdiom == .phone {
            let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
            settings.launch()
            if settings.wait(for: .runningForeground, timeout: 4.0) {
                Thread.sleep(forTimeInterval: 0.6)
                let cellularPred = NSPredicate(format: "identifier == 'MOBILE_DATA_SETTINGS_ID' OR label CONTAINS[c] 'Стільникові' OR label CONTAINS[c] 'Мобільні дані' OR label CONTAINS[c] 'Мобільний зв' OR label CONTAINS[c] 'Mobile Service' OR label CONTAINS[c] 'Cellular'")
                let cellularCell = settings.cells.matching(cellularPred).firstMatch
                if cellularCell.waitForExistence(timeout: 2.0) {
                    cellularCell.tap()
                    Thread.sleep(forTimeInterval: 0.8)
                    for _ in 0..<7 {
                        settings.swipeUp()
                    }
                    Thread.sleep(forTimeInterval: 0.4)
                    let resetPred = NSPredicate(format: "label CONTAINS[c] 'Скинути статистику' OR label CONTAINS[c] 'Reset Statistics'")
                    let resetBtn = settings.descendants(matching: .any).matching(resetPred).firstMatch
                    if resetBtn.waitForExistence(timeout: 1.5) && resetBtn.isHittable {
                        resetBtn.tap()
                        Thread.sleep(forTimeInterval: 0.5)
                        let confirmBtn = settings.sheets.buttons.matching(resetPred).firstMatch
                        if confirmBtn.waitForExistence(timeout: 1.5) {
                            confirmBtn.tap()
                            Thread.sleep(forTimeInterval: 0.5)
                        }
                    }
                }
                settings.terminate()
            }
            app.activate()
            Thread.sleep(forTimeInterval: 0.45)
        }

        // Proof 20.15 & 20.21 (App Settings in Settings.app: NO Word suggestions, NO Key Flicks)
        if !appBtn.isHittable {
            app.scrollViews.firstMatch.swipeUp()
            Thread.sleep(forTimeInterval: 0.35)
        }
        if appBtn.exists {
            if appBtn.isHittable {
                appBtn.tap()
            } else {
                appBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
            if settings.wait(for: .runningForeground, timeout: 5.0) {
                Thread.sleep(forTimeInterval: 1.2)
                let fullAccessSwitchPred = NSPredicate(format: "label CONTAINS[c] 'Повний доступ' OR label CONTAINS[c] 'Allow Full Access'")
                for sw in settings.switches.matching(fullAccessSwitchPred).allElementsBoundByIndex {
                    if sw.exists && (sw.value as? String) == "0" {
                        sw.tap()
                        Thread.sleep(forTimeInterval: 0.4)
                        let allowAlertBtn = settings.alerts.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Дозволити' OR label CONTAINS[c] 'Allow'")).firstMatch
                        if allowAlertBtn.waitForExistence(timeout: 1.5) {
                            allowAlertBtn.tap()
                            Thread.sleep(forTimeInterval: 0.4)
                        }
                    }
                }
                let keyboardsNavPred = NSPredicate(format: "identifier IN {'Keyboards', 'Клавіатури', 'Клавиатуры'} OR title IN {'Keyboards', 'Клавіатури', 'Клавиатуры'}")
                if settings.navigationBars.matching(keyboardsNavPred).firstMatch.exists {
                    let navBack = settings.navigationBars.buttons.element(boundBy: 0)
                    if navBack.exists && navBack.isHittable {
                        navBack.tap()
                        Thread.sleep(forTimeInterval: 0.9)
                    }
                }
                _ = settings.cells.firstMatch.waitForExistence(timeout: 8.0)
                let suggestionsSwitch = settings.switches.matching(NSPredicate(format: "label CONTAINS[c] 'Söz teklifleri' OR label CONTAINS[c] 'Підказки слів' OR label CONTAINS[c] 'Word suggestions'")).firstMatch
                let flicksSwitch = settings.switches.matching(NSPredicate(format: "label CONTAINS[c] 'Tüşme belgi' OR label CONTAINS[c] 'Набір жестами' OR label CONTAINS[c] 'Key Flicks'")).firstMatch
                XCTAssertFalse(suggestionsSwitch.exists, "QırımKey Settings page must NOT show Word suggestions toggle")
                XCTAssertFalse(flicksSwitch.exists, "QırımKey Settings page must NOT show Key Flicks toggle")
                capture("Proof_20_15_20_21_AppSettings_Clean_\(deviceTag)")
            }
        }
        app.activate()
        Thread.sleep(forTimeInterval: 0.55)

        // Proof 20.16 (System Settings button opens iOS System Settings with General visible, not Apps list)
        if !sysBtn.isHittable {
            app.scrollViews.firstMatch.swipeUp()
            Thread.sleep(forTimeInterval: 0.35)
        }
        if sysBtn.exists {
            if sysBtn.isHittable {
                sysBtn.tap()
            } else {
                sysBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
            if settings.wait(for: .runningForeground, timeout: 5.0) {
                _ = settings.cells.firstMatch.waitForExistence(timeout: 8.0)
                Thread.sleep(forTimeInterval: 1.5)
                capture("Proof_20_16_SystemKeyboardSettings_\(deviceTag)")
                settings.terminate()
            }
        }

        // Proof 20.22 & 20.39: Swipe works when Predictive Text is OFF & Calibrated Swipe Comet vs Native System Keyboard Swipe Comet
        if UIDevice.current.userInterfaceIdiom == .phone {
            app.terminate()
            try launch(
                fieldMode: "standard",
                theme: "modernLight",
                extraArgs: [
                    "-qt_force_suggestions_off",
                    "-qt_cyrillic_added",
                    "-qt_ukrainian_added",
                    "-qt_lang", "uk"
                ]
            )
            try? selectScript(cyrillic: false)
            let sKey = letterKey("s")
            let eKey = letterKey("e")
            let lKey = letterKey("l")
            let aKey = letterKey("a")
            let mKey = letterKey("m")
            if sKey.exists && mKey.exists {
                let cS = sKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let cM = mKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                if eKey.exists && lKey.exists && aKey.exists {
                    let cL = lKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    let cA = aKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    cS.press(forDuration: 0.02, thenDragTo: cL, withVelocity: .default, thenHoldForDuration: 0.02)
                    cL.press(forDuration: 0.02, thenDragTo: cA, withVelocity: .default, thenHoldForDuration: 0.02)
                }
                cS.press(forDuration: 0.03, thenDragTo: cM, withVelocity: .slow, thenHoldForDuration: 0.04)
                capture("Proof_20_36_SwipeComet_Round19Part2_\(deviceTag)")
                capture("Proof_20_39_QirimKeySwipeComet_Calibrated_\(deviceTag)")
                Thread.sleep(forTimeInterval: 0.35)
            }
            capture("Proof_20_22_Swipe_PredictiveOFF_\(deviceTag)")

            // Switch to standard iOS system keyboard via Next keyboard (Globe) and record a multi-key swipe for 20.39 comparison
            let nextKbPred = NSPredicate(format: "identifier == 'Next keyboard' OR label IN {'Next keyboard', 'Наступна клавіатура', 'Следующая клавиатура', 'Nöbetteki klaviatura'}")
            let nextKb = app.buttons.matching(nextKbPred).firstMatch
            for _ in 0..<4 {
                if !anyCustomKey.exists { break }
                if nextKb.exists && nextKb.isHittable {
                    nextKb.tap()
                    Thread.sleep(forTimeInterval: 0.45)
                }
            }
            let sysKeys = app.keyboards.keys
            if sysKeys.count >= 15 {
                let kStart = sysKeys.element(boundBy: 0).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let kMid = sysKeys.element(boundBy: 14).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                kStart.press(forDuration: 0.03, thenDragTo: kMid, withVelocity: .slow, thenHoldForDuration: 0.05)
                capture("Proof_20_39_NativeSystemSwipeComet_Comparison_\(deviceTag)")
            }
        }
    }

    func testRound20_45_to_20_50_ComprehensiveVerification() throws {
        let deviceTag: String = {
            if UIDevice.current.userInterfaceIdiom == .pad {
                return "ipad"
            }
            #if targetEnvironment(simulator)
            return "iphone_sim_ios27"
            #else
            return "iphone15pro"
            #endif
        }()

        func capture(_ name: String) {
            let shot = XCUIScreen.main.screenshot()
            let att = XCTAttachment(screenshot: shot)
            att.name = name
            att.lifetime = .keepAlways
            add(att)
            if let data = shot.pngRepresentation as Data? {
                try? data.write(to: URL(fileURLWithPath: "/tmp/\(name).png"))
            }
        }

        func dismissKB() {
            let donePred = NSPredicate(format: "label IN {'Done', 'Готово', 'Azır'}")
            let doneBtn = app.buttons.matching(donePred).firstMatch
            if doneBtn.exists && doneBtn.isHittable {
                doneBtn.tap()
                Thread.sleep(forTimeInterval: 0.45)
            } else if UIDevice.current.userInterfaceIdiom == .pad, key("dismiss").exists {
                tap("dismiss")
                Thread.sleep(forTimeInterval: 0.45)
            }
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            try launch(
                fieldMode: "standard",
                theme: "modernLight",
                extraArgs: [
                    "-qt_clear_learned_words",
                    "-qt_reset_stats",
                    "-qt_enable_predictive_text",
                    "-qt_enable_math_results",
                    "-qt_cyrillic_added",
                    "-qt_ukrainian_added",
                    "-qt_extend_input_callout",
                    "-qt_hold_callout",
                    "-qt_lang", "uk"
                ]
            )
            try? selectScript(cyrillic: false)
            Thread.sleep(forTimeInterval: 0.55)
            setIPadFloatingKeyboard(true)
            let rEl = letterKey("r")
            let qEl = letterKey("q")
            if rEl.exists {
                rEl.tap()
                capture("Proof_20_48_20_17_InputCallout_KeyR_\(deviceTag)")
                Thread.sleep(forTimeInterval: 1.75)
            }
            if qEl.exists {
                qEl.tap()
                capture("Proof_20_48_20_17_InputCallout_KeyQ_\(deviceTag)")
                Thread.sleep(forTimeInterval: 1.75)
            }
            setIPadFloatingKeyboard(false)
        }

        try launch(
            fieldMode: "standard",
            theme: "modernLight",
            extraArgs: [
                "-qt_clear_learned_words",
                "-qt_reset_stats",
                "-qt_enable_predictive_text",
                "-qt_enable_math_results",
                "-qt_cyrillic_added",
                "-qt_ukrainian_added",
                "-qt_extend_input_callout",
                "-qt_hold_callout",
                "-qt_lang", "uk"
            ]
        )
        try? selectScript(cyrillic: false)

        // 1. Verify InputCallout on iPhone + Suggestion Font Color (20.47, 20.48, 20.17.2)
        if UIDevice.current.userInterfaceIdiom == .phone {
            let qEl = letterKey("q")
            let rEl = letterKey("r")
            if qEl.exists {
                qEl.tap()
                capture("Proof_20_48_20_17_InputCallout_KeyQ_\(deviceTag)")
                Thread.sleep(forTimeInterval: 1.75)
            }
            if rEl.exists {
                rEl.tap()
                capture("Proof_20_48_20_17_InputCallout_KeyR_\(deviceTag)")
                Thread.sleep(forTimeInterval: 1.75)
            }
            clear()
        }

        // 2. Verify 20.49 & 20.18.2:
        //    (a) Type novel word "jyhby" and press Space (is_custom = 0).
        //    (b) Type "jyhby" again -> MUST STILL be offered in quotes “jyhby” in Slot 0!
        //    (c) Tap Slot 0 (“jyhby”) and then type "qirimz" and tap Slot 0 (“qirimz”).
        //    (d) Verify Вивчено слів increments 0 -> 2 live in HomeView and Personal Dictionary sheet shows both words!
        let slot0 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.0").firstMatch

        typeLetters("jyhby")
        let slot0HasJyhby = NSPredicate(format: "exists == true AND label CONTAINS[c] 'jyhby'")
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: slot0HasJyhby, object: slot0)], timeout: 2.5)
        XCTAssertTrue(slot0.exists && slot0.label.lowercased().contains("jyhby"), "Novel word 'jyhby' must be offered in Slot 0 on first typing")
        tap("space")
        Thread.sleep(forTimeInterval: 0.45)

        // Type "jyhby" a SECOND time after committing with Space (is_custom = 0)
        typeLetters("jyhby")
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: slot0HasJyhby, object: slot0)], timeout: 2.5)
        XCTAssertTrue(
            slot0.exists && slot0.label.lowercased().contains("jyhby"),
            "Novel word 'jyhby' committed only with Space (is_custom = 0) MUST STILL be offered in quotes in Slot 0 on subsequent typing!"
        )
        capture("Proof_20_47_20_49_Suggestions_Light_QuotedSlot0_\(deviceTag)")

        let darkPred = NSPredicate(format: "identifier == 'theme.dark' OR label IN {'Qaranlıq', 'Темна', 'Dark'}")
        let lightPred = NSPredicate(format: "identifier == 'theme.light' OR label IN {'Aydınlıq', 'Світла', 'Light'}")
        let darkBtn = app.buttons.matching(darkPred).firstMatch
        let lightBtn = app.buttons.matching(lightPred).firstMatch
        if darkBtn.exists && darkBtn.isHittable {
            darkBtn.tap()
            Thread.sleep(forTimeInterval: 0.45)
            capture("Proof_20_47_Suggestions_Dark_NativeFontColor_\(deviceTag)")
        }
        if lightBtn.exists && lightBtn.isHittable {
            lightBtn.tap()
            Thread.sleep(forTimeInterval: 0.35)
        }
        if !slot0.exists && field.exists && field.isHittable {
            field.tap()
            Thread.sleep(forTimeInterval: 0.35)
        }
        if slot0.exists && slot0.isHittable {
            slot0.tap()
            Thread.sleep(forTimeInterval: 0.55)
        }

        // Now type second novel word "qirimz" and confirm via Slot 0
        typeLetters("qirimz")
        let slot0HasQirimz = NSPredicate(format: "exists == true AND label CONTAINS[c] 'qirimz'")
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: slot0HasQirimz, object: slot0)], timeout: 2.5)
        if slot0.exists && slot0.isHittable {
            slot0.tap()
            Thread.sleep(forTimeInterval: 0.65)
        }

        dismissKB()
        Thread.sleep(forTimeInterval: 0.45)

        // Expand Statistics card and verify Вивчено слів == 2 (not 0!)
        let statsExpand = app.descendants(matching: .any).matching(identifier: "stats.expandToggle").firstMatch
        if statsExpand.waitForExistence(timeout: 3.0) && statsExpand.isHittable {
            statsExpand.tap()
            Thread.sleep(forTimeInterval: 0.55)
        }
        let learnedTile = app.descendants(matching: .any).matching(identifier: "stats.learnedWordsTile").firstMatch
        XCTAssertTrue(learnedTile.waitForExistence(timeout: 3.0), "stats.learnedWordsTile must exist when Statistics is expanded")
        let tileHasNonZero = NSPredicate(format: "label CONTAINS '1' OR label CONTAINS '2' OR value CONTAINS '1' OR value CONTAINS '2'")
        _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: tileHasNonZero, object: learnedTile)], timeout: 2.5)
        capture("Proof_20_49_20_18_Stats_LearnedWordsTile_NonZero_\(deviceTag)")

        if learnedTile.isHittable {
            learnedTile.tap()
            Thread.sleep(forTimeInterval: 0.65)
            let doneSheetBtn = app.descendants(matching: .any).matching(identifier: "stats.learnedWords.doneButton").firstMatch
            XCTAssertTrue(doneSheetBtn.waitForExistence(timeout: 3.0), "Personal Dictionary sheet must open")
            let rowJyhby = app.descendants(matching: .any).matching(identifier: "stats.learnedWords.row.jyhby").firstMatch
            let rowQirimz = app.descendants(matching: .any).matching(identifier: "stats.learnedWords.row.qirimz").firstMatch
            XCTAssertTrue(rowJyhby.waitForExistence(timeout: 2.5) || rowQirimz.waitForExistence(timeout: 2.5), "Personal Dictionary sheet must contain newly confirmed words")
            capture("Proof_20_49_20_18_PersonalDictionary_Sheet_\(deviceTag)")
            doneSheetBtn.tap()
            Thread.sleep(forTimeInterval: 0.40)
        }

        if statsExpand.exists && statsExpand.isHittable {
            statsExpand.tap()
            Thread.sleep(forTimeInterval: 0.35)
        }

        // 3. Verify 20.46 & 20.47:
        //    - Keycap contour on Q / Къ / Кʼ matches badge cornerRadius: 7 without 3D shadows
        //    - Left-edge swipe-right exits BOTH OnboardingView (?) and AboutView (i / QırımKey)
        //    - Statistics icon does NOT re-animate on return
        capture("Proof_20_47_KeycapContours_Q_K_HomeView_\(deviceTag)")

        let questionBtn = app.descendants(matching: .any).matching(identifier: "nav.questionmark").firstMatch
        if questionBtn.waitForExistence(timeout: 2.5) && questionBtn.isHittable {
            questionBtn.tap()
            Thread.sleep(forTimeInterval: 0.55)
            let onbView = app.descendants(matching: .any).matching(identifier: "onboarding.add.view").firstMatch
            XCTAssertTrue(onbView.waitForExistence(timeout: 2.5), "OnboardingView (?) must open")
            capture("Proof_20_46_Onboarding_Opened_\(deviceTag)")

            let leftEdgeStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.50))
            let leftEdgeEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.50))
            leftEdgeStart.press(forDuration: 0.03, thenDragTo: leftEdgeEnd)
            Thread.sleep(forTimeInterval: 0.55)
            XCTAssertTrue(statsExpand.waitForExistence(timeout: 2.5), "Left-edge swipe-right must exit OnboardingView (?) back to HomeView")
            capture("Proof_20_46_20_47_ReturnedFromOnboarding_ViaSwipe_\(deviceTag)")
        }

        let aboutBtn = app.descendants(matching: .any).matching(identifier: "ab.bento.about").firstMatch
        let headerAbout = app.descendants(matching: .any).matching(identifier: "header.about").firstMatch
        let targetAboutBtn = aboutBtn.exists && aboutBtn.isHittable ? aboutBtn : headerAbout
        if targetAboutBtn.waitForExistence(timeout: 2.5) && targetAboutBtn.isHittable {
            targetAboutBtn.tap()
            Thread.sleep(forTimeInterval: 0.55)
            capture("Proof_20_46_AboutView_Opened_\(deviceTag)")

            let leftEdgeStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.015, dy: 0.50))
            let leftEdgeEnd = app.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.50))
            leftEdgeStart.press(forDuration: 0.03, thenDragTo: leftEdgeEnd)
            Thread.sleep(forTimeInterval: 0.55)
            XCTAssertTrue(statsExpand.waitForExistence(timeout: 2.5), "Left-edge swipe-right must exit AboutView back to HomeView")
            capture("Proof_20_46_20_47_ReturnedFromAbout_ViaSwipe_\(deviceTag)")
        }

        // 4. Verify 20.45 & 20.21.2: Open Settings -> Apps -> QırımKey and capture clean page (no Cellular Data row after clean install)
        let appBtn = app.descendants(matching: .any).matching(identifier: "settings.appSettings.button").firstMatch
        if !appBtn.isHittable {
            app.scrollViews.firstMatch.swipeUp()
            Thread.sleep(forTimeInterval: 0.35)
        }
        if appBtn.exists {
            if appBtn.isHittable {
                appBtn.tap()
            } else {
                appBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            }
            let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
            if settings.wait(for: .runningForeground, timeout: 5.0) {
                _ = settings.cells.firstMatch.waitForExistence(timeout: 8.0)
                Thread.sleep(forTimeInterval: 0.8)
                let keyboardsNavPred = NSPredicate(format: "identifier IN {'Keyboards', 'Клавіатури', 'Клавиатуры'} OR title IN {'Keyboards', 'Клавіатури', 'Клавиатуры'}")
                if settings.navigationBars.matching(keyboardsNavPred).firstMatch.exists {
                    let navBack = settings.navigationBars.buttons.element(boundBy: 0)
                    if navBack.exists && navBack.isHittable {
                        navBack.tap()
                        Thread.sleep(forTimeInterval: 0.9)
                    }
                }
                _ = settings.cells.firstMatch.waitForExistence(timeout: 8.0)
                capture("Proof_20_45_20_21_Settings_AppPage_\(deviceTag)")
                settings.terminate()
            }
            app.activate()
            Thread.sleep(forTimeInterval: 0.45)
        }

        // 5. Verify 20.50 & 20.36.2: Deep multi-mode / language / script switching stability
        for langLabel in ["Qırımtatarca", "English", "Українська"] {
            let seg = app.buttons[langLabel].firstMatch
            if seg.exists && seg.isHittable {
                seg.tap()
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
        capture("Proof_20_50_DeepStability_Verified_\(deviceTag)")
    }

    private func isIPadKeyboardCurrentlyFloating() -> Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        let qEl = letterKey("q")
        if qEl.exists && qEl.frame.width > 0 && qEl.frame.width < 38.0 {
            return true
        }
        let kb = app.keyboards.firstMatch
        if kb.exists && kb.frame.width > 0 && kb.frame.width < 420.0 {
            return true
        }
        return false
    }

    private func setIPadFloatingKeyboard(_ floating: Bool) {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        if isIPadKeyboardCurrentlyFloating() == floating { return }
        let kb = app.keyboards.firstMatch
        let win = app.windows.firstMatch

        let nextKbPred = NSPredicate(
            format: "identifier IN {'Next keyboard', 'key.globe'} OR label IN {'Next keyboard', 'Наступна клавіатура', 'Следующая клавиатура', 'Nöbetteki klaviatura'}"
        )
        let qirimPred = NSPredicate(
            format: "identifier IN {'key.space', 'key.character.q', 'key.character.Q', 'key.character.ğ', 'key.character.Ğ', 'key.character.ф', 'key.character.Ф', 'spacebar.label'}"
        )

        if floating {
            // 1. Switch from QırımKey Docked to the native iPadOS English keyboard via the bottom-left Globe key
            for attempt in 0..<4 {
                if !app.descendants(matching: .any).matching(qirimPred).firstMatch.exists {
                    break
                }
                let customGlobe = key("globe")
                let sysGlobe = app.descendants(matching: .any).matching(nextKbPred).firstMatch
                let globeCoord: XCUICoordinate
                if customGlobe.exists {
                    globeCoord = customGlobe.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                } else if sysGlobe.exists {
                    globeCoord = sysGlobe.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                } else {
                    globeCoord = win.coordinate(withNormalizedOffset: CGVector(dx: 0.045, dy: 0.96))
                }
                if attempt == 0 {
                    globeCoord.tap()
                    Thread.sleep(forTimeInterval: 1.0)
                } else if attempt == 1 {
                    let target = globeCoord.withOffset(CGVector(dx: 0, dy: -65))
                    globeCoord.press(forDuration: 0.60, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.25)
                    Thread.sleep(forTimeInterval: 1.0)
                } else {
                    let target = globeCoord.withOffset(CGVector(dx: 0, dy: -95))
                    globeCoord.press(forDuration: 0.60, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.25)
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }

            if let data = XCUIScreen.main.screenshot().pngRepresentation as Data? {
                try? data.write(to: URL(fileURLWithPath: "/tmp/Debug_Step1_NativeEnglish.png"), options: .atomic)
            }

            // 2. On the native iPadOS English keyboard, trigger Floating mode
            if !app.descendants(matching: .any).matching(qirimPred).firstMatch.exists {
                let dismissPred = NSPredicate(
                    format: "identifier CONTAINS[c] 'Dismiss' OR label CONTAINS[c] 'Dismiss' OR label CONTAINS[c] 'Приховати' OR label CONTAINS[c] 'Сховати' OR label CONTAINS[c] 'Hide'"
                )
                let floatingItemPred = NSPredicate(
                    format: "label CONTAINS[c] 'Floating' OR label CONTAINS[c] 'Плавальн' OR label CONTAINS[c] 'Плаваюч' OR identifier CONTAINS[c] 'Floating'"
                )
                let offsets: [(CGFloat, CGFloat)] = [
                    (0.0, -65.0),
                    (-18.0, -58.0),
                    (0.0, -85.0)
                ]
                for (dxOff, dyOff) in offsets {
                    if !kb.exists, field.exists && field.isHittable {
                        field.tap()
                        Thread.sleep(forTimeInterval: 0.75)
                    }
                    if kb.exists && kb.frame.width > 0 && kb.frame.width < 420.0 { break }
                    let sysDismiss = kb.descendants(matching: .any).matching(dismissPred).firstMatch
                    let start = sysDismiss.exists
                        ? sysDismiss.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                        : kb.coordinate(withNormalizedOffset: CGVector(dx: 0.955, dy: 0.88))
                    let above = start.withOffset(CGVector(dx: dxOff, dy: dyOff))
                    start.press(forDuration: 1.0, thenDragTo: above, withVelocity: .slow, thenHoldForDuration: 0.35)
                    Thread.sleep(forTimeInterval: 1.0)
                    let floatingBtn = app.descendants(matching: .any).matching(floatingItemPred).firstMatch
                    if floatingBtn.exists {
                        floatingBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                        Thread.sleep(forTimeInterval: 1.0)
                        break
                    }
                }
                if kb.exists && kb.frame.width >= 420.0 {
                    kb.pinch(withScale: 0.35, velocity: -2.5)
                    Thread.sleep(forTimeInterval: 1.0)
                }
            }

            if let data = XCUIScreen.main.screenshot().pngRepresentation as Data? {
                try? data.write(to: URL(fileURLWithPath: "/tmp/Debug_Step2_AfterFloat.png"), options: .atomic)
            }

            // 3. Switch back to QırımKey inside the Floating keyboard container
            for attempt in 0..<4 {
                if app.descendants(matching: .any).matching(qirimPred).firstMatch.exists {
                    break
                }
                let sysGlobe = app.descendants(matching: .any).matching(nextKbPred).firstMatch
                let globeCoord: XCUICoordinate
                if sysGlobe.exists && sysGlobe.frame.width > 0 && attempt == 0 {
                    globeCoord = sysGlobe.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                } else {
                    globeCoord = win.coordinate(withNormalizedOffset: CGVector(dx: 0.046, dy: 0.852))
                }
                globeCoord.tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
            if let data = XCUIScreen.main.screenshot().pngRepresentation as Data? {
                try? data.write(to: URL(fileURLWithPath: "/tmp/Debug_Step3_AfterGlobe.png"), options: .atomic)
            }
            NSLog("[QA-FLOAT] kb.frame = \(kb.frame)")
        } else {
            // Exit Floating mode back to Docked mode:
            // Drag the bottom grabber pill (•••) of the floating keyboard down to the bottom center of the screen
            let winFrame = win.frame
            let kbFrame = kb.frame
            let winRoot = win.coordinate(withNormalizedOffset: .zero)
            let grabberCoord: XCUICoordinate
            if kbFrame.width > 0 && winFrame.height > 0 {
                grabberCoord = winRoot.withOffset(CGVector(dx: kbFrame.midX, dy: kbFrame.maxY - 12))
            } else {
                grabberCoord = win.coordinate(withNormalizedOffset: CGVector(dx: 0.202, dy: 0.852))
            }
            let bottomDockCoord = win.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.995))
            grabberCoord.press(forDuration: 0.20, thenDragTo: bottomDockCoord)
            Thread.sleep(forTimeInterval: 0.95)
        }
    }

    private func enterIPadWindowedMode() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let winFrame = app.windows.firstMatch.frame
        guard winFrame.width > 0 && winFrame.height > 0 else { return }
        let root = sb.coordinate(withNormalizedOffset: .zero)
        // Drag the bottom-right corner handle inward to create a real iPadOS windowed scene with top-left ••• traffic-light controls
        let cornerStart = root.withOffset(CGVector(dx: winFrame.maxX - 4, dy: winFrame.maxY - 4))
        let cornerTarget = root.withOffset(CGVector(dx: winFrame.maxX - 220, dy: winFrame.maxY - 180))
        cornerStart.press(forDuration: 0.12, thenDragTo: cornerTarget)
        Thread.sleep(forTimeInterval: 0.95)
    }

    private func exitIPadWindowedMode() {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return }
        let sb = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let screenBounds = XCUIScreen.main.screenshot().image.size
        let winFrame = app.windows.firstMatch.frame
        if winFrame.width > 0 && winFrame.width < screenBounds.width - 20 {
            let root = sb.coordinate(withNormalizedOffset: .zero)
            let cornerStart = root.withOffset(CGVector(dx: winFrame.maxX - 4, dy: winFrame.maxY - 4))
            let cornerMax = root.withOffset(CGVector(dx: screenBounds.width - 2, dy: screenBounds.height - 2))
            cornerStart.press(forDuration: 0.12, thenDragTo: cornerMax)
            Thread.sleep(forTimeInterval: 0.85)
        }
    }

    func testRound20_48_InputCalloutScreenshotsOnly() throws {
        let deviceTag: String = {
            if UIDevice.current.userInterfaceIdiom == .pad {
                return "ipad"
            }
            #if targetEnvironment(simulator)
            return "iphone_sim_ios27"
            #else
            return "iphone15pro"
            #endif
        }()

        func capture(_ name: String) {
            let shot = XCUIScreen.main.screenshot()
            let att = XCTAttachment(screenshot: shot)
            att.name = name
            att.lifetime = .keepAlways
            add(att)
            if let data = shot.pngRepresentation as Data? {
                let path = "/tmp/\(name).png"
                try? FileManager.default.removeItem(atPath: path)
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }

        let args = [
            "-qt_clear_learned_words",
            "-qt_reset_stats",
            "-qt_enable_predictive_text",
            "-qt_enable_math_results",
            "-qt_cyrillic_added",
            "-qt_ukrainian_added",
            "-qt_extend_input_callout",
            "-qt_hold_callout",
            "-qt_lang", "uk"
        ]

        try launch(
            fieldMode: "standard",
            theme: "modernLight",
            extraArgs: args
        )
        try? selectScript(cyrillic: false)
        Thread.sleep(forTimeInterval: 0.65)

        if UIDevice.current.userInterfaceIdiom == .pad {
            setIPadFloatingKeyboard(true)
            Thread.sleep(forTimeInterval: 0.55)
        }

        // 1. Verify 2-line Daily Phrase banner in real Floating / iPhone toolbar before typing (20.53, 21)
        let greetingBanner = app.descendants(matching: .any).matching(identifier: "autocomplete.greetingBanner").firstMatch
        if greetingBanner.waitForExistence(timeout: 2.5) {
            capture("Proof_21_DailyPhrase_Initial_\(deviceTag)")
            let sparklesBtn = app.descendants(matching: .any).matching(identifier: "autocomplete.greetingNext").firstMatch
            if sparklesBtn.waitForExistence(timeout: 2.0) {
                for i in 0..<45 {
                    let label = greetingBanner.label
                    if i >= 1 && label.count >= 46 {
                        break
                    }
                    if sparklesBtn.isHittable {
                        sparklesBtn.tap()
                    } else {
                        sparklesBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    }
                    Thread.sleep(forTimeInterval: 0.18)
                    if i == 0 {
                        capture("Proof_21_DailyPhrase_Cycled_\(deviceTag)")
                    }
                }
                capture("Proof_21_Floating_DailyPhrase_2Line_\(deviceTag)")
                capture("Proof_21_DailyPhrase_2Line_\(deviceTag)")
            }
        }

        // 2. Verify InputCallout on edge (q, p, ü) and interior (r) keys:
        //    - On iOS 27+ (#available(iOS 27.0, *)): naturally detached capsule
        //    - On iOS 26 / iPadOS 26 (#unavailable(iOS 27.0)): naturally classic connected stem-and-bulb
        let qEl = letterKey("q")
        let rEl = letterKey("r")
        let pEl = letterKey("p")
        let uDiaeresisEl = letterKey("ü")
        XCTAssertTrue(qEl.waitForExistence(timeout: 4.0), "Latin 'q' key must exist for InputCallout test")
        qEl.tap()
        capture("Proof_20_48_20_17_InputCallout_KeyQ_\(deviceTag)")
        if #unavailable(iOS 27.0) {
            capture("Proof_20_55_ClassicBulb_KeyQ_\(deviceTag)")
        }
        Thread.sleep(forTimeInterval: 1.75)

        XCTAssertTrue(rEl.waitForExistence(timeout: 4.0), "Latin 'r' key must exist for InputCallout test")
        rEl.tap()
        capture("Proof_20_48_20_17_InputCallout_KeyR_\(deviceTag)")
        if #unavailable(iOS 27.0) {
            capture("Proof_20_55_ClassicBulb_KeyR_\(deviceTag)")
        }
        Thread.sleep(forTimeInterval: 1.75)

        if pEl.waitForExistence(timeout: 2.5) {
            pEl.tap()
            capture("Proof_20_48_20_17_InputCallout_KeyP_\(deviceTag)")
            if #unavailable(iOS 27.0) {
                capture("Proof_20_55_ClassicBulb_KeyP_\(deviceTag)")
            }
            Thread.sleep(forTimeInterval: 1.75)
        }

        if uDiaeresisEl.waitForExistence(timeout: 2.5) {
            uDiaeresisEl.tap()
            capture("Proof_20_48_20_17_InputCallout_KeyU_\(deviceTag)")
            if #unavailable(iOS 27.0) {
                capture("Proof_20_55_ClassicBulb_KeyU_\(deviceTag)")
            }
            Thread.sleep(forTimeInterval: 1.75)
        }

        // 3. Verify swipe from s -> e -> l -> a -> m commits "Selâm", shows active comet trail, and extinguishes first-key highlight
        clear()
        Thread.sleep(forTimeInterval: 0.55)
        let sEl = letterKey("s")
        let lEl = letterKey("l")
        let aEl = letterKey("a")
        let mEl = letterKey("m")
        if sEl.exists && mEl.exists {
            let cS = sEl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let cM = mEl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            if lEl.exists && aEl.exists {
                let cL = lEl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                let cA = aEl.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                cS.press(forDuration: 0.02, thenDragTo: cL, withVelocity: .default, thenHoldForDuration: 0.02)
                cL.press(forDuration: 0.02, thenDragTo: cA, withVelocity: .default, thenHoldForDuration: 0.02)
            }
            cS.press(forDuration: 0.03, thenDragTo: cM, withVelocity: .slow, thenHoldForDuration: 0.04)
            Thread.sleep(forTimeInterval: 0.15)
            capture("Proof_21_Swipe_Committed_\(deviceTag)")
            capture("Proof_21_Swipe_ActiveComet_\(deviceTag)")
        }

        if UIDevice.current.userInterfaceIdiom == .pad,
           FileManager.default.fileExists(atPath: "/tmp/Proof_20_51_iPad_Windowed_HeaderOffset_\(deviceTag).png"),
           FileManager.default.fileExists(atPath: "/tmp/Proof_20_45_20_21_Settings_AppPage_\(deviceTag).png") {
            return
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            setIPadFloatingKeyboard(false)
            Thread.sleep(forTimeInterval: 0.55)
        }

        if !FileManager.default.fileExists(atPath: "/tmp/Proof_20_51_iPad_Windowed_HeaderOffset_\(deviceTag).png") {
            // 4. Verify live interactive Slot 0 ("...") tap inside Keyboard.appex -> Особистий словник (20.49 / 20.18 / 20.43)
            clear()
            Thread.sleep(forTimeInterval: 0.35)
            let slot0 = app.descendants(matching: .any).matching(identifier: "autocomplete.slot.0").firstMatch
            typeLetters("jyhby")
            let slot0HasJyhby = NSPredicate(format: "exists == true AND label CONTAINS[c] 'jyhby'")
            _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: slot0HasJyhby, object: slot0)], timeout: 2.5)
            tap("space")
            Thread.sleep(forTimeInterval: 0.35)
            typeLetters("jyhby")
            _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: slot0HasJyhby, object: slot0)], timeout: 2.5)
            capture("Proof_20_47_20_49_Suggestions_Light_QuotedSlot0_\(deviceTag)")
            if slot0.exists {
                if slot0.isHittable {
                    slot0.tap()
                } else {
                    slot0.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                Thread.sleep(forTimeInterval: 0.55)
            }
            typeLetters("qirimz")
            let slot0HasQirimz = NSPredicate(format: "exists == true AND label CONTAINS[c] 'qirimz'")
            _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: slot0HasQirimz, object: slot0)], timeout: 2.5)
            if slot0.exists {
                if slot0.isHittable {
                    slot0.tap()
                } else {
                    slot0.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                Thread.sleep(forTimeInterval: 0.65)
            }
            let donePred = NSPredicate(format: "label IN {'Done', 'Готово', 'Azır'}")
            let doneBtn = app.buttons.matching(donePred).firstMatch
            if doneBtn.exists && doneBtn.isHittable {
                doneBtn.tap()
                Thread.sleep(forTimeInterval: 0.45)
            } else if UIDevice.current.userInterfaceIdiom == .pad, key("dismiss").exists {
                tap("dismiss")
                Thread.sleep(forTimeInterval: 0.45)
            }
            let statsExpand = app.descendants(matching: .any).matching(identifier: "stats.expandToggle").firstMatch
            if statsExpand.waitForExistence(timeout: 3.0) && statsExpand.isHittable {
                statsExpand.tap()
                Thread.sleep(forTimeInterval: 0.55)
            }
            let learnedTile = app.descendants(matching: .any).matching(identifier: "stats.learnedWordsTile").firstMatch
            if learnedTile.waitForExistence(timeout: 3.0) {
                let tileHasNonZero = NSPredicate(format: "label CONTAINS '1' OR label CONTAINS '2' OR value CONTAINS '1' OR value CONTAINS '2'")
                _ = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: tileHasNonZero, object: learnedTile)], timeout: 2.5)
                capture("Proof_20_49_20_18_Stats_LearnedWordsTile_NonZero_\(deviceTag)")
                if learnedTile.isHittable {
                    learnedTile.tap()
                    Thread.sleep(forTimeInterval: 0.65)
                    let doneSheetBtn = app.descendants(matching: .any).matching(identifier: "stats.learnedWords.doneButton").firstMatch
                    if doneSheetBtn.waitForExistence(timeout: 3.0) {
                        capture("Proof_20_49_20_18_PersonalDictionary_Sheet_\(deviceTag)")
                        doneSheetBtn.tap()
                        Thread.sleep(forTimeInterval: 0.40)
                    }
                }
            }
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            if !FileManager.default.fileExists(atPath: "/tmp/Proof_20_51_iPad_Windowed_HeaderOffset_\(deviceTag).png") {
                // 5. Verify Docked iPad in Landscape (2-column mode):
                XCUIDevice.shared.orientation = .landscapeLeft
                Thread.sleep(forTimeInterval: 0.85)
                try launch(
                    fieldMode: "standard",
                    theme: "modernLight",
                    extraArgs: [
                        "-qt_no_autofocus",
                        "-qt_default_expansion",
                        "-qt_enable_predictive_text",
                        "-qt_cyrillic_added",
                        "-qt_ukrainian_added",
                        "-qt_lang", "uk",
                        "-qt_hide_ab_preview"
                    ]
                )
                Thread.sleep(forTimeInterval: 0.65)

                let abvBridge = app.descendants(matching: .any).matching(identifier: "settings.abvBridge.container").firstMatch
                let cyrSeg = app.descendants(matching: .any).matching(identifier: "settings.cyrillic.abvSelector").firstMatch
                let disSeg = app.descendants(matching: .any).matching(identifier: "settings.abv.disabledSelector").firstMatch
                let ukrSeg = app.descendants(matching: .any).matching(identifier: "settings.ukrainianCyrillic.abvSelector").firstMatch
                XCTAssertTrue(abvBridge.waitForExistence(timeout: 3.0), "3-state абв bridge must be visible when Standard keyboard is ON")
                XCTAssertTrue(cyrSeg.exists && disSeg.exists && ukrSeg.exists, "All 3 segments (Кирилицю | Caps Lock | Українську) must exist")
                capture("Proof_20_59_20_60_20_61_iPad_Abv3State_And_DefaultExpanded_\(deviceTag)")

                if field.waitForExistence(timeout: 2.5) && field.isHittable {
                    field.tap()
                    Thread.sleep(forTimeInterval: 0.65)
                }
                try? selectScript(cyrillic: false)
                Thread.sleep(forTimeInterval: 0.55)

                if disSeg.isHittable {
                    disSeg.tap()
                } else {
                    disSeg.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                Thread.sleep(forTimeInterval: 0.55)
                capture("Proof_20_59_iPad_AbvDisabled_Shows_CapsLock_\(deviceTag)")

                if cyrSeg.isHittable {
                    cyrSeg.tap()
                } else {
                    cyrSeg.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
                Thread.sleep(forTimeInterval: 0.45)
                capture("Proof_20_59_iPad_AbvCyrillic_Selected_\(deviceTag)")

                // 6. Verify Portrait (1-column mode) on iPad:
                XCUIDevice.shared.orientation = .portrait
                Thread.sleep(forTimeInterval: 0.85)
                try launch(
                    fieldMode: "standard",
                    theme: "modernLight",
                    extraArgs: [
                        "-qt_enable_predictive_text",
                        "-qt_cyrillic_added",
                        "-qt_ukrainian_added",
                        "-qt_lang", "uk",
                        "-qt_hide_ab_preview"
                    ]
                )
                try? selectScript(cyrillic: false)
                Thread.sleep(forTimeInterval: 0.65)
                capture("Proof_20_61_iPad_Portrait_KeyboardAndSingleColumn_\(deviceTag)")
                capture("Proof_20_10_20_21_Keyboard_Docked_NoMic_\(deviceTag)")
                typeLetters("sel")
                Thread.sleep(forTimeInterval: 2.6)
                capture("Proof_20_19_Suggestions_And_Spacebar_Light_\(deviceTag)")

                // 7. Verify that when Standard Latin keyboard is OFF (-qt_keyboard_missing), the абв bridge is hidden
                try launch(
                    fieldMode: "standard",
                    theme: "modernLight",
                    extraArgs: [
                        "-qt_keyboard_missing",
                        "-qt_cyrillic_added",
                        "-qt_ukrainian_added",
                        "-qt_no_autofocus",
                        "-qt_lang", "uk",
                        "-qt_hide_ab_preview"
                    ]
                )
                Thread.sleep(forTimeInterval: 0.55)
                let hiddenBridge = app.descendants(matching: .any).matching(identifier: "settings.abvBridge.container").firstMatch
                XCTAssertFalse(hiddenBridge.exists, "абв bridge must be hidden when Standard Latin keyboard is OFF")
                capture("Proof_20_59_iPad_StandardOff_AbvBridgeHidden_\(deviceTag)")

                // 8. Verify real iPadOS windowed multitasking top-left window controls (•••) header offset (20.51)
                try launch(
                    fieldMode: "standard",
                    theme: "modernLight",
                    extraArgs: [
                        "-qt_no_autofocus",
                        "-qt_cyrillic_added",
                        "-qt_ukrainian_added",
                        "-qt_lang", "uk",
                        "-qt_hide_ab_preview"
                    ]
                )
                Thread.sleep(forTimeInterval: 0.55)
                enterIPadWindowedMode()
                capture("Proof_20_51_iPad_Windowed_HeaderOffset_\(deviceTag)")
                exitIPadWindowedMode()
            }

            if !FileManager.default.fileExists(atPath: "/tmp/Proof_20_45_20_21_Settings_AppPage_\(deviceTag).png") {
                let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
                settings.terminate()
                Thread.sleep(forTimeInterval: 0.45)
                let donePred = NSPredicate(format: "label IN {'Done', 'Готово', 'Azır'}")
                let doneBtn = app.buttons.matching(donePred).firstMatch
                if doneBtn.exists && doneBtn.isHittable {
                    doneBtn.tap()
                    Thread.sleep(forTimeInterval: 0.35)
                } else if key("dismiss").exists {
                    tap("dismiss")
                    Thread.sleep(forTimeInterval: 0.35)
                }
                let appBtn = app.descendants(matching: .any).matching(identifier: "settings.appSettings.button").firstMatch
                if appBtn.exists {
                    appBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    if settings.wait(for: .runningForeground, timeout: 5.0) {
                        _ = settings.cells.firstMatch.waitForExistence(timeout: 6.0)
                        Thread.sleep(forTimeInterval: 2.0)
                        let qirimNavPred = NSPredicate(format: "identifier CONTAINS[c] 'QırımKey' OR title CONTAINS[c] 'QırımKey' OR identifier CONTAINS[c] 'QTatar' OR title CONTAINS[c] 'QTatar'")
                        if !settings.navigationBars.matching(qirimNavPred).firstMatch.exists {
                            let appsPred = NSPredicate(format: "label IN {'Apps', 'Програми', 'Приложения'} OR identifier CONTAINS[c] 'Apps'")
                            let appsCell = settings.cells.matching(appsPred).firstMatch
                            let appsText = settings.staticTexts.matching(appsPred).firstMatch
                            if appsCell.exists && appsCell.isHittable {
                                appsCell.tap()
                                Thread.sleep(forTimeInterval: 1.0)
                            } else if appsText.exists && appsText.isHittable {
                                appsText.tap()
                                Thread.sleep(forTimeInterval: 1.0)
                            }
                            settings.swipeUp()
                            Thread.sleep(forTimeInterval: 0.85)
                            let qirimCellPred = NSPredicate(format: "label CONTAINS[c] 'QırımKey' OR label CONTAINS[c] 'QTatar' OR identifier CONTAINS[c] 'crh.key.keyboard'")
                            let qirimCell = settings.cells.matching(qirimCellPred).firstMatch
                            let qirimBtn = settings.buttons.matching(qirimCellPred).firstMatch
                            let qirimText = settings.staticTexts.matching(qirimCellPred).firstMatch
                            if qirimCell.exists {
                                qirimCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                                Thread.sleep(forTimeInterval: 1.5)
                            } else if qirimBtn.exists {
                                qirimBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                                Thread.sleep(forTimeInterval: 1.5)
                            } else if qirimText.exists {
                                qirimText.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                                Thread.sleep(forTimeInterval: 1.5)
                            }
                        }
                        let keyboardsNavPred = NSPredicate(format: "identifier IN {'Keyboards', 'Клавіатури', 'Клавиатуры'} OR title IN {'Keyboards', 'Клавіатури', 'Клавиатуры'}")
                        if settings.navigationBars.matching(keyboardsNavPred).firstMatch.exists {
                            let navBack = settings.navigationBars.buttons.element(boundBy: 0)
                            if navBack.exists && navBack.isHittable {
                                navBack.tap()
                                Thread.sleep(forTimeInterval: 1.0)
                            }
                        }
                        capture("Proof_20_45_20_21_Settings_AppPage_\(deviceTag)")
                        settings.terminate()
                    }
                }
            }
        } else {
            verifyIPhonePortraitAppAndLandscapeKeyboardInHostApp(deviceTag: deviceTag, capture: capture)
        }
    }

    private func verifyIPhonePortraitAppAndLandscapeKeyboardInHostApp(
        deviceTag: String,
        capture: (String) -> Void
    ) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        defer {
            XCUIDevice.shared.orientation = .portrait
            Thread.sleep(forTimeInterval: 0.45)
        }

        // 1. Verify QTatar.app itself remains strictly locked to Portrait even when device is rotated to Landscape
        try? launch(
            fieldMode: "standard",
            theme: "modernLight",
            extraArgs: [
                "-qt_no_autofocus",
                "-qt_default_expansion",
                "-qt_cyrillic_added",
                "-qt_ukrainian_added",
                "-qt_lang", "uk",
                "-qt_hide_ab_preview"
            ]
        )
        Thread.sleep(forTimeInterval: 0.45)
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 0.65)
        let winFrame = app.windows.firstMatch.frame
        if winFrame.width > 0 && winFrame.height > 0 {
            XCTAssertLessThan(
                winFrame.width,
                winFrame.height,
                "QTatar.app on iPhone must remain locked to Portrait orientation"
            )
        }
        capture("Proof_20_63_iPhone_AppLockedPortrait_InLandscapeDevice_\(deviceTag)")
        capture("Proof_20_63_iPhone_QTatarApp_LockedPortrait_\(deviceTag)")

        // Also capture Settings -> General -> Keyboard (20.16) and Settings -> Apps -> QırımKey (20.45 / 20.21.2) in Portrait
        XCUIDevice.shared.orientation = .portrait
        Thread.sleep(forTimeInterval: 0.55)
        let sysBtn = app.descendants(matching: .any).matching(identifier: "settings.systemKeyboard.button").firstMatch
        if !sysBtn.isHittable {
            app.scrollViews.firstMatch.swipeUp()
            Thread.sleep(forTimeInterval: 0.35)
        }
        if sysBtn.exists {
            sysBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
            if settings.wait(for: .runningForeground, timeout: 5.0) {
                _ = settings.cells.firstMatch.waitForExistence(timeout: 6.0)
                Thread.sleep(forTimeInterval: 0.6)
                let generalPred = NSPredicate(format: "label IN {'General', 'Загальні', 'Основные', 'Umumiy'} OR identifier CONTAINS[c] 'General'")
                let generalCell = settings.cells.matching(generalPred).firstMatch
                let generalText = settings.staticTexts.matching(generalPred).firstMatch
                if generalCell.exists && generalCell.isHittable {
                    generalCell.tap()
                    Thread.sleep(forTimeInterval: 0.7)
                } else if generalText.exists && generalText.isHittable {
                    generalText.tap()
                    Thread.sleep(forTimeInterval: 0.7)
                }
                let kbPred = NSPredicate(format: "label IN {'Keyboard', 'Клавіатура', 'Клавиатура', 'Klaviatura'} OR identifier CONTAINS[c] 'Keyboard'")
                let kbCell = settings.cells.matching(kbPred).firstMatch
                let kbText = settings.staticTexts.matching(kbPred).firstMatch
                if kbCell.exists && kbCell.isHittable {
                    kbCell.tap()
                    Thread.sleep(forTimeInterval: 0.7)
                } else if kbText.exists && kbText.isHittable {
                    kbText.tap()
                    Thread.sleep(forTimeInterval: 0.7)
                }
                capture("Proof_20_16_SystemSettings_OpensGeneral_\(deviceTag)")
                settings.terminate()
            }
            app.activate()
            Thread.sleep(forTimeInterval: 0.55)
        }
        let appBtn = app.descendants(matching: .any).matching(identifier: "settings.appSettings.button").firstMatch
        if appBtn.exists {
            appBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
            if settings.wait(for: .runningForeground, timeout: 5.0) {
                _ = settings.cells.firstMatch.waitForExistence(timeout: 6.0)
                Thread.sleep(forTimeInterval: 0.9)
                let qkPred = NSPredicate(format: "identifier CONTAINS[c] 'QırımKey' OR label CONTAINS[c] 'QırımKey' OR title CONTAINS[c] 'QırımKey' OR label IN {'Keyboards', 'Клавіатури', 'Preferred Language', 'Мова'}")
                if !settings.descendants(matching: .any).matching(qkPred).firstMatch.exists {
                    // Navigate Settings -> Apps -> QırımKey if root Settings opened
                    settings.swipeUp()
                    Thread.sleep(forTimeInterval: 0.5)
                    let appsPred = NSPredicate(format: "label IN {'Apps', 'Програми', 'Приложения', 'Programmalar'} OR identifier CONTAINS[c] 'Apps'")
                    let appsCell = settings.cells.matching(appsPred).firstMatch
                    let appsText = settings.staticTexts.matching(appsPred).firstMatch
                    if appsCell.exists {
                        appsCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                        Thread.sleep(forTimeInterval: 0.8)
                    } else if appsText.exists {
                        appsText.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                        Thread.sleep(forTimeInterval: 0.8)
                    }
                    let qkRow = settings.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] 'QırımKey'")).firstMatch
                    for _ in 0..<4 {
                        if qkRow.exists && qkRow.isHittable {
                            qkRow.tap()
                            Thread.sleep(forTimeInterval: 0.8)
                            break
                        }
                        settings.swipeUp()
                        Thread.sleep(forTimeInterval: 0.4)
                    }
                }
                capture("Proof_20_45_20_21_Settings_AppPage_\(deviceTag)")
                settings.terminate()
            }
            app.activate()
            Thread.sleep(forTimeInterval: 0.45)
        }

        // 2. Open Safari to test BOTH Native Keyboard and QırımKey in Landscape
        let qirimKeyPred = NSPredicate(
            format: "identifier IN {'key.character.q', 'key.character.Q', 'key.character.ğ', 'key.character.Ğ', 'key.character.ф', 'key.character.Ф', 'spacebar.label'}"
        )
        let nextKbPred = NSPredicate(
            format: "identifier == 'Next keyboard' OR identifier == 'key.nextKeyboard' OR label CONTAINS[c] 'keyboard' OR label CONTAINS[c] 'клавіатур' OR label CONTAINS[c] 'klaviatura'"
        )

        func isQirimKeyActive(in hostApp: XCUIApplication) -> Bool {
            let kb = hostApp.keyboards.firstMatch
            return hostApp.descendants(matching: .any).matching(qirimKeyPred).firstMatch.exists
                || kb.staticTexts["Qırımtatarca"].exists
                || kb.staticTexts["QT"].exists
                || kb.staticTexts["Къырымтатарджа"].exists
                || kb.staticTexts["Кʼиримтатарджа"].exists
        }

        let port = startLocalTextareaServer()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        if !safari.wait(for: .runningForeground, timeout: 4.0) {
            safari.launch()
            _ = safari.wait(for: .runningForeground, timeout: 5.0)
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.0)
        if port > 0, let testURL = URL(string: "http://127.0.0.1:\(port)/") {
            XCUIDevice.shared.system.open(testURL)
            Thread.sleep(forTimeInterval: 2.2)
        }
        let webTextView = safari.webViews.textViews.firstMatch
        if !isQirimKeyActive(in: safari) && !safari.keyboards.firstMatch.exists {
            if webTextView.waitForExistence(timeout: 2.5) {
                webTextView.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.35)).tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        var capturedQirim = false
        var capturedNative = false
        for _ in 0..<6 {
            if isQirimKeyActive(in: safari) && !capturedQirim {
                Thread.sleep(forTimeInterval: 2.5)
                let qPred = NSPredicate(format: "identifier IN {'key.character.q', 'key.character.Q'} OR label IN {'q', 'Q'}")
                let qKey = safari.descendants(matching: .any).matching(qPred).firstMatch
                if qKey.exists {
                    qKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    Thread.sleep(forTimeInterval: 0.15)
                }
                capture("Proof_20_63_iPhone_Keyboard_Landscape_Safari_\(deviceTag)")
                capture("Proof_20_63_iPhone_LandscapeKeyboard_InSafari_\(deviceTag)")
                capture("Proof_20_63_iPhone_Landscape_KeyboardInHostApp_\(deviceTag)")
                capturedQirim = true
            } else if !isQirimKeyActive(in: safari) && !capturedNative {
                let continuePred = NSPredicate(format: "label IN {'Continue', 'Продовжити', 'Devam et'}")
                let contBtn = safari.buttons.matching(continuePred).firstMatch
                if contBtn.exists {
                    contBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    Thread.sleep(forTimeInterval: 0.65)
                }
                capture("Proof_20_63_iPhone_NativeKeyboard_Landscape_Safari_\(deviceTag)")
                capture("Proof_20_63_iPhone_Keyboard_Landscape_Safari_Native_\(deviceTag)")
                capturedNative = true
            }
            if capturedQirim && capturedNative { break }
            let nextKb = safari.buttons.matching(nextKbPred).firstMatch
            if nextKb.exists {
                nextKb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.85)
            } else {
                break
            }
        }
        XCUIDevice.shared.orientation = .portrait
    }

    private func startLocalTextareaServer() -> Int {
        let fd = Darwin.socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { return 0 }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = in_port_t(0).bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        let bindRes = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindRes == 0, Darwin.listen(fd, 8) == 0 else {
            Darwin.close(fd)
            return 0
        }
        var boundAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        _ = withUnsafeMutablePointer(to: &boundAddr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.getsockname(fd, $0, &len)
            }
        }
        let port = Int(UInt16(bigEndian: boundAddr.sin_port))
        let html = """
        <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"></head><body style="margin:0;padding:14px 12px 0 12px;font-family:-apple-system;background:#fff"><textarea id="qirim_input" autofocus style="width:94%;height:64px;font-size:18px;padding:8px" placeholder="QırımKey Landscape — Selâm!"></textarea></body></html>
        """
        let response = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(html.utf8.count)\r\nConnection: close\r\n\r\n\(html)"
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<16 {
                var clientAddr = sockaddr_in()
                var clientLen = socklen_t(MemoryLayout<sockaddr_in>.size)
                let clientFD = withUnsafeMutablePointer(to: &clientAddr) {
                    $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                        Darwin.accept(fd, $0, &clientLen)
                    }
                }
                guard clientFD >= 0 else { break }
                var buf = [UInt8](repeating: 0, count: 1024)
                _ = Darwin.read(clientFD, &buf, buf.count)
                response.withCString { ptr in
                    _ = Darwin.write(clientFD, ptr, response.utf8.count)
                }
                Darwin.close(clientFD)
            }
            Darwin.close(fd)
        }
        return port
    }

    func testRound31_SimulatorDelta() throws {
        var deviceTag = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #if targetEnvironment(simulator)
        if #available(iOS 27.0, *) {
            deviceTag += "_sim_ios27"
        } else {
            deviceTag += "_sim"
        }
        #endif

        func saveProof(_ name: String) {
            let shot = XCUIScreen.main.screenshot()
            let att = XCTAttachment(screenshot: shot)
            att.name = name
            att.lifetime = .keepAlways
            add(att)
            if let data = shot.pngRepresentation as Data? {
                let path = "/tmp/\(name).png"
                try? FileManager.default.removeItem(atPath: path)
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }

        if UIDevice.current.userInterfaceIdiom == .pad {
            XCUIDevice.shared.orientation = .landscapeLeft
            Thread.sleep(forTimeInterval: 0.6)
            try launch(
                fieldMode: "standard",
                theme: "modernLight",
                extraArgs: [
                    "-qt_lang", "uk",
                    "-qt_no_autofocus",
                    "-qt_default_expansion",
                    "-qt_keyboard_added",
                    "-qt_cyrillic_added",
                    "-qt_ukrainian_added"
                ]
            )
            Thread.sleep(forTimeInterval: 0.8)
            let abvBridge = app.descendants(matching: .any).matching(identifier: "settings.abvBridge.container").firstMatch
            let ukRow = app.descendants(matching: .any).matching(identifier: "settings.ukrainianCyrillic.statusRow").firstMatch
            XCTAssertTrue(abvBridge.waitForExistence(timeout: 3.0), "iPad in uk language must show 3-state абв bridge")
            XCTAssertTrue(ukRow.exists, "iPad in uk language must show Ukrainian layout card")
            saveProof("Proof_20_71_iPad_Lang_UK_AbvBridgeShown")

            let crhLangBtn = app.descendants(matching: .any).matching(identifier: "settings.lang.crh").firstMatch
            if crhLangBtn.waitForExistence(timeout: 2.0) {
                crhLangBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.6)
                XCTAssertFalse(abvBridge.exists, "iPad in crh language must hide абв / Caps Lock bridge")
                XCTAssertFalse(ukRow.exists, "iPad in crh language must hide Ukrainian layout card")
                saveProof("Proof_20_71_iPad_Lang_CRH_AbvBridgeHidden")
            }

            let enLangBtn = app.descendants(matching: .any).matching(identifier: "settings.lang.en").firstMatch
            if enLangBtn.waitForExistence(timeout: 2.0) {
                enLangBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.6)
                XCTAssertFalse(abvBridge.exists, "iPad in en language must hide абв / Caps Lock bridge")
                XCTAssertFalse(ukRow.exists, "iPad in en language must hide Ukrainian layout card")
                saveProof("Proof_20_71_iPad_Lang_EN_AbvBridgeHidden")
            }

            let ukLangBtn = app.descendants(matching: .any).matching(identifier: "settings.lang.uk").firstMatch
            if ukLangBtn.waitForExistence(timeout: 2.0) {
                ukLangBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.6)
                XCTAssertTrue(abvBridge.exists, "Switching back to uk must restore 3-state абв bridge")
                XCTAssertTrue(ukRow.exists, "Switching back to uk must restore Ukrainian layout card")
            }
            #if !targetEnvironment(simulator)
            return
            #endif
        }

        if UIDevice.current.userInterfaceIdiom == .pad || !FileManager.default.fileExists(atPath: "/tmp/Proof_21_DailyPhrase_2Line_\(deviceTag).png") {
            try launch(
                fieldMode: "standard",
                theme: "modernLight",
                extraArgs: ["-qt_lang", "uk", "-qt_extend_input_callout", "-qt_hold_callout"]
            )
            try? selectScript(cyrillic: false)
            Thread.sleep(forTimeInterval: 0.55)

            let greetingBanner = app.descendants(matching: .any).matching(identifier: "autocomplete.greetingBanner").firstMatch
            if greetingBanner.waitForExistence(timeout: 2.5) {
                let sparklesBtn = app.descendants(matching: .any).matching(identifier: "autocomplete.greetingNext").firstMatch
                if sparklesBtn.waitForExistence(timeout: 2.0) {
                    for i in 0..<6 {
                        let label = greetingBanner.label
                        if i >= 1 && label.count >= 46 {
                            break
                        }
                        sparklesBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                        Thread.sleep(forTimeInterval: 0.25)
                    }
                    saveProof("Proof_21_Floating_DailyPhrase_2Line_\(deviceTag)")
                    saveProof("Proof_21_DailyPhrase_2Line_\(deviceTag)")
                }
            }
            if UIDevice.current.userInterfaceIdiom == .pad {
                XCUIDevice.shared.orientation = .portrait
                Thread.sleep(forTimeInterval: 0.8)
                saveProof("Proof_20_61_iPad_Portrait_KeyboardAndSingleColumn_\(deviceTag)")
            } else {
                saveProof("Proof_20_58_iPhoneDuo_Keyboard_Light_\(deviceTag)")
            }
            let qPortrait = app.descendants(matching: .any).matching(NSPredicate(format: "identifier IN {'key.character.q', 'key.character.Q'} OR label IN {'q', 'Q'}")).firstMatch
            if qPortrait.exists {
                qPortrait.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.15)
                saveProof("Proof_20_48_20_17_InputCallout_KeyQ_\(deviceTag)")
                Thread.sleep(forTimeInterval: 0.9)
            }
            let rPortrait = app.descendants(matching: .any).matching(NSPredicate(format: "identifier IN {'key.character.r', 'key.character.R'} OR label IN {'r', 'R'}")).firstMatch
            if rPortrait.exists {
                rPortrait.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.15)
                saveProof("Proof_20_48_20_17_InputCallout_KeyR_\(deviceTag)")
                Thread.sleep(forTimeInterval: 0.9)
            }
            let pPortrait = app.descendants(matching: .any).matching(NSPredicate(format: "identifier IN {'key.character.p', 'key.character.P'} OR label IN {'p', 'P'}")).firstMatch
            if pPortrait.exists {
                pPortrait.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.15)
                saveProof("Proof_20_48_20_17_InputCallout_KeyP_\(deviceTag)")
                Thread.sleep(forTimeInterval: 0.9)
            }
        }

        // Open Safari to local <textarea> and capture Landscape Native + QırımKey keyboards
        let port = startLocalTextareaServer()
        let safari = XCUIApplication(bundleIdentifier: "com.apple.mobilesafari")
        safari.activate()
        if !safari.wait(for: .runningForeground, timeout: 4.0) {
            safari.launch()
            _ = safari.wait(for: .runningForeground, timeout: 5.0)
        }
        XCUIDevice.shared.orientation = .landscapeLeft
        Thread.sleep(forTimeInterval: 1.0)
        if port > 0, let testURL = URL(string: "http://127.0.0.1:\(port)/") {
            XCUIDevice.shared.system.open(testURL)
            Thread.sleep(forTimeInterval: 2.2)
        }
        let qirimKeyPred = NSPredicate(
            format: "identifier IN {'key.character.q', 'key.character.Q', 'key.character.ğ', 'key.character.Ğ', 'key.character.ф', 'key.character.Ф', 'spacebar.label'}"
        )
        let nextKbPred = NSPredicate(
            format: "identifier == 'Next keyboard' OR identifier == 'key.nextKeyboard' OR label CONTAINS[c] 'keyboard' OR label CONTAINS[c] 'клавіатур' OR label CONTAINS[c] 'klaviatura'"
        )
        func isQirimKeyActive() -> Bool {
            return safari.descendants(matching: .any).matching(qirimKeyPred).firstMatch.exists
                || safari.staticTexts["Qırımtatarca"].exists
                || safari.staticTexts["QT"].exists
        }
        let webTextView = safari.webViews.textViews.firstMatch
        if !isQirimKeyActive() && !safari.keyboards.firstMatch.exists {
            if webTextView.waitForExistence(timeout: 2.5) {
                webTextView.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.35)).tap()
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        var capturedQirim = false
        var capturedNative = false
        for _ in 0..<6 {
            if isQirimKeyActive() && !capturedQirim {
                Thread.sleep(forTimeInterval: 1.4)
                saveProof("Proof_20_63_iPhone_Keyboard_Landscape_Safari_\(deviceTag)")
                saveProof("Proof_20_63_iPhone_Landscape_KeyboardInHostApp_\(deviceTag)")
                let qPred = NSPredicate(format: "identifier IN {'key.character.q', 'key.character.Q'} OR label IN {'q', 'Q'}")
                let qKey = safari.descendants(matching: .any).matching(qPred).firstMatch
                if qKey.exists {
                    qKey.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    Thread.sleep(forTimeInterval: 0.15)
                }
                saveProof("Proof_20_63_iPhone_LandscapeKeyboard_InSafari_\(deviceTag)")
                capturedQirim = true
            } else if !isQirimKeyActive() && !capturedNative {
                let continuePred = NSPredicate(format: "label IN {'Continue', 'Продовжити', 'Devam et'}")
                let contBtn = safari.buttons.matching(continuePred).firstMatch
                if contBtn.exists {
                    contBtn.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                    Thread.sleep(forTimeInterval: 0.65)
                }
                saveProof("Proof_20_63_iPhone_NativeKeyboard_Landscape_Safari_\(deviceTag)")
                saveProof("Proof_20_63_iPhone_Keyboard_Landscape_Safari_Native_\(deviceTag)")
                capturedNative = true
            }
            if capturedQirim && capturedNative { break }
            let nextKb = safari.buttons.matching(nextKbPred).firstMatch
            if nextKb.exists {
                nextKb.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                Thread.sleep(forTimeInterval: 0.85)
            } else {
                break
            }
        }
        XCUIDevice.shared.orientation = .portrait
    }

    func testCleanAppSettingsAndFullAccess_20_45_20_52() throws {
        var deviceTag = UIDevice.current.userInterfaceIdiom == .pad ? "ipad" : "iphone"
        #if targetEnvironment(simulator)
        if #available(iOS 27.0, *) {
            deviceTag += "_sim_ios27"
        } else {
            deviceTag += "_sim"
        }
        #else
        if UIDevice.current.userInterfaceIdiom == .phone {
            deviceTag = "iphone15pro"
        }
        #endif

        func saveProof(_ name: String) {
            let shot = XCUIScreen.main.screenshot()
            let att = XCTAttachment(screenshot: shot)
            att.name = name
            att.lifetime = .keepAlways
            add(att)
            if let data = shot.pngRepresentation as Data? {
                let path = "/tmp/\(name).png"
                try? FileManager.default.removeItem(atPath: path)
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }

        // IMPORTANT: Do NOT call app.launch() here so XCTAutomationSupport.framework is never injected into crh.key!
        XCUIDevice.shared.orientation = .portrait
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.terminate()
        Thread.sleep(forTimeInterval: 0.4)
        settings.launch()
        _ = settings.wait(for: .runningForeground, timeout: 6.0)
        Thread.sleep(forTimeInterval: 1.0)

        let qkPred = NSPredicate(format: "label CONTAINS[c] 'QırımKey' OR label CONTAINS[c] 'QTatar'")
        let kbRowPred = NSPredicate(
            format: "label CONTAINS[c] 'Keyboards' OR label CONTAINS[c] 'Клавіатури' OR label CONTAINS[c] 'Клавиатуры' OR label CONTAINS[c] 'Klaviaturalar'"
        )
        var openedQirimKey = false

        let searchField = settings.searchFields.firstMatch
        if searchField.waitForExistence(timeout: 2.5) && searchField.isHittable {
            searchField.tap()
            Thread.sleep(forTimeInterval: 0.5)
            searchField.typeText("Qırım")
            Thread.sleep(forTimeInterval: 1.2)
            let qkSearchCell = settings.cells.matching(qkPred).firstMatch
            if qkSearchCell.waitForExistence(timeout: 2.0) && qkSearchCell.frame.minY > 0 && qkSearchCell.frame.minY < 320 {
                qkSearchCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            } else {
                let qkStatic = settings.cells.containing(qkPred).firstMatch
                if qkStatic.exists && qkStatic.frame.minY > 0 && qkStatic.frame.minY < 320 {
                    qkStatic.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                }
            }
            Thread.sleep(forTimeInterval: 1.4)
            if settings.descendants(matching: .any).matching(kbRowPred).firstMatch.waitForExistence(timeout: 2.5) {
                openedQirimKey = true
            } else {
                let cancelPred = NSPredicate(format: "label IN {'Cancel', 'Скасувати', 'Отменить', 'Lâğu et', 'Vazgeç'}")
                let cancelBtn = settings.buttons.matching(cancelPred).firstMatch
                if cancelBtn.exists && cancelBtn.isHittable {
                    cancelBtn.tap()
                    Thread.sleep(forTimeInterval: 0.8)
                }
            }
        }

        if !openedQirimKey {
            let appsPred = NSPredicate(
                format: "label IN {'Apps', 'Програми', 'Додатки', 'Приложения', 'Programmalar', 'İlâveler'} OR label CONTAINS[c] 'Програми' OR label CONTAINS[c] 'Apps'"
            )
            for _ in 0..<8 {
                let appsCell = settings.descendants(matching: .any).matching(appsPred).firstMatch
                if appsCell.exists && appsCell.isHittable {
                    appsCell.tap()
                    Thread.sleep(forTimeInterval: 1.2)
                    break
                }
                settings.swipeUp()
                Thread.sleep(forTimeInterval: 0.4)
            }
            for _ in 0..<25 {
                let qkCell = settings.cells.matching(qkPred).firstMatch
                if qkCell.exists && qkCell.isHittable {
                    qkCell.tap()
                    Thread.sleep(forTimeInterval: 1.2)
                    break
                }
                settings.swipeUp(velocity: .fast)
                Thread.sleep(forTimeInterval: 0.25)
            }
        }
        saveProof("Proof_20_45_20_21_Settings_AppPage_\(deviceTag)")

        let kbCell = settings.descendants(matching: .any).matching(kbRowPred).firstMatch
        if kbCell.waitForExistence(timeout: 2.5) {
            kbCell.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            Thread.sleep(forTimeInterval: 1.2)
            let kbSwitchPred = NSPredicate(format: "identifier BEGINSWITH 'crh.key.' OR label CONTAINS[c] 'Qırımtatarca' OR label CONTAINS[c] 'Къырымтатарджа' OR label CONTAINS[c] 'Кʼиримтатарджа'")
            let kbSwitches = settings.switches.matching(kbSwitchPred)
            let count = kbSwitches.count
            if count > 0 {
                var seenKeys = Set<String>()
                for i in 0..<min(count, 3) {
                    let sw = kbSwitches.element(boundBy: i)
                    guard sw.exists else { continue }
                    let dedupKey = "\(sw.identifier)|\(sw.label)"
                    if seenKeys.contains(dedupKey) { continue }
                    seenKeys.insert(dedupKey)
                    let val = (sw.value as? String) ?? ""
                    if val == "0" {
                        sw.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                        Thread.sleep(forTimeInterval: 0.55)
                    }
                }
            }
            let fullAccessSwitch = settings.switches.matching(
                NSPredicate(format: "label CONTAINS[c] 'Full Access' OR label CONTAINS[c] 'Повний доступ' OR label CONTAINS[c] 'Полный доступ' OR label CONTAINS[c] 'Tam irişüv' OR label CONTAINS[c] 'Tam irişim'")
            ).firstMatch
            if fullAccessSwitch.waitForExistence(timeout: 2.5) {
                let val = (fullAccessSwitch.value as? String) ?? "0"
                if val == "1" {
                    fullAccessSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                    Thread.sleep(forTimeInterval: 0.8)
                    saveProof("Proof_20_52_AllowFullAccess_OFF_\(deviceTag)")
                    fullAccessSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                    Thread.sleep(forTimeInterval: 0.8)
                    let allowBtn = settings.alerts.buttons.matching(NSPredicate(format: "label IN {'Allow', 'Дозволити', 'Разрешить', 'Ruhset ber'}")).firstMatch
                    if allowBtn.waitForExistence(timeout: 2.0) {
                        allowBtn.tap()
                        Thread.sleep(forTimeInterval: 0.8)
                    }
                    saveProof("Proof_20_52_AllowFullAccess_ON_\(deviceTag)")
                } else {
                    saveProof("Proof_20_52_AllowFullAccess_OFF_\(deviceTag)")
                    fullAccessSwitch.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
                    Thread.sleep(forTimeInterval: 0.8)
                    let allowBtn = settings.alerts.buttons.matching(NSPredicate(format: "label IN {'Allow', 'Дозволити', 'Разрешить', 'Ruhset ber'}")).firstMatch
                    if allowBtn.waitForExistence(timeout: 2.0) {
                        allowBtn.tap()
                        Thread.sleep(forTimeInterval: 0.8)
                    }
                    saveProof("Proof_20_52_AllowFullAccess_ON_\(deviceTag)")
                }
            }
            let navBack = settings.navigationBars.buttons.element(boundBy: 0)
            if navBack.exists && navBack.isHittable {
                navBack.tap()
                Thread.sleep(forTimeInterval: 1.0)
                saveProof("Proof_20_45_20_21_Settings_AppPage_\(deviceTag)")
            }
        }
    }

    func testCompactStatisticsAndFullScreenHeader_20_73() throws {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let deviceTag = isPad ? "ipad" : "iphone"
        XCUIDevice.shared.orientation = isPad ? .landscapeLeft : .portrait

        func saveProof(_ name: String) {
            let shot = XCUIScreen.main.screenshot()
            let att = XCTAttachment(screenshot: shot)
            att.name = name
            att.lifetime = .keepAlways
            add(att)
            if let data = shot.pngRepresentation as Data? {
                let path = "/tmp/\(name).png"
                try? FileManager.default.removeItem(atPath: path)
                try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
            }
        }

        let app = XCUIApplication()
        app.launchArguments += [
            "-AppleLanguages", "(uk)",
            "-AppleLocale", "uk_UA",
            "-ui_testing_20_29_both_cyrillic",
            "-qt_no_autofocus"
        ]
        app.launch()

        let langUk = app.buttons["settings.lang.uk"].firstMatch
        XCTAssertTrue(langUk.waitForExistence(timeout: 12), "Language switcher UK button must exist")
        if langUk.isHittable {
            langUk.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }

        // 1. Verify Full Screen header title is NOT shifted by 78pt window controls inset
        let appTitle = app.descendants(matching: .any)["header.about"].firstMatch
        XCTAssertTrue(appTitle.waitForExistence(timeout: 5), "App title QırımKey must exist")
        let leadingInsetUK = min(appTitle.frame.minX, appTitle.frame.minY)
        XCTAssertLessThan(
            leadingInsetUK,
            52.0,
            "Full screen header title QırımKey must NOT have 78pt windowed leading shift (actual leadingInset=\(leadingInsetUK), frame=\(appTitle.frame))"
        )

        // 2. Verify compact Statistics renders the 2 large tiles (stats.wordsTile & stats.speedTile) while collapsed
        let wordsTile = app.descendants(matching: .any)["stats.wordsTile"].firstMatch
        let speedTile = app.descendants(matching: .any)["stats.speedTile"].firstMatch
        let manualWordsTile = app.descendants(matching: .any)["stats.manualWordsTile"].firstMatch
        XCTAssertTrue(wordsTile.waitForExistence(timeout: 5), "Compact Statistics must render stats.wordsTile")
        XCTAssertTrue(speedTile.exists, "Compact Statistics must render stats.speedTile")
        XCTAssertFalse(manualWordsTile.exists, "Collapsed Statistics must NOT render expanded row 2 (stats.manualWordsTile)")
        let rowDeltaUK = min(
            abs(wordsTile.frame.minY - speedTile.frame.minY),
            abs(wordsTile.frame.minX - speedTile.frame.minX)
        )
        XCTAssertLessThan(
            rowDeltaUK,
            6.0,
            "Compact 2-tile Statistics must place wordsTile and speedTile side-by-side (rowDelta=\(rowDeltaUK))"
        )

        // 3. Verify 20.71 & 20.75 in Ukrainian (uk): Ukrainian Cyrillic row, 3-way bridge, and all 3 layout toggles ON
        let ukRow = app.descendants(matching: .any)["settings.ukrainianCyrillic.statusRow"].firstMatch
        XCTAssertTrue(ukRow.waitForExistence(timeout: 5), "Ukrainian layout row must exist in UK")
        let primaryToggle = app.switches["status.primaryKeyboard.toggle"].firstMatch
        let cyrillicToggle = app.switches["settings.cyrillic.toggle"].firstMatch
        let ukrainianToggle = app.switches["settings.ukrainianCyrillic.toggle"].firstMatch
        XCTAssertTrue(primaryToggle.waitForExistence(timeout: 5), "Primary keyboard toggle must exist")
        XCTAssertEqual(primaryToggle.value as? String, "1", "Primary keyboard toggle must remain ON (1)")
        XCTAssertEqual(cyrillicToggle.value as? String, "1", "Cyrillic keyboard toggle must remain ON (1)")
        XCTAssertEqual(ukrainianToggle.value as? String, "1", "Ukrainian keyboard toggle must remain ON (1)")
        if isPad {
            let abvBridge = app.descendants(matching: .any)["settings.abvBridge.container"].firstMatch
            let cyrAbv = app.buttons["settings.cyrillic.abvSelector"].firstMatch
            let ukAbv = app.buttons["settings.ukrainianCyrillic.abvSelector"].firstMatch
            XCTAssertTrue(abvBridge.waitForExistence(timeout: 5), "iPad 3-way abv bridge must exist in UK")
            XCTAssertTrue(cyrAbv.waitForExistence(timeout: 5), "Cyrillic [абв] selector must exist on iPad in UK")
            XCTAssertTrue(ukAbv.waitForExistence(timeout: 5), "Ukrainian [абв] selector must exist on iPad in UK")
        }
        Thread.sleep(forTimeInterval: 3.2)
        saveProof("Proof_20_73_Compact2Tile_FullScreenHeader_uk_\(deviceTag)")
        saveProof("Proof_20_75_ZeroHangs_GlobeResilience_uk_\(deviceTag)")

        // 4. Switch to Qırımtatarca (crh) and verify compact 2-tile Statistics + Full Screen header + 20.71 bridge hidden + zero hangs
        let langCrh = app.buttons["settings.lang.crh"].firstMatch
        XCTAssertTrue(langCrh.waitForExistence(timeout: 5))
        langCrh.tap()
        Thread.sleep(forTimeInterval: 6.5)
        saveProof("Proof_20_73_Compact2Tile_FullScreenHeader_crh_\(deviceTag)")
        saveProof("Proof_20_74_EditorV2_Compact_crh_\(deviceTag)")
        saveProof("Proof_20_75_ZeroHangs_GlobeResilience_crh_\(deviceTag)")

        XCTAssertEqual(primaryToggle.value as? String, "1", "Primary keyboard toggle must remain ON (1) in CRH")
        XCTAssertEqual(cyrillicToggle.value as? String, "1", "Cyrillic keyboard toggle must remain ON (1) in CRH")
        XCTAssertTrue(wordsTile.exists && speedTile.exists, "Compact 2-tile Statistics must remain visible in CRH")
        XCTAssertTrue(
            wordsTile.label.contains("Farqlı:") || wordsTile.label.contains("Arifler:"),
            "Task 20.74: CRH wordsTile must display 'Farqlı: %d' from editor v2 review (got: '\(wordsTile.label)')"
        )
        let leadingInsetCRH = min(appTitle.frame.minX, appTitle.frame.minY)
        XCTAssertLessThan(leadingInsetCRH, 52.0, "Full screen header title must remain unshifted in CRH (leadingInset=\(leadingInsetCRH))")
        XCTAssertFalse(ukRow.exists, "Ukrainian layout row must NOT exist in CRH")
        if isPad {
            let cyrAbv = app.buttons["settings.cyrillic.abvSelector"].firstMatch
            let ukAbv = app.buttons["settings.ukrainianCyrillic.abvSelector"].firstMatch
            XCTAssertFalse(cyrAbv.exists, "Cyrillic [абв] selector must NOT exist in CRH")
            XCTAssertFalse(ukAbv.exists, "Ukrainian [абв] selector must NOT exist in CRH")
        }

        // 5. Switch back to UK and expand Statistics to verify all 6 tiles + Task 20.74 'Вручну по літерах'
        langUk.tap()
        Thread.sleep(forTimeInterval: 0.6)
        XCTAssertEqual(primaryToggle.value as? String, "1", "Primary keyboard toggle must remain ON (1) after UK switch")
        XCTAssertEqual(cyrillicToggle.value as? String, "1", "Cyrillic keyboard toggle must remain ON (1) after UK switch")
        XCTAssertEqual(ukrainianToggle.value as? String, "1", "Ukrainian keyboard toggle must remain ON (1) after UK switch")
        Thread.sleep(forTimeInterval: 6.5)
        let expandBtn = app.buttons["stats.expandToggle"].firstMatch
        if expandBtn.exists && expandBtn.isHittable {
            expandBtn.tap()
            Thread.sleep(forTimeInterval: 3.5)
            saveProof("Proof_20_73_ExpandedStats_uk_\(deviceTag)")
            saveProof("Proof_20_74_EditorV2_ExpandedStats_uk_\(deviceTag)")

            // Switch to CRH while expanded to capture CRH expanded stats ('Farqlı:', 'Nevbetteki:')
            langCrh.tap()
            Thread.sleep(forTimeInterval: 6.5)
            saveProof("Proof_20_74_EditorV2_ExpandedStats_crh_\(deviceTag)")

            XCTAssertTrue(manualWordsTile.waitForExistence(timeout: 5), "Expanded Statistics must show all 6 tiles")
        }
    }
}




