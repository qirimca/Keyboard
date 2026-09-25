//
//  KeyboardViewController.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI
import KeyboardKit
import Combine

/**
 This keyboard demonstrates how to setup KeyboardKit and how
 to customize the standard configuration.

 To use this keyboard, you must enable it in system settings
 ("Settings/General/Keyboards"). It needs full access to get
 access to features like haptic feedback.
 */
class KeyboardViewController: KeyboardInputViewController {
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        self.hasDictationKey = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.hasDictationKey = true
    }

    /// Setting hasDictationKey to true informs iOS that this keyboard handles its own dictation,
    /// thereby suppressing the default system microphone key from being inserted into the accessory bar.
    override var hasDictationKey: Bool {
        get { true }
        set { }
    }

    private var didSetupKeyboard = false
    private var cancellables = Set<AnyCancellable>()

    /// This function is called when the controller loads.
    ///
    /// Here, we make demo-specific service keyboard configs.
    override func viewDidLoad() {
        self.hasDictationKey = true
        view.backgroundColor = .clear
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
        
        /// 💡 Setup a real Crimean Tatar autocomplete provider.
        let autocompleteProvider = CrimeanTatarAutocompleteProvider(
            context: state.autocompleteContext,
            keyboardContext: state.keyboardContext
        )
        autocompleteProvider.locale = Locale(identifier: "crh")
        services.autocompleteProvider = autocompleteProvider
        
        /// 💡 Setup a demo-specific callout action provider.
        services.calloutActionProvider = StandardCalloutActionProvider(
            keyboardContext: state.keyboardContext,
            baseProvider: DemoCalloutActionProvider())
        
        /// 💡 Setup Crimean Tatar layout provider.
        services.layoutProvider = DemoLayoutProvider()
        
        /// 💡 Setup Crimean Tatar style provider.
        services.styleProvider = DemoStyleProvider(
            keyboardContext: state.keyboardContext)
        

        /// 💡 Setup a custom keyboard locale.
        state.keyboardContext.setLocale(.tatar)
        state.keyboardContext.keyboardType = state.keyboardContext.preferredKeyboardType
        state.autocompleteContext.isAutocompleteEnabled = true
        state.autocompleteContext.isAutocorrectEnabled = true

        /// 💡 Add locales to the keyboard.
        state.keyboardContext.localePresentationLocale = .current
        state.keyboardContext.locales = []
        
        /// Avoid duplicate dictation key in keyboard view.
        state.keyboardContext.keyboardDictationReplacement = nil
        
        /// 💡 Configure space long press behavior.
        state.keyboardContext.spaceLongPressBehavior = .moveInputCursor
        
        /// 💡 Enable key preview balloon popup on key tap
        state.calloutContext.inputContext.isEnabled = true
        
        /// 💡 Setup audio and haptic feedback.
        #if targetEnvironment(simulator)
        state.feedbackConfiguration.isHapticFeedbackEnabled = false
        state.feedbackConfiguration.isAudioFeedbackEnabled = false
        #else
        state.feedbackConfiguration.isHapticFeedbackEnabled = true
        #endif
        
        /// Observe shift / keyboard case changes to immediately synchronize autocomplete word casing.
        state.keyboardContext.$keyboardType
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.performAutocomplete()
                }
            }
            .store(in: &cancellables)
        
        /// 💡 Call super to perform the base initialization.
        super.viewDidLoad()
        setupKeyboardEarlyIfNeeded()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.hasDictationKey = true
        view.backgroundColor = .clear
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
        let hasText = textDocumentProxy.hasText || !(textDocumentProxy.documentContextBeforeInput?.isEmpty ?? true)
        if hasText {
            performAutocomplete()
        } else {
            state.autocompleteContext.suggestions = []
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            self?.view.setNeedsLayout()
            self?.view.layoutIfNeeded()
        })
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
                renderBackground: true,
                buttonContent: { params in
                    if params.item.action == .space {
                        SpaceBarLabel(languageCode: "QT")
                    } else {
                        params.view
                    }
                },
                buttonView: { $0.view },
                emojiKeyboard: { $0.view },
                toolbar: { params in
                    params.view
                        .autocompleteToolbarStyle(.native(for: controller.state.keyboardContext))
                }
            )
        }
    }
}
