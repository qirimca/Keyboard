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
            .id(interfaceLanguage)
        }
    }
}
