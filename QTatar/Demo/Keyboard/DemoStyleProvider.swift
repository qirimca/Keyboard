//
//  DemoStyleProvider.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2022-12-21.
//  Copyright © 2022-2024 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import SwiftUI

/**
 This demo-specific provider inherits the standard one, then
 customizes the keyboard style to match Apple's native design:
 fonts, weights, colors, and shadows.
 */
class DemoStyleProvider: StandardKeyboardStyleProvider {

    private var isPad: Bool {
        keyboardContext.deviceType == .pad
    }
    
    /// Preview overrides require explicit registration of an in-process context.
    /// Shared defaults and an unknown host cannot authenticate a sandbox session.
    private static let sandboxPreviewContexts = NSHashTable<KeyboardContext>.weakObjects()

    static func registerSandboxPreview(_ context: KeyboardContext) {
        guard Bundle.main.bundleIdentifier == AppConfiguration.appBundleId else { return }
        sandboxPreviewContexts.add(context)
    }

    static func unregisterSandboxPreview(_ context: KeyboardContext) {
        sandboxPreviewContexts.remove(context)
    }

    static func isSandboxOverrideActive(for context: KeyboardContext) -> Bool {
        Bundle.main.bundleIdentifier == AppConfiguration.appBundleId
            && sandboxPreviewContexts.contains(context)
            && KeyboardPreferences.defaults.bool(forKey: "crh.key.test.sandboxFocused")
    }

    static func effectiveProxyKeyboardType(for context: KeyboardContext) -> UIKeyboardType {
        if isSandboxOverrideActive(for: context),
           let mode = KeyboardPreferences.defaults.string(forKey: "crh.key.test.fieldMode") {
            switch mode {
            case "field.search": return .webSearch
            case "field.email": return .emailAddress
            case "field.url": return .URL
            case "field.numbers": return .numbersAndPunctuation
            case "field.standard": return .default
            default: break
            }
        }
        return context.textDocumentProxy.keyboardType ?? .default
    }

    static func effectiveReturnKeyType(for context: KeyboardContext) -> UIReturnKeyType? {
        if isSandboxOverrideActive(for: context),
           let mode = KeyboardPreferences.defaults.string(forKey: "crh.key.test.fieldMode") {
            switch mode {
            case "field.search": return .search
            case "field.email": return .default
            case "field.url": return .go
            case "field.numbers": return .done
            case "field.standard": return .default
            default: break
            }
        }
        return context.textDocumentProxy.returnKeyType
    }

    static func effectiveEnablesReturnKeyAutomatically(for context: KeyboardContext) -> Bool {
        if isSandboxOverrideActive(for: context),
           let mode = KeyboardPreferences.defaults.string(forKey: "crh.key.test.fieldMode") {
            return mode != "field.standard"
        }
        return context.textDocumentProxy.enablesReturnKeyAutomatically == true
    }

    static func effectiveIsDark(for context: KeyboardContext) -> Bool {
        if isSandboxOverrideActive(for: context),
           KeyboardPreferences.defaults.object(forKey: "crh.key.test.isDark") != nil {
            return KeyboardPreferences.defaults.bool(forKey: "crh.key.test.isDark")
        }
        if context.keyboardAppearance == .dark {
            return true
        }
        if context.keyboardAppearance == .light {
            return false
        }
        if context.traitCollection.userInterfaceStyle == .dark
            || context.colorScheme == .dark
            || UITraitCollection.current.userInterfaceStyle == .dark
            || UIScreen.main.traitCollection.userInterfaceStyle == .dark {
            return true
        }
        return context.hasDarkColorScheme
    }

    static func shouldShowTopToolbar(for context: KeyboardContext) -> Bool {
        guard KeyboardPreferences.suggestionsEnabled && SystemKeyboardSettings.isPredictiveTextEnabled(for: context.textDocumentProxy) else {
            return false
        }
        if context.textDocumentProxy.isSecureTextEntry == true {
            return false
        }
        let kbType = effectiveProxyKeyboardType(for: context)
        switch kbType {
        case .default, .asciiCapable, .twitter, .namePhonePad, .webSearch:
            return true
        default:
            return false
        }
    }

