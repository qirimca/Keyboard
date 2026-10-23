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
    
    private func isSplitMode(_ context: KeyboardContext) -> Bool {
        context.deviceType == .pad && !context.isKeyboardFloating && context.isKeyboardSplit
    }

    static func splitHalfFraction(for context: KeyboardContext) -> Double {
        let isPortrait = context.interfaceOrientation.isPortrait
        let rawScreen = context.screenSize
        let totalWidth: Double
        if rawScreen.width > 0 && rawScreen.height > 0 {
            totalWidth = Double(isPortrait ? min(rawScreen.width, rawScreen.height) : max(rawScreen.width, rawScreen.height))
        } else {
            totalWidth = isPortrait ? 834.0 : 1112.0
        }
        let minGapFraction = isPortrait ? 0.22 : 0.38
        let maxHalfWidth = isPortrait ? 276.0 : 320.0
        let targetHalfWidth = min((totalWidth * (1.0 - minGapFraction)) / 2.0, maxHalfWidth)
        return targetHalfWidth / max(totalWidth, 1.0)
    }

    static func splitGapFraction(for context: KeyboardContext) -> Double {
        max(0.16, 1.0 - 2.0 * splitHalfFraction(for: context))
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
        if isSplitMode(context) {
            for r in 0..<3 {
                let rowInputs = actions[r]
                let leftCount = rowInputs.count / 2
                let leftInputs = Array(rowInputs.prefix(leftCount))
                let rightInputs = Array(rowInputs.dropFirst(leftCount))
                let leading: KeyboardAction.Row
                let trailing: KeyboardAction.Row
                switch r {
                case 0:
                    leading = topLeadingActions(for: context)
                    trailing = topTrailingActions(for: context)
                case 1:
                    leading = middleLeadingActions(for: context)
                    trailing = middleTrailingActions(for: context)
                default:
                    leading = lowerLeadingActions(for: context)
                    trailing = lowerTrailingActions(for: context)
                }
                result.append(leading + leftInputs + [.none] + rightInputs + trailing)
            }
            result.append(bottomActions(for: context))
            return result
        }

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

    /// Returns whether a layout item is a character key on the bottom (spacebar) row.
    static func isBottomRowCharacterItem(_ item: KeyboardLayout.Item, context: KeyboardContext) -> Bool {
        if abs(item.edgeInsets.bottom - 2.0) < 0.01 { return true }
        guard case .character(let char) = item.action else { return false }
        if context.keyboardType.isAlphabetic && char == "/" { return true }
        if case .percentage(let pct) = item.size.width {
            let dockedPitch = Self.letterPitch
            let half = Self.splitHalfFraction(for: context)
            let splitSide = half * 0.175
            let splitPitch = (half - splitSide) / 6.0
            if abs(pct - dockedPitch) > 0.001 && abs(pct - splitPitch) > 0.001 {
                return true
            }
        }
        return false
    }

    /// Returns the top secondary flick-down symbol for a Docked iPad key in `.alphabetic` or `.numeric` mode.
    static func flickSymbol(for action: KeyboardAction, row: Int? = nil, context: KeyboardContext) -> String? {
        guard context.deviceType == .pad && !context.isKeyboardFloating else { return nil }
        guard SystemKeyboardSettings.isKeyFlicksEnabled else { return nil }
        if let row, row >= 3 { return nil }
        guard case .character(let char) = action, !char.isEmpty else { return nil }

        let isCyrillic = context.locale.identifier.contains("Cyrl")
        let is11KeyRow1Cyr = isCyrillic
        let alphaRows = (isCyrillic
            ? (KeyboardPreferences.ukrainianCyrillicLayoutEnabled ? InputSet.crimeanTatarPadUkrainianCyrillic : InputSet.crimeanTatarStandardCyrillic)
            : InputSet.crimeanTatar).rows
        let numRows = (is11KeyRow1Cyr ? InputSet.crimeanTatarPadCyrillicNumeric : InputSet.crimeanTatarPadNumeric).rows
        let symRows = (is11KeyRow1Cyr ? InputSet.crimeanTatarPadCyrillicSymbolic : InputSet.crimeanTatarPadSymbolic).rows

        if context.keyboardType.isAlphabetic {
            for r in 0..<min(alphaRows.count, numRows.count) {
                if let col = alphaRows[r].firstIndex(where: { $0.lowercased == char || $0.uppercased == char }),
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
        if isSplitMode(context) {
            var result = KeyboardAction.Row()
            let switchAction = keyboardSwitchActionForBottomRow(for: context) ?? .keyboardType(.numeric)
            // Left thumb cluster
            result.append(.nextKeyboard)
            result.append(switchAction)
            if isURLContext(context) && context.keyboardType.isAlphabetic {
                result += [.character(":"), .character("/"), .character("_")]
            } else {
                result.append(.space)
            }
            // Center gap
            result.append(.none)
            // Right thumb cluster
            if isURLContext(context) && context.keyboardType.isAlphabetic {
                result += [.character("-"), .custom(named: "url_domain"), switchAction, .dismissKeyboard]
            } else if isEmailContext(context) && context.keyboardType.isAlphabetic {
                result += [.space, .character("."), .character("_"), .character("-"), .dismissKeyboard]
            } else {
                result += [.space, switchAction, .dismissKeyboard]
            }
            return result
        }

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
            return DemoStyleProvider.itemEdgeInsets(forRowAt: row, context: context)
        }
    }

    override func itemSizeHeight(
        for action: KeyboardAction,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> CGFloat {
        DemoStyleProvider.rowHeight(forRowAt: row, context: context)
    }

    override func itemAlignment(
        for action: KeyboardAction,
        in actions: KeyboardAction.Rows,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> Alignment {
        return .center
    }
    
    override func itemSizeWidth(
        for action: KeyboardAction,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> KeyboardLayout.ItemWidth {
        let isCyrillic = context.locale.identifier.contains("Cyrl")
        let is11KeyRow1Cyr = isCyrillic
        if isSplitMode(context) {
            let gap = Self.splitGapFraction(for: context)
            let half = Self.splitHalfFraction(for: context)
            let side = half * 0.175
            let pitch = (half - side) / 6.0
            if action == .none {
                return .percentage(gap)
            }
            if row == 0 {
                if action == .tab || action == .backspace {
                    return .percentage(side)
                }
                return .percentage(pitch)
            }
            if row == 1 {
                if index == 0 {
                    return .percentage(is11KeyRow1Cyr ? (side + pitch) : side)
                }
                if case .primary = action {
                    return .percentage(side)
                }
                return .percentage(pitch)
            }
            if row == 2 {
                if index == 0 {
                    return .percentage(side + pitch)
                }
                switch action {
                case .shift, .keyboardType:
                    return .percentage(side)
                default:
                    return .percentage(pitch)
                }
            }
            // Row 3 (bottom row) in Split Mode
            if action == .nextKeyboard || action == .dismissKeyboard {
                return .percentage(side)
            }
            if case .keyboardType = action {
                return .percentage(side * 1.1)
            }
            if isURLContext(context) && context.keyboardType.isAlphabetic {
                if index < 5 {
                    return .percentage((half - side * 2.1) / 3.0)
                }
                if action == .character("-") {
                    return .percentage(pitch)
                }
                if action == .custom(named: "url_domain") {
                    return .percentage(half - pitch - side * 2.1)
                }
            }
            if isEmailContext(context) && context.keyboardType.isAlphabetic {
                if index < 3 && action == .space {
                    return .percentage(half - side * 2.1)
                }
                if case .character = action {
                    return .percentage(pitch * 0.72)
                }
                if action == .space {
                    return .percentage(half - side - 3.0 * (pitch * 0.72))
                }
            }
            return .percentage(half - side * 2.1)
        }

        // Fixed fractions keep side keys 100% invariant across Latin/Cyrillic and Alphabetic/Numeric/Symbolic pages.
        // Every character key has the exact same pitch, so row 1 / row 2 are offset by exact half keys
        // (A between Q and W, Z between A and S; Ф between Й and Ц, Я between Ф and Ы / І).
        let pitch = Self.letterPitch
        if row == 0 {
            if action == .tab { return .percentage(Self.tabFraction) }
            if action == .backspace { return .percentage(Self.backspaceFraction) }
            return .available
        }
        if row == 1 {
            if index == 0 {
                // 12-key Row 1 (Latin): left control key ends half a key before first letter;
                // 11-key Row 1 (Standard Cyrillic ФЫВА & Docked iPad Ukrainian ФІВА): ends half a key before 'ф'.
                return .percentage(is11KeyRow1Cyr ? Self.tabFraction + pitch / 2 : Self.tabFraction - pitch / 2)
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
        if action == .nextKeyboard || action == .dismissKeyboard || action == .keyboardType(.emojis) {
            return .percentage(0.085)
        }
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
