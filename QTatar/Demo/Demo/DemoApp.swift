//
//  DemoApp.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI

/**
 This is the main demo app.
 
 The app has several keyboard extensions that can be enabled
 in System Settings. Full Access must be enabled for some of
 the features to work.
 */
@main
struct DemoApp: App {
    
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
        KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.forceFloating")
        DispatchQueue.global(qos: .utility).async {
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            SystemKeyboardSettings.triggerAsyncRefreshIfNeeded(force: false)
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