    static func effectiveScreenSize(for context: KeyboardContext) -> CGSize {
        if context.screenSize.width > 0 && context.screenSize.height > 0 {
            return context.screenSize
        }
        return UIScreen.main.bounds.size
    }

    static func resolvedMetrics(
        for context: KeyboardContext,
        isLandscapeOverride: Bool? = nil,
        isFloatingOverride: Bool? = nil,
        hasToolbarOverride: Bool? = nil
    ) -> KeyboardAdaptiveGeometry {
        let isPad = context.deviceType == .pad
        let isFloating = isFloatingOverride ?? context.isKeyboardFloating
        let isPortrait = !(isLandscapeOverride ?? context.interfaceOrientation.isLandscape)
        let hasToolbar = hasToolbarOverride ?? shouldShowTopToolbar(for: context)
        let screenSize = effectiveScreenSize(for: context)
        return KeyboardAdaptiveGeometry.resolve(
            isPad: isPad,
            isFloating: isFloating,
            isPortrait: isPortrait,
            screenSize: screenSize,
            hasToolbar: hasToolbar
        )
    }

    static func rowHeight(forRowAt rowIndex: Int, context: KeyboardContext) -> CGFloat {
        if context.isKeyboardFloating {
            return 43
        }
        return resolvedMetrics(for: context).rowHeight(forRowAt: rowIndex)
    }

    static func itemEdgeInsets(forRowAt rowIndex: Int, context: KeyboardContext) -> EdgeInsets {
        let metrics = resolvedMetrics(for: context)
        let vertical = metrics.verticalItemInset(forRowAt: rowIndex)
        let horizontal = metrics.horizontalItemInset
        return EdgeInsets(top: vertical, leading: horizontal, bottom: vertical, trailing: horizontal)
    }

    static func expectedKeyboardHeight(
        for context: KeyboardContext,
        isLandscapeOverride: Bool? = nil,
        isFloatingOverride: Bool? = nil,
        hasToolbar: Bool
    ) -> CGFloat {
        resolvedMetrics(
            for: context,
            isLandscapeOverride: isLandscapeOverride,
            isFloatingOverride: isFloatingOverride,
            hasToolbarOverride: hasToolbar
        ).totalKeyboardHeight
    }

    override var autocompleteToolbarStyle: Autocomplete.ToolbarStyle {
        var style = super.autocompleteToolbarStyle
        guard Self.shouldShowTopToolbar(for: keyboardContext) else {
            style.height = 0
            return style
        }
        style.height = Self.resolvedMetrics(for: keyboardContext, hasToolbarOverride: true).toolbarHeight
        return style
    }

    override func buttonCornerRadius(for action: KeyboardAction) -> CGFloat {
        Self.resolvedMetrics(for: keyboardContext).cornerRadius
    }
    
    override var keyboardEdgeInsets: EdgeInsets {
        let metrics = Self.resolvedMetrics(for: keyboardContext)
        return EdgeInsets(
            top: metrics.edgeTopBottomInset,
            leading: metrics.edgeHorizontalInset,
            bottom: metrics.edgeTopBottomInset,
            trailing: metrics.edgeHorizontalInset
        )
    }
    
    override var keyboardLayoutConfiguration: KeyboardLayout.Configuration {
        var config = super.keyboardLayoutConfiguration
        let metrics = Self.resolvedMetrics(for: keyboardContext)
        config.rowHeight = metrics.letterRowHeight
        config.buttonInsets = EdgeInsets(
            top: metrics.letterTopBottomInset,
            leading: metrics.horizontalItemInset,
            bottom: metrics.letterTopBottomInset,
            trailing: metrics.horizontalItemInset
        )
        config.buttonCornerRadius = metrics.cornerRadius
        return config
    }
    
    override func rowHeight(
        forRowAt rowIndex: Int,
        in layout: KeyboardLayout
    ) -> CGFloat {
        Self.rowHeight(forRowAt: rowIndex, context: keyboardContext)
    }
    
