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

    /// Tracks system menu appearance (long-press on globe) vs quick in-place cycling
    private var isCyrillicExtension: Bool { Bundle.main.bundleIdentifier == AppConfiguration.cyrillicKeyboardBundleId }

    func toggleScript() {
        guard KeyboardPreferences.cyrillicEnabled else { return }
        let isCyrillic = state.keyboardContext.locale.identifier.contains("Cyrl")
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            state.keyboardContext.locale = Locale(identifier: isCyrillic ? "crh-Latn" : "crh-Cyrl")
        }
        SpaceBarState.shared.triggerSwitchAnimation()
    }

    private static var didWarmTransliterator = false

    /// The transliteration rules compile ~50 regular expressions on first use. Do that off the main thread,
    /// and only where Cyrillic can actually be typed: the Cyrillic extension, or iPad's in-place toggle.
    private func warmTransliteratorIfNeeded() {
        guard KeyboardPreferences.cyrillicEnabled,
              isCyrillicExtension || state.keyboardContext.deviceType == .pad,
              !Self.didWarmTransliterator else { return }
        Self.didWarmTransliterator = true
        DispatchQueue.global(qos: .utility).async {
            _ = CrimeanTatarTransliterator.transliterate("а")
        }
    }

    private func applyPreferences() {
        state.autocompleteContext.isAutocompleteEnabled = KeyboardPreferences.suggestionsEnabled
        state.autocompleteContext.isAutocorrectEnabled = KeyboardPreferences.suggestionsEnabled
        if !KeyboardPreferences.suggestionsEnabled { state.autocompleteContext.suggestions = [] }
        if !KeyboardPreferences.cyrillicEnabled && !isCyrillicExtension {
            state.keyboardContext.locale = Locale(identifier: "crh-Latn")
        }
        warmTransliteratorIfNeeded()
        state.keyboardContext.objectWillChange.send()
    }

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
            baseProvider: DemoCalloutActionProvider(keyboardContext: state.keyboardContext))

        /// 💡 Setup Crimean Tatar layout provider.
        services.layoutProvider = DemoLayoutProvider()

        /// 💡 Setup Crimean Tatar style provider.
        services.styleProvider = DemoStyleProvider(
            keyboardContext: state.keyboardContext)


        /// 💡 Setup a custom keyboard locale.
        state.keyboardContext.locale = Locale(identifier: isCyrillicExtension ? "crh-Cyrl" : "crh-Latn")
        state.keyboardContext.syncTextDocumentProxy(with: self)
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
        services.spaceDragGestureHandler.verticalThreshold = 1000

        /// 💡 Enable key preview balloon popup on key tap
        state.calloutContext.inputContext.isEnabled = state.keyboardContext.deviceType == .phone || state.keyboardContext.isKeyboardFloating

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

        /// Observe text changes to update primary action (Search/Go) enabled state and autocomplete suggestions
        NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification)
            .sink { [weak self] _ in
                self?.view.setNeedsLayout()
            }
            .store(in: &cancellables)

        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let controller = Unmanaged<KeyboardViewController>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { [weak controller] in
                    controller?.refreshProxyState()
                }
            },
            "crh.key.sandboxTraitsChanged" as CFString,
            nil,
            .deliverImmediately
        )

        /// 💡 Call super to perform the base initialization.
        super.viewDidLoad()
        applyPreferences()
        viewWillSetupKeyboard()
    }

    deinit {
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.hasDictationKey = true
        view.backgroundColor = .clear
        resetHostBundleIdCache()
        state.keyboardContext.syncTextDocumentProxy(with: self)
        state.keyboardContext.hasChosenLettersInNumericField = false // new input session
        lastDocumentIdentifier = textDocumentProxy.safeDocumentIdentifier
        lastProxyKeyboardType = nil
        lastRenderSignature = nil
        syncPreferredKeyboardTypeWithProxy()

        if isCyrillicExtension {
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.cyrillicExtensionSeen")
        }
        applyPreferences()
        (services.actionHandler as? DemoActionHandler)?.resetComposition()
        TextHistoryManager.shared.reset()
        // UIKit does not expose the incoming globe gesture; opening a field must not flash a name.
        SpaceBarState.shared.resetToResting()
    }

    /// Writes what the keyboard can observe about its host (bundle id, bottom safe area, height) so that the
    /// "classic keyboard" look can be calibrated per device. Shown in the app's testing section.
    private func recordHostDiagnostics() {
        let window = view.window
        let text = String(
            format: "iOS %@ · host %@ · safeBottom %.1f/%.1f · height %.0f · width %.0f",
            UIDevice.current.systemVersion,
            hostBundleId ?? "nil",
            view.safeAreaInsets.bottom,
            window?.safeAreaInsets.bottom ?? -1,
            view.bounds.height,
            view.bounds.width
        )
        if KeyboardPreferences.defaults.string(forKey: KeyboardPreferences.hostDiagnosticsKey) != text {
            KeyboardPreferences.defaults.set(text, forKey: KeyboardPreferences.hostDiagnosticsKey)
        }
    }

    /// Many events in one key press ask for new suggestions (text change, shift change, our own edits).
    /// Each request reads the document through XPC, so requests in the same run-loop turn are merged into one.
    private var autocompletePending = false

    override func performAutocomplete() {
        guard !autocompletePending else { return }
        autocompletePending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.autocompletePending = false
            self.performAutocompleteNow()
        }
    }

    private func performAutocompleteNow() {
        super.performAutocomplete()
    }

    /// Preserve current suggestions across cursor-selection notifications fired during typing so Space can apply autocorrect.
    override func selectionWillChange(_ textInput: UITextInput?) {}
    override func selectionDidChange(_ textInput: UITextInput?) {}

    override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        state.keyboardContext.syncTextDocumentProxy(with: self)
    }

    /// Identifier of the text field the user last typed in (to detect a field switch without `viewWillAppear`).
    private var lastDocumentIdentifier: UUID?
    private var lastProxyKeyboardType: UIKeyboardType?

    /// The trait values the keyboard UI depends on. Publishing is only needed when this changes.
    private struct RenderSignature: Equatable {
        let keyboardType: UIKeyboardType?
        let returnKeyType: UIReturnKeyType?
        let autoReturnKey: Bool?
        let hasText: Bool
        let contentType: String?
        let isDark: Bool
        let cyrillicEnabled: Bool
        let suggestionsEnabled: Bool
        let classicStyle: Bool
    }
    private var lastRenderSignature: RenderSignature?

    private var currentRenderSignature: RenderSignature {
        let proxy = textDocumentProxy
        let context = state.keyboardContext
        return RenderSignature(
            keyboardType: DemoStyleProvider.effectiveProxyKeyboardType(for: context),
            returnKeyType: DemoStyleProvider.effectiveReturnKeyType(for: context),
            autoReturnKey: DemoStyleProvider.effectiveEnablesReturnKeyAutomatically(for: context),
            hasText: proxy.hasText,
            contentType: proxy.textContentType.map { $0.rawValue },
            isDark: DemoStyleProvider.effectiveIsDark(for: context),
            cyrillicEnabled: KeyboardPreferences.cyrillicEnabled,
            suggestionsEnabled: KeyboardPreferences.suggestionsEnabled,
            classicStyle: DemoStyleProvider.usesClassicGraySystemKeys(for: context)
        )
    }

    private func refreshProxyState() {
        state.keyboardContext.syncTextDocumentProxy(with: self)
        let context = state.keyboardContext
        let targetInterfaceStyle: UIUserInterfaceStyle = DemoStyleProvider.isSandboxOverrideActive(for: context)
            ? (DemoStyleProvider.effectiveIsDark(for: context) ? .dark : .light)
            : .unspecified
        if overrideUserInterfaceStyle != targetInterfaceStyle {
            overrideUserInterfaceStyle = targetInterfaceStyle
        }
        let documentID = textDocumentProxy.safeDocumentIdentifier
        if let last = lastDocumentIdentifier, last != documentID {
            state.keyboardContext.hasChosenLettersInNumericField = false // another field: start from its own default page
            lastProxyKeyboardType = nil
            resetHostBundleIdCache()
        }
        lastDocumentIdentifier = documentID
        syncPreferredKeyboardTypeWithProxy()
        // Re-render only when a trait the UI depends on changed (field traits, empty <-> non-empty for the Return key).
        let signature = currentRenderSignature
        if signature != lastRenderSignature {
            let prefsChanged = lastRenderSignature?.cyrillicEnabled != signature.cyrillicEnabled
                || lastRenderSignature?.suggestionsEnabled != signature.suggestionsEnabled
            lastRenderSignature = signature
            if prefsChanged {
                applyPreferences()
            } else {
                state.keyboardContext.objectWillChange.send()
            }
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        refreshProxyState()
    }

    override func textDidChangeAsync(_ textInput: UITextInput?) {
        super.textDidChangeAsync(textInput)
        refreshProxyState()
    }

    /// Ensures that if the text field requests a numeric keyboard, the keyboard opens on `.numeric`.
    /// `.numbersAndPunctuation` fields have a real ABC key: once the user taps it
    /// (`hasChosenLettersInNumericField`), the letters page must stay until the next input session.
    /// Pure number pads have no letter page, so they always stay numeric.
    private func syncPreferredKeyboardTypeWithProxy() {
        let context = state.keyboardContext
        let proxyType = DemoStyleProvider.effectiveProxyKeyboardType(for: context)
        let isNewOrChangedField = lastProxyKeyboardType != proxyType
        lastProxyKeyboardType = proxyType
        if isNewOrChangedField {
            context.hasChosenLettersInNumericField = false
        }
        switch proxyType {
        case .numberPad, .decimalPad, .phonePad, .asciiCapableNumberPad:
            if context.keyboardType.isAlphabetic { setKeyboardType(.numeric) }
        case .numbersAndPunctuation:
            if context.keyboardType.isAlphabetic && !context.hasChosenLettersInNumericField {
                setKeyboardType(.numeric)
            }
        default:
            if isNewOrChangedField && !context.keyboardType.isAlphabetic {
                context.keyboardType = .alphabetic(.lowercased)
            }
            let preferred = context.preferredKeyboardType
            if context.keyboardType != preferred {
                context.keyboardType = preferred
            }
        }
    }

    override var autocompleteText: String? {
        AutocompleteQueryResolver.queryText(for: textDocumentProxy)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let shouldEnableInputCallout = state.keyboardContext.deviceType == .phone || state.keyboardContext.isKeyboardFloating
        if state.calloutContext.inputContext.isEnabled != shouldEnableInputCallout {
            state.calloutContext.inputContext.isEnabled = shouldEnableInputCallout
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        recordHostDiagnostics()
        refreshProxyState()
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
    private static func keyIdentifier(for action: KeyboardAction) -> String {
        switch action {
        case .character(let text): return "key.character." + text
        case .keyboardType(.numeric): return "key.numeric"
        case .keyboardType(.symbolic): return "key.symbolic"
        case .keyboardType(.alphabetic): return "key.alphabetic"
        case .custom(let name): return "key." + name
        case .backspace: return "key.backspace"
        case .space: return "key.space"
        case .shift: return "key.shift"
        case .capsLock: return "key.capsLock"
        case .nextKeyboard: return "key.globe"
        case .primary: return "key.return"
        case .dismissKeyboard: return "key.dismiss"
        default: return "key." + String(describing: action)
        }
    }

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
                        let context = controller.state.keyboardContext
                        let isCyrillic = context.locale.identifier.contains("Cyrl")
                        let isCompact = context.deviceType == .phone || context.isKeyboardFloating
                        let isClassic = DemoStyleProvider.usesClassicGraySystemKeys(for: context)
                        SpaceBarLabel(
                            fullName: isCyrillic ? "Къырымтатарджа" : "Qırımtatarca",
                            languageCode: isCyrillic ? "КЪТ" : "QT",
                            spaceText: isCyrillic ? "Бошлукъ" : "Boşluq",
                            isCompact: isCompact,
                            isClassic: isClassic
                        )
                    } else {
                        params.view
                    }
                },
                buttonView: { params in
                    params.view.accessibilityIdentifier(Self.keyIdentifier(for: params.item.action))
                },
                emojiKeyboard: { $0.view },
                toolbar: { params in
                    if controller.state.autocompleteContext.isAutocompleteEnabled {
                        NativeAutocompleteToolbar(
                        autocompleteContext: controller.state.autocompleteContext,
                        keyboardContext: controller.state.keyboardContext,
                        autocompleteAction: params.autocompleteAction
                        )
                    }
                }
            )
        }
    }
}
