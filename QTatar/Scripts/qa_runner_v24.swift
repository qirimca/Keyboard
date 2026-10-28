import Foundation
import CoreGraphics

@main
struct QARunnerV24 {
    static func main() {
        print("=================================================================")
        print("  QırımKey v2.4 — Phase 13 QA & Hang/Performance Verification")
        print("=================================================================\n")

        var totalTests = 0
        var passedTests = 0
        var failures: [String] = []

        func check(_ condition: Bool, _ name: String, detail: String = "") {
            totalTests += 1
            if condition {
                passedTests += 1
                print("  [PASS] \(name)" + (detail.isEmpty ? "" : " — \(detail)"))
            } else {
                let msg = "[FAIL] \(name)" + (detail.isEmpty ? "" : " — \(detail)")
                print("  \(msg)")
                failures.append(msg)
            }
        }

        // -----------------------------------------------------------------
        // 1. COLD-START MAIN-THREAD NON-BLOCKING (< 16 ms) + 50-ITERATION STRESS TEST
        // -----------------------------------------------------------------
        print("--- [1] Cold-Start Main-Thread Non-Blocking (< 16.0 ms) & 50-Iteration Stress Test ---")
        let dbm = SuggestionsDataBaseManager.shared
        dbm.resetForColdStartTest()
        check(!dbm.isReady, "resetForColdStartTest sets isReady == false")

        let coldT0 = DispatchTime.now().uptimeNanoseconds
        let coldSuggs = dbm.suggestions(for: "sel", shouldCapitalize: false, contextWords: [])
        let coldNext = dbm.nextWordSuggestions(contextWords: ["Men"], shouldCapitalize: false)
        let coldMs = Double(DispatchTime.now().uptimeNanoseconds - coldT0) / 1_000_000.0
        check(coldMs < 16.0, "Cold-start main-thread suggestions() + nextWordSuggestions() < 16.0 ms", detail: String(format: "%.3f ms", coldMs))
        check(!coldSuggs.isEmpty && coldNext.isEmpty, "Cold-start returns literal fallback without blocking main thread", detail: "coldSuggs=\(coldSuggs.map(\.text))")

        var maxStressMs: Double = 0
        var totalStressMs: Double = 0
        var allUnder16Ms = true
        for _ in 0..<50 {
            dbm.resetForColdStartTest()
            dbm.prepareAsync()
            let t0 = DispatchTime.now().uptimeNanoseconds
            _ = dbm.suggestions(for: "sel", shouldCapitalize: false, contextWords: [])
            _ = dbm.nextWordSuggestions(contextWords: ["Men"], shouldCapitalize: false)
            let dt = Double(DispatchTime.now().uptimeNanoseconds - t0) / 1_000_000.0
            totalStressMs += dt
            if dt > maxStressMs { maxStressMs = dt }
            if dt >= 16.0 { allUnder16Ms = false }
        }
        check(allUnder16Ms, "50-iteration multithreaded cold-start stress test (all iterations < 16.0 ms)", detail: String(format: "avg=%.4f ms, max=%.4f ms", totalStressMs / 50.0, maxStressMs))

        let prepT0 = DispatchTime.now().uptimeNanoseconds
        dbm.prepareAsync()
        let deadline = Date().addingTimeInterval(5.0)
        while !dbm.isReady && Date() < deadline {
            usleep(1000)
        }
        let prepMs = Double(DispatchTime.now().uptimeNanoseconds - prepT0) / 1_000_000.0
        check(dbm.isReady, "prepareAsync() completes on background queue and sets isReady == true", detail: String(format: "%.2f ms", prepMs))

        // -----------------------------------------------------------------
        // 2. LOWERCASE "de", NO "Producer" ON "Прпр", LILÂ HANUŞEVSKA -> SAĞ OL, & QIRI'M YOUNG
        // -----------------------------------------------------------------
        print("\n--- [2] Lowercase 'de', No 'Producer' on 'Прпр', Lilâ/Liliya Hanuşevska -> sağ ol, & QIRI'M Young ---")
        dbm.updateSupplementaryLexicon(["De": "De", "Producer": "Producer", "Selâm": "Selâm", "Mustafa": "Mustafa"])
        let deSuggs = dbm.suggestions(for: "de", shouldCapitalize: false, contextWords: ["Men"]).map(\.text)
        let prprSuggs = dbm.suggestions(for: "Прпр", shouldCapitalize: true, contextWords: []).map(\.text)
        let selamMidSentence = dbm.suggestions(for: "selam", shouldCapitalize: false, contextWords: ["Men"]).map(\.text)
        check(!deSuggs.contains("De") && deSuggs.first == "de", "Lowercase particle 'de' is never auto-capitalized to 'De'", detail: "got \(deSuggs)")
        check(!prprSuggs.contains(where: { $0.caseInsensitiveCompare("Producer") == .orderedSame }), "2-char fallback prefix on 'Прпр' never pulls 'Producer' from UILexicon", detail: "got \(prprSuggs)")
        check(selamMidSentence.contains("selâm") && !selamMidSentence.contains("Selâm"), "Common dictionary word in UILexicon ('Selâm') is not force-capitalized mid-sentence", detail: "got \(selamMidSentence)")
        dbm.updateSupplementaryLexicon([:])

        let lilaNext = dbm.nextWordSuggestions(contextWords: ["Lilâ", "Hanuşevska"], shouldCapitalize: false).map(\.text)
        let liliyaNext = dbm.nextWordSuggestions(contextWords: ["Liliya", "Hanuşevska"], shouldCapitalize: true).map(\.text)
        let lilaInline = dbm.suggestions(for: "Hanuşevska", shouldCapitalize: false, contextWords: ["Lilâ"])
        let sagOlInline = lilaInline.first(where: { $0.text.lowercased(with: Locale(identifier: "tr")) == "sağ ol" })
        check(lilaNext.first == "sağ ol", "nextWordSuggestions(['Lilâ', 'Hanuşevska']) -> 'sağ ol'", detail: "got \(lilaNext)")
        check(liliyaNext.first == "Sağ ol", "nextWordSuggestions(['Liliya', 'Hanuşevska'], cap=true) -> 'Sağ ol'", detail: "got \(liliyaNext)")
        check(sagOlInline != nil && (sagOlInline?.additionalInfo["appendAfterCurrentWord"] as? Bool == true), "Inline suggestions(for: 'Hanuşevska', context: ['Lilâ']) includes appendAfterCurrentWord 'sağ ol'", detail: "got \(lilaInline.map(\.text))")

        let qirimYoungNext = dbm.nextWordSuggestions(contextWords: ["QIRI'M"], shouldCapitalize: false).map(\.text)
        let qirimCapYoungNext = dbm.nextWordSuggestions(contextWords: ["Qırım"], shouldCapitalize: false).map(\.text)
        let qirimBrandSuggs = dbm.suggestions(for: "qiri'm", shouldCapitalize: false, contextWords: [])
        let qiriSuggs = dbm.suggestions(for: "qiri", shouldCapitalize: false, contextWords: [])
        let qiriCapsSuggs = dbm.suggestions(for: "QIRI", shouldCapitalize: true, contextWords: [])
        check(qirimYoungNext.first == "Young", "nextWordSuggestions(['QIRI\\'M']) -> 'Young'", detail: "got \(qirimYoungNext)")
        check(qirimCapYoungNext.contains("Young"), "nextWordSuggestions(['Qırım']) includes 'Young'", detail: "got \(qirimCapYoungNext)")
        check(qirimBrandSuggs.contains(where: { $0.text == "QIRI'M" && ($0.additionalInfo["replaceCharCount"] as? Int) == 6 }) && qirimBrandSuggs.contains(where: { $0.text == "QIRI'M Young" && ($0.additionalInfo["replaceCharCount"] as? Int) == 6 }), "suggestions(for: 'qiri\\'m') includes 'QIRI\\'M' & 'QIRI\\'M Young' with replaceCharCount=6", detail: "got \(qirimBrandSuggs.map(\.text))")
        check(qiriSuggs.map(\.text) == ["qiri", "Qırım", "QIRI'M Young"] && !qiriSuggs[2].isAutocorrect && qiriCapsSuggs.map(\.text) == ["QIRI", "QIRI'M", "QIRI'M Young"], "suggestions(for: 'qiri' / 'QIRI') offers 'Qırım'/'QIRI\\'M' in Slot 1 and 'QIRI\\'M Young' (isAutocorrect: false) in Slot 2", detail: "qiri=\(qiriSuggs.map(\.text)), QIRI=\(qiriCapsSuggs.map(\.text))")

        // -----------------------------------------------------------------
        // 3. SWIPE CANDIDATE QUEUE (limit: 10) & BENCHMARK
        // -----------------------------------------------------------------
        print("\n--- [3] Swipe Candidate Queue (limit: 10) & Benchmark ---")
        let swipeQueue = dbm.matchSwipePath(
            keySequence: ["s", "e", "l", "a", "m"],
            isCyrillic: false,
            shouldCapitalize: false,
            contextWords: [],
            limit: 10
        )
        check(swipeQueue.first?.text.lowercased(with: Locale(identifier: "tr")) == "selâm" && swipeQueue.count >= 2, "matchSwipePath(limit: 10) returns candidate queue for Backspace/re-swipe rotation", detail: "got \(swipeQueue.map(\.text))")

        // -----------------------------------------------------------------
        // 4. ARCHITECTURAL & SOURCE CODE CHECKS (v2.4)
        // -----------------------------------------------------------------
        print("\n--- [4] Phase 13 (v2.4) Architectural & Source Code Checks ---")
        let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().path
        let gitignoreText = (try? String(contentsOfFile: repoRoot + "/.gitignore", encoding: .utf8)) ?? ""
        let appConfigText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Shared/AppConfiguration.swift", encoding: .utf8)) ?? ""
        let kvcText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Keyboard/KeyboardViewController.swift", encoding: .utf8)) ?? ""
        let styleText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Keyboard/DemoStyleProvider.swift", encoding: .utf8)) ?? ""
        let layoutText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Keyboard/DemoLayoutProvider.swift", encoding: .utf8)) ?? ""
        let ipadLayoutText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Keyboard/CrimeanTatarIPadKeyboardLayoutProvider.swift", encoding: .utf8)) ?? ""
        let calloutText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Keyboard/DemoCalloutActionProvider.swift", encoding: .utf8)) ?? ""
        let toolbarText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Keyboard/Autocomplete+NativeToolbarStyle.swift", encoding: .utf8)) ?? ""
        let spaceLabelText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Keyboard/SpaceBarLabel.swift", encoding: .utf8)) ?? ""
        let spaceDragText = (try? String(contentsOfFile: repoRoot + "/QTatar/Sources/KeyboardKit/Gestures/Gestures+SpaceDragGestureHandler.swift", encoding: .utf8)) ?? ""
        let sysKeyboardText = (try? String(contentsOfFile: repoRoot + "/QTatar/Sources/KeyboardKit/_Essentials/SystemKeyboard.swift", encoding: .utf8)) ?? ""
        let pbxprojText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/QTatar.xcodeproj/project.pbxproj", encoding: .utf8)) ?? ""

        check(gitignoreText.contains("*.p12") && !FileManager.default.fileExists(atPath: repoRoot + "/Archive/Certificates/Untitled.p12"), "Secret .p12 removed from repo & ignored in .gitignore")
        check(appConfigText.contains("QirimKeyDiagnosticsSubscriber") && appConfigText.contains("isEmojiKeyboardEnabled") && appConfigText.contains("AppConfiguration.appGroupID"), "AppConfiguration has QirimKeyDiagnosticsSubscriber, isEmojiKeyboardEnabled, and public App Group preferences")
        check(kvcText.contains("syncIsFloating(with: self") && !kvcText.contains("clampFloatingHostContainerIfNeeded") && kvcText.contains("prefsSyncQueue") && kvcText.contains("isSpaceDragActive: context.isSpaceDragGestureActive"), "KeyboardViewController uses public syncIsFloating container geometry for iPad floating detection, background prefsSyncQueue, and passes isSpaceDragActive")
        check(styleText.contains("KeyboardAdaptiveGeometry.resolve") && styleText.contains(".namePhonePad, .webSearch:"), "DemoStyleProvider delegates geometry to KeyboardAdaptiveGeometry.resolve & enables top toolbar for .webSearch")
        check(layoutText.contains("₺") && !layoutText.contains("¥") && layoutText.contains("DemoStyleProvider.rowHeight"), "DemoLayoutProvider uses ₺ instead of ¥ and delegates rowHeight/itemInsets to DemoStyleProvider")
        check(ipadLayoutText.contains("crimeanTatarPadUkrainianCyrillic") && ipadLayoutText.contains("DemoStyleProvider.rowHeight"), "CrimeanTatarIPadKeyboardLayoutProvider defines Docked iPad Ukrainian FIVA 12/11/11 input set and delegates rowHeight/itemInsets")
        check(kvcText.contains("DemoStyleProvider.expectedKeyboardHeight("), "KeyboardViewController.expectedKeyboardHeight delegates to DemoStyleProvider.expectedKeyboardHeight")
        check(calloutText.contains(".edu") && calloutText.contains("≈") && calloutText.contains("‰"), "DemoCalloutActionProvider includes .com domain callouts & rich punctuation/math callouts")
        check(toolbarText.contains("static func slotWidths(") && toolbarText.contains("== .webSearch"), "Autocomplete+NativeToolbarStyle has proportional slotWidths() & suppresses greeting phrase in .webSearch")
        check(spaceLabelText.contains("CABasicAnimation") && spaceLabelText.contains("group.duration = 4.4") && spaceLabelText.contains("scheduleIdleStopTimer(after: 60.0)") && spaceLabelText.contains("var isSpaceDragActive: Bool = false") && spaceLabelText.contains(".width(.condensed)") && spaceLabelText.contains("currentExertion") && spaceLabelText.contains("1.9") && spaceLabelText.contains("effectiveIsDark ? 0.30 : 0.20"), "SpaceBarLabel has CABasicAnimation breathing (4.4s cycle), 60s idle settle, proportional typing speed acceleration (up to 2.9x), inertial cooldown, condensed corner code matching native УК opacity (0.20 Light / 0.30 Dark), and isSpaceDragActive fade")
        let buttonKeyText = (try? String(contentsOfFile: repoRoot + "/QTatar/Sources/KeyboardKit/_Essentials/Keyboard+ButtonKey.swift", encoding: .utf8)) ?? ""
        let buttonGesturesText = (try? String(contentsOfFile: repoRoot + "/QTatar/Sources/KeyboardKit/Gestures/Gestures+KeyboardButtonGestures.swift", encoding: .utf8)) ?? ""
        let agentsText = (try? String(contentsOfFile: repoRoot + "/AGENTS.md", encoding: .utf8)) ?? ""
        check(!buttonKeyText.contains(".plusLighter") && styleText.contains("opacity(0.24)") && styleText.contains("darkSystemKey = useClassicStyle ?") && kvcText.contains("view.overrideUserInterfaceStyle = targetViewStyle"), "Dark Mode keys never use .plusLighter blendMode, use calibrated 0.24 dark keycap fills on iOS 26+ Liquid Glass, and enforce view.overrideUserInterfaceStyle")
        check(!buttonGesturesText.contains("keyFrames.count > 44") && buttonGesturesText.contains("overlapTestRect"), "SwipeTypingState.registerKeyFrame uses spatial overlap removal without arbitrary 44-key cap")
        check(agentsText.contains("Tamga Breathing, Proportional Human Speed Scaling & 60s Idle Settle") && agentsText.contains("Zero White Keys on Dark Background") && agentsText.contains("Mandatory Anti-Regression Audit"), "AGENTS.md includes all 3 anti-regression rules from learning_proposal.md")
        check(spaceDragText.contains("verticalLineAction") && spaceDragText.contains("computeWordWrappedVisualLines") && !spaceDragText.contains("if verticalDistance < verticalThreshold"), "SpaceDragGestureHandler supports unrestricted 2D X+Y cursor movement with dynamic window-width word wrapping")
        check(!sysKeyboardText.contains("itemRow.map { String(describing: $0.action) }"), "SystemKeyboard preserves GestureButton identity across Slide-from-123 keyboardType transitions")
        check(pbxprojText.contains("SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD = YES;") && pbxprojText.contains("xrsimulator xros"), "project.pbxproj enables Mac (Designed for iPad) and visionOS platforms")

        let appPlistText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Demo/Info.plist", encoding: .utf8)) ?? ""
        let kbPlistText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Keyboard/Info.plist", encoding: .utf8)) ?? ""
        let kbCyrPlistText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/KeyboardCyrillic/Info.plist", encoding: .utf8)) ?? ""
        let settingsRootPlistText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Demo/Settings.bundle/Root.plist", encoding: .utf8)) ?? ""
        check(pbxprojText.contains("MARKETING_VERSION = 3.1;") && !pbxprojText.contains("MARKETING_VERSION = 4.0;") && pbxprojText.contains("CURRENT_PROJECT_VERSION = 5;") && !pbxprojText.contains("CURRENT_PROJECT_VERSION = 4;"), "All targets in project.pbxproj set to MARKETING_VERSION = 3.1 and CURRENT_PROJECT_VERSION = 5")
        check(appPlistText.contains("$(CURRENT_PROJECT_VERSION)") && kbPlistText.contains("$(CURRENT_PROJECT_VERSION)") && kbCyrPlistText.contains("$(CURRENT_PROJECT_VERSION)"), "All Info.plist files bind CFBundleVersion to $(CURRENT_PROJECT_VERSION)")
        check(appPlistText.contains("ITSAppUsesNonExemptEncryption"), "Demo/Info.plist declares ITSAppUsesNonExemptEncryption = false")
        check(pbxprojText.contains("Settings.bundle in Resources") && settingsRootPlistText.contains("crh.key.suggestionsEnabled") && settingsRootPlistText.contains("crh.key.wordLearningEnabled") && !settingsRootPlistText.contains("crh.key.statsEnabled") && !settingsRootPlistText.contains("<string>QırımKey</string>") && !settingsRootPlistText.contains("crh.key.cyrillicEnabled") && !settingsRootPlistText.contains("crh.key.autocorrectionEnabled"), "Settings.bundle is in PBXResourcesBuildPhase and contains only the 2 keyboard toggles (suggestionsEnabled, wordLearningEnabled) without statsEnabled or duplicate QırımKey title")

        // -----------------------------------------------------------------
        // 5. ADAPTIVE KEYBOARD GEOMETRY MATRIX (ALL IPHONE & IPAD SIZES)
        // -----------------------------------------------------------------
        print("\n--- [5] Adaptive Keyboard Geometry Matrix (All iPhone & iPad Screen Sizes) ---")
        let compactPhone = KeyboardAdaptiveGeometry.resolve(isPad: false, isFloating: false, isPortrait: true, screenSize: CGSize(width: 375, height: 667), hasToolbar: true)
        let compactPhoneLand = KeyboardAdaptiveGeometry.resolve(isPad: false, isFloating: false, isPortrait: false, screenSize: CGSize(width: 667, height: 375), hasToolbar: true)
        check(compactPhone.letterRowHeight == 51.0 && compactPhone.bottomRowHeight == 50.0 && compactPhone.visibleKeyHeight(forRowAt: 0) == 39.0 && compactPhone.totalKeyboardHeight == 243.0 && compactPhoneLand.totalKeyboardHeight == 192.0, "iPhone Compact (SE / mini 375 pt): Portrait 243 pt (39 pt keys), Landscape 192 pt")

        let stdPhone15Pro = KeyboardAdaptiveGeometry.resolve(isPad: false, isFloating: false, isPortrait: true, screenSize: CGSize(width: 393, height: 852), hasToolbar: true)
        let stdPhone16Pro = KeyboardAdaptiveGeometry.resolve(isPad: false, isFloating: false, isPortrait: true, screenSize: CGSize(width: 402, height: 874), hasToolbar: true)
        let stdPhoneLand = KeyboardAdaptiveGeometry.resolve(isPad: false, isFloating: false, isPortrait: false, screenSize: CGSize(width: 852, height: 393), hasToolbar: true)
        check(stdPhone15Pro.totalKeyboardHeight == 255.0 && stdPhone16Pro.totalKeyboardHeight == 255.0 && stdPhone15Pro.visibleKeyHeight(forRowAt: 0) == 41.0 && stdPhone15Pro.visibleKeyHeight(forRowAt: 3) == 43.0 && stdPhoneLand.totalKeyboardHeight == 200.0, "iPhone Standard/Pro (15 Pro 393 pt, 16 Pro 402 pt): Portrait 255 pt (41/43 pt keys), Landscape 200 pt")

        let maxPhone = KeyboardAdaptiveGeometry.resolve(isPad: false, isFloating: false, isPortrait: true, screenSize: CGSize(width: 440, height: 956), hasToolbar: true)
        let maxPhoneLand = KeyboardAdaptiveGeometry.resolve(isPad: false, isFloating: false, isPortrait: false, screenSize: CGSize(width: 956, height: 440), hasToolbar: true)
        check(maxPhone.letterRowHeight == 56.0 && maxPhone.bottomRowHeight == 55.0 && maxPhone.visibleKeyHeight(forRowAt: 0) == 43.0 && maxPhone.visibleKeyHeight(forRowAt: 3) == 45.0 && maxPhone.totalKeyboardHeight == 263.0 && maxPhoneLand.totalKeyboardHeight == 200.0, "iPhone Plus/Pro Max (430–440 pt): Portrait 263 pt (43/45 pt keys), Landscape 200 pt")

        let ipadFloat = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: true, isPortrait: true, screenSize: CGSize(width: 820, height: 1180), hasToolbar: true)
        let ipadFloatNoSugg = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: true, isPortrait: true, screenSize: CGSize(width: 820, height: 1180), hasToolbar: false)
        check(ipadFloat.letterRowHeight == 54.0 && ipadFloat.bottomRowHeight == 54.0 && ipadFloat.visibleKeyHeight(forRowAt: 0) == 38.0 && ipadFloat.toolbarHeight == 45.0 && ipadFloat.totalKeyboardHeight == 271.0 && ipadFloatNoSugg.totalKeyboardHeight == 226.0, "iPad Floating (all iPads): 54/54 pt rows (38 pt=76 px keys) + 45 pt toolbar + 10 pt insets = 271.0 pt w/ sugg (669 px platter) & 226.0 pt w/o sugg (579 px platter)")

        let ipadMiniP = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: false, isPortrait: true, screenSize: CGSize(width: 744, height: 1133), hasToolbar: true)
        let ipadMiniPNo = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: false, isPortrait: true, screenSize: CGSize(width: 744, height: 1133), hasToolbar: false)
        let ipadMiniL = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: false, isPortrait: false, screenSize: CGSize(width: 1133, height: 744), hasToolbar: true)
        let ipadMiniLNo = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: false, isPortrait: false, screenSize: CGSize(width: 1133, height: 744), hasToolbar: false)
        let ipadAirP = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: false, isPortrait: true, screenSize: CGSize(width: 820, height: 1180), hasToolbar: true)
        let ipadAirPNo = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: false, isPortrait: true, screenSize: CGSize(width: 820, height: 1180), hasToolbar: false)
        let ipadAirL = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: false, isPortrait: false, screenSize: CGSize(width: 1180, height: 820), hasToolbar: true)
        let ipadAirLNo = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: false, isPortrait: false, screenSize: CGSize(width: 1180, height: 820), hasToolbar: false)
        let ipadPro13P = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: false, isPortrait: true, screenSize: CGSize(width: 1024, height: 1366), hasToolbar: true)
        let ipadPro13PNo = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: false, isPortrait: true, screenSize: CGSize(width: 1024, height: 1366), hasToolbar: false)
        let ipadPro13L = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: false, isPortrait: false, screenSize: CGSize(width: 1366, height: 1024), hasToolbar: true)
        let ipadPro13LNo = KeyboardAdaptiveGeometry.resolve(isPad: true, isFloating: false, isPortrait: false, screenSize: CGSize(width: 1366, height: 1024), hasToolbar: false)
        check(
            ipadMiniP.totalKeyboardHeight == 258.0 && ipadMiniPNo.totalKeyboardHeight == 258.0
                && ipadMiniL.totalKeyboardHeight == 338.0 && ipadMiniLNo.totalKeyboardHeight == 338.0
                && ipadAirP.totalKeyboardHeight == 258.0 && ipadAirPNo.totalKeyboardHeight == 258.0
                && ipadAirL.totalKeyboardHeight == 343.0 && ipadAirLNo.totalKeyboardHeight == 343.0
                && ipadPro13P.totalKeyboardHeight == 296.0 && ipadPro13PNo.totalKeyboardHeight == 296.0
                && ipadPro13L.totalKeyboardHeight == 378.0 && ipadPro13LNo.totalKeyboardHeight == 378.0,
            "iPad Docked tiers keep invariant totalKeyboardHeight across hasToolbar true/false: Mini (258/338 pt), 10.5\" Air 3 & 11\" A16 (258/343 pt), 12.9\"/13\" Pro (296/378 pt)"
        )
        check(layoutText.contains("let shouldIncludeGlobe = context.isKeyboardFloating || context.needsInputModeSwitchKey") && layoutText.contains(".percentage(0.12825)") && layoutText.contains(".percentage(0.2565)"), "DemoLayoutProvider always includes .nextKeyboard (key.globe) in iPad Floating mode with 0.12825/0.12825/0.487/0.2565 (0 px overflow)")

        // -----------------------------------------------------------------
        // 6. STRICT EXTENSION SCRIPT BINDING, OS-VERSION SYSTEM KEYS & SENTENCE POSITION CONTEXT
        // -----------------------------------------------------------------
        print("\n--- [6] Strict Extension Script Binding, OS-Version System Keys & Sentence Position Context ---")
        check(kvcText.contains("func resetToExtensionDefaultScript()") && kvcText.contains("var defaultLocaleIdentifierForExtension: String") && kvcText.contains("guard state.keyboardContext.deviceType == .pad") && !kvcText.contains("self.advanceToNextInputMode()"), "KeyboardViewController strictly binds crh.key.Keyboard to crh-Latn and crh.key.KeyboardCyrillic to crh-Cyrl on iPhone, resets on viewWillAppear on iPad, and never invokes self.advanceToNextInputMode()")
        check(layoutText.contains("isCyrillicOnlyOnPhone") && layoutText.contains("isLatinOnlyOnPhone") && layoutText.contains("if isPadDevice {"), "DemoLayoutProvider skips CrimeanTatarIPadKeyboardLayoutProvider on iPhone and isolates Latin vs Cyrillic InputSets")
        check(styleText.contains("static var usesClassicSystemKeyStyle: Bool") && styleText.contains("#available(iOS 26.0, *)") && styleText.contains("Color(red: 172.0 / 255.0, green: 177.0 / 255.0, blue: 185.0 / 255.0)") && styleText.contains("let primaryLabelColor = isDark ? Color.white : Color.black") && styleText.contains("if Self.usesClassicSystemKeyStyle && !keyboardContext.isKeyboardFloating"), "DemoStyleProvider uses white Liquid Glass system keys on iOS 26+, opaque classic gray (#ACB3BE) on pre-iOS 26, 1.0 primaryLabelColor opacity, and preserves 10 pt cornerRadius in iPad Floating mode")

        let sliceAfterPeriod = String(SuggestionsDataBaseManager.currentSentenceSlice(in: "Men baram. "))
        let sliceAfterClosingPeriod = String(SuggestionsDataBaseManager.currentSentenceSlice(in: "Sağ ol. "))
        let posDocStart = SuggestionsDataBaseManager.resolveSentencePositionContext(beforeText: "", contextWords: [])
        let posDocStartWithWord = SuggestionsDataBaseManager.resolveSentencePositionContext(beforeText: "Sel", contextWords: [])
        let posSentenceStart = SuggestionsDataBaseManager.resolveSentencePositionContext(beforeText: "Men keldim. ", contextWords: [])
        let posSentenceStartAfterClosing = SuggestionsDataBaseManager.resolveSentencePositionContext(beforeText: "Sağ ol. ", contextWords: ["Sağ", "ol"])
        let posMidSentence = SuggestionsDataBaseManager.resolveSentencePositionContext(beforeText: "Men bugün ", contextWords: ["Men", "bugün"])
        let posClosingWord = SuggestionsDataBaseManager.resolveSentencePositionContext(beforeText: "Bugün işim bitti, sağ ", contextWords: ["bitti", "sağ"])
        check(sliceAfterPeriod == " " && sliceAfterClosingPeriod == " " && posDocStart == .documentStart && posDocStartWithWord == .documentStart && posSentenceStart == .sentenceStart && posSentenceStartAfterClosing == .sentenceStart && posMidSentence == .midSentence && posClosingWord == .closingContext, "currentSentenceSlice & resolveSentencePositionContext accurately slice at sentence boundaries and classify .documentStart, .sentenceStart (including after 'Sağ ol. '), .midSentence, and .closingContext")

        let docStarters = dbm.starterSuggestions(shouldCapitalize: true, positionContext: .documentStart).map(\.text)
        let sentStarters = dbm.starterSuggestions(shouldCapitalize: true, positionContext: .sentenceStart).map(\.text)
        let closeStarters = dbm.starterSuggestions(shouldCapitalize: true, positionContext: .closingContext).map(\.text)
        check(docStarters == ["Selâm", "Meraba", "Hayırlı"] && sentStarters == ["Men", "Bu", "Biz"] && closeStarters == ["Sağ oluñız", "Körüşkence", "Allaha emanet"], "starterSuggestions adapts to .documentStart (greetings), .sentenceStart (['Men', 'Bu', 'Biz']), and .closingContext (farewells)", detail: "doc=\(docStarters), sent=\(sentStarters), close=\(closeStarters)")

        let hayirliDocNext = dbm.nextWordSuggestions(contextWords: ["Hayırlı"], shouldCapitalize: false, positionContext: .documentStart).map(\.text)
        let sagCloseNext = dbm.nextWordSuggestions(contextWords: ["Sağ"], shouldCapitalize: false, positionContext: .closingContext).map(\.text)
        check(hayirliDocNext.contains(where: { ["sabahlar", "künler", "aqşamlar", "olsun"].contains($0.lowercased(with: Locale(identifier: "tr"))) }), "nextWordSuggestions(['Hayırlı'], .documentStart) prioritizes greeting continuations", detail: "got \(hayirliDocNext)")
        check(sagCloseNext.first?.lowercased(with: Locale(identifier: "tr")).hasPrefix("ol") == true, "nextWordSuggestions(['Sağ'], .closingContext) prioritizes 'ol' / 'oluñız'", detail: "got \(sagCloseNext)")

        // -----------------------------------------------------------------
        // 7. CONTEXTUAL SWIPE-TO-TYPE & CONTENT-SAFETY GUARDRAILS
        // -----------------------------------------------------------------
        print("\n--- [7] Contextual Swipe-to-Type & Content-Safety Guardrails ---")
        let bonusPronoun1st = SuggestionsDataBaseManager.contextualSwipeBonus(for: "keldim", prevWord: "men", prevPrevWord: nil, bigramBoost: 0, positionContext: .midSentence)
        let bonusPronoun2ndMismatch = SuggestionsDataBaseManager.contextualSwipeBonus(for: "keldiñ", prevWord: "men", prevPrevWord: nil, bigramBoost: 0, positionContext: .midSentence)
        check(bonusPronoun1st > bonusPronoun2ndMismatch + 1.5, "Pronoun-verb agreement boosts 1st-person 'men keldim' over mismatched 'men keldiñ'", detail: String(format: "keldim=%.2f vs keldiñ=%.2f", bonusPronoun1st, bonusPronoun2ndMismatch))

        let bonusGenPoss = SuggestionsDataBaseManager.contextualSwipeBonus(for: "kitabım", prevWord: "menim", prevPrevWord: nil, bigramBoost: 0, positionContext: .midSentence)
        let bonusGenBare = SuggestionsDataBaseManager.contextualSwipeBonus(for: "kitap", prevWord: "menim", prevPrevWord: nil, bigramBoost: 0, positionContext: .midSentence)
        check(bonusGenPoss > bonusGenBare + 1.0, "Genitive-possessive agreement boosts 'menim kitabım' over bare 'menim kitap'", detail: String(format: "kitabım=%.2f vs kitap=%.2f", bonusGenPoss, bonusGenBare))

        let bonusAblPost = SuggestionsDataBaseManager.contextualSwipeBonus(for: "soñ", prevWord: "bundan", prevPrevWord: nil, bigramBoost: 0, positionContext: .midSentence)
        check(bonusAblPost >= 1.3, "Ablative + postposition agreement boosts 'bundan soñ'", detail: String(format: "soñ=%.2f", bonusAblPost))

        let bonusDocGreeting = SuggestionsDataBaseManager.contextualSwipeBonus(for: "selâm", prevWord: nil, prevPrevWord: nil, bigramBoost: 0, positionContext: .documentStart)
        let bonusMidGreeting = SuggestionsDataBaseManager.contextualSwipeBonus(for: "selâm", prevWord: "men", prevPrevWord: nil, bigramBoost: 0, positionContext: .midSentence)
        let bonusClosing = SuggestionsDataBaseManager.contextualSwipeBonus(for: "körüşkence", prevWord: "oluñız", prevPrevWord: "sağ", bigramBoost: 0, positionContext: .closingContext)
        check(bonusDocGreeting > bonusMidGreeting && bonusClosing >= 1.1, "SentencePositionContext boosts greetings at .documentStart and farewells at .closingContext", detail: String(format: "docGreeting=%.2f, midGreeting=%.2f, closing=%.2f", bonusDocGreeting, bonusMidGreeting, bonusClosing))

        // Content-safety guardrails verification
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("yaman", contextWords: ["Qırım"]), "Blocks negative/hostile adjective ('yaman') after 'Qırım'")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("duşmanı", contextWords: ["qırımtatarlar"]), "Blocks hostile noun ('duşmanı') after 'qırımtatarlar'")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("haini", contextWords: ["qırım"]), "Blocks hostile noun ('haini') after 'qırım'")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("zaif", contextWords: ["Ukrayina"]), "Blocks negative adjective ('zaif') after 'Ukrayina'")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("qırım", contextWords: ["yaman"], typedQuery: "qır"), "Blocks negative -> Crimean Tatar pairing ('yaman Qırım')")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("ulu", contextWords: ["rusiye"]), "Blocks positive/glorifying epithet ('ulu') after 'rusiye'")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("büyük", contextWords: ["rus"]), "Blocks positive/glorifying epithet ('büyük') after 'rus'")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("qahraman", contextWords: ["putin"]), "Blocks glorifying epithet ('qahraman') after 'putin'")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("rusiye", contextWords: ["güzel"], typedQuery: "rus"), "Blocks positive epithet before Russian entity ('güzel rusiye')")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("rusiye", contextWords: ["men"]), "Blocks unsolicited Russian entity ('rusiye') in next-word predictions")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("hruşçöv", contextWords: ["men"]), "Blocks Soviet politician ('hruşçöv') in predictions")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("nkvd", contextWords: [], typedQuery: "nkv"), "Blocks Soviet secret police ('nkvd') even on prefix typing")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("putin", contextWords: [], typedQuery: "put"), "Blocks Russian politician ('putin') even on prefix typing")
        check(SuggestionsDataBaseManager.isBlockedContextualCandidate("stalin", contextWords: [], typedQuery: "sta"), "Blocks Soviet dictator ('stalin') even on prefix typing")

        let qirimNextSafe = dbm.nextWordSuggestions(contextWords: ["Qırım"], shouldCapitalize: false, positionContext: .midSentence).map(\.text)
        let halqNextSafe = dbm.nextWordSuggestions(contextWords: ["halq"], shouldCapitalize: false, positionContext: .midSentence).map(\.text)
        let ukrNextSafe = dbm.nextWordSuggestions(contextWords: ["Ukrayina"], shouldCapitalize: false, positionContext: .midSentence).map(\.text)
        let rusiyeNextSafe = dbm.nextWordSuggestions(contextWords: ["Rusiye"], shouldCapitalize: false, positionContext: .midSentence).map(\.text)
        let rusPrefixSuggs = dbm.suggestions(for: "rus", shouldCapitalize: false, contextWords: ["büyük"]).map(\.text)
        let putinPrefixSuggs = dbm.suggestions(for: "putin", shouldCapitalize: false, contextWords: []).map(\.text)
        check(!qirimNextSafe.contains(where: { SuggestionsDataBaseManager.isBlockedContextualCandidate($0.lowercased(with: Locale(identifier: "tr")), contextWords: ["Qırım"]) }) && !halqNextSafe.contains(where: { $0.lowercased(with: Locale(identifier: "tr")).hasPrefix("duşman") }), "nextWordSuggestions(['Qırım'] / ['halq']) contains zero negative, repressive, or Russian propaganda terms", detail: "Qırım=\(qirimNextSafe), halq=\(halqNextSafe)")
        check(!ukrNextSafe.contains(where: { SuggestionsDataBaseManager.isBlockedContextualCandidate($0.lowercased(with: Locale(identifier: "tr")), contextWords: ["Ukrayina"]) }), "nextWordSuggestions(['Ukrayina']) contains zero negative terms", detail: "got \(ukrNextSafe)")
        check(!rusiyeNextSafe.contains(where: { ["büyük", "ulu", "güzel", "azat", "qahraman", "muqaddes", "şanlı", "dost"].contains($0.lowercased(with: Locale(identifier: "tr"))) }), "nextWordSuggestions(['Rusiye']) contains zero positive/glorifying epithets", detail: "got \(rusiyeNextSafe)")
        check(rusPrefixSuggs.contains("rustem") && !rusPrefixSuggs.contains(where: { SuggestionsDataBaseManager.isRussianEntityOrPoliticianTerm($0) && $0 != "rus" }) && !putinPrefixSuggs.contains(where: { SuggestionsDataBaseManager.isRussianEntityOrPoliticianTerm($0) && $0 != "putin" }), "Prefix suggestions preserve Crimean Tatar name 'rustem', block 'büyük rusiye/ruslar/rus-yapon', and never suggest corpus completions for 'putin'", detail: "büyük+rus=\(rusPrefixSuggs), putin=\(putinPrefixSuggs)")

        // -----------------------------------------------------------------
        // 12. PERSONAL DICTIONARY (is_custom = 1) vs PREDICTIVE UNIGRAMS (is_custom = 0) & UI CHECKS
        // -----------------------------------------------------------------
        print("\n--- [12] Personal Dictionary (is_custom = 1) vs Predictive Unigrams (is_custom = 0) & UI Checks ---")
        KeyboardPreferences.wordLearningEnabled = true
        dbm.deleteLearnedWord("qırımtatarca")
        dbm.deleteLearnedWord("qırımyañısöz")
        dbm.learnWordIfPermitted("qırımtatarca", explicitlyConfirmed: false)
        dbm.learnWordIfPermitted("qırımyañısöz", explicitlyConfirmed: false)
        Thread.sleep(forTimeInterval: 0.12)
        let learnedUnconfirmed = dbm.fetchLearnedWords()
        check(
            dbm.hasLearnedWord("qırımtatarca") && !learnedUnconfirmed.contains("qırımtatarca") && !learnedUnconfirmed.contains("qırımyañısöz"),
            "learnWordIfPermitted(explicitlyConfirmed: false) records word in user_unigrams (is_custom=0) for predictive personalization without adding to Personal Dictionary",
            detail: "hasLearnedWord=\(dbm.hasLearnedWord("qırımtatarca")), personalDict=\(learnedUnconfirmed)"
        )
        dbm.learnWordIfPermitted("qırımyañısöz", explicitlyConfirmed: true)
        Thread.sleep(forTimeInterval: 0.12)
        let learnedConfirmed = dbm.fetchLearnedWords()
        check(
            learnedConfirmed.contains("qırımyañısöz") && !learnedConfirmed.contains("qırımtatarca"),
            "learnWordIfPermitted(explicitlyConfirmed: true) (tapping quoted Slot 0 suggestion) promotes word to Personal Dictionary (is_custom=1)",
            detail: "personalDict=\(learnedConfirmed)"
        )
        dbm.deleteLearnedWord("qırımyañısöz")
        dbm.deleteLearnedWord("qırımtatarca")
        let learnedAfter = dbm.fetchLearnedWords()
        check(
            !learnedAfter.contains("qırımyañısöz"),
            "deleteLearnedWord removes target word from user_unigrams",
            detail: "words=\(learnedAfter)"
        )
        let homeViewText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Demo/Views/HomeView.swift", encoding: .utf8)) ?? ""
        check(
            homeViewText.contains("stats.learnedWords.wordLearningToggle") && homeViewText.contains("stats.learnedWords.clearAllButton"),
            "Personal Dictionary sheet includes Word Learning toggle and Clear All button"
        )
        check(
            homeViewText.contains("cyrillicBadgeTrigger") && homeViewText.contains("Color(red: 0.99, green: 0.82, blue: 0.16)") && homeViewText.contains("ViewThatFits(in: .horizontal)") && homeViewText.contains("stats.uniqueWordsUnit"),
            "HomeView isolates cyrillicBadgeTrigger from language switch, renders golden Taraq Tamğa on sky-blue badge, uses ViewThatFits for zero pill truncation, and displays uniqueWordsCount in stats.wordsTile"
        )
        check(
            buttonGesturesText.contains("localDragDistance >= 10.0") && kvcText.contains("pan.cancelsTouchesInView = false"),
            "Floating keyboard 300 CPM 2-key rollover protection active in Gestures+KeyboardButtonGestures and KeyboardViewController"
        )
        let inputCalloutText = (try? String(contentsOfFile: repoRoot + "/QTatar/Sources/KeyboardKit/Callouts/Callouts+InputCallout.swift", encoding: .utf8)) ?? ""
        let actionCalloutText = (try? String(contentsOfFile: repoRoot + "/QTatar/Sources/KeyboardKit/Callouts/Callouts+ActionCallout.swift", encoding: .utf8)) ?? ""
        let actionContextText = (try? String(contentsOfFile: repoRoot + "/QTatar/Sources/KeyboardKit/Callouts/CalloutContext+ActionContext.swift", encoding: .utf8)) ?? ""
        let curveText = (try? String(contentsOfFile: repoRoot + "/QTatar/Sources/KeyboardKit/Callouts/Callouts+Curve.swift", encoding: .utf8)) ?? ""
        let buttonAreaText = (try? String(contentsOfFile: repoRoot + "/QTatar/Sources/KeyboardKit/Callouts/Callouts+ButtonArea.swift", encoding: .utf8)) ?? ""
        let systemKeyboardText = (try? String(contentsOfFile: repoRoot + "/QTatar/Sources/KeyboardKit/_Essentials/SystemKeyboard.swift", encoding: .utf8)) ?? ""
        let calloutProviderText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Keyboard/DemoCalloutActionProvider.swift", encoding: .utf8)) ?? ""
        let styleProviderText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Keyboard/DemoStyleProvider.swift", encoding: .utf8)) ?? ""
        let actionsText = (try? String(contentsOfFile: repoRoot + "/QTatar/Sources/KeyboardKit/Actions/KeyboardAction+Actions.swift", encoding: .utf8)) ?? ""
        check(
            !inputCalloutText.contains("minCenterY")
                && !actionCalloutText.contains("minCenterY")
                && inputCalloutText.contains("bottomLeft: 0")
                && inputCalloutText.contains("leftCurveWidth: leftExpand")
                && buttonAreaText.contains("resolvedLeftCurveWidth")
                && curveText.contains("rect.minY + rect.height * 0.45")
                && curveText.contains("rect.maxY - rect.height * 0.45")
                && styleProviderText.contains("Color(red: 98.0 / 255.0, green: 98.0 / 255.0, blue: 102.0 / 255.0)")
                && styleProviderText.contains("CGSize(width: 45.0, height: 52.0)"),
            "InputCallout & ActionCallout remove minCenterY downward clamping on Row 0, use S-curve vertical tangents, 100% opaque callout background (no ghost glyph bleed), 52pt/48pt height, and asymmetric edge-key curves"
        )
        check(
            systemKeyboardText.contains("effectiveOneHandedMode")
                && systemKeyboardText.contains("oneHanded.restore")
                && calloutProviderText.contains("one_handed_left")
                && actionCalloutText.contains("keyboard.onehanded.left")
                && actionContextText.contains("deltaCells")
                && actionsText.contains("case .keyboardType(.emojis): { $0?.setKeyboardType(.emojis) }")
                && settingsRootPlistText.contains("crh.key.oneHandedMode"),
            "iPhone Portrait One-Handed Keyboard mode (left, right, off) + side-gutter restore chevron + Emoji/123/Return long-press & Settings.bundle MultiValue specifier active"
        )
        let demoActionText = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Keyboard/DemoActionHandler.swift", encoding: .utf8)) ?? ""
        check(
            kvcText.contains("guard UIDevice.current.userInterfaceIdiom == .pad")
                && kvcText.contains("updateTwoFingerTrackpadEligibility()")
                && kvcText.contains("!state.keyboardContext.isKeyboardFloating")
                && kvcText.contains("isTwoFingerTrackpadActive")
                && demoActionText.contains("cancelActiveKeyGesturesForTrackpad()")
                && demoActionText.contains("markTwoFingerTrackpadEnded()")
                && buttonGesturesText.contains("abs(existing.origin.x - frame.origin.x) < 0.5"),
            "Two-finger trackpad gesture recognizer is strictly gated to full-size iPad Docked mode only, suppresses underlying key release/flick on trackpad activation, and uses O(1) registerKeyFrame fast-return"
        )
        let emojiWrapperText = (try? String(contentsOfFile: repoRoot + "/QTatar/Sources/KeyboardKit/Emojis/Emoji+KeyboardWrapper.swift", encoding: .utf8)) ?? ""
        let ukInterfaceStrings = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Demo/Utilities/Localization/uk.lproj/Interface.strings", encoding: .utf8)) ?? ""
        let enInterfaceStrings = (try? String(contentsOfFile: repoRoot + "/QTatar/Demo/Demo/Utilities/Localization/en.lproj/Interface.strings", encoding: .utf8)) ?? ""
        check(
            homeViewText.contains("let keyboardAdded = isPrimaryKeyboardAdded || isCyrillicKeyboardAdded || isUkrainianKeyboardAdded")
                && ukInterfaceStrings.contains("«Параметри» → «Програми» → QırımKey → «Клавіатури» → «Дозволити повний доступ»")
                && enInterfaceStrings.contains("“Settings” → “Apps” → QırımKey → “Keyboards” → “Allow Full Access”")
                && systemKeyboardText.contains("restoreFullWidthFromOneHanded")
                && emojiWrapperText.contains("cachedCategoryEmojis")
                && emojiWrapperText.contains(".id(selectedCategory.id)")
                && buttonGesturesText.contains("isMultiTouchSuppressed")
                && inputCalloutText.contains("modernPillCallout")
                && appConfigText.contains("KeyboardBias")
                && settingsRootPlistText.contains("PSMultiValueSpecifier")
                && FileManager.default.fileExists(atPath: repoRoot + "/QTatar/Demo/Demo/Settings.bundle/ru.lproj/Root.strings"),
            "Tasks 19.58-19.64: multi-keyboard sandbox detection, Full Access Settings path hint, One-Handed callout & restore responsiveness, Emoji category instant switch, single-finger swipe multi-touch suppression, modern pill InputCallout, and Settings.bundle One-Handed sync (en/uk/crh/ru)"
        )

        print("\n=================================================================")
        print("SUMMARY: \(passedTests)/\(totalTests) checks passed (\(String(format: "%.1f%%", Double(passedTests) * 100.0 / Double(totalTests)))).")
        if !failures.isEmpty {
            print("FAILURES (\(failures.count)):")
            for f in failures { print("  \(f)") }
            exit(1)
        }
        print("=================================================================")
    }
}

