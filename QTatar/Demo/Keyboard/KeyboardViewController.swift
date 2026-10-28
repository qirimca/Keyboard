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
class KeyboardViewController: KeyboardInputViewController, UIGestureRecognizerDelegate {

    private var didSetupKeyboard = false
    private var keyboardHeightConstraint: NSLayoutConstraint?
    private var twoFingerTrackpadPanRecognizer: UIPanGestureRecognizer?
    private var twoFingerTrackpadStartLocation: CGPoint = .zero
    private var cancellables = Set<AnyCancellable>()
    private var lastObservedUkrainianCyrillic = KeyboardPreferences.ukrainianCyrillicLayoutEnabled
    private static let prefsSyncQueue = DispatchQueue(label: "crh.key.prefsSyncQueue", qos: .utility)

    override var hasDictationKey: Bool {
        get { false }
        set { super.hasDictationKey = false }
    }

    /// Tracks whether this process is the Cyrillic extension (`crh.key.KeyboardCyrillic` or `crh.key.KeyboardUkrainian`) or a standalone keyboard extension.
    private var isUkrainianCyrillicExtension: Bool {
        AppConfiguration.isUkrainianCyrillicKeyboardExtensionBundleId(Bundle.main.bundleIdentifier)
    }
    private var isCyrillicExtension: Bool {
        AppConfiguration.isCyrillicKeyboardExtensionBundleId(Bundle.main.bundleIdentifier)
    }
    private var isRealKeyboardExtension: Bool {
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        return bundleId == AppConfiguration.keyboardBundleId
            || AppConfiguration.isCyrillicKeyboardExtensionBundleId(bundleId)
    }
    private var defaultLocaleIdentifierForExtension: String {
        isCyrillicExtension ? "crh-Cyrl" : "crh-Latn"
    }