    override func buttonContentInsets(for action: KeyboardAction) -> EdgeInsets {
        if action.isInputAction {
            return .init(top: 0, leading: 0, bottom: 0, trailing: 0)
        }
        if case .custom(let name) = action, name == "url_domain" {
            return .init(top: 0, leading: 0, bottom: 0, trailing: 0)
        }
        // In compact/floating or 12-column phone mode, Shift and Backspace are 1.0x unit wide (~22-28pt),
        // so the default 8pt horizontal content inset crushes or overflows their icons.
        if keyboardContext.isKeyboardFloating || keyboardContext.deviceType == .phone {
            return .init(top: 2, leading: 2, bottom: 2, trailing: 2)
        }
        if isPad {
            return .init(top: 5, leading: 6, bottom: 5, trailing: 6)
        }
        return super.buttonContentInsets(for: action)
    }
    
    override func buttonImageScaleFactor(for action: KeyboardAction) -> CGFloat {
        if keyboardContext.isKeyboardFloating {
            return 0.90
        }
        if keyboardContext.deviceType == .phone {
            switch action {
            case .shift, .capsLock, .backspace:
                return 0.85
            default:
                return 1.0
            }
        }
        if isPad {
            return 1.0
        }
        return super.buttonImageScaleFactor(for: action)
    }
    
    override func buttonImage(for action: KeyboardAction) -> Image? {
        switch action {
        case .shift(let casing):
            switch casing {
            case .lowercased, .auto:
                return Image(systemName: "shift")
            case .uppercased:
                return Image(systemName: "shift.fill")
            case .capsLocked:
                // When a dedicated Caps Lock key is visible on Docked iPad (Cyrillic disabled),
                // Caps Lock shows capslock.fill while Shift stays shift outline.
                if isPad && !keyboardContext.isKeyboardFloating && !KeyboardPreferences.cyrillicEnabled {
                    return Image(systemName: "shift")
                }
                return Image(systemName: "capslock.fill")
            }
        case .capsLock:
            return Image(systemName: keyboardContext.keyboardType.isAlphabeticCapsLocked ? "capslock.fill" : "capslock")
        case .backspace:
            return Image(systemName: "delete.backward")
        case .dismissKeyboard:
            return Image(systemName: "keyboard.chevron.compact.down")
        case .tab:
            return Image(systemName: "arrow.right.to.line")
        case .custom(let name):
            if name == "undo" {
                return Image(systemName: "arrow.uturn.backward")
            } else if name == "redo" {
                return Image(systemName: "arrow.uturn.forward")
            } else if name == "url_domain" || name == "toggle_script" {
                return nil
            }
            return super.buttonImage(for: action)
        case .nextKeyboard:
            return Image(systemName: "globe")
        case .keyboardType(let type):
            if type == .emojis {
                return super.buttonImage(for: action)
            }
            return super.buttonImage(for: action)
        case .primary(let type):
            switch type {
            case .search:
                return Image(systemName: "magnifyingglass")
            case .return, .newLine:
                return Image(systemName: "return")
            case .go:
                return Image(systemName: "arrow.right")
            case .send:
                return Image(systemName: "arrow.up")
            case .done:
                return Image(systemName: "checkmark")
            case .next:
                return Image(systemName: "arrow.right.to.line")
            case .continue:
                return Image(systemName: "arrow.right")
            default:
                return Image(systemName: "return")
            }
        default:
            return super.buttonImage(for: action)
        }
    }
    
    override func buttonText(for action: KeyboardAction) -> String? {
        switch action {
        case .space, .tab, .capsLock:
            return nil
        case .custom(let name):
            if name == "toggle_script" {
                return keyboardContext.locale.identifier.contains("Cyrl") ? "abc" : "абв"
            }
            if name == "url_domain" {
                return ".com"
            }
            return nil
        case .keyboardType(let type):
            switch type {
            case .numeric:
                return (isPad && !keyboardContext.isKeyboardFloating) ? ".?123" : "123"
            case .symbolic:
                return "#+="
            case .alphabetic:
                return keyboardContext.locale.identifier.contains("Cyrl") ? "АБВ" : "ABC"
            default:
                return super.buttonText(for: action)
            }
        case .primary:
            return nil
        default:
            return super.buttonText(for: action)
        }
    }
    
