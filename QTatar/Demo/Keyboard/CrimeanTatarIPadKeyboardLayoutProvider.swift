//
//  CrimeanTatarIPadKeyboardLayoutProvider.swift
//  Keyboard
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import CoreGraphics
import KeyboardKit
import SwiftUI
import UIKit

/// Docked iPad layout. Side keys use fixed fractions of the available width;
/// letters share the remaining width, independently of script or symbol page.
final class CrimeanTatarIPadKeyboardLayoutProvider: iPadKeyboardLayoutProvider {
    
    private func isEmailContext(_ context: KeyboardContext) -> Bool {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let proxy = context.textDocumentProxy
        if proxy.keyboardType == .emailAddress {
            return true
        }
        if #available(iOS 10.0, *), proxy.textContentType == .emailAddress {
            return true
        }
        #endif
        return false
    }
    
    private func isURLContext(_ context: KeyboardContext) -> Bool {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let proxy = context.textDocumentProxy
        if proxy.keyboardType == .URL {
            return true
        }
        if #available(iOS 10.0, *), proxy.textContentType == .URL {
            return true
        }
        #endif
        return false
    }
    
    override func actions(
        for inputs: InputSet.Rows,
        context: KeyboardContext
    ) -> KeyboardAction.Rows {
        var actions = BaseKeyboardLayoutProvider(
            alphabeticInputSet: alphabeticInputSet,
            numericInputSet: numericInputSet,
            symbolicInputSet: symbolicInputSet
        ).actions(for: inputs, context: context)
        guard actions.count == 3 else { return actions }
        
        // In email fields on iPad, replace the trailing comma in row 2 with '@'
        // In URL fields on iPad, replace the trailing comma in row 2 with '/'
        if context.keyboardType.isAlphabetic {
            if isEmailContext(context) {
                if let lastCharIndex = actions[2].lastIndex(where: { $0 == .character(",") }) {
                    actions[2][lastCharIndex] = .character("@")
                }
            } else if isURLContext(context) {
                if let lastCharIndex = actions[2].lastIndex(where: { $0 == .character(",") }) {
                    actions[2][lastCharIndex] = .character("/")
                }
            }
        }
        
        var result = KeyboardAction.Rows()
        result.append(topLeadingActions(for: context) + actions[0] + topTrailingActions(for: context))
        result.append(middleLeadingActions(for: context) + actions[1] + middleTrailingActions(for: context))
        result.append(lowerLeadingActions(for: context) + actions[2] + lowerTrailingActions(for: context))
        result.append(bottomActions(for: context))
        return result
    }
    
    /// Row 0 side keys as fractions of the row width; the 12 letters share the rest, which defines the key pitch.
    static let tabFraction = 0.10
    static let backspaceFraction = 0.075
    static var letterPitch: Double { (1 - tabFraction - backspaceFraction) / 12 }
    
    override func topLeadingActions(for context: KeyboardContext) -> KeyboardAction.Row {
        [.tab]
    }
    
    override func topTrailingActions(for context: KeyboardContext) -> KeyboardAction.Row {
        [.backspace]
    }
    
    override func middleLeadingActions(for context: KeyboardContext) -> KeyboardAction.Row {
        switch context.keyboardType {
        case .numeric:
            return [.custom(named: "undo")]
        case .symbolic:
            return [.custom(named: "redo")]
        case .alphabetic:
            return KeyboardPreferences.cyrillicEnabled ? [.custom(named: "toggle_script")] : [.none]
        default:
            return [.characterMargin("â")]
        }
    }
    
    override func middleTrailingActions(for context: KeyboardContext) -> KeyboardAction.Row {
        [keyboardReturnAction(for: context)]
    }
    
    override func lowerLeadingActions(for context: KeyboardContext) -> KeyboardAction.Row {
        guard let action = keyboardSwitchActionForBottomInputRow(for: context) else { return [] }
        return [action]
    }
    
    override func lowerTrailingActions(for context: KeyboardContext) -> KeyboardAction.Row {
        guard let action = keyboardSwitchActionForBottomInputRow(for: context) else { return [] }
        return [action]
    }
    
    override func bottomActions(for context: KeyboardContext) -> KeyboardAction.Row {
        var result = KeyboardAction.Row()
        result.append(.nextKeyboard)
        if let action = keyboardSwitchActionForBottomRow(for: context) {
            result.append(action)
        }
        if isURLContext(context) {
            result += [.character("."), .character("/"), .custom(named: "url_domain")]
        } else {
            result.append(.space)
        }
        if isEmailContext(context) && context.keyboardType.isAlphabetic {
            result.append(.character("."))
            result.append(.character("_"))
            result.append(.character("-"))
        } else if isURLContext(context) {
            if let action = keyboardSwitchActionForBottomRow(for: context) {
                result.append(action)
            }
        } else {
            if let action = keyboardSwitchActionForBottomRow(for: context) {
                result.append(action)
            }
        }
        result.append(.dismissKeyboard)
        return result
    }
    
    override func itemAlignment(
        for action: KeyboardAction,
        in actions: KeyboardAction.Rows,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> Alignment {
        .center
    }
    
    override func itemSizeWidth(
        for action: KeyboardAction,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> KeyboardLayout.ItemWidth {
        // Fixed fractions keep side keys stable across scripts and symbol pages.
        // On alphabetic pages every letter key has the same pitch, so row 1 / row 2 are offset by exact half keys
        // (A between Q and W, Z between A and S) like the system QWERTY layout.
        let isAlphabetic = context.keyboardType.isAlphabetic
        let isCyrillic = context.locale.identifier.contains("Cyrl")
        let pitch = Self.letterPitch
        if row == 0 {
            if action == .tab { return .percentage(Self.tabFraction) }
            if action == .backspace { return .percentage(Self.backspaceFraction) }
            return .available
        }
        if row == 1 {
            if !isAlphabetic {
                if index == 0 { return .percentage(0.145) }
                if case .primary = action { return .percentage(0.14) }
                return .available
            }
            if index == 0 {
                // Latin: АБВ key ends half a key before 'â'; Cyrillic: ABC key ends half a key before 'ф'.
                return .percentage(isCyrillic ? Self.tabFraction + pitch / 2 : Self.tabFraction - pitch / 2)
            }
            if case .primary = action { return .available }
            return .percentage(pitch)
        }
        if row == 2 {
            if !isAlphabetic {
                if index == 0 { return .percentage(0.115) }
                switch action {
                case .shift, .keyboardType: return .percentage(0.115)
                default: return .available
                }
            }
            if index == 0 { return .percentage(Self.tabFraction + pitch) }
            if case .shift = action { return .available }
            return .percentage(pitch)
        }
        if action == .space || action == .custom(named: "url_domain") { return .available }
        if case .character = action { return isURLContext(context) ? .available : .percentage(0.07) }
        if action == .nextKeyboard || action == .dismissKeyboard { return .percentage(0.08) }
        return .percentage(0.10)
    }
    
    override func keyboardReturnAction(
        for context: KeyboardContext
    ) -> KeyboardAction {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let proxy = context.textDocumentProxy
        let returnType = proxy.returnKeyType?.keyboardReturnKeyType
        if let returnType {
            return returnType == .return ? .primary(.newLine) : .primary(returnType)
        }
        #endif
        return .primary(.newLine)
    }
}