    /// Resets the keyboard script to the extension's strict default (`crh-Latn` for `crh.key.Keyboard`,
    /// `crh-Cyrl` for `crh.key.KeyboardCyrillic`) on `viewDidLoad` and `viewWillAppear`.
    func resetToExtensionDefaultScript() {
        let targetId = defaultLocaleIdentifierForExtension
        if state.keyboardContext.locale.identifier != targetId {
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                state.keyboardContext.locale = Locale(identifier: targetId)
            }
        }
    }

    private func syncExtensionAddedPreferencesIfNeeded() {
        let defaults = KeyboardPreferences.defaults
        let isUITesting = defaults.bool(forKey: "crh.key.test.isUITesting")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || CommandLine.arguments.contains("-UITesting")
        var didMutate = false
        if isUkrainianCyrillicExtension {
            if !defaults.bool(forKey: "crh.key.ukrainianExtensionSeen") {
                defaults.set(true, forKey: "crh.key.ukrainianExtensionSeen")
                didMutate = true
            }
            if !KeyboardPreferences.cyrillicEnabled {
                KeyboardPreferences.setCyrillicEnabled(true)
                didMutate = true
            }
            if !KeyboardPreferences.ukrainianCyrillicLayoutEnabled {
                KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(true)
                didMutate = true
            }
        } else if Bundle.main.bundleIdentifier == AppConfiguration.cyrillicKeyboardBundleId {
            if !defaults.bool(forKey: "crh.key.cyrillicExtensionSeen") {
                defaults.set(true, forKey: "crh.key.cyrillicExtensionSeen")
                didMutate = true
            }
            if !KeyboardPreferences.cyrillicEnabled {
                KeyboardPreferences.setCyrillicEnabled(true)
                didMutate = true
            }
            if KeyboardPreferences.ukrainianCyrillicLayoutEnabled {
                KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(false)
                didMutate = true
            }
        } else if state.keyboardContext.deviceType == .pad && !isUITesting {
            let hasAuthoritativeList = SystemKeyboardSettings.hasAuthoritativeSystemKeyboardsList()
                || !(defaults.stringArray(forKey: SystemKeyboardSettings.cachedEnabledKeyboardsKey) ?? []).isEmpty
            let hasUkExt = SystemKeyboardSettings.isUkrainianKeyboardExtensionEnabled
            let hasCyrExt = SystemKeyboardSettings.isCyrillicKeyboardExtensionEnabled
            if hasUkExt && !defaults.bool(forKey: "crh.key.ukrainianExtensionSeen") {
                defaults.set(true, forKey: "crh.key.ukrainianExtensionSeen")
                didMutate = true
            }
            if hasCyrExt && !defaults.bool(forKey: "crh.key.cyrillicExtensionSeen") {
                defaults.set(true, forKey: "crh.key.cyrillicExtensionSeen")
                didMutate = true
            }
            if hasCyrExt || hasUkExt {
                if !KeyboardPreferences.cyrillicEnabled {
                    KeyboardPreferences.setCyrillicEnabled(true)
                    didMutate = true
                }
                if hasUkExt && !hasCyrExt && !KeyboardPreferences.ukrainianCyrillicLayoutEnabled {
                    KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(true)
                    didMutate = true
                } else if hasCyrExt && !hasUkExt && KeyboardPreferences.ukrainianCyrillicLayoutEnabled {
                    KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(false)
                    didMutate = true
                }
            } else if hasAuthoritativeList {
                if KeyboardPreferences.cyrillicEnabled {
                    KeyboardPreferences.setCyrillicEnabled(false)
                    didMutate = true
                }
            }
        }
        if didMutate {
            defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        }
    }

    func toggleScript() {
        KeyboardPreferences.refreshCachedPreferences()
        let isUITestHostPreview = !isRealKeyboardExtension
            && KeyboardPreferences.defaults.bool(forKey: "crh.key.test.isUITesting")
            && DemoStyleProvider.isSandboxOverrideActive(for: state.keyboardContext)
        guard state.keyboardContext.deviceType == .pad || isUITestHostPreview else { return }
        guard KeyboardPreferences.cyrillicEnabled else { return }
        SwipeTypingState.shared.clearKeyFrames()
        let isCyrillic = state.keyboardContext.locale.identifier.contains("Cyrl")
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            state.keyboardContext.locale = Locale(identifier: isCyrillic ? "crh-Latn" : "crh-Cyrl")
            state.keyboardContext.renderVersion &+= 1
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

    private func expectedKeyboardHeight(targetSize: CGSize? = nil) -> CGFloat {
        let context = state.keyboardContext
        let isPad = context.deviceType == .pad
        let width = targetSize?.width ?? view.bounds.width
        let isFloating = isPad && width.isFinite && width > 0 && width < 420
        let hasToolbar = state.autocompleteContext.isAutocompleteEnabled && DemoStyleProvider.shouldShowTopToolbar(for: context)
        let isLandscape: Bool = {
            if let sceneOrientation = view.window?.windowScene?.interfaceOrientation, sceneOrientation != .unknown {
                return sceneOrientation.isLandscape
            }
            if let targetSize, targetSize.width > 0 {
                let screenBounds = view.window?.windowScene?.screen.bounds ?? UIScreen.main.bounds
                let maxDim = max(screenBounds.width, screenBounds.height)
                let minDim = min(screenBounds.width, screenBounds.height)
                if abs(targetSize.width - maxDim) < abs(targetSize.width - minDim) {
                    return true
                } else if abs(targetSize.width - minDim) < abs(targetSize.width - maxDim) {
                    return false
                }
            }
            return context.interfaceOrientation.isLandscape
        }()
        return DemoStyleProvider.expectedKeyboardHeight(
            for: context,
            isLandscapeOverride: isLandscape,
            isFloatingOverride: isFloating,
            hasToolbar: hasToolbar
        )
    }

    private func updateKeyboardHeightConstraint(targetSize: CGSize? = nil) {
        guard isViewLoaded else { return }
        if keyboardHeightConstraint == nil {
            let constraint = view.heightAnchor.constraint(equalToConstant: expectedKeyboardHeight(targetSize: targetSize))
            constraint.priority = .init(999)
            constraint.identifier = "crh.key.keyboardHeightConstraint"
            keyboardHeightConstraint = constraint
        }
        guard let constraint = keyboardHeightConstraint else { return }
        let width = targetSize?.width ?? view.bounds.width
        let usesCompactLayout = state.keyboardContext.deviceType == .pad
            && width.isFinite && width > 0 && width < 420
        let targetH = expectedKeyboardHeight(targetSize: targetSize)
        let targetPriority: UILayoutPriority = .init(999)
        if constraint.priority != targetPriority {
            constraint.priority = targetPriority
        }
        if usesCompactLayout {
            let desiredSize = CGSize(width: 0, height: targetH)
            if abs(preferredContentSize.height - desiredSize.height) > 0.5 || preferredContentSize.width != 0 {
                preferredContentSize = desiredSize
            }
        } else if preferredContentSize != .zero {
            preferredContentSize = .zero
        }
        if abs(constraint.constant - targetH) > 0.5 {
            constraint.constant = targetH
        }
        if !constraint.isActive {
            constraint.isActive = true
        }
        children.first?.view.invalidateIntrinsicContentSize()
    }

    private func syncPreferencesFromDiskInBackground() {
        let beforeSug = KeyboardPreferences.suggestionsEnabled
        let beforeWl = KeyboardPreferences.wordLearningEnabled
        let beforeCyr = KeyboardPreferences.cyrillicEnabled
        let beforeUk = KeyboardPreferences.ukrainianCyrillicLayoutEnabled
        let beforeStats = KeyboardPreferences.statsEnabled
        let beforeOneHanded = KeyboardPreferences.oneHandedMode
        Self.prefsSyncQueue.async { [weak self] in
            KeyboardPreferences.defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isViewLoaded else { return }
                KeyboardPreferences.refreshCachedPreferences()
                let changed = beforeSug != KeyboardPreferences.suggestionsEnabled
                    || beforeWl != KeyboardPreferences.wordLearningEnabled
                    || beforeCyr != KeyboardPreferences.cyrillicEnabled
                    || beforeUk != KeyboardPreferences.ukrainianCyrillicLayoutEnabled
                    || beforeStats != KeyboardPreferences.statsEnabled
                    || beforeOneHanded != KeyboardPreferences.oneHandedMode
                if changed {
                    self.applyPreferences(syncDisk: false)
                    self.refreshProxyState(forceRender: false)
                }
            }
        }
    }

    private func applyPreferences(syncDisk: Bool = false) {
        if syncDisk {
            syncPreferencesFromDiskInBackground()
        }
        KeyboardPreferences.refreshCachedPreferences()
        let topBarAllowed = DemoStyleProvider.shouldShowTopToolbar(for: state.keyboardContext)
        let suggestionsMasterOn = KeyboardPreferences.suggestionsEnabled && SystemKeyboardSettings.isPredictiveTextEnabled(for: textDocumentProxy)
        let suggestionsOn = suggestionsMasterOn && topBarAllowed
        let autocorrectOn = suggestionsOn
            && (textDocumentProxy.autocorrectionType != .no)
            && SystemKeyboardSettings.isAutoCorrectionEnabled(for: textDocumentProxy)
        state.autocompleteContext.isAutocompleteEnabled = suggestionsOn
        state.autocompleteContext.isAutocorrectEnabled = autocorrectOn
        state.keyboardContext.isAutoCapitalizationEnabled = SystemKeyboardSettings.isAutoCapitalizationEnabled(for: textDocumentProxy)
        if !suggestionsOn { state.autocompleteContext.suggestions = [] }
        if !KeyboardPreferences.statsEnabled {
            KeyboardUsageStats.reclaimResourcesWhenDisabled()
        }
        SuggestionsDataBaseManager.shared.reclaimResourcesForDisabledFeatures(
            suggestionsActive: suggestionsMasterOn,
            wordLearningActive: KeyboardPreferences.wordLearningEnabled,
            autocorrectActive: KeyboardPreferences.suggestionsEnabled && SystemKeyboardSettings.isAutoCorrectionEnabled(for: textDocumentProxy)
        )
        if suggestionsMasterOn {
            SuggestionsDataBaseManager.shared.prepareAsync { [weak self] in
                guard let self, self.isViewLoaded, self.view.window != nil else { return }
                let hasText = self.textDocumentProxy.hasText || !(self.textDocumentProxy.documentContextBeforeInput?.isEmpty ?? true)
                if hasText {
                    self.performAutocomplete()
                }
            }
        }
        // UIKit owns keyboard modes. Old app preferences must not fabricate split geometry.
        state.keyboardContext.isKeyboardSplit = false
        let oneHandedNow = KeyboardPreferences.oneHandedMode
        if state.keyboardContext.oneHandedMode != oneHandedNow {
            state.keyboardContext.oneHandedMode = oneHandedNow
            SwipeTypingState.shared.clearKeyFrames()
        }
        let ukCyrNow = KeyboardPreferences.ukrainianCyrillicLayoutEnabled
        let ukCyrChanged = (ukCyrNow != lastObservedUkrainianCyrillic)
        lastObservedUkrainianCyrillic = ukCyrNow
        let isUITestHostPreview = !isRealKeyboardExtension
            && KeyboardPreferences.defaults.bool(forKey: "crh.key.test.isUITesting")
            && DemoStyleProvider.isSandboxOverrideActive(for: state.keyboardContext)

        if state.keyboardContext.deviceType != .pad {
            if isCyrillicExtension {
                if !state.keyboardContext.locale.identifier.contains("Cyrl") {
                    state.keyboardContext.locale = Locale(identifier: "crh-Cyrl")
                    SpaceBarState.shared.triggerSwitchAnimation()
                }
            } else if isUITestHostPreview && ukCyrNow && ukCyrChanged {
                (services.actionHandler as? DemoActionHandler)?.resetComposition()
                state.keyboardContext.locale = Locale(identifier: "crh-Cyrl")
                SpaceBarState.shared.triggerSwitchAnimation()
            } else if !(isUITestHostPreview && ukCyrNow) && state.keyboardContext.locale.identifier.contains("Cyrl") {
                (services.actionHandler as? DemoActionHandler)?.resetComposition()
                state.keyboardContext.locale = Locale(identifier: "crh-Latn")
                SpaceBarState.shared.triggerSwitchAnimation()
            }
        } else {
            if !isCyrillicExtension && !KeyboardPreferences.cyrillicEnabled {
                if state.keyboardContext.locale.identifier.contains("Cyrl") {
                    (services.actionHandler as? DemoActionHandler)?.resetComposition()
                    state.keyboardContext.locale = Locale(identifier: "crh-Latn")
                    SpaceBarState.shared.triggerSwitchAnimation()
                }
            } else if isUITestHostPreview && ukCyrNow && ukCyrChanged && !state.keyboardContext.locale.identifier.contains("Cyrl") {
                (services.actionHandler as? DemoActionHandler)?.resetComposition()
                state.keyboardContext.locale = Locale(identifier: "crh-Cyrl")
                SpaceBarState.shared.triggerSwitchAnimation()
            }
        }
        warmTransliteratorIfNeeded()
        SwipeTypingState.shared.isSlideToTypeSettingEnabled = SystemKeyboardSettings.isSlideToTypeEnabled
            && KeyboardPreferences.suggestionsEnabled
            && SystemKeyboardSettings.isPredictiveTextEnabled(for: textDocumentProxy)
        updateKeyboardHeightConstraint()
        state.keyboardContext.renderVersion &+= 1
    }

    /// This function is called when the controller loads.
    ///
    /// Here, we make demo-specific service keyboard configs.
    override func viewDidLoad() {
        QirimKeyDiagnosticsSubscriber.shared.start()
        if KeyboardPreferences.suggestionsEnabled && SystemKeyboardSettings.isPredictiveTextEnabled(for: textDocumentProxy) {
            SuggestionsDataBaseManager.shared.prepareAsync { [weak self] in
                guard let self, self.isViewLoaded, self.view.window != nil else { return }
                let hasText = self.textDocumentProxy.hasText || !(self.textDocumentProxy.documentContextBeforeInput?.isEmpty ?? true)
                if hasText {
                    self.performAutocomplete()
                }
            }
        }
        view.backgroundColor = .clear

        /// 💡 Setup custom keyboard behavior that respects iOS system keyboard settings.
        services.keyboardBehavior = DemoKeyboardBehavior(keyboardContext: state.keyboardContext)

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
            keyboardContext: state.keyboardContext,
            controller: self
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

        /// 💡 Avoid duplicate dictation key in keyboard view.
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

        /// Observe shift / keyboard case changes to immediately synchronize autocomplete word casing in memory.
        state.keyboardContext.$keyboardType
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] newType in
                guard let self else { return }
                if case .alphabetic(let casing) = newType {
                    let trLocale = Locale(identifier: "tr")
                    let current = self.state.autocompleteContext.suggestions
                    if !current.isEmpty {
                        self.state.autocompleteContext.suggestions = current.map { s in
                            let recased: String = {
                                switch casing {
                                case .capsLocked:
                                    return s.text.uppercased(with: trLocale)
                                case .uppercased:
                                    guard let first = s.text.first else { return s.text }
                                    return String(first).uppercased(with: trLocale) + String(s.text.dropFirst())
                                case .lowercased:
                                    return s.isUnknown ? s.text : s.text.lowercased(with: trLocale)
                                default:
                                    return s.text
                                }
                            }()
                            return Autocomplete.Suggestion(
                                text: recased,
                                title: s.title,
                                isAutocorrect: s.isAutocorrect,
                                isUnknown: s.isUnknown,
                                subtitle: s.subtitle,
                                additionalInfo: s.additionalInfo
                            )
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.performAutocomplete()
                }
            }
            .store(in: &cancellables)

        /// When Spacebar Trackpad drag ends, refresh proxy state and autocomplete once at final cursor position.
        state.keyboardContext.$isSpaceDragGestureActive
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] isActive in
                guard let self, !isActive, self.isViewLoaded, self.view.window != nil else { return }
                self.refreshProxyState()
                self.performAutocomplete()
            }
            .store(in: &cancellables)

        /// Observe text changes to update primary action (Search/Go) enabled state and autocomplete suggestions
        NotificationCenter.default.publisher(for: UITextField.textDidChangeNotification)
            .sink { [weak self] _ in
                self?.view.setNeedsLayout()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: SwipeTypingState.didCompleteSwipeNotification)
            .sink { [weak self] note in
                guard let self, let keys = note.userInfo?["keys"] as? [String] else { return }
                let points = note.userInfo?["points"] as? [CGPoint] ?? []
                let timestamps = note.userInfo?["timestamps"] as? [TimeInterval] ?? []
                let keyFrames = note.userInfo?["keyFrames"] as? [String: CGRect] ?? [:]
                (self.services.actionHandler as? DemoActionHandler)?.handleSwipePath(
                    keys,
                    trailPoints: points,
                    timestamps: timestamps,
                    keyFrames: keyFrames
                )
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: SwipeTypingState.didCompleteSlideFrom123Notification)
            .sink { [weak self] note in
                guard let self,
                      let ch = (note.userInfo?["char"] as? String) ?? (note.userInfo?["character"] as? String) else { return }
                (self.services.actionHandler as? DemoActionHandler)?.handleSlideFrom123Character(ch)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Notification.Name("crh.key.gestureEnded"))
            .sink { [weak self] _ in
                guard let self else { return }
                let twoFingerState = self.twoFingerTrackpadPanRecognizer?.state
                guard twoFingerState != .began && twoFingerState != .changed else { return }
                if self.state.keyboardContext.isSpaceDragGestureActive {
                    self.state.keyboardContext.setIsSpaceDragGestureActive(false, animated: true)
                }
                if DemoStyleProvider.isSandboxOverrideActive(for: self.state.keyboardContext),
                   let rawSwipe = KeyboardPreferences.defaults.string(forKey: "crh.key.test.demoSwipeKeys"),
                   !rawSwipe.isEmpty {
                    let swipeKeys = rawSwipe.split(separator: ",").map(String.init)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        SwipeTypingState.shared.showDemoCometTrail(forKeys: swipeKeys, holdSeconds: 8.0)
                    }
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Notification.Name("crh.key.backspaceSlideLeft"))
            .sink { [weak self] _ in
                (self?.services.actionHandler as? DemoActionHandler)?.handleBackspaceSlideLeft()
            }
            .store(in: &cancellables)

        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let controller = Unmanaged<KeyboardViewController>.fromOpaque(observer).takeUnretainedValue()
                KeyboardViewController.prefsSyncQueue.async { [weak controller] in
                    KeyboardPreferences.defaults.synchronize()
                    CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                    DispatchQueue.main.async { [weak controller] in
                        guard let controller, controller.isViewLoaded, controller.view.window != nil else { return }
                        controller.refreshProxyState(forceRender: true)
                    }
                }
            },
            "crh.key.sandboxTraitsChanged" as CFString,
            nil,
            .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let controller = Unmanaged<KeyboardViewController>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { [weak controller] in
                    guard let controller, controller.isViewLoaded else { return }
                    (controller.services.actionHandler as? DemoActionHandler)?.resetComposition()
                    controller.applyPreferences(syncDisk: true)
                    let isSandboxPreview = DemoStyleProvider.isSandboxOverrideActive(for: controller.state.keyboardContext)
                        && (controller.state.keyboardContext.deviceType == .pad
                            || (!controller.isRealKeyboardExtension && KeyboardPreferences.defaults.bool(forKey: "crh.key.test.isUITesting")))
                    if isSandboxPreview
                        && KeyboardPreferences.ukrainianCyrillicLayoutEnabled
                        && KeyboardPreferences.cyrillicEnabled
                        && !controller.state.keyboardContext.locale.identifier.contains("Cyrl") {
                        controller.state.keyboardContext.locale = Locale(identifier: "crh-Cyrl")
                        SpaceBarState.shared.triggerSwitchAnimation()
                        controller.state.keyboardContext.renderVersion &+= 1
                    } else if controller.state.keyboardContext.locale.identifier.contains("Cyrl") {
                        SpaceBarState.shared.triggerSwitchAnimation()
                        controller.state.keyboardContext.renderVersion &+= 1
                    }
                }
            },
            KeyboardPreferences.ukrainianCyrillicLayoutChangedNotification as CFString,
            nil,
            .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let controller = Unmanaged<KeyboardViewController>.fromOpaque(observer).takeUnretainedValue()
                KeyboardViewController.prefsSyncQueue.async { [weak controller] in
                    KeyboardPreferences.defaults.synchronize()
                    CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                    DispatchQueue.main.async { [weak controller] in
                        guard let controller, controller.isViewLoaded else { return }
                        KeyboardPreferences.refreshCachedPreferences()
                        let mode = KeyboardPreferences.oneHandedMode
                        if controller.state.keyboardContext.oneHandedMode != mode {
                            SwipeTypingState.shared.clearKeyFrames()
                            controller.state.keyboardContext.oneHandedMode = mode
                            controller.state.keyboardContext.renderVersion &+= 1
                        }
                    }
                }
            },
            KeyboardPreferences.oneHandedModeChangedNotification as CFString,
            nil,
            .deliverImmediately
        )

        /// Configure initial preferences and default script BEFORE `super.viewDidLoad()` mounts `SystemKeyboard`,
        /// preventing redundant SwiftUI hierarchy rebuilds on cold start.
        self.hasDictationKey = false
        resetToExtensionDefaultScript()
        syncExtensionAddedPreferencesIfNeeded()
        applyPreferences(syncDisk: false)
        super.viewDidLoad()
        installTwoFingerTrackpadGestureIfNeeded()
        QirimKeyDiagnosticsSubscriber.recordLifecycleEvent(
            "viewDidLoad",
            details: ["locale": state.keyboardContext.locale.identifier]
        )
    }

    private var isTwoFingerTrackpadActive = false

    private func installTwoFingerTrackpadGestureIfNeeded() {
        guard UIDevice.current.userInterfaceIdiom == .pad,
              state.keyboardContext.deviceType == .pad else {
            if let existing = twoFingerTrackpadPanRecognizer {
                existing.isEnabled = false
                view.removeGestureRecognizer(existing)
                twoFingerTrackpadPanRecognizer = nil
            }
            return
        }
        guard twoFingerTrackpadPanRecognizer == nil else {
            updateTwoFingerTrackpadEligibility()
            return
        }
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerTrackpadPan(_:)))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2
        pan.cancelsTouchesInView = false
        pan.delaysTouchesBegan = false
        pan.delaysTouchesEnded = false
        pan.delegate = self
        pan.isEnabled = !state.keyboardContext.isKeyboardFloating && !state.keyboardContext.isKeyboardSplit
        view.addGestureRecognizer(pan)
        twoFingerTrackpadPanRecognizer = pan
    }

    private func updateTwoFingerTrackpadEligibility() {
        let eligible = UIDevice.current.userInterfaceIdiom == .pad
            && state.keyboardContext.deviceType == .pad
            && !state.keyboardContext.isKeyboardFloating
            && !state.keyboardContext.isKeyboardSplit
        if twoFingerTrackpadPanRecognizer?.isEnabled != eligible {
            twoFingerTrackpadPanRecognizer?.isEnabled = eligible
        }
        if !eligible && (isTwoFingerTrackpadActive || state.keyboardContext.isSpaceDragGestureActive) {
            isTwoFingerTrackpadActive = false
            state.keyboardContext.setIsSpaceDragGestureActive(false, animated: false)
        }
    }

    @objc private func handleTwoFingerTrackpadPan(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .ended, .cancelled, .failed:
            if isTwoFingerTrackpadActive {
                (services.actionHandler as? DemoActionHandler)?.markTwoFingerTrackpadEnded()
                isTwoFingerTrackpadActive = false
            }
            if state.keyboardContext.isSpaceDragGestureActive {
                state.keyboardContext.setIsSpaceDragGestureActive(false, animated: true)
            }
            return
        default:
            break
        }
        guard UIDevice.current.userInterfaceIdiom == .pad,
              state.keyboardContext.deviceType == .pad,
              !state.keyboardContext.isKeyboardFloating,
              !state.keyboardContext.isKeyboardSplit else { return }
        let location = recognizer.location(in: view)
        let translation = recognizer.translation(in: view)
        let panDistance = hypot(translation.x, translation.y)
        switch recognizer.state {
        case .began:
            twoFingerTrackpadStartLocation = location
        case .changed:
            guard panDistance >= 14.0 || isTwoFingerTrackpadActive else { return }
            if !isTwoFingerTrackpadActive {
                isTwoFingerTrackpadActive = true
                (services.actionHandler as? DemoActionHandler)?.cancelActiveKeyGesturesForTrackpad()
                KeyFlickState.shared.reset()
                SwipeTypingState.shared.reset(clearTrailImmediately: true)
                state.calloutContext.inputContext.reset()
                state.calloutContext.actionContext.reset()
                services.spaceDragGestureHandler.currentDragStartLocation = nil
                services.spaceDragGestureHandler.handleDragGesture(
                    from: twoFingerTrackpadStartLocation,
                    to: twoFingerTrackpadStartLocation
                )
                state.keyboardContext.setIsSpaceDragGestureActive(true, animated: true)
                if state.feedbackConfiguration.isHapticFeedbackEnabled {
                    HapticFeedback.lightImpact.trigger()
                }
            }
            services.spaceDragGestureHandler.handleDragGesture(
                from: twoFingerTrackpadStartLocation,
                to: location
            )
        default:
            break
        }
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer === twoFingerTrackpadPanRecognizer {
            return UIDevice.current.userInterfaceIdiom == .pad
                && state.keyboardContext.deviceType == .pad
                && !state.keyboardContext.isKeyboardFloating
                && !state.keyboardContext.isKeyboardSplit
        }
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        return true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        if gestureRecognizer === twoFingerTrackpadPanRecognizer && otherGestureRecognizer is UIPinchGestureRecognizer {
            return true
        }
        return false
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        SuggestionsDataBaseManager.shared.releaseMemory()
    }

    private func refreshSupplementaryLexicon() {
        guard KeyboardPreferences.suggestionsEnabled && SystemKeyboardSettings.isAutoCorrectionEnabled(for: textDocumentProxy) else {
            SuggestionsDataBaseManager.shared.updateSupplementaryLexicon([:])
            return
        }
        requestSupplementaryLexicon { lexicon in
            var map: [String: String] = [:]
            for entry in lexicon.entries {
                let key = entry.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
                let val = entry.documentText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty, !val.isEmpty else { continue }
                map[key] = val
            }
            SuggestionsDataBaseManager.shared.updateSupplementaryLexicon(map)
        }
    }

    deinit {
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer)
    }

    override func viewWillAppear(_ animated: Bool) {
        self.hasDictationKey = false
        SuggestionsDataBaseManager.shared.resumeAccess()
        isResettingDocumentState = false
        view.backgroundColor = .clear
        if view.bounds.width >= 420 && preferredContentSize != .zero {
            preferredContentSize = .zero
        }
        resetHostBundleIdCache()
        state.keyboardContext.syncTextDocumentProxy(with: self)
        state.keyboardContext.syncIsFloating(with: self)
        if state.keyboardContext.traitCollection != traitCollection {
            state.keyboardContext.traitCollection = traitCollection
        }
        let sandboxActive = DemoStyleProvider.isSandboxOverrideActive(for: state.keyboardContext)
        let uiTestTs = KeyboardPreferences.defaults.double(forKey: "crh.key.test.uiTestingTimestamp")
        let isRecentUITest = uiTestTs > 0 && abs(Date().timeIntervalSince1970 - uiTestTs) < 600.0
        if !sandboxActive && !isRecentUITest && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil && !CommandLine.arguments.contains("-UITesting") {
            let defaults = KeyboardPreferences.defaults
            for key in [
                "crh.key.test.isUITesting",
                "crh.key.test.allowSpaceBarBreathing",
                "crh.key.test.holdCallout",
                "crh.key.test.demoSwipeKeys",
                "crh.key.test.useModernPillCallout"
            ] {
                defaults.removeObject(forKey: key)
            }
        }
        state.keyboardContext.proxyKeyboardTypeOverride = sandboxActive
            ? DemoStyleProvider.effectiveProxyKeyboardType(for: state.keyboardContext)
            : nil
        state.keyboardContext.hasChosenLettersInNumericField = false // new input session
        lastDocumentIdentifier = textDocumentProxy.safeDocumentIdentifier
        lastProxyKeyboardType = nil
        resetToExtensionDefaultScript()
        syncExtensionAddedPreferencesIfNeeded()
        syncPreferredKeyboardTypeWithProxy()

        (services.actionHandler as? DemoActionHandler)?.resetComposition()
        TextHistoryManager.shared.reset()
        SpaceBarState.shared.prepareForAppearance()
        GreetingBannerState.shared.prepareForAppearance(reshuffle: true)
        refreshProxyState(forceRender: true)
        updateTwoFingerTrackpadEligibility()
        syncPreferencesFromDiskInBackground()
        super.viewWillAppear(animated)
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshProxyState(forceRender: previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle)
    }

    /// Many events in one key press ask for new suggestions (text change, shift change, our own edits).
    /// Each request reads the document through XPC, so requests in the same run-loop turn are merged into one.
    private var autocompletePending = false
    /// Prevents reading `textDocumentProxy` (`_controllerState`) on the main thread while XPC mutates it between `textWillChange` and `textDidChange`.
    private var isResettingDocumentState = false

    override func performAutocomplete() {
        guard !isResettingDocumentState, isViewLoaded, view.window != nil else { return }
        guard !autocompletePending else { return }
        autocompletePending = true
        DispatchQueue.main.async { [weak self] in
            guard let self, self.autocompletePending else { return }
            self.autocompletePending = false
            self.performAutocompleteNow()
        }
    }

    private func performAutocompleteNow() {
        guard !isResettingDocumentState, isViewLoaded, view.window != nil else { return }
        if (services.actionHandler as? DemoActionHandler)?.hasActivePostSwipeSuggestions == true {
            return
        }
        super.performAutocomplete()
    }

    /// Preserve current suggestions across cursor-selection notifications fired during typing so Space can apply autocorrect.
    override func selectionWillChange(_ textInput: UITextInput?) {}
    override func selectionDidChange(_ textInput: UITextInput?) {}

    override func textWillChange(_ textInput: UITextInput?) {
        isResettingDocumentState = true
        autocompletePending = false
        super.textWillChange(textInput)
        DispatchQueue.main.async { [weak self] in
            self?.isResettingDocumentState = false
        }
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
        let ukrainianCyrillicLayoutEnabled: Bool
        let suggestionsEnabled: Bool
        let isEmojiKeyboardEnabled: Bool
        let splitEnabled: Bool
        let oneHandedMode: String
        let isFloating: Bool
        let localeIdentifier: String
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
            ukrainianCyrillicLayoutEnabled: KeyboardPreferences.ukrainianCyrillicLayoutEnabled,
            suggestionsEnabled: KeyboardPreferences.suggestionsEnabled,
            isEmojiKeyboardEnabled: SystemKeyboardSettings.isEmojiKeyboardEnabled,
            splitEnabled: context.isKeyboardSplit,
            oneHandedMode: KeyboardPreferences.oneHandedMode,
            isFloating: context.isKeyboardFloating,
            localeIdentifier: context.locale.identifier
        )
    }

    private func refreshProxyState(forceRender: Bool = false) {
        if forceRender {
            isResettingDocumentState = false
        }
        guard !isResettingDocumentState else { return }
        let documentID = textDocumentProxy.safeDocumentIdentifier
        if let last = lastDocumentIdentifier, last != documentID {
            resetHostBundleIdCache()
            state.keyboardContext.hasChosenLettersInNumericField = false // another field: start from its own default page
            lastProxyKeyboardType = nil
        }
        lastDocumentIdentifier = documentID
        state.keyboardContext.syncTextDocumentProxy(with: self)
        let context = state.keyboardContext
        let isSandboxActive = DemoStyleProvider.isSandboxOverrideActive(for: context)
        context.proxyKeyboardTypeOverride = isSandboxActive
            ? DemoStyleProvider.effectiveProxyKeyboardType(for: context)
            : nil
        if isSandboxActive,
           let mode = KeyboardPreferences.defaults.string(forKey: "crh.key.test.fieldMode") {
            switch mode {
            case "field.email", "field.url", "field.numbers", "field.search":
                context.autocapitalizationTypeOverride = Keyboard.AutocapitalizationType.none
            default:
                context.autocapitalizationTypeOverride = .sentences
            }
        } else {
            context.autocapitalizationTypeOverride = nil
        }
        if isSandboxActive,
           let rawSwipe = KeyboardPreferences.defaults.string(forKey: "crh.key.test.demoSwipeKeys"),
           !rawSwipe.isEmpty {
            let swipeKeys = rawSwipe.split(separator: ",").map(String.init)
            for delay in [0.35, 0.85, 1.45] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    SwipeTypingState.shared.showDemoCometTrail(forKeys: swipeKeys, holdSeconds: 8.0)
                }
            }
        }
        let holdCalloutForUITest = isSandboxActive && KeyboardPreferences.defaults.bool(forKey: "crh.key.test.holdCallout")
        state.calloutContext.inputContext.minimumVisibleDuration = holdCalloutForUITest ? 0.55 : 0.09
        Gestures.Defaults.longPressDelay = holdCalloutForUITest ? 0.60 : 0.30
        let topBarAllowed = DemoStyleProvider.shouldShowTopToolbar(for: context)
        let suggestionsOn = KeyboardPreferences.suggestionsEnabled
            && SystemKeyboardSettings.isPredictiveTextEnabled(for: textDocumentProxy)
            && topBarAllowed
        if state.autocompleteContext.isAutocompleteEnabled != suggestionsOn {
            state.autocompleteContext.isAutocompleteEnabled = suggestionsOn
        }
        if !suggestionsOn && !state.autocompleteContext.suggestions.isEmpty {
            state.autocompleteContext.suggestions = []
        }
        let shouldAutocorrect = suggestionsOn
            && SystemKeyboardSettings.isAutoCorrectionEnabled(for: textDocumentProxy)
            && (textDocumentProxy.autocorrectionType != .no)
        if state.autocompleteContext.isAutocorrectEnabled != shouldAutocorrect {
            state.autocompleteContext.isAutocorrectEnabled = shouldAutocorrect
        }
        let targetCapitalize = SystemKeyboardSettings.isAutoCapitalizationEnabled(for: textDocumentProxy)
        if context.isAutoCapitalizationEnabled != targetCapitalize {
            context.isAutoCapitalizationEnabled = targetCapitalize
        }
        if overrideUserInterfaceStyle != .unspecified {
            overrideUserInterfaceStyle = .unspecified
        }
        let systemDark = traitCollection.userInterfaceStyle == .dark
        let baseTraits = UITraitCollection(traitsFrom: [
            traitCollection,
            UITraitCollection(userInterfaceStyle: systemDark ? .dark : .light)
        ])
        if context.traitCollection != baseTraits {
            context.traitCollection = baseTraits
        }
        let effectiveDark = DemoStyleProvider.effectiveIsDark(for: context)
        let resolvedTraits = UITraitCollection(traitsFrom: [
            traitCollection,
            UITraitCollection(userInterfaceStyle: effectiveDark ? .dark : .light)
        ])
        if context.traitCollection != resolvedTraits {
            context.traitCollection = resolvedTraits
        }
        let targetViewStyle: UIUserInterfaceStyle = effectiveDark ? .dark : .light
        if view.overrideUserInterfaceStyle != targetViewStyle {
            view.overrideUserInterfaceStyle = targetViewStyle
        }
        children.forEach { child in
            if child.overrideUserInterfaceStyle != targetViewStyle {
                child.overrideUserInterfaceStyle = targetViewStyle
            }
        }
        syncPreferredKeyboardTypeWithProxy()
        let signature = currentRenderSignature
        let isSearchField = DemoStyleProvider.isSearchField(for: context)
        let isDocEmpty = !signature.hasText
            && (textDocumentProxy.documentContextBeforeInput ?? "").isEmpty
            && (textDocumentProxy.documentContextAfterInput ?? "").isEmpty
        if !isDocEmpty || isSearchField {
            GreetingBannerState.shared.dismissForTyping()
            if suggestionsOn {
                let dbReady = SuggestionsDataBaseManager.shared.isReady
                if isSearchField && isDocEmpty {
                    let starter = dbReady
                        ? ((services.autocompleteProvider as? CrimeanTatarAutocompleteProvider)?.suggestionsNow(for: "") ?? [])
                        : []
                    if !starter.isEmpty {
                        state.autocompleteContext.suggestions = starter
                    } else {
                        performAutocomplete()
                    }
                } else if forceRender || lastRenderSignature?.hasText != signature.hasText || lastRenderSignature?.keyboardType != signature.keyboardType {
                    let immediate = dbReady
                        ? ((services.autocompleteProvider as? CrimeanTatarAutocompleteProvider)?.suggestionsNow(for: autocompleteText ?? "") ?? [])
                        : []
                    if !immediate.isEmpty {
                        state.autocompleteContext.suggestions = immediate
                    } else {
                        performAutocomplete()
                    }
                }
            }
        } else {
            if !state.autocompleteContext.suggestions.isEmpty {
                state.autocompleteContext.suggestions = []
            }
            if lastRenderSignature?.hasText == true
                || lastRenderSignature?.keyboardType != signature.keyboardType
                || GreetingBannerState.shared.isDismissedForCurrentSession {
                GreetingBannerState.shared.prepareForAppearance(reshuffle: false)
            }
        }
        if signature != lastRenderSignature || forceRender {
            let prefsChanged = lastRenderSignature == nil
                || lastRenderSignature?.cyrillicEnabled != signature.cyrillicEnabled
                || lastRenderSignature?.ukrainianCyrillicLayoutEnabled != signature.ukrainianCyrillicLayoutEnabled
                || lastRenderSignature?.suggestionsEnabled != signature.suggestionsEnabled
                || lastRenderSignature?.splitEnabled != signature.splitEnabled
                || lastRenderSignature?.oneHandedMode != signature.oneHandedMode
            if prefsChanged {
                applyPreferences(syncDisk: false)
            } else {
                updateKeyboardHeightConstraint()
                state.keyboardContext.renderVersion &+= 1
            }
            lastRenderSignature = currentRenderSignature
            view.setNeedsLayout()
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        isResettingDocumentState = false
        if state.keyboardContext.isSpaceDragGestureActive {
            return
        }
        state.keyboardContext.proxyKeyboardTypeOverride = DemoStyleProvider.isSandboxOverrideActive(for: state.keyboardContext)
            ? DemoStyleProvider.effectiveProxyKeyboardType(for: state.keyboardContext)
            : nil
        super.textDidChange(textInput)
        refreshProxyState()
    }

    override func textDidChangeAsync(_ textInput: UITextInput?) {
        guard !isResettingDocumentState, !state.keyboardContext.isSpaceDragGestureActive, isViewLoaded, view.window != nil else { return }
        super.textDidChangeAsync(textInput)
    }

    /// Ensures that if the text field requests a numeric keyboard, the keyboard opens on `.numeric`.
    /// `.numbersAndPunctuation` fields have a real ABC key: once the user taps it
    /// (`hasChosenLettersInNumericField`), the letters page must stay until the next input session.
    /// Pure number pads have no letter page, so they always stay numeric.
    private func syncPreferredKeyboardTypeWithProxy() {
        let context = state.keyboardContext
        let proxyType = DemoStyleProvider.effectiveProxyKeyboardType(for: context)
        context.proxyKeyboardTypeOverride = DemoStyleProvider.isSandboxOverrideActive(for: context) ? proxyType : nil
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
        guard !isResettingDocumentState else { return nil }
        return AutocompleteQueryResolver.queryText(for: textDocumentProxy)
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        state.keyboardContext.syncIsFloating(with: self)
        updateKeyboardHeightConstraint()
        updateTwoFingerTrackpadEligibility()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        view.clipsToBounds = false
        inputView?.clipsToBounds = false
        children.first?.view.clipsToBounds = false
        updateKeyboardHeightConstraint()
        updateTwoFingerTrackpadEligibility()
        let shouldEnableInputCallout = state.keyboardContext.deviceType == .phone || state.keyboardContext.isKeyboardFloating
        if state.calloutContext.inputContext.isEnabled != shouldEnableInputCallout {
            state.calloutContext.inputContext.isEnabled = shouldEnableInputCallout
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        refreshSupplementaryLexicon()
        let seenKey = isUkrainianCyrillicExtension
            ? "crh.key.ukrainianExtensionSeen"
            : (isCyrillicExtension ? "crh.key.cyrillicExtensionSeen" : "crh.key.primaryExtensionSeen")
        if !KeyboardPreferences.defaults.bool(forKey: seenKey) {
            KeyboardPreferences.defaults.set(true, forKey: seenKey)
        }
        if KeyboardPreferences.suggestionsEnabled && SystemKeyboardSettings.isPredictiveTextEnabled(for: textDocumentProxy) {
            SuggestionsDataBaseManager.shared.prepareAsync { [weak self] in
                guard let self, self.isViewLoaded, self.view.window != nil else { return }
                let hasText = self.textDocumentProxy.hasText || !(self.textDocumentProxy.documentContextBeforeInput?.isEmpty ?? true)
                let isSearch = DemoStyleProvider.isSearchField(for: self.state.keyboardContext)
                if hasText || isSearch {
                    self.performAutocomplete()
                }
            }
        }
        state.keyboardContext.syncIsFloating(with: self)
        updateTwoFingerTrackpadEligibility()
        SpaceBarState.shared.triggerSwitchAnimation()
        updateKeyboardHeightConstraint()
        refreshProxyState()
        QirimKeyDiagnosticsSubscriber.recordLifecycleEvent(
            "viewDidAppear",
            details: [
                "boundsWidth": "\(Int(view.bounds.width))",
                "boundsHeight": "\(Int(view.bounds.height))",
                "isFloating": "\(state.keyboardContext.isKeyboardFloating)",
                "preferredContentHeight": "\(Int(preferredContentSize.height))",
                "constraintHeight": "\(Int(keyboardHeightConstraint?.constant ?? 0))",
                "constraintPriority": "\(Int(keyboardHeightConstraint?.priority.rawValue ?? 0))",
                "locale": state.keyboardContext.locale.identifier
            ]
        )
        let hasText = textDocumentProxy.hasText || !(textDocumentProxy.documentContextBeforeInput?.isEmpty ?? true)
        let isSearch = DemoStyleProvider.isSearchField(for: state.keyboardContext)
        if hasText || isSearch {
            performAutocomplete()
        } else {
            state.autocompleteContext.suggestions = []
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        autocompletePending = false
        isTwoFingerTrackpadActive = false
        if state.keyboardContext.isSpaceDragGestureActive {
            state.keyboardContext.setIsSpaceDragGestureActive(false, animated: false)
        }
        SuggestionsDataBaseManager.shared.suspendAccess()
        KeyboardUsageStats.scheduleCrossProcessSync(immediate: true)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        SwipeTypingState.shared.clearKeyFrames()
        state.keyboardContext.syncIsFloating(with: self, targetWidth: size.width)
        updateKeyboardHeightConstraint(targetSize: size)
        updateTwoFingerTrackpadEligibility()
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            self.state.keyboardContext.syncIsFloating(with: self, targetWidth: size.width)
            self.updateKeyboardHeightConstraint(targetSize: size)
            self.updateTwoFingerTrackpadEligibility()
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            guard let self else { return }
            SwipeTypingState.shared.clearKeyFrames()
            self.state.keyboardContext.syncIsFloating(with: self)
            self.updateKeyboardHeightConstraint()
            self.updateTwoFingerTrackpadEligibility()
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
        case .keyboardType(.emojis): return "key.emojis"
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
                    let context = controller.state.keyboardContext
                    let isBottomRow = CrimeanTatarIPadKeyboardLayoutProvider.isBottomRowCharacterItem(params.item, context: context)
                    let isPro5Row = CrimeanTatarIPadKeyboardLayoutProvider.isIPadPro5RowLayout(context) && context.keyboardType.isAlphabetic
                    let isTopNumberRow = isPro5Row && params.item.size.height < DemoStyleProvider.rowHeight(forRowAt: 1, totalRows: 5, context: context) - 1.0
                    let itemRow = isBottomRow ? (isPro5Row ? 4 : 3) : (isTopNumberRow ? 0 : (isPro5Row ? 2 : 0))
                    if params.item.action == .space {
                        let isCyrillic = context.locale.identifier.contains("Cyrl")
                        let isUkrainianCyr = isCyrillic && KeyboardPreferences.ukrainianCyrillicLayoutEnabled
                        let isCompact = context.deviceType == .phone || context.isKeyboardFloating || context.isKeyboardSplit
                        let isDark = DemoStyleProvider.effectiveIsDark(for: context)
                        SpaceBarLabel(
                            fullName: isCyrillic ? (isUkrainianCyr ? "Кʼиримтатарджа" : "Къырымтатарджа") : "Qırımtatarca",
                            languageCode: isCyrillic ? (isUkrainianCyr ? "Кʼ" : "КЪ") : "QT",
                            isCompact: isCompact,
                            isDarkOverride: isDark,
                            isSpaceDragActive: context.isSpaceDragGestureActive
                        )
                    } else if let dual = CrimeanTatarIPadKeyboardLayoutProvider.iPadProDualLegend(
                        for: params.item.action,
                        row: itemRow,
                        context: context
                    ) {
                        let isLandscape = context.interfaceOrientation.isLandscape
                        let isDark = DemoStyleProvider.effectiveIsDark(for: context)
                        IPadProDualKeyContentView(
                            topSymbol: dual.top,
                            bottomSymbol: dual.bottom,
                            isLandscape: isLandscape,
                            isDark: isDark
                        )
                    } else if let flick = CrimeanTatarIPadKeyboardLayoutProvider.flickSymbol(
                        for: params.item.action,
                        row: itemRow,
                        context: context
                    ) {
                        let isLandscape = context.interfaceOrientation.isLandscape
                        let isDark = DemoStyleProvider.effectiveIsDark(for: context)
                        FlickKeyContentView(
                            action: params.item.action,
                            flickSymbol: flick,
                            isLandscape: isLandscape,
                            isDark: isDark
                        ) {
                            params.view
                        }
                    } else if context.deviceType == .pad,
                              !context.isKeyboardFloating,
                              !context.isKeyboardSplit,
                              !CrimeanTatarIPadKeyboardLayoutProvider.isIPadPro5RowLayout(context),
                              SystemKeyboardSettings.isKeyFlicksEnabled,
                              itemRow == 0,
                              case .character = params.item.action {
                        let isLandscape = context.interfaceOrientation.isLandscape
                        let isDark = DemoStyleProvider.effectiveIsDark(for: context)
                        FlickKeyContentView(
                            action: params.item.action,
                            flickSymbol: nil,
                            isLandscape: isLandscape,
                            isDark: isDark
                        ) {
                            params.view
                        }
                    } else {
                        params.view
                    }
                },
                buttonView: { params in
                    params.view.accessibilityIdentifier(Self.keyIdentifier(for: params.item.action))
                },
                emojiKeyboard: { $0.view },
                toolbar: { params in
                    if controller.state.autocompleteContext.isAutocompleteEnabled,
                       DemoStyleProvider.shouldShowTopToolbar(for: controller.state.keyboardContext) {
                        NativeAutocompleteToolbar(
                            autocompleteContext: controller.state.autocompleteContext,
                            keyboardContext: controller.state.keyboardContext,
                            autocompleteAction: params.autocompleteAction
                        )
                    }
                }
            )
            .environment(\.colorScheme, DemoStyleProvider.effectiveIsDark(for: controller.state.keyboardContext) ? .dark : .light)
        }
    }
}

