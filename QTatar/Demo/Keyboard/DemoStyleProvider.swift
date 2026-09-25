//
//  DemoStyleProvider.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2022-12-21.
//  Copyright © 2022-2024 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import SwiftUI
import UIKit

/**
 Crimean Tatar custom style provider matching iOS system keyboard geometry,
 fonts, weights, colors, and shadows.
 */
class DemoStyleProvider: StandardKeyboardStyleProvider {

    private var isPadDocked: Bool {
        keyboardContext.deviceType == .pad && !keyboardContext.isKeyboardFloating
    }

    override func buttonCornerRadius(for action: KeyboardAction) -> CGFloat {
        isPadDocked ? 6 : 5
    }
    
    override var keyboardEdgeInsets: EdgeInsets {
        if keyboardContext.isKeyboardFloating {
            return .init()
        }
        switch keyboardContext.deviceType {
        case .phone:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        case .pad:
            return EdgeInsets(top: 0, leading: 0, bottom: 4, trailing: 0)
        default:
            return super.keyboardEdgeInsets
        }
    }
    
    override func rowHeight(
        forRowAt rowIndex: Int,
        in layout: KeyboardLayout
    ) -> CGFloat {
        let isCompact = keyboardContext.deviceType == .phone || keyboardContext.isKeyboardFloating
        if isCompact {
            return letterRowHeight
        }
        return super.rowHeight(forRowAt: rowIndex, in: layout)
    }
    
