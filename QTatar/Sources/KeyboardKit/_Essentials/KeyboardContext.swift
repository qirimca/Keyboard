//
//  KeyboardContext.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2020-06-15.
//  Copyright © 2020-2024 Daniel Saidi. All rights reserved.
//

import Combine
import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

/**
 This class provides keyboard extensions with contextual and
 observable information about the keyboard extension.

 This class will continuously sync with the input controller
 to updated its state. It's also extensively used within the
 library, to make keyboard-related decisions.
 
 For instance, you can change the ``keyboardType`` to change
 which kind of keyboard that is rendered.

 You can use ``locale`` to get & set the raw keyboard locale
 or use the properties and functions that allows us to use a
 ``KeyboardLocale``. If ``locales`` has multiple values, the
 ``selectNextLocale()`` function toggles through the locales.
 
 KeyboardKit automatically creates an instance of this class
 and injects it into ``KeyboardInputViewController/state``.
 */
public class KeyboardContext: ObservableObject {

    public init() {}

    
    // MARK: - Published Properties
    
    /// Set this to override the ``autocapitalizationType``.
    @Published
    public var autocapitalizationTypeOverride: Keyboard.AutocapitalizationType?

    /// The current device type.
    @Published
    public var deviceType: DeviceType = .current

    /// Whether or not the keyboard has a dictation key.
    @Published
    public var hasDictationKey: Bool = false

    /// Whether or not the extension has full access.
    @Published
    public var hasFullAccess: Bool = false

    /// The bundle ID of the keyboard host application.
    @Published
    public var hostApplicationBundleId: String?
    
    /// The current interface orientation.
    @Published
    public var interfaceOrientation: InterfaceOrientation = .portrait

    /// Whether or not autocapitalization is enabled.
    @Published
    public var isAutoCapitalizationEnabled = true

    /// Whether or not the keyboard is in floating mode.
    @Published
    public var isKeyboardFloating = false

    /// Whether or not the iPad keyboard is in split (thumb-cluster) mode.
    @Published
    public var isKeyboardSplit = false

    /// Tracks the last observed UIKit system split state (`UIKeyboardImpl` / `UIPeripheralHost` / `UIInputWindowController`).
    public var lastObservedSystemSplit: Bool?

    /// True while UIKit is animating the keyboard container from Docked to Floating (`width < 420`).
    public var isTransitioningToFloating = false

    /// True while UIKit is transitioning between Split and Merged/Floating modes.
    public var isTransitioningSplit = false

    /// Whether or not a space drag gesture is active.
    @Published
    public var isSpaceDragGestureActive = false
    
    public func setIsSpaceDragGestureActive(
        _ value: Bool,
        animated: Bool
    ) {
        if animated {
            withAnimation { isSpaceDragGestureActive = value }
        } else {
            isSpaceDragGestureActive = value
        }
    }

    /// An optional dictation replacement action.
    @Published
    public var keyboardDictationReplacement: KeyboardAction?

    /// The keyboard type that is currently used.
    @Published
    public var keyboardType = Keyboard.KeyboardType.alphabetic(.lowercased)

    /// The locale that is currently being used.
    @Published
    public var locale = Locale.current

    /// The locales that are currently available.
    @Published
    public var locales: [Locale] = [.current]

    /// The locale to use when displaying other locales.
    @Published
    public var localePresentationLocale: Locale?

    /// Whether or not to add an input mode switch key.
    @Published
    public var needsInputModeSwitchKey = false

    /// Whether or not the context prefers autocomplete.
    @Published
    public var prefersAutocomplete = true

    /// The primary language that is currently being used.
    @Published
    public var primaryLanguage: String?

    /// The current screen size (avoid using this).
    @Published
    public var screenSize = CGSize.zero

    /// The space long press behavior to use.
    @Published
    public var spaceLongPressBehavior = Gestures.SpaceLongPressBehavior.moveInputCursor

    /// Set when the user taps the ABC key inside a `.numbersAndPunctuation` field. Until the next input session
    /// the preferred keyboard type no longer forces the numeric page back.
    public var hasChosenLettersInNumericField = false

