//
//  DemoLayoutProvider.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2022-12-21.
//  Copyright © 2022-2024 Daniel Saidi. All rights reserved.
//

import CoreGraphics
import KeyboardKit
import UIKit

/// iPhone layout provider tuned for Crimean Tatar Latin alphabet (12 keys in row 0 & row 1).
///
/// In Crimean Tatar Latin, row 0 and row 1 have 12 letters each (qwertyuıopğü / asdfghjklşiñ).
/// Row 2 has Shift + 10 letters (zxcvbnmöçâ) + Backspace.
/// Setting Shift and Backspace width to .input (1.0x) ensures:
/// - Row 0: 12 keys = 12.0 units
/// - Row 1: 12 keys = 12.0 units
/// - Row 2: Shift (1.0) + 10 letters (10.0) + Backspace (1.0) = 12.0 units
/// All letter buttons across rows 0, 1, and 2 have identical width, and the rows align perfectly.
final class CrimeanTatarIPhoneKeyboardLayoutProvider: iPhoneKeyboardLayoutProvider {
    
    override func lowerSystemButtonWidth(for context: KeyboardContext) -> KeyboardLayout.ItemWidth {
        if context.keyboardType.isAlphabetic {
            return .input
        }
        return super.lowerSystemButtonWidth(for: context)
    }
    
    override func bottomActions(
        for context: KeyboardContext
    ) -> KeyboardAction.Row {
        var result = KeyboardAction.Row()
        if let action = keyboardSwitchActionForBottomRow(for: context) {
            result.append(action)
        }
        // In iPad floating mode, system provides external grab bar with globe/mic; do not add nextKeyboard inside keyboard
        if !context.isKeyboardFloating {
            result.append(.nextKeyboard)
        }
        result.append(.space)
        #if os(iOS) || os(tvOS) || os(visionOS)
        if context.textDocumentProxy.keyboardType == .emailAddress {
            result.append(.character("@"))
            result.append(.character("."))
        }
        if context.textDocumentProxy.returnKeyType == .go {
            result.append(.character("."))
        }
        #endif
        result.append(keyboardReturnAction(for: context))
        return result
    }
    
    override func bottomSystemButtonWidth(for context: KeyboardContext) -> KeyboardLayout.ItemWidth {
        if context.isKeyboardFloating {
            return .percentage(0.20)
        }
        let isPortrait = context.interfaceOrientation.isPortrait
        return .percentage(isPortrait ? 0.125 : 0.11)
    }
    
    override func itemSizeWidth(
        for action: KeyboardAction,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> KeyboardLayout.ItemWidth {
        switch action {
        case .nextKeyboard:
            let isPortrait = context.interfaceOrientation.isPortrait
            return .percentage(isPortrait ? 0.105 : 0.09)
        case .keyboardType(let type):
            // Row 2 contains the #+= (symbolic) or 123 (numeric) switcher button
            if row != 3 {
                return lowerSystemButtonWidth(for: context)
            }
            if context.isKeyboardFloating {
                return .percentage(0.20)
            }
            let isPortrait = context.interfaceOrientation.isPortrait
            if type == .emojis {
                return .percentage(isPortrait ? 0.105 : 0.09)
            }
            return .percentage(isPortrait ? 0.125 : 0.11)
        case .primary:
            if context.isKeyboardFloating {
                return .percentage(0.20)
            }
            let isPortrait = context.interfaceOrientation.isPortrait
            return .percentage(isPortrait ? 0.235 : 0.195)
        case .space:
            return .available
        case .character(let char):
            if row == 3 && (char == "@" || char == ".") {
                return .percentage(0.12)
            }
            return super.itemSizeWidth(for: action, row: row, index: index, context: context)
        default:
            return super.itemSizeWidth(for: action, row: row, index: index, context: context)
        }
    }
}

extension InputSet {
    /// Standardized phone numeric set (matching native iOS phone layout)
    static var crimeanTatarPhoneNumeric: InputSet {
        .init(rows: [
            .init(chars: "1234567890"),
            .init(chars: "-/:;()₴&@\""),
            .init(chars: ".,?!'")
        ])
    }
    
