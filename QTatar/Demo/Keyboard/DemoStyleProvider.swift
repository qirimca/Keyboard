//
//  DemoStyleProvider.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2022-12-21.
//  Copyright © 2022-2024 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import SwiftUI

/// Styles the keyboard to match the native iOS system appearance.
class DemoStyleProvider: StandardKeyboardStyleProvider {
    
    /// Bottom row is taller on the native iOS keyboard.
    private let bottomRowExtraHeight: CGFloat = 8
    
    override var keyboardLayoutConfiguration: KeyboardLayout.Configuration {
        var config = super.keyboardLayoutConfiguration
        config.buttonCornerRadius = 5
        return config
    }
    
    override func rowHeight(
        forRowAt rowIndex: Int,
        in layout: KeyboardLayout
    ) -> CGFloat {
        let base = keyboardLayoutConfiguration.rowHeight
        guard rowIndex == layout.bottomRowIndex else { return base }
        return base + bottomRowExtraHeight
    }
    
    override func buttonBackgroundColor(
        for action: KeyboardAction,
        isPressed: Bool
    ) -> Color {
        guard usesNativeWhiteKeyStyle(for: action) else {
            return super.buttonBackgroundColor(for: action, isPressed: isPressed)
        }
        
        let context = keyboardContext
        if isPressed {
            return context.hasDarkColorScheme
                ? .keyboardButtonBackground(for: context)
                : .white
        }
        return .keyboardButtonBackground(for: context)
    }
    
    override func buttonForegroundColor(
        for action: KeyboardAction,
        isPressed: Bool
    ) -> Color {
        guard usesNativeWhiteKeyStyle(for: action) else {
            return super.buttonForegroundColor(for: action, isPressed: isPressed)
        }
        return Color.keyboardButtonForeground(for: keyboardContext)
    }
    
    override func buttonText(for action: KeyboardAction) -> String? {
        switch action {
        case .space:
            return nil
        case .keyboardType(let type):
            switch type {
            case .numeric, .symbolic:
                return "123"
            case .alphabetic:
                return "ABC"
            default:
                return super.buttonText(for: action)
            }
        default:
            return super.buttonText(for: action)
        }
    }
    
    private func usesNativeWhiteKeyStyle(for action: KeyboardAction) -> Bool {
        action.isSystemAction || action.isPrimaryAction
    }
}
