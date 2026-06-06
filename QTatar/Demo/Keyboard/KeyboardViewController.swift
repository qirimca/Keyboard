//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI
import KeyboardKit

/**
 This keyboard demonstrates how to setup KeyboardKit and how
 to customize the standard configuration.

 To use this keyboard, you must enable it in system settings
 ("Settings/General/Keyboards"). It needs full access to get
 access to features like haptic feedback.
 */
class KeyboardViewController: KeyboardInputViewController {
    
    private var didSetupKeyboard = false

    /// This function is called when the controller loads.
    ///
    /// Here, we make demo-specific service keyboard configs.
    override func viewDidLoad() {
        SuggestionsDataBaseManager.shared.prepareAsync()
        
        /// 💡 Setup a demo-specific action handler.
        ///
        /// The demo handler has custom code for tapping and
        /// long pressing image actions.
        services.actionHandler = DemoActionHandler(
            controller: self,
            keyboardContext: state.keyboardContext,
            keyboardBehavior: services.keyboardBehavior,
            autocompleteContext: state.autocompleteContext,
            feedbackConfiguration: state.feedbackConfiguration,
            spaceDragGestureHandler: services.spaceDragGestureHandler)
        
        /// 💡 Setup a fake autocomplete provider.
        ///
        /// This fake provider will provide fake suggestions.
        /// Try the Pro demo for real suggestions.
        let autocompleteProvider = FakeAutocompleteProvider(
            context: state.autocompleteContext,
            keyboardContext: state.keyboardContext
        )
        autocompleteProvider.locale = Locale(identifier: "crh")
        services.autocompleteProvider = autocompleteProvider
        
        /// 💡 Setup a demo-specific callout action provider.
        ///
        /// The demo provider adds "keyboard" callout action
        /// buttons to the "k" key.
        services.calloutActionProvider = StandardCalloutActionProvider(
            keyboardContext: state.keyboardContext,
            baseProvider: DemoCalloutActionProvider())
        
        /// 💡 Setup a demo-specific layout provider.
        ///
        /// The demo provider adds a "next locale" button if
        /// needed, as well as a rocket emoji button.
        services.layoutProvider = DemoLayoutProvider()
        
        /// 💡 Setup a demo-specific style provider.
        ///
        /// The demo provider styles the rocket emoji button
        /// and has some commented out code that you can try.
        services.styleProvider = DemoStyleProvider(
            keyboardContext: state.keyboardContext)
        

        /// 💡 Setup a custom keyboard locale.
        ///
        /// Without KeyboardKit Pro, changing locale will by
        /// default only affects localized texts.
        state.keyboardContext.setLocale(.tatar)
        state.keyboardContext.keyboardType = .alphabetic(.lowercased)
        state.autocompleteContext.isAutocompleteEnabled = true
        state.autocompleteContext.isAutocorrectEnabled = true

        /// 💡 Add more locales to the keyboard.
        ///
        /// The demo layout provider will add a "next locale"
        /// button if you have more than one locale.
        state.keyboardContext.localePresentationLocale = .current
        state.keyboardContext.locales = [] // KeyboardLocale.all.locales
        
        /// Emoji is already on the bottom row; avoid a duplicate key.
        state.keyboardContext.keyboardDictationReplacement = nil
        
        /// 💡 Configure the space long press behavior.
        ///
        /// The locale context menu will only open up if the
        /// keyboard has multiple locales.
        state.keyboardContext.spaceLongPressBehavior = .moveInputCursor
        // state.keyboardContext.spaceLongPressBehavior = .openLocaleContextMenu
        
        /// 💡 Setup audio and haptic feedback.
        ///
        /// The code below enabled haptic feedback and plays
        /// a rocket sound when a rocket button is tapped.
        #if targetEnvironment(simulator)
        state.feedbackConfiguration.isHapticFeedbackEnabled = false
        state.feedbackConfiguration.isAudioFeedbackEnabled = false
        #else
        state.feedbackConfiguration.isHapticFeedbackEnabled = true
        #endif
        
        /// 💡 Call super to perform the base initialization.
        super.viewDidLoad()
        setupKeyboardEarlyIfNeeded()
    }
    
    private func setupKeyboardEarlyIfNeeded() {
        guard !didSetupKeyboard else { return }
        viewWillSetupKeyboard()
    }
    
    override var autocompleteText: String? {
        AutocompleteQueryResolver.queryText(for: textDocumentProxy)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        performAutocomplete()
    }

    /// This function is called whenever the keyboard should
    /// be created or updated.
    ///
    /// Here, we just create a standard system keyboard like
    /// the library does it, just to show how it's done. You
    /// can customize anything you want.
    override func viewWillSetupKeyboard() {
        guard !didSetupKeyboard else { return }
        didSetupKeyboard = true

        /// 💡 Make the demo use a standard ``SystemKeyboard``.
        setup { controller in
            SystemKeyboard(
                state: controller.state,
                services: controller.services,
                renderBackground: false,
                buttonContent: { params in
                    if params.item.action == .space {
                        SpaceBarLabel(title: "Qırımtatar tili (β)")
                    } else {
                        params.view
                    }
                },
                buttonView: { $0.view },
                emojiKeyboard: { $0.view },
                toolbar: { params in
                    params.view
                        .autocompleteToolbarStyle(.native)
                }
            )
            // .autocorrectionDisabled()
        }
    }
}