    /// Standardized phone symbolic set (matching native iOS phone layout)
    static var crimeanTatarPhoneSymbolic: InputSet {
        .init(rows: [
            .init(chars: "[]{}#%^*+="),
            .init(chars: "_\\|~<>€$£•"),
            .init(chars: ".,?!'")
        ])
    }
    
    /// Standardized pad numeric set
    static var crimeanTatarPadNumeric: InputSet {
        .init(rows: [
            .init(chars: "1234567890"),
            .init(chars: "@#₴&*()\"\"'"),
            .init(chars: "%-+=/;:!?")
        ])
    }
    
    /// Standardized pad symbolic set
    static var crimeanTatarPadSymbolic: InputSet {
        .init(rows: [
            .init(chars: "1234567890"),
            .init(chars: "€$£_^[]{}§"),
            .init(chars: "§|~…\\<>!?")
        ])
    }
}

/**
 This demo-specific provider inherits the standard one, then
 configures custom iPhone and iPad layout providers for Crimean Tatar.
 */
class DemoLayoutProvider: StandardKeyboardLayoutProvider {
    
    init() {
        let baseProvider = InputSetBasedKeyboardLayoutProvider(
            numericInputSet: .crimeanTatarPadNumeric,
            symbolicInputSet: .crimeanTatarPadSymbolic
        )
        baseProvider.iPadProvider = CrimeanTatarIPadKeyboardLayoutProvider(
            alphabeticInputSet: baseProvider.alphabeticInputSet,
            numericInputSet: .crimeanTatarPadNumeric,
            symbolicInputSet: .crimeanTatarPadSymbolic
        )
        baseProvider.iPhoneProvider = CrimeanTatarIPhoneKeyboardLayoutProvider(
            alphabeticInputSet: baseProvider.alphabeticInputSet,
            numericInputSet: .crimeanTatarPhoneNumeric,
            symbolicInputSet: .crimeanTatarPhoneSymbolic
        )
        super.init(baseProvider: baseProvider)
    }

    override func keyboardLayout(for context: KeyboardContext) -> KeyboardLayout {
        // If iPad is in floating mode, use iPhone layout for a compact phone-like keyboard
        if context.isKeyboardFloating {
            if let base = baseProvider as? InputSetBasedKeyboardLayoutProvider {
                let layout = base.iPhoneProvider.keyboardLayout(for: context)
                layout.applyNativeRowInsets(for: context)
                return layout
            }
        }
        
        let layout = super.keyboardLayout(for: context)
        layout.applyNativeRowInsets(for: context)
        
        return layout
    }
}

private extension KeyboardLayout {
    
    func applyNativeRowInsets(for context: KeyboardContext) {
        let bottomIndex = bottomRowIndex
        guard bottomIndex >= 0 else { return }
        
        if context.isKeyboardFloating {
            let horizontal: CGFloat = 2.5
            let vertical: CGFloat = 2.5
            for rowIndex in itemRows.indices {
                for index in itemRows[rowIndex].indices {
                    var item = itemRows[rowIndex][index]
                    guard !item.action.isSpacer else { continue }
                    item.edgeInsets = .init(
                        top: vertical,
                        leading: horizontal,
                        bottom: vertical,
                        trailing: horizontal
                    )
                    itemRows[rowIndex][index] = item
                }
            }
            return
        }
        
        let isPhone = context.deviceType == .phone
        let padConfig = KeyboardLayout.Configuration.standard(for: context)
        let horizontal = isPhone ? CGFloat(3) : padConfig.buttonInsets.leading
        let vertical = isPhone ? CGFloat(6) : padConfig.buttonInsets.top
        
        for rowIndex in itemRows.indices {
            for index in itemRows[rowIndex].indices {
                var item = itemRows[rowIndex][index]
                guard !item.action.isSpacer else { continue }
                
                item.edgeInsets = .init(
                    top: vertical,
                    leading: horizontal,
                    bottom: vertical,
                    trailing: horizontal
                )
                itemRows[rowIndex][index] = item
            }
        }
    }
}
