//
//  DemoLayoutProvider.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2022-12-21.
//  Copyright © 2022-2024 Daniel Saidi. All rights reserved.
//

import CoreGraphics
import KeyboardKit
import SwiftUI
import UIKit

/// iPhone & iPad Floating layout provider tuned for Crimean Tatar Latin alphabet (12 keys in row 0 & row 1).
///
/// In Crimean Tatar Latin, row 0 and row 1 have 12 letters each (qwertyuıopğü / âasdfghjklşi).
/// Row 2 has Shift + 10 letters (zxcvbnmöçñ) + Backspace.
/// Setting Shift and Backspace width to .input (1.0x) ensures:
/// - Row 0: 12 keys = 12.0 units
/// - Row 1: 12 keys = 12.0 units
/// - Row 2: Shift (1.0) + 10 letters (10.0) + Backspace (1.0) = 12.0 units
/// All letter buttons across rows 0, 1, and 2 have identical width, and the rows align perfectly.
final class CrimeanTatarIPhoneKeyboardLayoutProvider: iPhoneKeyboardLayoutProvider {
    
    override func actions(
        for inputs: InputSet.Rows,
        context: KeyboardContext
    ) -> KeyboardAction.Rows {
        var actions = super.actions(for: inputs, context: context)
        if context.keyboardType.isAlphabetic && actions.count >= 3 {
            let isCyrillic = context.locale.identifier.contains("Cyrl")
            for row in 0...2 {
                // Keep .characterMargin in row 1 for Cyrillic (11 keys) so 'ф' is centered between 'й' and 'ц'
                let keepMargins = isCyrillic && row == 1
                actions[row].removeAll { action in
                    switch action {
                    case .characterMargin: return !keepMargins
                    case .none: return true
                    case .character(let text):
                        return row == 2 && !isCyrillic && (text == "," || text == ".")
                    default: return false
                    }
                }
            }
        }
        return actions
    }
    
    override func itemInsets(
        for action: KeyboardAction,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> EdgeInsets {
        switch action {
        case .characterMargin, .none:
            return EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)
        default:
            if context.isKeyboardFloating {
                // Native iPad floating keyboard button insets (49pt row - 15pt vertical insets = 34pt key cap)
                return EdgeInsets(top: 7.5, leading: 2.5, bottom: 7.5, trailing: 2.5)
            }
            return super.itemInsets(for: action, row: row, index: index, context: context)
        }
    }
    
    override func itemSizeHeight(
        for action: KeyboardAction,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> CGFloat {
        if context.isKeyboardFloating {
            return 49
        }
        return super.itemSizeHeight(for: action, row: row, index: index, context: context)
    }
    
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
        // In Liquid Glass floating mode, iPadOS provides an external globe button below the keyboard;
        // in Classic mode (e.g. Gmail), the floating container has no external globe so include .nextKeyboard in Row 4.
        let shouldIncludeGlobe = context.isKeyboardFloating
            ? DemoStyleProvider.usesClassicGraySystemKeys(for: context)
            : context.needsInputModeSwitchKey
        if shouldIncludeGlobe {
            result.append(.nextKeyboard)
        }

        #if os(iOS) || os(tvOS) || os(visionOS)
        let proxy = context.textDocumentProxy
        let effectiveType = DemoStyleProvider.effectiveProxyKeyboardType(for: context)
        let isSandbox = DemoStyleProvider.isSandboxOverrideActive(for: context)
        let isEmail: Bool = {
            if effectiveType == .emailAddress { return true }
            if !isSandbox, #available(iOS 10.0, *), proxy.textContentType == .emailAddress { return true }
            return false
        }()
        let isURL: Bool = {
            if effectiveType == .URL { return true }
            if !isSandbox, #available(iOS 10.0, *), proxy.textContentType == .URL { return true }
            return false
        }()
        let isWebSearch: Bool = {
            return effectiveType == .webSearch
        }()
        
        if isURL {
            // Native iOS URL mode has NO spacebar — only `.`, `/`, and `.com` between switcher and Go!
            result.append(.character("."))
            result.append(.character("/"))
            result.append(.custom(named: "url_domain"))
        } else if isEmail && context.keyboardType.isAlphabetic {
            result.append(.space)
            result.append(.character("@"))
            result.append(.character("."))
        } else if isWebSearch && context.keyboardType.isAlphabetic {
            result.append(.space)
            result.append(.character("."))
        } else {
            result.append(.space)
        }
        #else
        result.append(.space)
        #endif
        
        result.append(keyboardReturnAction(for: context))
        return result
    }

    override func keyboardReturnAction(for context: KeyboardContext) -> KeyboardAction {
        #if os(iOS) || os(tvOS) || os(visionOS)
        if let returnType = DemoStyleProvider.effectiveReturnKeyType(for: context)?.keyboardReturnKeyType {
            return .primary(returnType)
        }
        #endif
        return super.keyboardReturnAction(for: context)
    }
    
