//
//  CrimeanTatarIPadKeyboardLayoutProvider.swift
//  Keyboard
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import CoreGraphics
import KeyboardKit

/// iPad layout tuned for the wider Crimean Tatar alphabet.
///
/// Ensures perfect mathematical alignment across all rows (13.0 units total each)
/// so that every letter key has the exact same width without any distortion or stretching.
final class CrimeanTatarIPadKeyboardLayoutProvider: iPadKeyboardLayoutProvider {
    
    /// No stagger needed: row 1 already has 12 letters + Return = 13 keys, matching row 0.
    override func middleLeadingActions(for context: KeyboardContext) -> KeyboardAction.Row {
        []
    }
    
    /// In native full-size iPadOS keyboards, the globe key is in the very left corner.
    override func bottomActions(for context: KeyboardContext) -> KeyboardAction.Row {
        var result = KeyboardAction.Row()
        result.append(.nextKeyboard)
        if let action = keyboardSwitchActionForBottomRow(for: context) {
            result.append(action)
        }
        result.append(.space)
        if let action = keyboardSwitchActionForBottomRow(for: context) {
            result.append(action)
        }
        result.append(.dismissKeyboard)
        return result
    }
    
    override func itemSizeWidth(
        for action: KeyboardAction,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> KeyboardLayout.ItemWidth {
        switch action {
        case .character:
            return .input
        case .backspace:
            return .input
        case .primary:
            return .input
        case .shift:
            return .inputPercentage(1.5)
        case .keyboardType:
            return .inputPercentage(1.5)
        case .nextKeyboard:
            return .inputPercentage(1.25)
        case .dismissKeyboard:
            return .inputPercentage(1.5)
        case .space:
            return .available
        default:
            return super.itemSizeWidth(for: action, row: row, index: index, context: context)
        }
    }
}
