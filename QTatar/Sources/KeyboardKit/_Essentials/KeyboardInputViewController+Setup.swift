//
//  KeyboardViewController+Setup.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2023-12-06.
//  Copyright © 2023-2024 Daniel Saidi. All rights reserved.
//

#if os(iOS) || os(tvOS) || os(visionOS)
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension KeyboardInputViewController {
    
    /// Setup KeyboardKit with a custom root view.
    func setup<Content: View>(
        withRootView view: Content
    ) {
        self.children.forEach {
            $0.willMove(toParent: nil)
            $0.removeFromParent()
        }
        self.view.subviews.forEach { $0.removeFromSuperview() }
        let view = view.keyboardState(from: self)
        let host = KeyboardHostingController(rootView: view)
        host.add(to: self)
        #if os(iOS)
        self.hasDictationKey = true
        #endif
    }
    
    /// Setup the controller when it has loaded.
    func setupController() {
        #if os(iOS)
        self.hasDictationKey = true
        #endif
        setupInitialWidth()
        setupLocaleObservation()
    }
    
    /// Set up an initial width to avoid SwiftUI layout bugs.
    func setupInitialWidth() {
        #if os(iOS) || os(tvOS)
        if view.frame.size.width == 0 {
            view.frame.size.width = UIScreen.main.bounds.width
        }
        #else
        view.frame.size.width = 500
        #endif
    }

    /// Sync the input view chrome with the standard keyboard appearance.
    func syncKeyboardChromeAppearance() {
        view.backgroundColor = .clear
        inputView?.backgroundColor = .clear
    }
    
    /// Setup locale observation to handle locale changes.
    func setupLocaleObservation() {
        state.keyboardContext.$locale
            .removeDuplicates()
            .sink { [weak self] in
                guard let self = self else { return }
                let locale = $0
                if self.primaryLanguage != locale.identifier {
                    self.primaryLanguage = locale.identifier
                }
                self.services.autocompleteProvider.locale = locale
            }.store(in: &cancellables)
    }
}
#endif
