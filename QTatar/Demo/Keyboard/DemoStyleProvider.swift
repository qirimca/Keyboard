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
    
    override func buttonBackgroundColor(
        for action: KeyboardAction,
        isPressed: Bool
    ) -> Color {
        if action.isPrimaryAction {
            let context = keyboardContext
            if isPressed {
                return context.hasDarkColorScheme
                    ? .keyboardDarkButtonBackground(for: context)
                    : .white
            }
            return .blue
        }
        return super.buttonBackgroundColor(for: action, isPressed: isPressed)
    }
    
    override func buttonForegroundColor(
        for action: KeyboardAction,
        isPressed: Bool
    ) -> Color {
        if action.isPrimaryAction {
            let context = keyboardContext
            if isPressed {
                return context.hasDarkColorScheme ? .white : .blue
            }
            return .white
        }
        return super.buttonForegroundColor(for: action, isPressed: isPressed)
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
}
