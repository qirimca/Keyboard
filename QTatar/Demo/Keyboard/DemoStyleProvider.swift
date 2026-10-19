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
    
    static func isSandboxOverrideActive(for context: KeyboardContext) -> Bool {
        let isOwnApp = context.hostApplicationBundleId == nil || context.hostApplicationBundleId == AppConfiguration.appBundleId
        return isOwnApp && KeyboardPreferences.defaults.bool(forKey: "crh.key.test.sandboxFocused")
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
        return context.hasDarkColorScheme || context.keyboardAppearance == .dark
    }

    /// Whether the keyboard should render like the *classic* (pre-Liquid-Glass) system keyboard: gray system keys.
    ///
    /// - Before iOS 26 the system keyboard never has the Liquid Glass design, so this is always `true`.
    /// - On iOS 26+ the design depends on the host: apps built with an older SDK (or opted out through
    ///   `UIDesignRequiresCompatibility`) keep the classic keyboard. That is not decided by a list of app
    ///   names; it is read from the keyboard's own environment (see ``ClassicHostDetector``).
    /// - The Testing Sandbox of this app may force either style, but only while its field is focused and only
    ///   for this app, so the override can never leak into other apps.
    static func usesClassicGraySystemKeys(for context: KeyboardContext) -> Bool {
        if isSandboxOverrideActive(for: context),
           let overrideMode = KeyboardPreferences.defaults.string(forKey: "crh.key.test.systemKeyStyle") {
            if overrideMode == "google_gray" { return true }
            if overrideMode == "ios26_white" { return false }
        }
        switch KeyboardPreferences.systemKeyStyle {
        case "classic": return true
        case "modern": return false
        default: break
        }
        if #unavailable(iOS 26) { return true }
        return ClassicHostDetector.shared.isClassicHost
    }

    private var usesClassicGraySystemKeys: Bool {
        Self.usesClassicGraySystemKeys(for: keyboardContext)
    }

    override var autocompleteToolbarStyle: Autocomplete.ToolbarStyle {
        var style = super.autocompleteToolbarStyle
        guard KeyboardPreferences.suggestionsEnabled else {
            style.height = 0
            return style
        }
        if keyboardContext.isKeyboardFloating {
            style.height = 42
        } else if isPad {
            style.height = 37
        } else {
            style.height = 42
        }
        return style
    }

    override func buttonCornerRadius(for action: KeyboardAction) -> CGFloat {
        if keyboardContext.isKeyboardFloating {
            return 7.5
        }
        if isPad {
            return keyboardContext.interfaceOrientation.isPortrait ? 6.5 : 7.5
        }
        return 5
    }
    
    override var keyboardEdgeInsets: EdgeInsets {
        if keyboardContext.isKeyboardFloating {
            // Native iPad floating keyboard has 6pt horizontal, 4pt top, and 6pt bottom padding inside the floating card
            return EdgeInsets(top: 4, leading: 6, bottom: 6, trailing: 6)
        }
        switch keyboardContext.deviceType {
        case .phone:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        case .pad:
            return EdgeInsets(top: 0, leading: 1, bottom: 0, trailing: 1)
        default:
            return super.keyboardEdgeInsets
        }
    }
    
    override var keyboardLayoutConfiguration: KeyboardLayout.Configuration {
        var config = super.keyboardLayoutConfiguration
        if keyboardContext.isKeyboardFloating {
            config.rowHeight = 49
            config.buttonInsets = EdgeInsets(top: 7.5, leading: 2.5, bottom: 7.5, trailing: 2.5)
            config.buttonCornerRadius = 7.5
        } else if keyboardContext.deviceType == .phone {
            let isPortrait = keyboardContext.interfaceOrientation.isPortrait
            config.rowHeight = isPortrait ? 54 : 42
        } else if isPad {
            let isPortrait = keyboardContext.interfaceOrientation.isPortrait
            config.rowHeight = isPortrait ? 55 : 72
            config.buttonInsets = isPortrait
                ? EdgeInsets(top: 4.5, leading: 5.0, bottom: 4.5, trailing: 5.0)
                : EdgeInsets(top: 5.5, leading: 6.5, bottom: 5.5, trailing: 6.5)
            config.buttonCornerRadius = isPortrait ? 6.5 : 7.5
        }
        return config
    }
    
    override func rowHeight(
        forRowAt rowIndex: Int,
        in layout: KeyboardLayout
    ) -> CGFloat {
        let isCompact = keyboardContext.deviceType == .phone || keyboardContext.isKeyboardFloating
        if isCompact {
            return letterRowHeight
        }
        if isPad {
            return keyboardContext.interfaceOrientation.isPortrait ? 55 : 72
        }
        return super.rowHeight(forRowAt: rowIndex, in: layout)
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
        // Centered system labels keep sufficient padding on docked iPad.
        if isPad {
            return .init(top: 7, leading: 9, bottom: 7, trailing: 9)
        }
        return super.buttonContentInsets(for: action)
    }
    
    override func buttonImageScaleFactor(for action: KeyboardAction) -> CGFloat {
        // In iPad floating mode, use compact phone icon scale instead of iPad's 1.2x scale
        // so Shift and Backspace icons fit cleanly inside their compact keys.
        if keyboardContext.isKeyboardFloating {
            return 0.92
        }
        if keyboardContext.deviceType == .phone {
            switch action {
            case .shift, .capsLock, .backspace:
                return 0.95
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
            } else if name == "url_domain" {
                return nil
            }
            return super.buttonImage(for: action)
        case .nextKeyboard:
            return Image(systemName: "globe")
        case .keyboardType(let type):
            if type == .emojis {
                // Use Apple's exact native keyboard emoji vector icon
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
            // Native iOS/iPadOS always uses SF Symbol icons for Return, Search, Go, etc.
            return nil
        default:
            return super.buttonText(for: action)
        }
    }
    
    /// Height of letter rows tuned for native iOS look and feel
    private var letterRowHeight: CGFloat {
        if keyboardContext.isKeyboardFloating {
            return 49 // Native iPad floating keyboard row height (4 * 49 = 196pt + 44pt toolbar = 240pt)
        }
        let isPortrait = keyboardContext.interfaceOrientation.isPortrait
        return isPortrait ? 54 : 42 // Standard iOS keyboard row height on iPhone (portrait ~54pt)
    }
    
    var isPrimaryActionEnabled: Bool {
        let proxy = keyboardContext.textDocumentProxy
        if Self.effectiveEnablesReturnKeyAutomatically(for: keyboardContext) {
            let hasText = proxy.hasText || !(proxy.documentContextBeforeInput?.isEmpty ?? true)
            return hasText
        }
        return true
    }
    
    override func buttonBackgroundColor(
        for action: KeyboardAction,
        isPressed: Bool
    ) -> Color {
        if !usesClassicGraySystemKeys && (action.isUppercasedShiftAction || (action == .capsLock && keyboardContext.keyboardType.isAlphabeticCapsLocked)) {
            return .white
        }
        switch action {
        case .none, .characterMargin:
            return .clear
        default:
            break
        }
        
        let context = keyboardContext
        let isDark = Self.effectiveIsDark(for: context)
        
        let darkInputKey = Color(white: 0.28)
        let darkInputKeyPressed = Color(white: 0.18)
        let modern = !usesClassicGraySystemKeys
        let darkSystemKey = modern ? darkInputKey : Color(white: 0.18)
        let darkSystemKeyPressed = modern ? darkInputKeyPressed : Color(white: 0.32)
        
        let lightInputKey = Color.white
        let lightInputKeyPressed = Color(white: 0.85)
        let lightSystemKeyGray = Color(red: 172/255, green: 177/255, blue: 185/255)
        let lightSystemKeyGrayPressed = Color.white
        
        // On iPad in standard iOS 26 mode (Safari, Notes, etc.), system keys are pure white like letter keys.
        // Classic mode uses gray system keys on both iPhone and iPad.
        let useWhiteSystemKeysInLight = !usesClassicGraySystemKeys
        let lightSystemKey = useWhiteSystemKeysInLight ? lightInputKey : lightSystemKeyGray
        let lightSystemKeyPressed = useWhiteSystemKeysInLight ? lightInputKeyPressed : lightSystemKeyGrayPressed
        
        // Return / Primary actions
        if case .primary(let type) = action {
            switch type {
            case .newLine, .return:
                return isPressed
                    ? (isDark ? darkSystemKeyPressed : lightSystemKeyPressed)
                    : (isDark ? darkSystemKey : lightSystemKey)
            default:
                // Primary action keys (Search, Go, Send, etc.):
                // When field is empty, key remains an inactive gray button (even in Safari iOS 26!).
                // Only illuminates blue when input contains text.
                guard isPrimaryActionEnabled else {
                    return isPressed
                        ? (isDark ? darkSystemKeyPressed : lightSystemKeyGrayPressed)
                        : (isDark ? darkSystemKey : lightSystemKeyGray)
                }
                return isPressed ? Color.blue.opacity(0.7) : Color.blue
            }
        }
        
        // URL domain (.com) is styled as an input/white key on iOS
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
        
        // System actions (Tab, Shift, Backspace, 123, Globe, Dismiss, etc.)
        if action.isSystemAction {
            return isPressed
                ? (isDark ? darkSystemKeyPressed : lightSystemKeyPressed)
                : (isDark ? darkSystemKey : lightSystemKey)
        }
        
        // Letter / Input keys (identical styling for letters, numbers, symbols, and space)
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
        if !usesClassicGraySystemKeys && (action.isUppercasedShiftAction || (action == .capsLock && keyboardContext.keyboardType.isAlphabeticCapsLocked)) {
            return .black
        }
        switch action {
        case .none, .characterMargin:
            return .clear
        default:
            break
        }
        
        let context = keyboardContext
        let isDark = Self.effectiveIsDark(for: context)
        
        if case .primary(let type) = action {
            switch type {
            case .newLine, .return:
                return isDark ? .white : .black
            default:
                guard isPrimaryActionEnabled else {
                    return isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.35)
                }
                return .white
            }
        }
        
        // Dim Undo / Redo icons when stack is empty
        if case .custom(let name) = action {
            if name == "undo" && !TextHistoryManager.shared.canUndo {
                return isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.35)
            }
            if name == "redo" && !TextHistoryManager.shared.canRedo {
                return isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.35)
            }
        }
        
        return isDark ? .white : .black
    }

    override func buttonFont(for action: KeyboardAction) -> KeyboardFont {
        let isFloating = keyboardContext.isKeyboardFloating
        let isDockedPad = isPad && !isFloating
        switch action {
        case .character(let char):
            let isLetter = char.first?.isLetter ?? false
            if isLetter {
                let isLower = char == char.lowercased() && char != char.uppercased()
                if isFloating {
                    return .system(size: isLower ? 22 : 19, weight: .regular)
                } else if isDockedPad {
                    return .system(size: isLower ? 23 : 21, weight: isLower ? .light : .regular)
                } else {
                    return .system(size: isLower ? 25 : 22, weight: .regular)
                }
            }
            return .system(size: isFloating ? 19 : (isDockedPad ? 21 : 22), weight: .regular)
        case .custom(let name) where name == "url_domain":
            return .system(size: isFloating ? 14 : (isDockedPad ? 15 : 16), weight: .regular)
        case .custom(let name) where name == "toggle_script":
            return .system(size: isDockedPad ? 17 : 14, weight: .regular)
        case .keyboardType:
            return .system(size: isFloating ? 14 : (isDockedPad ? 18 : 16), weight: .regular)
        default:
            if buttonImage(for: action) != nil {
                if isDockedPad {
                    return .system(size: keyboardContext.interfaceOrientation.isPortrait ? 22 : 24, weight: .regular)
                }
                return .system(size: isFloating ? 17 : 20, weight: .regular)
            }
            return super.buttonFont(for: action)
        }
    }
    
    override func buttonShadowStyle(for action: KeyboardAction) -> Keyboard.ButtonShadowStyle {
        if keyboardContext.isSpaceDragGestureActive || isPad || keyboardContext.isKeyboardFloating { return .noShadow }
        switch action {
        case .characterMargin, .emoji, .none:
            return .noShadow
        default:
            // Native iOS buttons have a subtle 1pt bottom drop shadow on key cap
            let isDark = Self.effectiveIsDark(for: keyboardContext)
            let shadowColor = isDark 
                ? Color.black.opacity(0.45) 
                : Color.black.opacity(0.25)
            
            return .init(
                color: shadowColor,
                size: 1
            )
        }
    }
}

/// Decides whether the current host shows the *classic* system keyboard on iOS 26+ (apps linked against an
/// older SDK). Research on iOS 27 simulators found no public signal visible to a keyboard extension (traits are
/// identical in classic and modern hosts; the host's bundle id is private and often unavailable). So:
/// - "classic" / "modern" in the app's settings decide explicitly;
/// - "auto" means modern on iOS 26+ (before iOS 26 the caller already returns classic).
/// The keyboard records host diagnostics (`recordHostDiagnostics`) to calibrate a geometric signal later.
final class ClassicHostDetector {
    static let shared = ClassicHostDetector()
    var isClassicHost: Bool {
        switch KeyboardPreferences.systemKeyStyle {
        case "classic": return true
        default: return false
        }
    }
}