    /// Incremented whenever non-published traits or shared preferences change so SwiftUI rebuilds the keyboard layout immediately.
    @Published
    public var renderVersion: Int = 0
    
    
    #if os(iOS) || os(tvOS) || os(visionOS)
    
    // MARK: - iOS/tvOS proxy properties
    
    /// The original text document proxy.
    @Published
    public var originalTextDocumentProxy: UITextDocumentProxy = .preview

    /// The text document proxy that is currently active.
    public var textDocumentProxy: UITextDocumentProxy {
        textInputProxy ?? originalTextDocumentProxy
    }
    
    /// A custom text proxy to which text can be routed.
    @Published
    public var textInputProxy: TextInputProxy?

    /// Set this to override the ``textDocumentProxy`` keyboard type (e.g. for live in-app sandbox testing).
    public var proxyKeyboardTypeOverride: UIKeyboardType?
    
    
    // MARK: - iOS/tvOS properties

    /// The text input mode of the input controller.
    @Published
    public var textInputMode: UITextInputMode?

    /// The input controller's current trait collection.
    @Published
    public var traitCollection = UITraitCollection()
    #endif
}


// MARK: - Public iOS/tvOS Properties

#if os(iOS) || os(tvOS) || os(visionOS)
public extension KeyboardContext {

    /// The current trait collection's color scheme.
    var colorScheme: ColorScheme {
        traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    /// The current keyboard appearance.
    var keyboardAppearance: UIKeyboardAppearance {
        textDocumentProxy.keyboardAppearance ?? .default
    }
}
#endif


// MARK: - Public Properties

public extension KeyboardContext {

    /// The autocapitalization type to use.
    ///
    /// This value comes from the ``textDocumentProxy``. The
    /// ``autocapitalizationTypeOverride`` value can be used
    /// to overrides this property.
    var autocapitalizationType: Keyboard.AutocapitalizationType? {
        #if os(iOS) || os(tvOS) || os(visionOS)
        autocapitalizationTypeOverride ?? textDocumentProxy.autocapitalizationType?.keyboardType
        #else
        autocapitalizationTypeOverride ?? nil
        #endif
    }

    /// Whether or not to use a dark color scheme.
    var hasDarkColorScheme: Bool {
        #if os(iOS) || os(tvOS) || os(visionOS)
        colorScheme == .dark || keyboardAppearance == .dark
        #else
        false
        #endif
    }
    
    /// Whether or not the context has multiple locales.
    var hasMultipleLocales: Bool {
        locales.count > 1
    }

    /// Map the current ``locale`` to a ``KeyboardLocale``.
    var keyboardLocale: KeyboardLocale? {
        KeyboardLocale.allCases.first { $0.localeIdentifier == locale.identifier }
    }

    /// Whether or not the current iPad hardware model supports Split Keyboard in official iPadOS
    /// (Home-button iPads such as iPad Air 3rd generation and iPad 5th–9th gen, plus iPad mini).
    var deviceSupportsSplitKeyboard: Bool {
        guard deviceType == .pad else { return false }
        #if os(iOS)
        if let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "UIKeyboardDeviceSupportsSplit") {
            typealias SupportsSplitFn = @convention(c) () -> Bool
            let fn = unsafeBitCast(sym, to: SupportsSplitFn.self)
            return fn()
        }
        let modelIdentifier: String = {
            if let simModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simModel.isEmpty {
                return simModel
            }
            var sysinfo = utsname()
            uname(&sysinfo)
            return withUnsafePointer(to: &sysinfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(cString: $0)
                }
            }
        }()
        let supportedModels: Set<String> = [
            "iPad11,3", "iPad11,4",
            "iPad11,1", "iPad11,2", "iPad14,1", "iPad14,2", "iPad16,1", "iPad16,2",
            "iPad6,11", "iPad6,12", "iPad7,5", "iPad7,6", "iPad7,11", "iPad7,12",
            "iPad11,6", "iPad11,7", "iPad12,1", "iPad12,2",
            "iPad6,3", "iPad6,4", "iPad7,3", "iPad7,4",
            "iPad5,1", "iPad5,2", "iPad5,3", "iPad5,4"
        ]
        return supportedModels.contains(modelIdentifier)
        #else
        return false
        #endif
    }
}


