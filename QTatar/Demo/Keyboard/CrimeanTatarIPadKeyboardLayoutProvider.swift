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
        if DemoStyleProvider.effectiveProxyKeyboardType(for: context) == .emailAddress {
            return true
        }
        if !DemoStyleProvider.isSandboxOverrideActive(for: context),
           #available(iOS 10.0, *),
           context.textDocumentProxy.textContentType == .emailAddress {
            return true
        }
        #endif
        return false
    }
    
    private func isURLContext(_ context: KeyboardContext) -> Bool {
        #if os(iOS) || os(tvOS) || os(visionOS)
        if DemoStyleProvider.effectiveProxyKeyboardType(for: context) == .URL {
            return true
        }
        if !DemoStyleProvider.isSandboxOverrideActive(for: context),
           #available(iOS 10.0, *),
           context.textDocumentProxy.textContentType == .URL {
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
        // In URL fields on iPad, replace the trailing comma in row 2 with '.' (matching native iPadOS Web layout)
        if context.keyboardType.isAlphabetic {
            if isEmailContext(context) {
                if let lastCharIndex = actions[2].lastIndex(where: { $0 == .character(",") }) {
                    actions[2][lastCharIndex] = .character("@")
                }
            } else if isURLContext(context) {
                if let lastCharIndex = actions[2].lastIndex(where: { $0 == .character(",") }) {
                    actions[2][lastCharIndex] = .character(".")
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
    static let backspaceFraction = 0.095
    static var letterPitch: Double { (1 - tabFraction - backspaceFraction) / 12 }

    /// Returns the top secondary flick-down symbol for a Docked iPad key in `.alphabetic` or `.numeric` mode.
    static func flickSymbol(for action: KeyboardAction, row: Int? = nil, context: KeyboardContext) -> String? {
        guard context.deviceType == .pad && !context.isKeyboardFloating else { return nil }
        if let row, row >= 3 { return nil }
        guard case .character(let char) = action, !char.isEmpty else { return nil }

        let isCyrillic = context.locale.identifier.contains("Cyrl")
        let alphaRows = (isCyrillic ? InputSet.crimeanTatarCyrillic : InputSet.crimeanTatar).rows
        let numRows = (isCyrillic ? InputSet.crimeanTatarPadCyrillicNumeric : InputSet.crimeanTatarPadNumeric).rows
        let symRows = (isCyrillic ? InputSet.crimeanTatarPadCyrillicSymbolic : InputSet.crimeanTatarPadSymbolic).rows

        if context.keyboardType.isAlphabetic {
            let lower = char.lowercased()
            for r in 0..<min(alphaRows.count, numRows.count) {
                if let col = alphaRows[r].firstIndex(where: { $0.lowercased == lower }),
                   col < numRows[r].count {
                    return numRows[r][col].neutral
                }
            }
            // In email context, the trailing comma on Row 2 is replaced by '@'; in URL context, by '.'
            let isEmail = DemoStyleProvider.effectiveProxyKeyboardType(for: context) == .emailAddress
                || (!DemoStyleProvider.isSandboxOverrideActive(for: context) && context.textDocumentProxy.textContentType == .emailAddress)
            let isURL = DemoStyleProvider.effectiveProxyKeyboardType(for: context) == .URL
                || (!DemoStyleProvider.isSandboxOverrideActive(for: context) && context.textDocumentProxy.textContentType == .URL)
            if (isEmail && char == "@") || (isURL && char == "."),
               numRows.count > 2,
               let last = numRows[2].last {
                return last.neutral
            }
            return nil
        }

        if context.keyboardType == .numeric {
            for r in 0..<min(numRows.count, symRows.count) {
                if let col = numRows[r].firstIndex(where: { $0.neutral == char }),
                   col < symRows[r].count {
                    let sym = symRows[r][col].neutral
                    return sym != char ? sym : nil
                }
            }
        }

        return nil
    }
    
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
            return KeyboardPreferences.cyrillicEnabled ? [.custom(named: "toggle_script")] : [.capsLock]
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
        if isURLContext(context) && context.keyboardType.isAlphabetic {
            result += [.character(":"), .character("/"), .character("_"), .character("-"), .custom(named: "url_domain")]
        } else {
            result.append(.space)
        }
        if isEmailContext(context) && context.keyboardType.isAlphabetic {
            result.append(.character("."))
            result.append(.character("_"))
            result.append(.character("-"))
        } else if isURLContext(context) && context.keyboardType.isAlphabetic {
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
        // On iOS 27+, native iPad system keys align symbols/labels to the outer corners.
        // On iOS 26 and earlier, native iPad system keys center their symbols/labels.
        guard #available(iOS 27.0, *) else {
            return .center
        }
        switch action {
        case .tab, .capsLock, .nextKeyboard:
            return .bottomLeading
        case .custom(let name) where name == "toggle_script" || name == "undo" || name == "redo":
            return .bottomLeading
        case .backspace, .primary, .dismissKeyboard:
            return .bottomTrailing
        case .shift, .keyboardType:
            if row == 2 {
                return index == 0 ? .bottomLeading : .bottomTrailing
            }
            return index < 2 ? .bottomLeading : .bottomTrailing
        default:
            return .center
        }
    }
    
    override func itemSizeWidth(
        for action: KeyboardAction,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> KeyboardLayout.ItemWidth {
        // Fixed fractions keep side keys 100% invariant across Latin/Cyrillic and Alphabetic/Numeric/Symbolic pages.
        // Every character key has the exact same pitch, so row 1 / row 2 are offset by exact half keys
        // (A between Q and W, Z between A and S; Ф between Й and Ц, Я between Ф and Ы).
        let isCyrillic = context.locale.identifier.contains("Cyrl")
        let pitch = Self.letterPitch
        if row == 0 {
            if action == .tab { return .percentage(Self.tabFraction) }
            if action == .backspace { return .percentage(Self.backspaceFraction) }
            return .available
        }
        if row == 1 {
            if index == 0 {
                // Latin (12 keys): left control key ends half a key before 'â'; Cyrillic (11 keys): ends half a key before 'ф'.
                return .percentage(isCyrillic ? Self.tabFraction + pitch / 2 : Self.tabFraction - pitch / 2)
            }
            if case .primary = action { return .available }
            return .percentage(pitch)
        }
        if row == 2 {
            if index == 0 {
                // Row 2 keys start at tab + pitch so row 3 sits another half key to the right.
                return .percentage(Self.tabFraction + pitch)
            }
            switch action {
            case .shift, .keyboardType:
                return .available
            default:
                return .percentage(pitch)
            }
        }
        if action == .space || action == .custom(named: "url_domain") { return .available }
        if case .character = action { return isURLContext(context) ? .percentage(0.115) : .percentage(0.07) }
        if action == .nextKeyboard || action == .dismissKeyboard { return .percentage(0.085) }
        return .percentage(0.10)
    }
    
    override func keyboardReturnAction(
        for context: KeyboardContext
    ) -> KeyboardAction {
        #if os(iOS) || os(tvOS) || os(visionOS)
        let returnType = DemoStyleProvider.effectiveReturnKeyType(for: context)?.keyboardReturnKeyType
        if let returnType {
            return returnType == .return ? .primary(.newLine) : .primary(returnType)
        }
        #endif
        return .primary(.newLine)
    }
}