final class KeyFlickState {
    static let shared = KeyFlickState()

    struct Event {
        let action: KeyboardAction
        let progress: CGFloat
    }

    let subject = PassthroughSubject<Event, Never>()
    private var currentAction: KeyboardAction?
    private var currentProgress: CGFloat = 0
    private var endObserver: NSObjectProtocol?

    private init() {
        endObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name("crh.key.gestureEnded"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.reset()
        }
    }

    func update(action: KeyboardAction, progress: CGFloat) {
        let clamped = min(max(progress, 0), 1)
        if let prev = currentAction, prev != action {
            subject.send(Event(action: prev, progress: 0))
            currentProgress = 0
        }
        currentAction = action
        if abs(clamped - currentProgress) > 0.001 || (clamped == 0 && currentProgress != 0) || (clamped == 1 && currentProgress != 1) {
            currentProgress = clamped
            subject.send(Event(action: action, progress: clamped))
        }
    }

    func reset() {
        guard let active = currentAction else { return }
        currentAction = nil
        currentProgress = 0
        subject.send(Event(action: active, progress: 0))
    }
}

/// Renders an iPad Docked key with an optional top secondary flick symbol that smoothly slides down
/// into the center, scales up to primary font size, and transitions from gray to solid black/white
/// while the primary character slides down and fades out during a downward key flick.
struct FlickKeyContentView<PrimaryContent: View>: View {
    let action: KeyboardAction
    let flickSymbol: String?
    let isLandscape: Bool
    let isDark: Bool
    @ViewBuilder let primaryContent: () -> PrimaryContent