// MARK: - Public Functions

public extension KeyboardContext {

    /// Whether or not the context has a certain locale.
    func hasKeyboardLocale(
        _ locale: KeyboardLocale
    ) -> Bool {
        self.locale.identifier == locale.localeIdentifier
    }

    /// Whether or not a certain keyboard type is selected.
    func hasKeyboardType(
        _ type: Keyboard.KeyboardType
    ) -> Bool {
        keyboardType == type
    }

    /// Select the next locale in ``locales``.
    ///
    /// This will loop through all locales in ``locales``.
    func selectNextLocale() {
        let fallback = locales.first ?? locale
        guard let currentIndex = locales.firstIndex(of: locale) else { return locale = fallback }
        let nextIndex = currentIndex.advanced(by: 1)
        guard locales.count > nextIndex else { return locale = fallback }
        locale = locales[nextIndex]
    }

    /// Set ``keyboardType`` to the provided type.
    func setKeyboardType(_ type: Keyboard.KeyboardType) {
        keyboardType = type
    }

    /// Set ``locale`` to the provided locale.
    func setLocale(_ locale: Locale) {
        self.locale = locale
    }

    /// Set ``locale`` to the provided keyboard locale.
    func setLocale(_ locale: KeyboardLocale) {
        self.locale = locale.locale
    }

    /// Set ``locales`` to the provided locales.
    func setLocales(_ locales: [Locale]) {
        self.locales = locales
    }

    /// Set ``locales`` to the provided keyboard locales.
    func setLocales(_ locales: [KeyboardLocale]) {
        self.locales = locales.map { $0.locale }
    }
}


// MARK: - iOS/tvOS syncing

#if os(iOS) || os(tvOS) || os(visionOS)
public extension KeyboardContext {
    
    /// Sync the context with the provided input controller.
    func sync(with controller: KeyboardInputViewController) {
        DispatchQueue.main.async {
            self.syncAfterAsync(with: controller)
        }
    }
    
    /// Sync the ``originalTextDocumentProxy``.
    func syncTextDocumentProxy(with controller: KeyboardInputViewController) {
        if let bundleId = controller.hostBundleId, hostApplicationBundleId != bundleId {
            hostApplicationBundleId = bundleId
        }
        if originalTextDocumentProxy === controller.originalTextDocumentProxy { return }
        originalTextDocumentProxy = controller.originalTextDocumentProxy
    }
    
    /// Sync the ``textInputProxy``.
    func syncTextInputProxy(with controller: KeyboardInputViewController) {
        if textInputProxy === controller.textInputProxy { return }
        DispatchQueue.main.async {
            self.textInputProxy = controller.textInputProxy
        }
    }
}

extension KeyboardContext {

    /// Perform a sync after an async delay.
    func syncAfterAsync(with controller: KeyboardInputViewController) {
        syncTextDocumentProxy(with: controller)
        syncTextInputProxy(with: controller)
        
        if hasDictationKey != controller.hasDictationKey {
            hasDictationKey = controller.hasDictationKey
        }
        
        if hasFullAccess != controller.hasFullAccess {
            hasFullAccess = controller.hasFullAccess
        }
        
        if hostApplicationBundleId != controller.hostBundleId {
            hostApplicationBundleId = controller.hostBundleId
        }
        
        if interfaceOrientation != controller.orientation {
            interfaceOrientation = controller.orientation
        }
        
        if needsInputModeSwitchKey != controller.needsInputModeSwitchKey {
            needsInputModeSwitchKey = controller.needsInputModeSwitchKey
        }
        
        let effectiveKeyboardType = proxyKeyboardTypeOverride ?? textDocumentProxy.keyboardType
        let keyboardPrefersAutocomplete = effectiveKeyboardType?.prefersAutocomplete ?? true
        let returnKeyPrefersAutocomplete = textDocumentProxy.returnKeyType?.prefersAutocomplete ?? true
        let newPrefersAutocomplete = keyboardType.prefersAutocomplete && keyboardPrefersAutocomplete && returnKeyPrefersAutocomplete
        if prefersAutocomplete != newPrefersAutocomplete {
            prefersAutocomplete = newPrefersAutocomplete
        }
        
        if primaryLanguage != controller.primaryLanguage {
            primaryLanguage = controller.primaryLanguage
        }
        
        if screenSize != controller.screenSize {
            screenSize = controller.screenSize
        }
        
        if textInputMode != controller.textInputMode {
            textInputMode = controller.textInputMode
        }

        if traitCollection != controller.traitCollection {
            traitCollection = controller.traitCollection
        }
    }