    override func buttonContentInsets(for action: KeyboardAction) -> EdgeInsets {
        if action.isInputAction {
            return .init(top: 0, leading: 0, bottom: 0, trailing: 0)
        }
        return super.buttonContentInsets(for: action)
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
        case .nextKeyboard:
            if keyboardContext.isKeyboardFloating {
                return nil
            } else if keyboardContext.deviceType == .phone {
                return super.buttonImage(for: .keyboardType(.emojis))
            } else {
                return Image(systemName: "globe")
            }
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
        case .keyboardType(let type):
            switch type {
            case .numeric:
                return "123"
            case .symbolic:
                return "#+="
            case .alphabetic:
                return "ABC"
            default:
                return super.buttonText(for: action)
            }
        case .primary:
            // Native iOS uses SF Symbols (icons) for all primary actions
            return nil
        default:
            return super.buttonText(for: action)
        }
    }
    
    /// Height of letter rows tuned for native iOS look and feel
    private var letterRowHeight: CGFloat {
        if keyboardContext.isKeyboardFloating {
            return 52 // Native iPad floating keyboard row height (standard button height ~47pt)
        }
        let isPortrait = keyboardContext.interfaceOrientation.isPortrait
        return isPortrait ? 42 : 38
    }
    
    var isPrimaryActionEnabled: Bool {
        let proxy = keyboardContext.textDocumentProxy
        let enablesAuto = proxy.enablesReturnKeyAutomatically ?? false
        let isSearch = proxy.returnKeyType == .search
        if enablesAuto || isSearch {
            let hasText = proxy.hasText || !(proxy.documentContextBeforeInput?.isEmpty ?? true)
            return hasText
        }
        return true
    }
    
    override func buttonBackgroundColor(
        for action: KeyboardAction,
        isPressed: Bool
    ) -> Color {
        let context = keyboardContext
        let isPad = context.deviceType == .pad
        let isDark = context.hasDarkColorScheme
        
        let darkInputKey = Color(white: 0.28)
        let darkInputKeyPressed = Color(white: 0.18)
        let darkSystemKey = Color(white: 0.18)
        let darkSystemKeyPressed = Color(white: 0.32)
        
        let lightInputKey = Color.white
        let lightInputKeyPressed = Color(white: 0.85)
        let lightSystemKey = Color(red: 172/255, green: 177/255, blue: 185/255)
        let lightSystemKeyPressed = Color.white
        
        // Return / Primary actions
        if case .primary(let type) = action {
            switch type {
            case .newLine, .return:
                if isPadDocked {
                    return isPressed
                        ? (isDark ? Color(white: 0.22) : Color(white: 0.85))
                        : (isDark ? darkInputKey : lightInputKey)
                }
                return isPressed
                    ? (isDark ? darkSystemKeyPressed : lightSystemKeyPressed)
                    : (isDark ? darkSystemKey : lightSystemKey)
            case .search:
                // On iOS Spotlight and search fields, Search key is ALWAYS blue
                return isPressed ? Color.blue.opacity(0.7) : Color.blue
            default:
                guard isPrimaryActionEnabled else {
                    return isPressed
                        ? (isDark ? darkSystemKeyPressed : lightSystemKeyPressed)
                        : (isDark ? darkSystemKey : lightSystemKey)
                }
                return isPressed ? Color.blue.opacity(0.7) : Color.blue
            }
        }
        
        // On iPad docked, ALL buttons (including system keys: Shift, Return, Delete, 123, dismiss) have pure white background in light mode
        if isPadDocked {
            return isPressed
                ? (isDark ? Color(white: 0.22) : Color(white: 0.85))
                : (isDark ? darkInputKey : lightInputKey)
        }
        
        // Active Uppercased / CapsLocked Shift key (never dark background, always clean light background with filled black arrow)
        if action.isUppercasedShiftAction {
            return isPressed
                ? (isDark ? Color(white: 0.85) : Color(white: 0.90))
                : Color.white
        }
        
        // System actions on iPhone (Shift idle, Backspace, 123, Emoji, etc.)
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
        let isDark = keyboardContext.hasDarkColorScheme
        
        if case .primary(let type) = action {
            switch type {
            case .newLine, .return:
                return isDark ? .white : .black
            case .search:
                return .white
            default:
                guard isPrimaryActionEnabled else {
                    return isDark ? Color.white.opacity(0.35) : Color.black.opacity(0.35)
                }
                return .white
            }
        }
        if action.isUppercasedShiftAction {
            return .black
        }
        
        return isDark ? .white : .black
    }
    
    override func buttonFontSize(for action: KeyboardAction) -> CGFloat {
        let isPhone = keyboardContext.deviceType == .phone
        let isFloating = keyboardContext.isKeyboardFloating
        
        if isFloating {
            if action.isInputAction {
                // Optical balance: cap-height letters at 20pt visually match 22pt lowercase
                if case .character(let char) = action, let scalar = char.first, scalar.isUppercase {
                    return 20
                }
                return 22
            }
            switch action {
            case .backspace: return 16
            case .shift: return 17
            case .primary: return 16
            default: return 16
            }
        }
        
        if action.isInputAction {
            // Optical balance between uppercase and lowercase glyphs
            // In SF Pro, 21.5/22pt uppercase perfectly matches stroke thickness of 23.5/24pt lowercase
            if case .character(let char) = action, let scalar = char.first, scalar.isUppercase {
                return isPhone ? 21.5 : 22
            }
            return isPhone ? 23.5 : 24
        }
        switch action {
        case .backspace:
            return isPhone ? 14 : 18
        case .shift:
            return isPhone ? 16 : 19
        case .primary:
            return isPhone ? 16 : 18
        case .keyboardType(let type):
            if type == .emojis {
                return isPhone ? 18 : 22
            }
            return super.buttonFontSize(for: action)
        default:
            return super.buttonFontSize(for: action)
        }
    }
    
    override func buttonFontWeight(for action: KeyboardAction) -> KeyboardFont.FontWeight? {
        if action.isInputAction {
            return .regular
        }
        switch action {
        case .shift(let casing):
            switch casing {
            case .uppercased, .capsLocked:
                return .bold
            default:
                return .regular
            }
        case .primary(let type):
            switch type {
            case .search:
                return .semibold
            default:
                return .regular
            }
        default:
            return .regular
        }
    }
    
    // MARK: - Shadows
    
    override func buttonShadowStyle(for action: KeyboardAction) -> Keyboard.ButtonShadowStyle {
        if keyboardContext.isSpaceDragGestureActive { return .noShadow }
        if isPadDocked { return .noShadow }
        switch action {
        case .characterMargin, .emoji, .none:
            return .noShadow
        default:
            return Keyboard.ButtonShadowStyle(
                color: Color.black.opacity(0.35),
                size: 1
            )
        }
    }
    
    // MARK: - Callouts
    
    override var calloutStyle: Callouts.CalloutStyle {
        var style = super.calloutStyle
        style.backgroundColor = keyboardContext.hasDarkColorScheme
            ? Color(white: 0.44).opacity(0.85)
            : Color.white.opacity(0.92)
        style.borderColor = Color.clear
        style.shadowColor = Color.black.opacity(0.25)
        style.shadowRadius = 8
        return style
    }
}
