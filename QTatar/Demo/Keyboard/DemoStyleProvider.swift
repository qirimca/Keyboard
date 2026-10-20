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
        if let bundleId = context.hostApplicationBundleId, bundleId != AppConfiguration.appBundleId {
            return false
        }
        guard KeyboardPreferences.defaults.bool(forKey: "crh.key.test.sandboxFocused") else {
            return false
        }
        let ts = KeyboardPreferences.defaults.double(forKey: "crh.key.test.overrideTimestamp")
        let recentlyToggled = ts > 0 && (Date().timeIntervalSince1970 - ts) < 2.5
        if context.hostApplicationBundleId == nil && !recentlyToggled {
            let appearance = context.textDocumentProxy.keyboardAppearance ?? .default
            if appearance == .default {
                return false
            }
        }
        return true
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

    override var autocompleteToolbarStyle: Autocomplete.ToolbarStyle {
        var style = super.autocompleteToolbarStyle
        guard KeyboardPreferences.suggestionsEnabled else {
            style.height = 0
            return style
        }
        if keyboardContext.isKeyboardFloating {
            style.height = 38
        } else if isPad {
            style.height = 38
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
            return keyboardContext.interfaceOrientation.isPortrait ? 7.0 : 8.0
        }
        return 5.5
    }
    
    override var keyboardEdgeInsets: EdgeInsets {
        if keyboardContext.isKeyboardFloating {
            // Leave the bottom 30pt floatingChromeBuffer grabber bar uncovered inside the 346pt system floating card
            return EdgeInsets(top: 2, leading: 6, bottom: 4, trailing: 6)
        }
        switch keyboardContext.deviceType {
        case .phone:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        case .pad:
            return EdgeInsets(top: 2, leading: 3, bottom: 2, trailing: 3)
        default:
            return super.keyboardEdgeInsets
        }
    }
    
    override var keyboardLayoutConfiguration: KeyboardLayout.Configuration {
        var config = super.keyboardLayoutConfiguration
        if keyboardContext.isKeyboardFloating {
            config.rowHeight = 43
            config.buttonInsets = EdgeInsets(top: 5.0, leading: 2.5, bottom: 5.0, trailing: 2.5)
            config.buttonCornerRadius = 7.5
        } else if keyboardContext.deviceType == .phone {
            let isPortrait = keyboardContext.interfaceOrientation.isPortrait
            config.rowHeight = isPortrait ? 55 : 42
            config.buttonInsets = isPortrait
                ? EdgeInsets(top: 5.0, leading: 2.5, bottom: 5.0, trailing: 2.5)
                : EdgeInsets(top: 3.5, leading: 2.5, bottom: 3.5, trailing: 2.5)
            config.buttonCornerRadius = 5.5
        } else if isPad {
            let isPortrait = keyboardContext.interfaceOrientation.isPortrait
            config.rowHeight = isPortrait ? 58 : 75
            config.buttonInsets = isPortrait
                ? EdgeInsets(top: 4.0, leading: 3.5, bottom: 4.0, trailing: 3.5)
                : EdgeInsets(top: 5.0, leading: 4.5, bottom: 5.0, trailing: 4.5)
            config.buttonCornerRadius = isPortrait ? 7.0 : 8.0
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
            return keyboardContext.interfaceOrientation.isPortrait ? 58 : 75
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
        if isPad {
            if #available(iOS 27.0, *) {
                return .init(top: 9, leading: 11, bottom: 9, trailing: 11)
            } else {
                return .init(top: 5, leading: 6, bottom: 5, trailing: 6)
            }
        }
        return super.buttonContentInsets(for: action)
    }
    
    override func buttonImageScaleFactor(for action: KeyboardAction) -> CGFloat {
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
        if keyboardContext.isKeyboardFloating {
            return 43
        }
        let isPortrait = keyboardContext.interfaceOrientation.isPortrait
        return isPortrait ? 55 : 42
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
        let darkSystemKey = darkInputKey
        let darkSystemKeyPressed = darkInputKeyPressed
        
        let lightInputKey = Color.white
        let lightInputKeyPressed = Color(white: 0.85)
        let lightSystemKeyGray = Color(red: 172/255, green: 177/255, blue: 185/255)
        let lightSystemKeyGrayPressed = Color.white
        
        let lightSystemKey = lightInputKey
        let lightSystemKeyPressed = lightInputKeyPressed
        
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
        let isPortrait = keyboardContext.interfaceOrientation.isPortrait
        switch action {
        case .character(let char):
            let isLetter = char.first?.isLetter ?? false
            if isLetter {
                let isLower = char == char.lowercased() && char != char.uppercased()
                if isFloating {
                    return .system(size: isLower ? 22 : 19, weight: .regular)
                } else if isDockedPad {
                    return .system(size: isPortrait ? (isLower ? 21 : 19.5) : (isLower ? 23 : 21.5), weight: .regular)
                } else {
                    return .system(size: isLower ? 24.5 : 21.5, weight: .regular)
                }
            }
            return .system(size: isFloating ? 19 : (isDockedPad ? (isPortrait ? 20 : 22) : 21.5), weight: .regular)
        case .custom(let name) where name == "url_domain":
            return .system(size: isFloating ? 14 : (isDockedPad ? 15 : 15.5), weight: .regular)
        case .custom(let name) where name == "toggle_script":
            return .system(size: isDockedPad ? (isPortrait ? 16 : 18) : 14, weight: .regular)
        case .keyboardType:
            return .system(size: isFloating ? 14 : (isDockedPad ? (isPortrait ? 16 : 18) : 15.5), weight: .regular)
        default:
            if buttonImage(for: action) != nil {
                if isDockedPad {
                    return .system(size: isPortrait ? 19 : 21, weight: .regular)
                }
                return .system(size: isFloating ? 17 : 19, weight: .regular)
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
