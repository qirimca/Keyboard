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
/// iPad layout tuned for Crimean Tatar letter rows.
///
/// Edge keys use the same fixed width as letters so delete,
/// return, and shift never stretch to the screen edge.
final class CrimeanTatarIPadKeyboardLayoutProvider: iPadKeyboardLayoutProvider {
    
    /// Matches the native iPad stagger before the A-row.
    private let middleRowStagger = CGFloat(0.4)
    
    override func itemSizeWidth(
        for action: KeyboardAction,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> KeyboardLayout.ItemWidth {
        switch action {
        case .none where row == 1:
            return .inputPercentage(middleRowStagger)
        case .backspace where row == 0,
             .primary where row == 1,
             .shift where row == 2,
             .keyboardType where row == 2:
            return .input
        default:
            return super.itemSizeWidth(for: action, row: row, index: index, context: context)
        }
    }
}