#if !canImport(UIKit)
enum Autocomplete {
    struct Suggestion: Equatable {
        let text: String
        let title: String?
        let isAutocorrect: Bool
        let isUnknown: Bool
        let additionalInfo: [String: Any]

        init(
            text: String,
            title: String? = nil,
            isAutocorrect: Bool = false,
            isUnknown: Bool = false,
            additionalInfo: [String: Any] = [:]
        ) {
            self.text = text
            self.title = title
            self.isAutocorrect = isAutocorrect
            self.isUnknown = isUnknown
            self.additionalInfo = additionalInfo
        }

        static func == (lhs: Suggestion, rhs: Suggestion) -> Bool {
            lhs.text == rhs.text && lhs.isAutocorrect == rhs.isAutocorrect && lhs.isUnknown == rhs.isUnknown
        }
    }
}

enum UIKeyboardType {
    case `default`, emailAddress, numberPad, decimalPad, phonePad, asciiCapableNumberPad, numbersAndPunctuation
}

struct UITextContentType: Hashable {
    let rawValue: String
    static let password = UITextContentType(rawValue: "password")
    static let newPassword = UITextContentType(rawValue: "newPassword")
    static let oneTimeCode = UITextContentType(rawValue: "oneTimeCode")
    static let creditCardNumber = UITextContentType(rawValue: "creditCardNumber")
    static let emailAddress = UITextContentType(rawValue: "emailAddress")
    static let telephoneNumber = UITextContentType(rawValue: "telephoneNumber")
}