    override func bottomSystemButtonWidth(for context: KeyboardContext) -> KeyboardLayout.ItemWidth {
        if context.isKeyboardFloating {
            return .percentage(0.21)
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
            if context.isKeyboardFloating {
                return .percentage(0.13)
            }
            let isPortrait = context.interfaceOrientation.isPortrait
            return .percentage(isPortrait ? 0.105 : 0.09)
        case .keyboardType(let type):
            // Row 2 contains the #+= (symbolic) or 123 (numeric) switcher button
            if row != 3 {
                return lowerSystemButtonWidth(for: context)
            }
            if context.isKeyboardFloating {
                return .percentage(0.21)
            }
            let isPortrait = context.interfaceOrientation.isPortrait
            if type == .emojis {
                return .percentage(isPortrait ? 0.105 : 0.09)
            }
            return .percentage(isPortrait ? 0.125 : 0.11)
        case .primary:
            if context.isKeyboardFloating {
                return .percentage(0.21)
            }
            let isPortrait = context.interfaceOrientation.isPortrait
            return .percentage(isPortrait ? 0.235 : 0.195)
        case .space:
            return .available
        case .custom(let name) where name == "url_domain":
            return .available
        case .character(let char):
            if row == 3 && (char == "@" || char == "." || char == "/") {
                if char == "." || char == "/" {
                    let proxy = context.textDocumentProxy
                    let effectiveType = DemoStyleProvider.effectiveProxyKeyboardType(for: context)
                    let isSandbox = DemoStyleProvider.isSandboxOverrideActive(for: context)
                    let isURL = effectiveType == .URL || (!isSandbox && proxy.textContentType == .URL)
                    if isURL {
                        return .available
                    }
                }
                return .percentage(context.isKeyboardFloating ? 0.11 : 0.12)
            }
            return super.itemSizeWidth(for: action, row: row, index: index, context: context)
        default:
            return super.itemSizeWidth(for: action, row: row, index: index, context: context)
        }
    }
}

extension InputSet {
    static var crimeanTatarCyrillic: InputSet {
        .init(rows: [
            .init(lowercased: "йцукенгшщзхъ", uppercased: "ЙЦУКЕНГШЩЗХЪ"),
            .init(lowercased: "фывапролджэ", uppercased: "ФЫВАПРОЛДЖЭ"),
            .init(lowercased: "ячсмитьбюё", uppercased: "ЯЧСМИТЬБЮЁ")
        ])
    }

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
    
    /// Standardized pad numeric set (matching native iPad layout page 1)
    /// Row 0: 11 characters (1234567890-)
    /// Row 1: 10 characters (@#₴&*-()'")
    /// Row 2: 9 characters (%_+=/;:!?)
    static var crimeanTatarPadNumeric: InputSet {
        .init(rows: [
            .init(chars: "1234567890-"),
            .init(chars: "@#₴&*-()'\""),
            .init(chars: "%_+=/;:!?")
        ])
    }
    
    /// Standardized pad symbolic set (matching native iPad layout page 2)
    /// Row 0: 11 characters (1234567890—)
    /// Row 1: 10 characters (€$£•^|[]{})
    /// Row 2: 9 characters (§~…≠\<>!?)
    static var crimeanTatarPadSymbolic: InputSet {
        .init(rows: [
            .init(chars: "1234567890—"),
            .init(chars: "€$£•^|[]{}"),
            .init(chars: "§~…≠\\<>!?")
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
        guard let base = baseProvider as? InputSetBasedKeyboardLayoutProvider else {
            return super.keyboardLayout(for: context)
        }
        let inputSet: InputSet = context.locale.identifier.contains("Cyrl") ? .crimeanTatarCyrillic : .crimeanTatar
        (base.iPhoneProvider as? BaseKeyboardLayoutProvider)?.alphabeticInputSet = inputSet
        (base.iPadProvider as? BaseKeyboardLayoutProvider)?.alphabeticInputSet = inputSet
        let provider = context.isKeyboardFloating || context.deviceType == .phone ? base.iPhoneProvider : base.iPadProvider
        let layout = provider.keyboardLayout(for: context)
        layout.applyNativeRowInsets(for: context)

        return layout
    }
}

private extension KeyboardLayout {
    
    func applyNativeRowInsets(for context: KeyboardContext) {
        guard !context.isKeyboardFloating else { return }
        let bottomIndex = bottomRowIndex
        guard bottomIndex >= 0 else { return }
        
        // Pad bottom-row buttons with standard insets
        for index in itemRows[bottomIndex].indices {
            var item = itemRows[bottomIndex][index]
            var insets = item.edgeInsets
            insets.bottom = 2
            item.edgeInsets = insets
            itemRows[bottomIndex][index] = item
        }
    }
}