    @State private var progress: CGFloat = 0

    private var primaryFontSize: CGFloat { isLandscape ? 25.5 : 23.0 }
    private var restingScale: CGFloat { isLandscape ? (13.5 / 25.5) : (11.5 / 23.0) }
    private var flickGlyphBaselineCompensation: CGFloat {
        switch flickSymbol {
        case ",", ".", "_":
            return isLandscape ? -3.0 : -2.5
        default:
            return 0
        }
    }
    private var restingOffsetY: CGFloat { (isLandscape ? -20.5 : -14.5) + flickGlyphBaselineCompensation }
    private var restingOpacity: Double { isDark ? 0.42 : 0.34 }
    private var restingPrimaryOffsetY: CGFloat { isLandscape ? 7.0 : 6.0 }

    var body: some View {
        let currentFlickScale = restingScale + (1.0 - restingScale) * progress
        let currentFlickOffsetY = restingOffsetY * (1.0 - progress)
        let currentFlickOpacity = restingOpacity + (1.0 - restingOpacity) * Double(progress)

        let currentPrimaryOffsetY = restingPrimaryOffsetY + progress * (isLandscape ? 14.0 : 11.0)
        let currentPrimaryScale = 1.0 - progress * 0.22
        let currentPrimaryOpacity = max(0.0, 1.0 - Double(progress) * 1.0)

        ZStack {
            primaryContent()
                .scaleEffect(currentPrimaryScale)
                .offset(y: currentPrimaryOffsetY)
                .opacity(currentPrimaryOpacity)

            if let flickSymbol {
                Text(flickSymbol)
                    .font(.system(size: primaryFontSize, weight: .regular))
                    .foregroundColor((isDark ? Color.white : Color.black).opacity(currentFlickOpacity))
                    .scaleEffect(currentFlickScale)
                    .offset(y: currentFlickOffsetY)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .onReceive(KeyFlickState.shared.subject) { event in
            guard event.action == action else { return }
            if event.progress == 0 {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                    progress = 0
                }
            } else {
                withAnimation(.interactiveSpring(response: 0.04, dampingFraction: 0.96)) {
                    progress = event.progress
                }
            }
        }
        .onChange(of: action) { _ in
            progress = 0
        }
    }
}

/// Renders a 5-row iPad Pro dual-legend keycap (e.g., `/` above `\`, `!` above `1`, `:` above `,`)
/// with both legends in solid primary text color matching native iPad Pro hardware-style keycaps.
struct IPadProDualKeyContentView: View {
    let topSymbol: String
    let bottomSymbol: String
    let isLandscape: Bool
    let isDark: Bool

    var body: some View {
        let primaryColor = isDark ? Color.white : Color.black
        let fontSize: CGFloat = isLandscape ? 16.0 : 14.0
        VStack(spacing: isLandscape ? 3.0 : 1.5) {
            Text(topSymbol)
                .font(.system(size: fontSize, weight: .regular))
                .foregroundColor(primaryColor)
                .lineLimit(1)
            Text(bottomSymbol)
                .font(.system(size: fontSize, weight: .regular))
                .foregroundColor(primaryColor)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityValue(bottomSymbol)
    }
}

