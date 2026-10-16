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
    
    /// Checks whether the floating keyboard should display the internal Globe button
    /// (e.g. in Google/Gmail where the external floating bar lacks a Globe, or when Google/Gmail mode is selected in the sandbox).
    private func shouldShowInternalGlobeInFloating(_ context: KeyboardContext) -> Bool {
        // NOTE: the sandbox theme override (`crh.key.test.systemKeyStyle`) is deliberately NOT consulted here.
        // In our own app the system floating bar always draws a globe, so an internal one would be a duplicate.
        if let bundleId = context.hostApplicationBundleId?.lowercased() {
            if bundleId.contains("google") || bundleId.contains("gmail") || bundleId.contains("youtube") || bundleId.contains("chrome") {
                return true
            }
        }
        // In standard iPadOS floating mode (Safari, Notes, Demo app, etc.), the system floating bar
        // below the keyboard ALREADY renders the Globe & Dictation icons!
        return false
    }
    
    override func actions(
        for inputs: InputSet.Rows,
        context: KeyboardContext
    ) -> KeyboardAction.Rows {
        var actions = super.actions(for: inputs, context: context)
        // In iPhone and iPad floating mode, alphabetic row 2 must not have any punctuation (no comma, no period)
        // so that Shift (1.0) + 10 letters (10.0) + Backspace (1.0) = 12.0 units, exactly matching row 0 (12) and row 1 (12).
        if context.keyboardType.isAlphabetic && actions.count >= 3 {
            actions[2].removeAll { action in
                if case .character(let char) = action {
                    return char == "," || char == "."
                }
                return false
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
                // Native iPad floating keyboard button insets
                return EdgeInsets(top: 3.5, leading: 2.5, bottom: 3.5, trailing: 2.5)
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
            return 45
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
        // In iPad floating mode:
        // - Standard iOS apps (Safari, Notes, etc.) already display the external Globe & Mic in the system floating bar below,
        //   so we do NOT duplicate the Globe inside row 3.
        // - Classic apps like Gmail suppress the external Globe in the floating bar, so we include `.nextKeyboard` inside row 3.
        // On iPhone, `.nextKeyboard` is always included in row 3.
        if context.isKeyboardFloating {
            if shouldShowInternalGlobeInFloating(context) {
                result.append(.nextKeyboard)
            }
        } else {
            result.append(.nextKeyboard)
        }
        
        #if os(iOS) || os(tvOS) || os(visionOS)
        let proxy = context.textDocumentProxy
        let isEmail: Bool = {
            if proxy.keyboardType == .emailAddress { return true }
            if #available(iOS 10.0, *), proxy.textContentType == .emailAddress { return true }
            return false
        }()
        let isURL: Bool = {
            if proxy.keyboardType == .URL { return true }
            if #available(iOS 10.0, *), proxy.textContentType == .URL { return true }
            return false
        }()
        let isWebSearch: Bool = {
            return proxy.keyboardType == .webSearch || proxy.returnKeyType == .search
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
    
    override func bottomSystemButtonWidth(for context: KeyboardContext) -> KeyboardLayout.ItemWidth {
        if context.isKeyboardFloating {
            return .percentage(0.16)
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
                return .percentage(0.16)
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
                    let isURL = proxy.keyboardType == .URL || proxy.textContentType == .URL
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
            .init(phoneLowercased: "ячсмитьбю", phoneUppercased: "ЯЧСМИТЬБЮ",
                  padLowercased: "ячсмитьбю,", padUppercased: "ЯЧСМИТЬБЮ,")
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