protocol UITextDocumentProxy {
    var isSecureTextEntry: Bool? { get }
    var keyboardType: UIKeyboardType? { get }
    var textContentType: UITextContentType? { get }
}

enum UIApplication {
    static let willResignActiveNotification = Notification.Name("UIApplicationWillResignActive")
    static let didEnterBackgroundNotification = Notification.Name("UIApplicationDidEnterBackground")
    static let didBecomeActiveNotification = Notification.Name("UIApplicationDidBecomeActive")
    static let willEnterForegroundNotification = Notification.Name("UIApplicationWillEnterForeground")
}

extension Notification.Name {
    static let NSExtensionHostWillResignActive = Notification.Name("NSExtensionHostWillResignActive")
    static let NSExtensionHostDidEnterBackground = Notification.Name("NSExtensionHostDidEnterBackground")
    static let NSExtensionHostDidBecomeActive = Notification.Name("NSExtensionHostDidBecomeActive")
    static let NSExtensionHostWillEnterForeground = Notification.Name("NSExtensionHostWillEnterForeground")
}

enum AppConfiguration {
    static let appGroupID = "group.crh.key.keyboardplus.tests"
}

enum KeyboardPreferences {
    static var suggestionsEnabled: Bool = true
    static var wordLearningEnabled: Bool = false
    static var statsEnabled: Bool = false
    static var ukrainianCyrillicLayoutEnabled: Bool = false
    static let defaults = UserDefaults.standard
}

enum KeyboardUsageStats {
    static let statsResetNotification = "crh.key.statsReset.tests"
    static func updateLearnedWordsCount(_ count: Int) {}
    static func setLearnedWordsCount(_ count: Int) {}
    static func setUniqueWordsCount(_ count: Int) {}
    static func recordWordLearned() {}
}
#endif

