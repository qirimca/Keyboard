//
//  DemoApp.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI
import UIKit

final class DemoAppDelegate: NSObject, UIApplicationDelegate {
    static var temporarilyDisallowThirdPartyKeyboards: Bool = false

    func application(
        _ application: UIApplication,
        shouldAllowExtensionPointIdentifier extensionPointIdentifier: UIApplication.ExtensionPointIdentifier
    ) -> Bool {
        if extensionPointIdentifier == .keyboard {
            if Self.temporarilyDisallowThirdPartyKeyboards || ProcessInfo.processInfo.arguments.contains("-qt_force_system_keyboard") {
                return false
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .all
        }
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-qt_force_landscape") {
            return .landscapeLeft
        }
        if args.contains("-qt_keep_orientation") {
            return .allButUpsideDown
        }
        return .portrait
    }
}

/**
 This is the main demo app.
 
 The app has several keyboard extensions that can be enabled
 in System Settings. Full Access must be enabled for some of
 the features to work.
 */
@main
struct DemoApp: App {
    @UIApplicationDelegateAdaptor(DemoAppDelegate.self) private var appDelegate
    @State private var navigationPath = NavigationPath()

    init() {
        let args = ProcessInfo.processInfo.arguments
        if let langIdx = args.firstIndex(of: "-qt_lang"), langIdx + 1 < args.count {
            let rawLang = args[langIdx + 1].lowercased()
            let requestedLang: String
            if rawLang.hasPrefix("en") {
                requestedLang = "en"
            } else if rawLang.hasPrefix("uk") || rawLang.hasPrefix("ua") {
                requestedLang = "uk"
            } else {
                requestedLang = "crh"
            }
            KeyboardPreferences.defaults.set(requestedLang, forKey: KeyboardPreferences.languageKey)
            KeyboardPreferences.setInterfaceLanguage(requestedLang)
        } else if args.contains("-qt_reset_text") {
            KeyboardPreferences.defaults.set("crh", forKey: KeyboardPreferences.languageKey)
            KeyboardPreferences.setInterfaceLanguage("crh")
        } else if args.contains("-qt_dump_all_proofs") {
            KeyboardPreferences.defaults.set("uk", forKey: KeyboardPreferences.languageKey)
            KeyboardPreferences.setInterfaceLanguage("uk")
        }
        if args.contains("-qt_force_suggestions_on") {
            KeyboardPreferences.defaults.set(Date().timeIntervalSince1970, forKey: "crh.key.test.uiTestingTimestamp")
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.test.sysPref.KeyboardPrediction")
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.test.sysPref.KeyboardAutocorrection")
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.test.sysPref.KeyboardMathExpressionCompletion")
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.test.holdCallout")
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.test.extendInputCalloutDuration")
        } else {
            KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.sysPref.KeyboardPrediction")
            KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.sysPref.KeyboardAutocorrection")
            KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.sysPref.KeyboardMathExpressionCompletion")
            if args.contains("-qt_hold_callout") || args.contains("-qt_extend_input_callout") {
                KeyboardPreferences.defaults.set(true, forKey: "crh.key.test.holdCallout")
                KeyboardPreferences.defaults.set(true, forKey: "crh.key.test.extendInputCalloutDuration")
            } else {
                KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.holdCallout")
                KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.extendInputCalloutDuration")
            }
        }
        let isActualUITestRun = (args.contains("-UITesting")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil)
            && !args.contains("-qt_live_system_keyboards")
        if !isActualUITestRun {
            KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.isUITesting")
            KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.uiTestingTimestamp")
        }
        KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.forceFloating")
        #if canImport(MetricKit) && os(iOS)
        QirimKeyDiagnosticsSubscriber.shared.start()
        #endif
        DispatchQueue.global(qos: .utility).async {
            CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            SystemKeyboardSettings.triggerAsyncRefreshIfNeeded(force: true)
        }
    }

    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                HomeView(onNavigate: { route in
                    navigationPath.append(route)
                })
                .navigationDestination(for: DemoRoute.self) { route in
                    switch route {
                    case .about:
                        AboutView(onNavigate: { nextRoute in
                            navigationPath.append(nextRoute)
                        })
                    case .onboarding:
                        OnboardingView()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }
}