    /// Height of letter rows tuned for native iOS look and feel
    private var letterRowHeight: CGFloat {
        Self.resolvedMetrics(for: keyboardContext).letterRowHeight
    }
    
    var isPrimaryActionEnabled: Bool {
        let proxy = keyboardContext.textDocumentProxy
        if Self.effectiveEnablesReturnKeyAutomatically(for: keyboardContext) {
            let hasText = proxy.hasText || !(proxy.documentContextBeforeInput?.isEmpty ?? true)
            return hasText
        }
        return true
    }
    
    static var usesClassicSystemKeyStyle: Bool {
        if let override = KeyboardPreferences.defaults.object(forKey: "crh.key.test.useClassicStyle") as? Bool {
            return override
        }
        if #available(iOS 26.0, *) {
            return false
        }
        return true
    }

    override func buttonBackgroundColor(
        for action: KeyboardAction,
        isPressed: Bool
    ) -> Color {
        switch action {
        case .none, .characterMargin:
            return .clear
        default:
            break
        }
        
        let context = keyboardContext
        let isDark = Self.effectiveIsDark(for: context)
        let useClassicStyle = Self.usesClassicSystemKeyStyle

        let darkInputKey = useClassicStyle
            ? Color(white: 0.28)
            : Color(red: 0.27, green: 0.27, blue: 0.29).opacity(0.88)
        let darkInputKeyPressed = useClassicStyle
            ? Color(white: 0.18)
            : Color(red: 0.36, green: 0.36, blue: 0.39).opacity(0.92)
        let darkSystemKeyGray = useClassicStyle
            ? Color(white: 0.20)
            : Color(red: 0.21, green: 0.21, blue: 0.23).opacity(0.82)
        let darkSystemKeyGrayPressed = useClassicStyle
            ? Color(white: 0.28)
            : Color(red: 0.31, green: 0.31, blue: 0.34).opacity(0.90)
        let darkSystemKey = useClassicStyle ? darkSystemKeyGray : darkInputKey
        let darkSystemKeyPressed = useClassicStyle ? darkSystemKeyGrayPressed : darkInputKeyPressed

        let lightInputKey = useClassicStyle
            ? Color.white
            : Color.white.opacity(0.92)
        let lightInputKeyPressed = useClassicStyle
            ? Color(white: 0.85)
            : Color(white: 0.72).opacity(0.68)
        let lightSystemKeyGray = useClassicStyle
            ? Color(red: 172.0 / 255.0, green: 177.0 / 255.0, blue: 185.0 / 255.0) // #ACB3BE
            : Color(red: 0.68, green: 0.70, blue: 0.75).opacity(0.46)
        let lightSystemKeyGrayPressed = lightInputKey

        let lightSystemKey = useClassicStyle ? lightSystemKeyGray : lightInputKey
        let lightSystemKeyPressed = useClassicStyle ? lightSystemKeyGrayPressed : lightInputKeyPressed
        
        // Return / Primary actions
        if case .primary(let type) = action {
            switch type {
            case .newLine, .return:
                return isPressed
                    ? (isDark ? darkSystemKeyPressed : lightSystemKeyPressed)
                    : (isDark ? darkSystemKey : lightSystemKey)
            default:
                guard isPrimaryActionEnabled else {
                    return isPressed
                        ? (isDark ? darkSystemKeyPressed : lightSystemKeyGrayPressed)
                        : (isDark ? darkSystemKey : lightSystemKeyGray)
                }
                return isPressed ? Color.blue.opacity(0.7) : Color.blue
            }
        }
        
        if case .custom(let name) = action {
            if name == "url_domain" {
                return isPressed
                    ? (isDark ? darkInputKeyPressed : lightInputKeyPressed)
                    : (isDark ? darkInputKey : lightInputKey)
            }
            if name == "undo" || name == "redo" || name == "toggle_script" {
                return isPressed
                    ? (isDark ? darkSystemKeyPressed : lightSystemKeyPressed)
                    : (isDark ? darkSystemKey : lightSystemKey)
            }
        }
        
        // System actions (Tab, Shift, CapsLock, Backspace, 123, Globe, Dismiss, etc.)
        // Note: Active Shift and Caps Lock keep the standard system key background — only the arrow symbol fills.
        if action.isSystemAction {
            return isPressed
                ? (isDark ? darkSystemKeyPressed : lightSystemKeyPressed)
                : (isDark ? darkSystemKey : lightSystemKey)
        }
        
        if action.isInputAction {
            return isPressed
                ? (isDark ? darkInputKeyPressed : lightInputKeyPressed)
                : (isDark ? darkInputKey : lightInputKey)
        }
        
        return super.buttonBackgroundColor(for: action, isPressed: isPressed)
    }
    
    override func buttonForegroundColor(
        for action: KeyboardAction,
        isPressed: Bool
    ) -> Color {
        switch action {
        case .none, .characterMargin:
            return .clear
        default:
            break
        }
        
        let context = keyboardContext
        let isDark = Self.effectiveIsDark(for: context)
        let primaryLabelColor = isDark ? Color.white.opacity(0.88) : Color.black.opacity(0.84)
        
        if case .primary(let type) = action {
            switch type {
            case .newLine, .return:
                return primaryLabelColor
            default:
                guard isPrimaryActionEnabled else {
                    return isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.35)
                }
                return .white
            }
        }
        
        if case .custom(let name) = action {
            if name == "undo" && !TextHistoryManager.shared.canUndo {
                return isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.35)
            }
            if name == "redo" && !TextHistoryManager.shared.canRedo {
                return isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.35)
            }
        }
        
        return primaryLabelColor
    }

    override func buttonFont(for action: KeyboardAction) -> KeyboardFont {
        let isFloating = keyboardContext.isKeyboardFloating
        let isDockedPad = isPad && !isFloating
        let isPortrait = keyboardContext.interfaceOrientation.isPortrait
        let effScreen = Self.effectiveScreenSize(for: keyboardContext)
        let minScreenDim = min(effScreen.width, effScreen.height)
        let isCompactPhone = !isPad && !isFloating && minScreenDim > 0 && minScreenDim < 385
        switch action {
        case .character(let char):
            let isLetter = char.first?.isLetter ?? false
            if isLetter {
                let isLower = char == char.lowercased() && char != char.uppercased()
                if isFloating {
                    return .system(size: isLower ? 19.5 : 17.5, weight: .regular)
                } else if isDockedPad {
                    return .system(size: isPortrait ? (isLower ? 20.5 : 19.5) : (isLower ? 23.0 : 21.5), weight: .regular)
                } else if isCompactPhone {
                    return .system(size: isLower ? 22.5 : 19.5, weight: .regular)
                } else {
                    return .system(size: isLower ? 24.5 : 21.5, weight: .regular)
                }
            }
            return .system(size: isFloating ? 18 : (isDockedPad ? (isPortrait ? 20 : 22) : (isCompactPhone ? 20 : 21.5)), weight: .regular)
        case .custom(let name) where name == "url_domain":
            return .system(size: isFloating ? 14 : (isDockedPad ? 15 : 15.5), weight: .regular)
        case .custom(let name) where name == "toggle_script":
            return .system(size: isDockedPad ? (isPortrait ? 17.5 : 18) : 14, weight: .regular)
        case .keyboardType(let type):
            if type == .emojis {
                if isDockedPad {
                    return .system(size: isPortrait ? 19 : 21, weight: .regular)
                }
                return .system(size: isFloating ? 16.5 : 19, weight: .regular)
            }
            return .system(size: isFloating ? 14 : (isDockedPad ? (isPortrait ? 17.5 : 18) : 15.0), weight: .regular)
        case .shift, .capsLock, .backspace:
            if isDockedPad {
                return .system(size: isPortrait ? 19 : 21, weight: .regular)
            }
            return .system(size: 16.5, weight: .regular)
        default:
            if buttonImage(for: action) != nil {
                if isDockedPad {
                    return .system(size: isPortrait ? 19 : 21, weight: .regular)
                }
                return .system(size: isFloating ? 16.5 : 19, weight: .regular)
            }
            return super.buttonFont(for: action)
        }
    }
    
    override func buttonShadowStyle(for action: KeyboardAction) -> Keyboard.ButtonShadowStyle {
        .noShadow
    }
}
