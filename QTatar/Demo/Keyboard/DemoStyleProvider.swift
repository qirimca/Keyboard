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
    
    /// Bottom system row is slightly taller on the native iOS keyboard.
    private let bottomRowExtraHeight: CGFloat = 8
    
    /// Matches the native iPhone letter-row height (KeyboardKit default is 43).
    private let letterRowHeight: CGFloat = 43
    
    /// Space below the bottom row for the system globe/mic chrome.
    private let bottomChromeHeight: CGFloat = 18
    
    /// Side inset for the iPad key grid (matches system keyboard).
    private let iPadHorizontalKeyboardInset: CGFloat = 12
    
    override var keyboardLayoutConfiguration: KeyboardLayout.Configuration {
        var config = super.keyboardLayoutConfiguration
        config.buttonCornerRadius = 5
        
        guard keyboardContext.deviceType == .phone else {
            return config
        }
        
        config.rowHeight = letterRowHeight
        config.buttonInsets = EdgeInsets(top: 3, leading: 3, bottom: 3, trailing: 3)
        return config
    }
    
    override var keyboardEdgeInsets: EdgeInsets {
        switch keyboardContext.deviceType {
        case .phone where keyboardContext.interfaceOrientation.isPortrait:
            return EdgeInsets(top: 0, leading: 0, bottom: bottomChromeHeight, trailing: 0)
        case .pad:
            return EdgeInsets(
                top: 0,
                leading: iPadHorizontalKeyboardInset,
                bottom: 4,
                trailing: iPadHorizontalKeyboardInset
            )
        default:
            return super.keyboardEdgeInsets
        }
    }
    
    override func rowHeight(
        forRowAt rowIndex: Int,
        in layout: KeyboardLayout
    ) -> CGFloat {
        let base = keyboardLayoutConfiguration.rowHeight
        guard keyboardContext.deviceType == .phone,
              rowIndex == layout.bottomRowIndex else {
            return base
        }
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
