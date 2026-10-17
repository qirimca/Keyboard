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
    
    /// Checks whether the keyboard should render with classic gray system keys on iPad
    /// (e.g. Google/Gmail apps or when "google_gray" is selected in the Testing Sandbox),
    /// vs modern iPadOS 26 all-white keys (Safari, Notes, standard apps).
    private var usesClassicGraySystemKeysOnPad: Bool {
        guard isPad else { return true }
        let defaults = UserDefaults(suiteName: "group.crh.key.keyboardplus")
        if let overrideMode = defaults?.string(forKey: "crh.key.test.systemKeyStyle") {
            if overrideMode == "google_gray" { return true }
            if overrideMode == "ios26_white" { return false }
        }
        if let bundleId = keyboardContext.hostApplicationBundleId?.lowercased() {
            if bundleId.contains("google") || bundleId.contains("gmail") || bundleId.contains("youtube") || bundleId.contains("chrome") {
                return true
            }
        }
        return false
    }

    override var autocompleteToolbarStyle: Autocomplete.ToolbarStyle {
        var style = super.autocompleteToolbarStyle
        guard KeyboardPreferences.suggestionsEnabled else {
            style.height = 0
            return style
        }
        if keyboardContext.isKeyboardFloating {
            style.height = 34
        } else if isPad {
            style.height = 37
        } else {
            style.height = 42
        }
        return style
    }

    override func buttonCornerRadius(for action: KeyboardAction) -> CGFloat {
        if isPad && !keyboardContext.isKeyboardFloating {
            return keyboardContext.interfaceOrientation.isPortrait ? 6.5 : 7.5
        }
        return 5
    }
    
    override var keyboardEdgeInsets: EdgeInsets {
        if keyboardContext.isKeyboardFloating {
            // Native iPad floating keyboard has ~6pt horizontal and 4pt bottom padding inside the floating card
            return EdgeInsets(top: 2, leading: 6, bottom: 4, trailing: 6)
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
            config.rowHeight = 45
            config.buttonInsets = EdgeInsets(top: 3.5, leading: 2.5, bottom: 3.5, trailing: 2.5)
            config.buttonCornerRadius = 5
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
            return Image(systemName: "capslock.fill")
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
        case .space:
            return nil
        case .tab:
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
            return 45 // Native iPad floating keyboard row height (4 * 45 = 180pt + 34pt toolbar = 214pt)
        }
        let isPortrait = keyboardContext.interfaceOrientation.isPortrait
        return isPortrait ? 54 : 42 // Standard iOS keyboard row height on iPhone (portrait ~54pt)
    }
    
    var isPrimaryActionEnabled: Bool {
        let proxy = keyboardContext.textDocumentProxy
        let enablesAuto = proxy.enablesReturnKeyAutomatically ?? false
        let returnType = proxy.returnKeyType
        let isSpecialAction = returnType == .search || returnType == .go || returnType == .send || returnType == .next || returnType == .done || returnType == .join || returnType == .route || returnType == .yahoo || returnType == .google
        if enablesAuto || isSpecialAction {
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
        let isDark = context.hasDarkColorScheme || context.keyboardAppearance == .dark
        
        let darkInputKey = Color(white: 0.28)
        let darkInputKeyPressed = Color(white: 0.18)
        let modernPad = isPad && !usesClassicGraySystemKeysOnPad
        let darkSystemKey = modernPad ? darkInputKey : Color(white: 0.18)
        let darkSystemKeyPressed = modernPad ? darkInputKeyPressed : Color(white: 0.32)
        
        let lightInputKey = Color.white
        let lightInputKeyPressed = Color(white: 0.85)
        let lightSystemKeyGray = Color(red: 172/255, green: 177/255, blue: 185/255)
        let lightSystemKeyGrayPressed = Color.white
        
        // On iPad in standard iOS 26 mode (Safari, Notes, etc.), system keys are pure white like letter keys.
        // On iPhone, or on iPad in classic Google/Gmail mode, system keys are classic gray (#ACB1B9).
        let useWhiteSystemKeysInLight = isPad && !usesClassicGraySystemKeysOnPad
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
        switch action {
        case .none, .characterMargin:
            return .clear
        default:
            break
        }
        
        let context = keyboardContext
        let isDark = context.hasDarkColorScheme || context.keyboardAppearance == .dark
        
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
        if keyboardContext.isSpaceDragGestureActive || (isPad && !keyboardContext.isKeyboardFloating) { return .noShadow }
        switch action {
        case .characterMargin, .emoji, .none:
            return .noShadow
        default:
            // Native iOS buttons have a subtle 1pt bottom drop shadow on key cap
            let isDark = keyboardContext.hasDarkColorScheme || keyboardContext.keyboardAppearance == .dark
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