    func syncAfterLayout(with controller: KeyboardInputViewController) {
        syncIsFloating(with: controller)
        if needsInputModeSwitchKey != controller.needsInputModeSwitchKey {
            needsInputModeSwitchKey = controller.needsInputModeSwitchKey
        }
        if let bundleId = controller.hostBundleId, hostApplicationBundleId != bundleId {
            hostApplicationBundleId = bundleId
        }
        if controller.orientation == interfaceOrientation { return }
        sync(with: controller)
    }

    /// Perform an immediate sync to check if the iPad keyboard is in floating mode (`width < 420`).
    public func syncIsFloating(
        with controller: KeyboardInputViewController,
        targetWidth: CGFloat? = nil
    ) {
        let resolvedWidth: CGFloat = {
            if let targetWidth, targetWidth > 0 { return targetWidth }
            var minW = controller.view.bounds.width > 0 ? controller.view.bounds.width : controller.view.frame.width
            var cur = controller.view.superview
            while let node = cur {
                let w = node.bounds.width
                if w > 0 && w < minW {
                    minW = w
                }
                cur = node.superview
            }
            return minW
        }()
        let isPadDevice = controller.traitCollection.userInterfaceIdiom == .pad || deviceType == .pad
        guard isPadDevice, resolvedWidth > 0 else {
            if isKeyboardFloating { isKeyboardFloating = false }
            return
        }
        if targetWidth == nil && controller.view.window == nil && resolvedWidth >= 420 {
            return
        }
        let wasFloating = isKeyboardFloating
        if isTransitioningToFloating {
            if resolvedWidth < 420 {
                isTransitioningToFloating = false
            } else {
                if !isKeyboardFloating {
                    isKeyboardFloating = true
                    if isKeyboardSplit { isKeyboardSplit = false }
                    renderVersion &+= 1
                }
                return
            }
        }
        #if os(iOS)
        let sysFloating = (targetWidth == nil) ? (Self.querySystemIsFloating(in: controller) ?? false) : false
        let isFloating = (resolvedWidth < 420) || sysFloating
        #else
        let isFloating = resolvedWidth < 420
        #endif
        if isKeyboardFloating != isFloating {
            isKeyboardFloating = isFloating
            if isFloating && isKeyboardSplit {
                isKeyboardSplit = false
            }
            renderVersion &+= 1
        }
        #if os(iOS)
        if Self.hasActiveSystemFloatingGesture(in: controller.view) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak controller] in
                guard let self, let controller else { return }
                self.syncIsFloating(with: controller)
            }
        }
        if !isFloating && controller.preferredContentSize != .zero {
            controller.preferredContentSize = .zero
        }
        if wasFloating && !isFloating && !isTransitioningSplit && deviceSupportsSplitKeyboard {
            for delay in [0.06, 0.18, 0.35] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak controller] in
                    guard let self, let controller, !self.isKeyboardFloating, !self.isTransitioningSplit else { return }
                    let userPrefSplit = UserDefaults(suiteName: "group.crh.key.keyboardplus")?.object(forKey: "crh.key.splitKeyboardEnabled") as? Bool
                    if let delayedSplit = Self.querySystemIsSplit(in: controller) {
                        let resolvedSplit = (userPrefSplit == false) ? false : delayedSplit
                        self.lastObservedSystemSplit = resolvedSplit
                        if self.isKeyboardSplit != resolvedSplit {
                            self.isKeyboardSplit = resolvedSplit
                            self.renderVersion &+= 1
                            NotificationCenter.default.post(
                                name: Notification.Name("crh.key.systemSplitStateDidChange"),
                                object: NSNumber(value: resolvedSplit)
                            )
                        }
                    }
                }
            }
        }
        if !isFloating && !isTransitioningSplit && deviceSupportsSplitKeyboard, let sysSplit = Self.querySystemIsSplit(in: controller) {
            let userPrefSplit = UserDefaults(suiteName: "group.crh.key.keyboardplus")?.object(forKey: "crh.key.splitKeyboardEnabled") as? Bool
            let effectiveSysSplit = (userPrefSplit == false) ? false : sysSplit
            if (wasFloating && effectiveSysSplit) || (lastObservedSystemSplit != nil && lastObservedSystemSplit != effectiveSysSplit) {
                lastObservedSystemSplit = effectiveSysSplit
                if isKeyboardSplit != effectiveSysSplit {
                    isKeyboardSplit = effectiveSysSplit
                    renderVersion &+= 1
                    NotificationCenter.default.post(
                        name: Notification.Name("crh.key.systemSplitStateDidChange"),
                        object: NSNumber(value: effectiveSysSplit)
                    )
                }
            } else if lastObservedSystemSplit == nil {
                lastObservedSystemSplit = effectiveSysSplit
                if effectiveSysSplit && !isKeyboardSplit {
                    isKeyboardSplit = true
                    renderVersion &+= 1
                    NotificationCenter.default.post(
                        name: Notification.Name("crh.key.systemSplitStateDidChange"),
                        object: NSNumber(value: true)
                    )
                }
            }
        }
        #endif
    }

    #if os(iOS)
    public static func querySystemIsFloating(in controller: UIInputViewController) -> Bool? {
        if let rootVC = controller.view.window?.rootViewController {
            let placementSel = NSSelectorFromString("placement")
            if rootVC.responds(to: placementSel),
               let placement = rootVC.perform(placementSel)?.takeUnretainedValue() {
                let className = NSStringFromClass(type(of: placement))
                if className.contains("Floating") {
                    return true
                }
                let isFloatingSel = NSSelectorFromString("isFloating")
                if placement.responds(to: isFloatingSel),
                   let method = class_getInstanceMethod(type(of: placement), isFloatingSel) {
                    typealias IsFloatingFn = @convention(c) (AnyObject, Selector) -> Bool
                    let fn = unsafeBitCast(method_getImplementation(method), to: IsFloatingFn.self)
                    if fn(placement, isFloatingSel) {
                        return true
                    }
                }
            }
        }
        if let implClass: AnyClass = NSClassFromString("UIKeyboardImpl") {
            let isFloatingSel = NSSelectorFromString("isFloating")
            if let method = class_getClassMethod(implClass, isFloatingSel) {
                typealias ClassBoolFn = @convention(c) (AnyObject, Selector) -> Bool
                let fn = unsafeBitCast(method_getImplementation(method), to: ClassBoolFn.self)
                if fn(implClass, isFloatingSel) {
                    return true
                }
            }
        }
        return nil
    }

    public static func querySystemIsSplit(in controller: UIInputViewController) -> Bool? {
        if let tiClass = NSClassFromString("TIPreferencesController") as? NSObject.Type {
            let sharedSel = NSSelectorFromString("sharedPreferencesController")
            if tiClass.responds(to: sharedSel),
               let tiCtrl = tiClass.perform(sharedSel)?.takeUnretainedValue() as? NSObject {
                let syncSel = NSSelectorFromString("synchronizePreferences")
                if tiCtrl.responds(to: syncSel) {
                    _ = tiCtrl.perform(syncSel)
                }
                let valSel = NSSelectorFromString("valueForPreferenceKey:")
                if tiCtrl.responds(to: valSel) {
                    if let num = tiCtrl.perform(valSel, with: "UIKeyboardPersistentSplitLock" as NSString)?.takeUnretainedValue() as? NSNumber,
                       num.boolValue {
                        return true
                    }
                    if let prog = tiCtrl.perform(valSel, with: "UIKeyboardPersistentSplitProgress" as NSString)?.takeUnretainedValue() as? NSNumber,
                       prog.doubleValue > 0.5 {
                        return true
                    }
                }
            }
        }
        if let rootVC = controller.view.window?.rootViewController {
            let placementSel = NSSelectorFromString("placement")
            if rootVC.responds(to: placementSel),
               let placement = rootVC.perform(placementSel)?.takeUnretainedValue() {
                let className = NSStringFromClass(type(of: placement))
                if className.contains("Split") {
                    return true
                }
                let isSplitSel = NSSelectorFromString("isSplit")
                if placement.responds(to: isSplitSel),
                   let method = class_getInstanceMethod(type(of: placement), isSplitSel) {
                    typealias IsSplitFn = @convention(c) (AnyObject, Selector) -> Bool
                    let fn = unsafeBitCast(method_getImplementation(method), to: IsSplitFn.self)
                    if fn(placement, isSplitSel) {
                        return true
                    }
                }
            }
        }
        if let hostClass: AnyClass = NSClassFromString("UIPeripheralHost") {
            let sharedSel = NSSelectorFromString("sharedInstance")
            if hostClass.responds(to: sharedSel),
               let host = (hostClass as AnyObject).perform(sharedSel)?.takeUnretainedValue() {
                for selName in ["isSplit", "isSplitting"] {
                    let sel = NSSelectorFromString(selName)
                    if host.responds(to: sel),
                       let method = class_getInstanceMethod(type(of: host), sel) {
                        typealias BoolFn = @convention(c) (AnyObject, Selector) -> Bool
                        let fn = unsafeBitCast(method_getImplementation(method), to: BoolFn.self)
                        if fn(host, sel) {
                            return true
                        }
                    }
                }
            }
        }
        if let implClass: AnyClass = NSClassFromString("UIKeyboardImpl") {
            let isSplitSel = NSSelectorFromString("isSplit")
            if let method = class_getClassMethod(implClass, isSplitSel) {
                typealias ClassBoolFn = @convention(c) (AnyObject, Selector) -> Bool
                let fn = unsafeBitCast(method_getImplementation(method), to: ClassBoolFn.self)
                if fn(implClass, isSplitSel) {
                    return true
                }
            }
            let activeSel = NSSelectorFromString("activeInstance")
            if implClass.responds(to: activeSel),
               let active = (implClass as AnyObject).perform(activeSel)?.takeUnretainedValue() {
                if active.responds(to: isSplitSel),
                   let method = class_getInstanceMethod(type(of: active), isSplitSel) {
                    typealias InstBoolFn = @convention(c) (AnyObject, Selector) -> Bool
                    let fn = unsafeBitCast(method_getImplementation(method), to: InstBoolFn.self)
                    if fn(active, isSplitSel) {
                        return true
                    }
                }
            }
        }
        return nil
    }

    public static func hasActiveSystemFloatingGesture(in view: UIView) -> Bool {
        var current: UIView? = view
        while let node = current {
            if let recognizers = node.gestureRecognizers {
                for gr in recognizers {
                    guard gr.state == .began || gr.state == .changed else { continue }
                    if gr is UIPinchGestureRecognizer || gr is UIPanGestureRecognizer {
                        let typeName = NSStringFromClass(type(of: gr))
                        let delegateName = gr.delegate.map { NSStringFromClass(type(of: $0)) } ?? ""
                        if gr is UIPinchGestureRecognizer
                            || delegateName.contains("Floating")
                            || delegateName.contains("Peripheral")
                            || delegateName.contains("Dock")
                            || typeName.contains("Keyboard") {
                            return true
                        }
                    }
                }
            }
            current = node.superview
        }
        return false
    }
    #endif
}

private extension UIInputViewController {

    var orientation: InterfaceOrientation {
        #if os(iOS) || os(tvOS)
        view.window?.screen.interfaceOrientation ?? .portrait
        #else
        .portrait
        #endif
    }

    var screenSize: CGSize {
        #if os(iOS) || os(tvOS)
        view.window?.screen.bounds.size ?? .zero
        #else
        .zero
        #endif
    }
}
#endif
