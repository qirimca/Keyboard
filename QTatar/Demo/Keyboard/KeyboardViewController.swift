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
    private var didInstallSplitGesture = false
    private var isTransitioningToFloating = false
    private var keyboardHeightConstraint: NSLayoutConstraint?
    private var cancellables = Set<AnyCancellable>()
    private var lastObservedUkrainianCyrillic = KeyboardPreferences.ukrainianCyrillicLayoutEnabled

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

    func requestFloatingKeyboardMode() {
        isTransitioningToFloating = true
        keyboardHeightConstraint?.isActive = false
        preferredContentSize = CGSize(width: 320, height: 254)
        KeyboardPreferences.setSplitKeyboardEnabled(false)
        state.keyboardContext.lastObservedSystemSplit = false
        Self.invokeSystemSetSplit(false)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            state.keyboardContext.isKeyboardSplit = false
            state.keyboardContext.isKeyboardFloating = true
            state.keyboardContext.renderVersion &+= 1
        }
        updateSplitBackdropMask()
        children.first?.view.invalidateIntrinsicContentSize()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("crh.key.requestFloatingKeyboard" as CFString),
            nil,
            nil,
            true
        )
        DispatchQueue.main.async { [weak self] in
            Self.invokeSystemSetFloating(true)
            self?.clampFloatingKeyboardToScreenBounds()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.clampFloatingKeyboardToScreenBounds()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            self?.clampFloatingKeyboardToScreenBounds()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) { [weak self] in
            guard let self else { return }
            self.isTransitioningToFloating = false
            self.state.keyboardContext.syncIsFloating(with: self)
            self.updateKeyboardHeightConstraint()
            self.clampFloatingKeyboardToScreenBounds()
        }
    }

    func requestDockedKeyboardMode() {
        isTransitioningToFloating = false
        preferredContentSize = .zero
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            state.keyboardContext.isKeyboardFloating = false
            state.keyboardContext.renderVersion &+= 1
        }
        updateKeyboardHeightConstraint()
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("crh.key.requestDockedKeyboard" as CFString),
            nil,
            nil,
            true
        )
        DispatchQueue.main.async {
            Self.invokeSystemSetFloating(false)
        }
    }

    func setSplitKeyboardMode(_ enabled: Bool) {
        guard state.keyboardContext.deviceSupportsSplitKeyboard else {
            if state.keyboardContext.isKeyboardSplit {
                state.keyboardContext.isKeyboardSplit = false
            }
            KeyboardPreferences.setSplitKeyboardEnabled(false)
            return
        }
        state.keyboardContext.lastObservedSystemSplit = enabled
        KeyboardPreferences.setSplitKeyboardEnabled(enabled)
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            if state.keyboardContext.isKeyboardSplit != enabled {
                state.keyboardContext.isKeyboardSplit = enabled
            }
            state.keyboardContext.renderVersion &+= 1
        }
        if state.keyboardContext.isKeyboardFloating {
            requestDockedKeyboardMode()
        }
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName((enabled ? "crh.key.requestSplitKeyboard" : "crh.key.requestMergedKeyboard") as CFString),
            nil,
            nil,
            true
        )
        Self.invokeSystemSetSplit(enabled)
        updateKeyboardHeightConstraint()
        updateSplitBackdropMask()
        view.setNeedsLayout()
        view.layoutIfNeeded()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.updateSplitBackdropMask()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.updateSplitBackdropMask()
        }
    }

    static func invokeSystemSetSplit(_ split: Bool) {
        if let implClass: AnyClass = NSClassFromString("UIKeyboardImpl") {
            for selName in ["setRivenPreference:", "setSplit:"] {
                let implSel = NSSelectorFromString(selName)
                if let method = class_getClassMethod(implClass, implSel) {
                    typealias SetSplitFn = @convention(c) (AnyObject, Selector, Bool) -> Void
                    let fn = unsafeBitCast(method_getImplementation(method), to: SetSplitFn.self)
                    fn(implClass, implSel, split)
                }
            }
        }
        if let hostClass: AnyClass = NSClassFromString("UIPeripheralHost") {
            let hostSel = NSSelectorFromString("setSplit:")
            if let method = class_getClassMethod(hostClass, hostSel) {
                typealias SetHostSplitFn = @convention(c) (AnyObject, Selector, Bool) -> Void
                let fn = unsafeBitCast(method_getImplementation(method), to: SetHostSplitFn.self)
                fn(hostClass, hostSel, split)
            }
        }
    }

    static func invokeSystemSetFloating(_ floating: Bool) {
        var alreadyMatching = false
        if let implClass: AnyClass = NSClassFromString("UIKeyboardImpl") {
            let isFloatingSel = NSSelectorFromString("isFloating")
            if let checkMethod = class_getClassMethod(implClass, isFloatingSel) {
                typealias IsFloatingFn = @convention(c) (AnyObject, Selector) -> Bool
                let checkFn = unsafeBitCast(method_getImplementation(checkMethod), to: IsFloatingFn.self)
                alreadyMatching = (checkFn(implClass, isFloatingSel) == floating)
            }
            if !alreadyMatching {
                let implSel = NSSelectorFromString("setFloating:")
                if let method = class_getClassMethod(implClass, implSel) {
                    typealias SetFloatingFn = @convention(c) (AnyObject, Selector, Bool) -> Void
                    let fn = unsafeBitCast(method_getImplementation(method), to: SetFloatingFn.self)
                    fn(implClass, implSel, floating)
                }
            }
        }
        if !alreadyMatching, let hostClass: AnyClass = NSClassFromString("UIPeripheralHost") {
            let hostSel = NSSelectorFromString("setFloating:onCompletion:")
            if let method = class_getClassMethod(hostClass, hostSel) {
                typealias SetHostFloatingFn = @convention(c) (AnyObject, Selector, Bool, AnyObject?) -> Void
                let fn = unsafeBitCast(method_getImplementation(method), to: SetHostFloatingFn.self)
                fn(hostClass, hostSel, floating, nil)
            }
        }
    }

    func clampFloatingKeyboardToScreenBounds() {
        guard isViewLoaded, let window = view.window else { return }
        let screenBounds = window.bounds.width > 0 ? window.bounds : UIScreen.main.bounds
        guard screenBounds.width > 500 else { return }
        let safeRect = screenBounds.insetBy(dx: 16, dy: 24)
        var cursor: UIView? = view
        while let current = cursor, current !== window {
            let frameInWin = current.superview?.convert(current.frame, to: window) ?? current.frame
            if frameInWin.width >= 240 && frameInWin.width <= 420 && frameInWin.height >= 160 && frameInWin.height <= 360 {
                var targetX = frameInWin.origin.x
                var targetY = frameInWin.origin.y
                if targetX < safeRect.minX {
                    targetX = safeRect.minX
                } else if targetX + frameInWin.width > safeRect.maxX {
                    targetX = safeRect.maxX - frameInWin.width
                }
                if targetY < safeRect.minY {
                    targetY = safeRect.minY
                } else if targetY + frameInWin.height > safeRect.maxY {
                    targetY = safeRect.maxY - frameInWin.height
                }
                if abs(targetX - frameInWin.origin.x) > 0.5 || abs(targetY - frameInWin.origin.y) > 0.5,
                   let superview = current.superview {
                    current.frame = window.convert(
                        CGRect(x: targetX, y: targetY, width: frameInWin.width, height: frameInWin.height),
                        to: superview
                    )
                }
            }
            cursor = current.superview
        }
    }

    func updateSplitBackdropMask() {
        guard isViewLoaded else { return }
        let context = state.keyboardContext
        let isSplitActive = context.deviceType == .pad && context.isKeyboardSplit && !context.isKeyboardFloating && !isTransitioningToFloating
        let totalWidth = max(view.bounds.width, 1)
        let totalHeight = max(view.bounds.height, 1)
        let isPortrait = context.interfaceOrientation.isPortrait
        let minGapFraction: CGFloat = isPortrait ? 0.22 : 0.38
        let maxHalfWidth: CGFloat = isPortrait ? 276 : 320
        let clusterWidth = min(max((totalWidth * (1.0 - minGapFraction)) / 2.0, 1), maxHalfWidth)

        view.backgroundColor = .clear
        view.isOpaque = false
        children.first?.view.backgroundColor = .clear
        children.first?.view.isOpaque = false

        func applyIslandMask(to target: UIView) {
            if isSplitActive && totalWidth > 400 {
                let leftRect = view.convert(CGRect(x: 0, y: 0, width: clusterWidth, height: totalHeight), to: target)
                let rightRect = view.convert(CGRect(x: totalWidth - clusterWidth, y: 0, width: clusterWidth, height: totalHeight), to: target)
                let hostPath = UIBezierPath(roundedRect: leftRect, cornerRadius: 14)
                hostPath.append(UIBezierPath(roundedRect: rightRect, cornerRadius: 14))
                let maskLayer = (target.layer.mask as? CAShapeLayer) ?? CAShapeLayer()
                maskLayer.path = hostPath.cgPath
                target.layer.mask = maskLayer
            } else if target.layer.mask != nil {
                target.layer.mask = nil
            }
        }

        applyIslandMask(to: view)
        if let inputView {
            applyIslandMask(to: inputView)
        }
        if let window = view.window {
            applyIslandMask(to: window)
        }

        var cursor: UIView? = view.superview
        while let ancestor = cursor {
            ancestor.backgroundColor = .clear
            ancestor.isOpaque = false
            applyIslandMask(to: ancestor)
            cursor = ancestor.superview
        }

        func inspectViewHierarchy(_ node: UIView) {
            for sub in node.subviews {
                let subName = String(describing: type(of: sub))
                let isBackdropLike = subName.contains("Backdrop")
                    || subName.contains("VisualEffect")
                    || subName.contains("Platter")
                    || subName.contains("Shadow")
                    || subName.contains("Background")
                let isChildOfSelf = sub.isDescendant(of: view)

                if isBackdropLike && !isChildOfSelf {
                    if sub.alpha == 0 { sub.alpha = 1 }
                    if sub.isHidden { sub.isHidden = false }
                    applyIslandMask(to: sub)
                }
                if sub !== view && !isChildOfSelf {
                    inspectViewHierarchy(sub)
                }
            }
        }

        if let root = view.window ?? view.superview {
            inspectViewHierarchy(root)
        }
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
        let isFloating = context.isKeyboardFloating || isTransitioningToFloating
        let hasToolbar = state.autocompleteContext.isAutocompleteEnabled
        if isFloating {
            return (hasToolbar ? 38 : 0) + (43 * 4) + 6
        }
        let isLandscape: Bool = {
            if let targetSize, targetSize.width > 0 {
                let screenBounds = UIScreen.main.bounds
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
        if isPad {
            let toolbarH: CGFloat = hasToolbar ? 38 : 0
            let rowH: CGFloat = isLandscape ? 75 : 58
            return toolbarH + (rowH * 4) + 4
        } else {
            let toolbarH: CGFloat = hasToolbar ? 42 : 0
            let rowH: CGFloat = isLandscape ? 42 : 55
            return toolbarH + (rowH * 4)
        }
    }

    private func updateKeyboardHeightConstraint(targetSize: CGSize? = nil) {
        guard isViewLoaded else { return }
        if keyboardHeightConstraint == nil {
            let constraint = view.heightAnchor.constraint(equalToConstant: expectedKeyboardHeight(targetSize: targetSize))
            constraint.priority = .defaultHigh
            constraint.identifier = "crh.key.keyboardHeightConstraint"
            keyboardHeightConstraint = constraint
        }
        guard let constraint = keyboardHeightConstraint else { return }
        let isTargetFloating = targetSize.map { $0.width > 0 && $0.width <= 360 } ?? false
        let isFloatingOrTransitioning = state.keyboardContext.isKeyboardFloating
            || isTransitioningToFloating
            || isTargetFloating
            || (view.bounds.width > 0 && view.bounds.width <= 360)
            || KeyboardContext.hasActiveSystemFloatingGesture(in: view)
        if isFloatingOrTransitioning {
            if constraint.isActive {
                constraint.isActive = false
            }
        } else {
            if preferredContentSize != .zero {
                preferredContentSize = .zero
            }
            let targetH = expectedKeyboardHeight(targetSize: targetSize)
            if abs(constraint.constant - targetH) > 0.5 {
                constraint.constant = targetH
            }
            if !constraint.isActive {
                constraint.isActive = true
            }
        }
        children.first?.view.invalidateIntrinsicContentSize()
    }

    private func applyPreferences(syncDisk: Bool = false) {
        if syncDisk {
            KeyboardPreferences.defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        }
        KeyboardPreferences.refreshCachedPreferences()
        let suggestionsOn = KeyboardPreferences.suggestionsEnabled && SystemKeyboardSettings.isPredictiveTextEnabled
        state.autocompleteContext.isAutocompleteEnabled = suggestionsOn
        state.autocompleteContext.isAutocorrectEnabled = suggestionsOn
            && (textDocumentProxy.autocorrectionType != .no)
            && SystemKeyboardSettings.isAutoCorrectionEnabled
        state.keyboardContext.isAutoCapitalizationEnabled = SystemKeyboardSettings.isAutoCapitalizationEnabled
        if !suggestionsOn { state.autocompleteContext.suggestions = [] }
        let supportsSplit = state.keyboardContext.deviceSupportsSplitKeyboard
        if !supportsSplit && KeyboardPreferences.splitKeyboardEnabled {
            KeyboardPreferences.setSplitKeyboardEnabled(false)
        }
        let splitEnabled = supportsSplit && KeyboardPreferences.splitKeyboardEnabled
        if state.keyboardContext.isKeyboardSplit != splitEnabled {
            state.keyboardContext.isKeyboardSplit = splitEnabled
        }
        let ukCyrNow = KeyboardPreferences.ukrainianCyrillicLayoutEnabled
        let ukCyrChanged = (ukCyrNow != lastObservedUkrainianCyrillic)
        lastObservedUkrainianCyrillic = ukCyrNow

        if !KeyboardPreferences.cyrillicEnabled {
            if state.keyboardContext.locale.identifier.contains("Cyrl") {
                (services.actionHandler as? DemoActionHandler)?.resetComposition()
                state.keyboardContext.locale = Locale(identifier: "crh-Latn")
                SpaceBarState.shared.triggerSwitchAnimation()
            }
        } else if ukCyrChanged && ukCyrNow && !state.keyboardContext.locale.identifier.contains("Cyrl") {
            (services.actionHandler as? DemoActionHandler)?.resetComposition()
            state.keyboardContext.locale = Locale(identifier: "crh-Cyrl")
            SpaceBarState.shared.triggerSwitchAnimation()
        } else if ukCyrChanged && !ukCyrNow && !isCyrillicExtension && state.keyboardContext.deviceType != .pad && state.keyboardContext.locale.identifier.contains("Cyrl") {
            (services.actionHandler as? DemoActionHandler)?.resetComposition()
            state.keyboardContext.locale = Locale(identifier: "crh-Latn")
            SpaceBarState.shared.triggerSwitchAnimation()
        } else if isCyrillicExtension && state.keyboardContext.deviceType != .pad && !state.keyboardContext.locale.identifier.contains("Cyrl") {
            state.keyboardContext.locale = Locale(identifier: "crh-Cyrl")
            SpaceBarState.shared.triggerSwitchAnimation()
        }
        warmTransliteratorIfNeeded()
        SwipeTypingState.shared.isSlideToTypeSettingEnabled = SystemKeyboardSettings.isSlideToTypeEnabled
            && KeyboardPreferences.suggestionsEnabled
            && SystemKeyboardSettings.isPredictiveTextEnabled
        updateKeyboardHeightConstraint()
        state.keyboardContext.renderVersion &+= 1
    }

    /// This function is called when the controller loads.
    ///
    /// Here, we make demo-specific service keyboard configs.
    override func viewDidLoad() {
        self.hasDictationKey = true
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

        NotificationCenter.default.publisher(for: SwipeTypingState.didCompleteSwipeNotification)
            .sink { [weak self] note in
                guard let self, let keys = note.userInfo?["keys"] as? [String] else { return }
                (self.services.actionHandler as? DemoActionHandler)?.handleSwipePath(keys)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: Notification.Name("crh.key.systemSplitStateDidChange"))
            .sink { [weak self] note in
                guard let self else { return }
                let split = (note.object as? NSNumber)?.boolValue ?? self.state.keyboardContext.isKeyboardSplit
                KeyboardPreferences.setSplitKeyboardEnabled(split)
                CFNotificationCenterPostNotification(
                    CFNotificationCenterGetDarwinNotifyCenter(),
                    CFNotificationName(KeyboardPreferences.splitModeChangedNotification as CFString),
                    nil,
                    nil,
                    true
                )
                CFNotificationCenterPostNotification(
                    CFNotificationCenterGetDarwinNotifyCenter(),
                    CFNotificationName((split ? "crh.key.requestSplitKeyboard" : "crh.key.requestMergedKeyboard") as CFString),
                    nil,
                    nil,
                    true
                )
                self.updateKeyboardHeightConstraint()
                self.updateSplitBackdropMask()
                self.view.setNeedsLayout()
                self.view.layoutIfNeeded()
            }
            .store(in: &cancellables)

        for sysNote in ["TIPreferencesControllerChangedNotification", "UIKeyboardRivenVisualStyleDidChange"] {
            NotificationCenter.default.publisher(for: Notification.Name(sysNote))
                .sink { [weak self] _ in
                    guard let self, self.isViewLoaded, !self.isTransitioningToFloating else { return }
                    self.state.keyboardContext.syncIsFloating(with: self)
                    self.updateKeyboardHeightConstraint()
                    self.updateSplitBackdropMask()
                }
                .store(in: &cancellables)
        }

        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, observer, _, _, _ in
                guard let observer else { return }
                let controller = Unmanaged<KeyboardViewController>.fromOpaque(observer).takeUnretainedValue()
                DispatchQueue.main.async { [weak controller] in
                    guard let controller, controller.isViewLoaded, controller.view.window != nil else { return }
                    controller.refreshProxyState(forceRender: true)
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
                    controller.applyPreferences(syncDisk: true)
                }
            },
            KeyboardPreferences.splitModeChangedNotification as CFString,
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
                }
            },
            KeyboardPreferences.ukrainianCyrillicLayoutChangedNotification as CFString,
            nil,
            .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            observer,
            { _, _, _, _, _ in
                SuggestionsDataBaseManager.shared.clearUserLexicon()
            },
            KeyboardUsageStats.statsResetNotification as CFString,
            nil,
            .deliverImmediately
        )

        /// 💡 Call super to perform the base initialization.
        super.viewDidLoad()
        Self.installPinchPassthroughIfNeeded()
        installSplitPinchGestureIfNeeded()
        applyPreferences(syncDisk: false)
    }

    private func installSplitPinchGestureIfNeeded() {
        guard !didInstallSplitGesture, state.keyboardContext.deviceSupportsSplitKeyboard else { return }
        didInstallSplitGesture = true
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handleSplitPinchGesture(_:)))
        pinch.cancelsTouchesInView = false
        pinch.delaysTouchesBegan = false
        pinch.delaysTouchesEnded = false
        pinch.delegate = self
        view.addGestureRecognizer(pinch)
    }

    @objc private func handleSplitPinchGesture(_ gesture: UIPinchGestureRecognizer) {
        guard state.keyboardContext.deviceSupportsSplitKeyboard,
              !state.keyboardContext.isKeyboardFloating else { return }
        if gesture.state == .changed || gesture.state == .ended {
            if !state.keyboardContext.isKeyboardSplit && gesture.scale > 1.32 {
                state.calloutContext.inputContext.reset()
                state.calloutContext.actionContext.reset()
                KeyFlickState.shared.reset()
                NotificationCenter.default.post(name: Notification.Name("crh.key.gestureEnded"), object: nil)
                setSplitKeyboardMode(true)
            } else if state.keyboardContext.isKeyboardSplit && gesture.scale < 0.75 {
                state.calloutContext.inputContext.reset()
                state.calloutContext.actionContext.reset()
                KeyFlickState.shared.reset()
                NotificationCenter.default.post(name: Notification.Name("crh.key.gestureEnded"), object: nil)
                setSplitKeyboardMode(false)
            }
        }
    }

    private func refreshSupplementaryLexicon() {
        requestSupplementaryLexicon { lexicon in
            var map: [String: String] = [:]
            for entry in lexicon.entries {
                let key = entry.userInput.trimmingCharacters(in: .whitespacesAndNewlines)
                let val = entry.documentText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !key.isEmpty, !val.isEmpty, key != val else { continue }
                map[key] = val
            }
            SuggestionsDataBaseManager.shared.updateSupplementaryLexicon(map)
        }
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    private static var didInstallPinchPassthrough = false

    /// Ensures SwiftUI's zero-distance drag gesture recognizer on key buttons never blocks
    /// the system's two-finger pinch-to-floating gesture recognizer on iPad.
    private static func installPinchPassthroughIfNeeded() {
        guard !didInstallPinchPassthrough else { return }
        didInstallPinchPassthrough = true

        if let origCanPrevent = class_getInstanceMethod(UIGestureRecognizer.self, #selector(UIGestureRecognizer.canPrevent(_:))),
           let swizCanPrevent = class_getInstanceMethod(UIGestureRecognizer.self, #selector(UIGestureRecognizer.qirim_canPrevent(_:))) {
            method_exchangeImplementations(origCanPrevent, swizCanPrevent)
        }
        if let origCanBePrevented = class_getInstanceMethod(UIGestureRecognizer.self, #selector(UIGestureRecognizer.canBePrevented(by:))),
           let swizCanBePrevented = class_getInstanceMethod(UIGestureRecognizer.self, #selector(UIGestureRecognizer.qirim_canBePrevented(by:))) {
            method_exchangeImplementations(origCanBePrevented, swizCanBePrevented)
        }
    }

    deinit {
        let observer = UnsafeRawPointer(Unmanaged.passUnretained(self).toOpaque())
        CFNotificationCenterRemoveEveryObserver(CFNotificationCenterGetDarwinNotifyCenter(), observer)
    }

    override func viewWillAppear(_ animated: Bool) {
        SuggestionsDataBaseManager.shared.resumeAccess()
        refreshSupplementaryLexicon()
        isResettingDocumentState = false
        self.hasDictationKey = true
        view.backgroundColor = .clear
        resetHostBundleIdCache()
        state.keyboardContext.syncTextDocumentProxy(with: self)
        state.keyboardContext.syncIsFloating(with: self)
        if state.keyboardContext.traitCollection != traitCollection {
            state.keyboardContext.traitCollection = traitCollection
        }
        state.keyboardContext.proxyKeyboardTypeOverride = DemoStyleProvider.isSandboxOverrideActive(for: state.keyboardContext)
            ? DemoStyleProvider.effectiveProxyKeyboardType(for: state.keyboardContext)
            : nil
        state.keyboardContext.hasChosenLettersInNumericField = false // new input session
        lastDocumentIdentifier = textDocumentProxy.safeDocumentIdentifier
        lastProxyKeyboardType = nil
        syncPreferredKeyboardTypeWithProxy()

        if isCyrillicExtension {
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.cyrillicExtensionSeen")
        }
        applyPreferences(syncDisk: true)
        lastRenderSignature = currentRenderSignature
        super.viewWillAppear(animated)
        (services.actionHandler as? DemoActionHandler)?.resetComposition()
        TextHistoryManager.shared.reset()
        SpaceBarState.shared.prepareForAppearance()
        GreetingBannerState.shared.prepareForAppearance()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if state.keyboardContext.traitCollection != traitCollection {
            state.keyboardContext.traitCollection = traitCollection
        }
        if previousTraitCollection?.userInterfaceStyle != traitCollection.userInterfaceStyle {
            refreshProxyState(forceRender: true)
        }
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
        super.performAutocomplete()
    }

    /// Preserve current suggestions across cursor-selection notifications fired during typing so Space can apply autocorrect.
    override func selectionWillChange(_ textInput: UITextInput?) {}
    override func selectionDidChange(_ textInput: UITextInput?) {}

    override func textWillChange(_ textInput: UITextInput?) {
        isResettingDocumentState = true
        autocompletePending = false
        super.textWillChange(textInput)
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
        let splitEnabled: Bool
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
            splitEnabled: context.isKeyboardSplit,
            isFloating: context.isKeyboardFloating,
            localeIdentifier: context.locale.identifier
        )
    }

    private func refreshProxyState(forceRender: Bool = false) {
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
        let effectiveKeyboardType = context.proxyKeyboardTypeOverride ?? textDocumentProxy.keyboardType
        let isURLOrEmail = effectiveKeyboardType == .URL || effectiveKeyboardType == .emailAddress
        let shouldAutocorrect = KeyboardPreferences.suggestionsEnabled
            && SystemKeyboardSettings.isPredictiveTextEnabled
            && SystemKeyboardSettings.isAutoCorrectionEnabled
            && (textDocumentProxy.autocorrectionType != .no)
            && !isURLOrEmail
        if state.autocompleteContext.isAutocorrectEnabled != shouldAutocorrect {
            state.autocompleteContext.isAutocorrectEnabled = shouldAutocorrect
        }
        let targetCapitalize = SystemKeyboardSettings.isAutoCapitalizationEnabled
        if context.isAutoCapitalizationEnabled != targetCapitalize {
            context.isAutoCapitalizationEnabled = targetCapitalize
        }
        let targetInterfaceStyle: UIUserInterfaceStyle = isSandboxActive
            ? (DemoStyleProvider.effectiveIsDark(for: context) ? .dark : .light)
            : .unspecified
        if overrideUserInterfaceStyle != targetInterfaceStyle {
            overrideUserInterfaceStyle = targetInterfaceStyle
        }
        if context.traitCollection != traitCollection {
            context.traitCollection = traitCollection
        }
        syncPreferredKeyboardTypeWithProxy()
        // Re-render only when a trait the UI depends on changed (field traits, empty <-> non-empty for the Return key).
        let signature = currentRenderSignature
        if !signature.hasText && (textDocumentProxy.documentContextBeforeInput ?? "").isEmpty && (textDocumentProxy.documentContextAfterInput ?? "").isEmpty {
            if lastRenderSignature?.hasText == true {
                GreetingBannerState.shared.prepareForAppearance()
            }
        }
        if signature != lastRenderSignature || forceRender {
            let prefsChanged = forceRender
                || lastRenderSignature?.cyrillicEnabled != signature.cyrillicEnabled
                || lastRenderSignature?.ukrainianCyrillicLayoutEnabled != signature.ukrainianCyrillicLayoutEnabled
                || lastRenderSignature?.suggestionsEnabled != signature.suggestionsEnabled
                || lastRenderSignature?.splitEnabled != signature.splitEnabled
            if prefsChanged {
                applyPreferences(syncDisk: forceRender)
            } else {
                state.keyboardContext.renderVersion &+= 1
            }
            lastRenderSignature = currentRenderSignature
            view.setNeedsLayout()
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        isResettingDocumentState = false
        state.keyboardContext.proxyKeyboardTypeOverride = DemoStyleProvider.isSandboxOverrideActive(for: state.keyboardContext)
            ? DemoStyleProvider.effectiveProxyKeyboardType(for: state.keyboardContext)
            : nil
        super.textDidChange(textInput)
        refreshProxyState()
    }

    override func textDidChangeAsync(_ textInput: UITextInput?) {
        guard !isResettingDocumentState, isViewLoaded, view.window != nil else { return }
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
        if !isTransitioningToFloating {
            state.keyboardContext.syncIsFloating(with: self)
        }
        updateKeyboardHeightConstraint()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateKeyboardHeightConstraint()
        updateSplitBackdropMask()
        if state.keyboardContext.isKeyboardFloating || isTransitioningToFloating {
            clampFloatingKeyboardToScreenBounds()
        }
        let shouldEnableInputCallout = state.keyboardContext.deviceType == .phone || state.keyboardContext.isKeyboardFloating
        if state.calloutContext.inputContext.isEnabled != shouldEnableInputCallout {
            state.calloutContext.inputContext.isEnabled = shouldEnableInputCallout
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        SuggestionsDataBaseManager.shared.prepareAsync()
        if !isTransitioningToFloating {
            state.keyboardContext.syncIsFloating(with: self)
        }
        updateKeyboardHeightConstraint()
        updateSplitBackdropMask()
        refreshProxyState()
        SpaceBarState.shared.triggerSwitchAnimation()
        let hasText = textDocumentProxy.hasText || !(textDocumentProxy.documentContextBeforeInput?.isEmpty ?? true)
        if hasText {
            performAutocomplete()
        } else {
            state.autocompleteContext.suggestions = []
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        autocompletePending = false
        SuggestionsDataBaseManager.shared.suspendAccess()
        KeyboardUsageStats.scheduleCrossProcessSync(immediate: true)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        if !isTransitioningToFloating {
            state.keyboardContext.syncIsFloating(with: self, targetWidth: size.width)
        }
        updateKeyboardHeightConstraint(targetSize: size)
        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self else { return }
            if !self.isTransitioningToFloating {
                self.state.keyboardContext.syncIsFloating(with: self, targetWidth: size.width)
            }
            self.updateKeyboardHeightConstraint(targetSize: size)
            self.updateSplitBackdropMask()
            if self.state.keyboardContext.isKeyboardFloating || self.isTransitioningToFloating {
                self.clampFloatingKeyboardToScreenBounds()
            }
            self.view.setNeedsLayout()
            self.view.layoutIfNeeded()
        }, completion: { [weak self] _ in
            guard let self else { return }
            if !self.isTransitioningToFloating {
                self.state.keyboardContext.syncIsFloating(with: self)
            }
            self.updateKeyboardHeightConstraint()
            self.updateSplitBackdropMask()
            if self.state.keyboardContext.isKeyboardFloating || self.isTransitioningToFloating {
                self.clampFloatingKeyboardToScreenBounds()
            }
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
                    let context = controller.state.keyboardContext
                    let itemRow = CrimeanTatarIPadKeyboardLayoutProvider.isBottomRowCharacterItem(params.item, context: context) ? 3 : 0
                    if params.item.action == .space {
                        let isCyrillic = context.locale.identifier.contains("Cyrl")
                        let isCompact = context.deviceType == .phone || context.isKeyboardFloating || context.isKeyboardSplit
                        SpaceBarLabel(
                            fullName: isCyrillic ? "Къырымтатарджа" : "Qırımtatarca",
                            languageCode: isCyrillic ? "КЪ" : "QT",
                            isCompact: isCompact
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
        if abs(clamped - currentProgress) > 0.005 || (clamped == 0 && currentProgress != 0) || (clamped == 1 && currentProgress != 1) {
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

/// Renders an iPad Docked key with a top secondary flick symbol that smoothly slides down
/// into the center, scales up to primary font size, and transitions from gray to solid black/white
/// while the primary character slides down and fades out during a downward key flick.
struct FlickKeyContentView<PrimaryContent: View>: View {
    let action: KeyboardAction
    let flickSymbol: String
    let isLandscape: Bool
    let isDark: Bool
    @ViewBuilder let primaryContent: () -> PrimaryContent

    @State private var progress: CGFloat = 0

    private var primaryFontSize: CGFloat { isLandscape ? 23 : 21 }
    private var restingScale: CGFloat { isLandscape ? (12.0 / 23.0) : (10.5 / 21.0) }
    private var flickGlyphBaselineCompensation: CGFloat {
        switch flickSymbol {
        case ",", ".", "_":
            return isLandscape ? -3.0 : -2.5
        default:
            return 0
        }
    }
    private var restingOffsetY: CGFloat { (isLandscape ? -21.5 : -16.5) + flickGlyphBaselineCompensation }
    private var restingOpacity: Double { isDark ? 0.45 : 0.42 }
    private var restingPrimaryOffsetY: CGFloat { isLandscape ? 8.5 : 7.5 }

    var body: some View {
        let currentFlickScale = restingScale + (1.0 - restingScale) * progress
        let currentFlickOffsetY = restingOffsetY * (1.0 - progress)
        let currentFlickOpacity = restingOpacity + (1.0 - restingOpacity) * Double(progress)

        let currentPrimaryOffsetY = restingPrimaryOffsetY + progress * (isLandscape ? 12.0 : 9.5)
        let currentPrimaryScale = 1.0 - progress * 0.25
        let currentPrimaryOpacity = max(0.0, 1.0 - Double(progress) * 1.65)

        ZStack {
            primaryContent()
                .scaleEffect(currentPrimaryScale)
                .offset(y: currentPrimaryOffsetY)
                .opacity(currentPrimaryOpacity)

            Text(flickSymbol)
                .font(.system(size: primaryFontSize, weight: .regular))
                .foregroundColor((isDark ? Color.white : Color.black).opacity(currentFlickOpacity))
                .scaleEffect(currentFlickScale)
                .offset(y: currentFlickOffsetY)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .onReceive(KeyFlickState.shared.subject) { event in
            guard event.action == action else { return }
            if event.progress == 0 {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                    progress = 0
                }
            } else {
                withAnimation(.interactiveSpring(response: 0.07, dampingFraction: 0.92)) {
                    progress = event.progress
                }
            }
        }
        .onChange(of: action) { _ in
            progress = 0
        }
    }
}

private extension UIGestureRecognizer {
    var qirim_isSystemFloatingGesture: Bool {
        if self is UIPinchGestureRecognizer {
            return true
        }
        if self is UIPanGestureRecognizer {
            let className = NSStringFromClass(type(of: self))
            let delegateName = delegate.map { NSStringFromClass(type(of: $0)) } ?? ""
            if delegateName.contains("Floating")
                || delegateName.contains("Peripheral")
                || delegateName.contains("Dock")
                || className.contains("Keyboard") {
                return true
            }
        }
        return false
    }

    @objc func qirim_canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        if preventedGestureRecognizer.qirim_isSystemFloatingGesture {
            return false
        }
        return qirim_canPrevent(preventedGestureRecognizer)
    }

    @objc func qirim_canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        if qirim_isSystemFloatingGesture {
            return false
        }
        return qirim_canBePrevented(by: preventingGestureRecognizer)
    }
}
