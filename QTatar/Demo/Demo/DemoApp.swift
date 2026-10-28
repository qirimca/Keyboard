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
    
    @AppStorage(KeyboardPreferences.languageKey, store: KeyboardPreferences.defaults) private var interfaceLanguage = "crh"
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
        } else if args.contains("-qt_reset_text") {
            KeyboardPreferences.defaults.set("crh", forKey: KeyboardPreferences.languageKey)
        }
        if args.contains("-qt_modern_pill_callout") {
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.test.useModernPillCallout")
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        } else if args.contains("-qt_classic_callout") {
            KeyboardPreferences.defaults.set(false, forKey: "crh.key.test.useModernPillCallout")
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        } else {
            KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.useModernPillCallout")
        }
        SystemKeyboardSettings.refreshSystemEmojiKeyboardState()
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationStack(path: $navigationPath) {
                HomeView(navigationPath: $navigationPath)
                    .navigationDestination(for: DemoRoute.self) { route in
                        switch route {
                        case .about:
                            AboutView(navigationPath: $navigationPath)
                        case .onboarding:
                            OnboardingView()
                        }
                    }
            }
            .environment(\.locale, Locale(identifier: interfaceLanguage))
        }
    }
}
