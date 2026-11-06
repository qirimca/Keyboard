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

    static func isIPadPro5RowLayout(_ context: KeyboardContext) -> Bool {
        guard context.deviceType == .pad, !context.isKeyboardFloating, !context.isKeyboardSplit else { return false }
        let screen = DemoStyleProvider.effectiveScreenSize(for: context)
        let portraitWidth: CGFloat
        if screen.width > 0 && screen.height > 0 {
            portraitWidth = min(screen.width, screen.height)
        } else if screen.width > 0 {
            portraitWidth = screen.width
        } else {
            portraitWidth = 834.0
        }
        return portraitWidth >= 960.0
    }

    static let proKeyPitch: Double = 1.0 / 15.0

    static func iPadProTopNumberRowActions(for context: KeyboardContext) -> KeyboardAction.Row {
        let isCyrillic = context.locale.identifier.contains("Cyrl")
        let isShifted = context.keyboardType == .alphabetic(.uppercased) || context.keyboardType == .alphabetic(.capsLocked)
        let firstKey = isCyrillic ? "\\" : (isShifted ? "Â" : "â")
        let chars = [firstKey, "1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="]
        return chars.map { .character($0) } + [.backspace]
    }

    static func iPadProDualLegend(for action: KeyboardAction, row: Int?, context: KeyboardContext) -> (top: String, bottom: String)? {
        guard isIPadPro5RowLayout(context), context.keyboardType.isAlphabetic else { return nil }
        if row == 3 || row == 4 { return nil } // Bottom spacebar row character items
        guard case .character(let char) = action else { return nil }
        let isCyrillic = context.locale.identifier.contains("Cyrl")
        let isUkrainianCyr = isCyrillic && KeyboardPreferences.ukrainianCyrillicLayoutEnabled
        let isTopRowNumberSymbol = ["1", "2", "3", "4", "5", "6", "7", "8", "9", "0", "-", "="].contains(char)

        if row == 0 || (row == nil && isTopRowNumberSymbol) {
            if isCyrillic {
                switch char {
                case "\\", "/": return ("/", "\\")
                case "1", "!": return ("!", "1")
                case "2", "\"": return ("\"", "2")
                case "3", "№": return ("№", "3")
                case "4", ";": return (";", "4")
                case "5", "%": return ("%", "5")
                case "6", ":": return (":", "6")
                case "7", "?": return ("?", "7")
                case "8", "*": return ("*", "8")
                case "9", "(": return ("(", "9")
                case "0", ")": return (")", "0")
                case "-", "_": return ("_", "-")
                case "=", "+": return ("+", "=")
                default:
                    return nil
                }
            } else {
                switch char {
                case "1", "!": return ("!", "1")
                case "2", "'": return ("'", "2")
                case "3", "^": return ("^", "3")
                case "4", "+": return ("+", "4")
                case "5", "%": return ("%", "5")
                case "6", "&": return ("&", "6")
                case "7", "/": return ("/", "7")
                case "8", "(": return ("(", "8")
                case "9", ")": return (")", "9")
                case "0": return ("=", "0")
                case "-", "_": return ("_", "-")
                case "=", "*": return ("*", "=")
                default:
                    return nil
                }
            }
        }

        // Rows 1..3 (letter/punctuation rows on 5-row iPad Pro)
        if isCyrillic {
            switch char {
            case "\\", "/":
                return ("/", "\\")
            case ";":
                return (";", ",")
            case ":":
                return isUkrainianCyr ? (":", ",") : nil
            case "\u{02BC}":
                return isUkrainianCyr ? (".", "\u{02BC}") : nil
            case ".":
                return isUkrainianCyr ? (".", "\u{02BC}") : (",", ".")
            case ",":
                return isUkrainianCyr ? (":", ",") : (";", ",")
            default:
                return nil
            }
        } else {
            switch char {
            case "\\", "/":
                return ("/", "\\")
            case ",", ";":
                return (";", ",")
            case ".", ":":
                return (":", ".")
            default:
                return nil
            }
        }
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
        
        // In email fields on 4-row iPad, replace the trailing comma in row 2 with '@'
        // In URL fields on 4-row iPad, replace the trailing comma in row 2 with '.' (matching native iPadOS Web layout)
        if context.keyboardType.isAlphabetic && !Self.isIPadPro5RowLayout(context) {
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

        if Self.isIPadPro5RowLayout(context) && context.keyboardType.isAlphabetic {
            let row1TrailingAction: KeyboardAction = .character("\\")
            let returnAction = keyboardReturnAction(for: context)
            result.append(Self.iPadProTopNumberRowActions(for: context))
            result.append([.tab] + actions[0] + [row1TrailingAction])
            result.append(middleLeadingActions(for: context) + actions[1] + [returnAction])
            result.append(lowerLeadingActions(for: context) + actions[2] + lowerTrailingActions(for: context))
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
        guard case .character(let char) = item.action else { return false }
        if context.keyboardType.isAlphabetic && char == "/" && !Self.isIPadPro5RowLayout(context) { return true }
        if case .percentage(let pct) = item.size.width {
            if Self.isIPadPro5RowLayout(context) && context.keyboardType.isAlphabetic {
                return abs(pct - Self.proKeyPitch) > 0.001
            }
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

    private static func buildAlphaFlickMap(alpha: InputSet, numeric: InputSet) -> [String: String] {
        var map: [String: String] = [:]
        let alphaRows = alpha.rows
        let numRows = numeric.rows
        for r in 0..<min(alphaRows.count, numRows.count) {
            for col in 0..<min(alphaRows[r].count, numRows[r].count) {
                let sym = numRows[r][col].neutral
                map[alphaRows[r][col].lowercased] = sym
                map[alphaRows[r][col].uppercased] = sym
            }
        }
        return map
    }

    private static func buildNumericFlickMap(numeric: InputSet, symbolic: InputSet) -> [String: String] {
        var map: [String: String] = [:]
        let numRows = numeric.rows
        let symRows = symbolic.rows
        for r in 0..<min(numRows.count, symRows.count) {
            for col in 0..<min(numRows[r].count, symRows[r].count) {
                let num = numRows[r][col].neutral
                let sym = symRows[r][col].neutral
                if sym != num {
                    map[num] = sym
                }
            }
        }
        return map
    }

    private static let latinAlphaFlickMap: [String: String] = buildAlphaFlickMap(
        alpha: .crimeanTatarPadLatin,
        numeric: .crimeanTatarPadNumeric
    )
    private static let stdCyrAlphaFlickMap: [String: String] = buildAlphaFlickMap(
        alpha: .crimeanTatarStandardCyrillic,
        numeric: .crimeanTatarPadCyrillicNumeric
    )
    private static let ukCyrAlphaFlickMap: [String: String] = buildAlphaFlickMap(
        alpha: .crimeanTatarPadUkrainianCyrillic,
        numeric: .crimeanTatarPadCyrillicNumeric
    )
    private static let latinNumericFlickMap: [String: String] = buildNumericFlickMap(
        numeric: .crimeanTatarPadNumeric,
        symbolic: .crimeanTatarPadSymbolic
    )
    private static let cyrNumericFlickMap: [String: String] = buildNumericFlickMap(
        numeric: .crimeanTatarPadCyrillicNumeric,
        symbolic: .crimeanTatarPadCyrillicSymbolic
    )
    private static let latinTrailingFlickSymbol: String? = InputSet.crimeanTatarPadNumeric.rows.count > 2
        ? InputSet.crimeanTatarPadNumeric.rows[2].last?.neutral
        : nil
    private static let cyrTrailingFlickSymbol: String? = InputSet.crimeanTatarPadCyrillicNumeric.rows.count > 2
        ? InputSet.crimeanTatarPadCyrillicNumeric.rows[2].last?.neutral
        : nil

    /// Returns the top secondary flick-down symbol for a Docked iPad key in `.alphabetic` or `.numeric` mode.
    static func flickSymbol(for action: KeyboardAction, row: Int? = nil, context: KeyboardContext) -> String? {
        guard context.deviceType == .pad && !context.isKeyboardFloating else { return nil }
        if Self.isIPadPro5RowLayout(context) && context.keyboardType.isAlphabetic {
            return Self.iPadProDualLegend(for: action, row: row, context: context)?.top
        }
        guard SystemKeyboardSettings.isKeyFlicksEnabled else { return nil }
        if let row, row >= 3 { return nil }
        guard case .character(let char) = action, !char.isEmpty else { return nil }

        let isCyrillic = context.locale.identifier.contains("Cyrl")

        if context.keyboardType.isAlphabetic {
            let map = isCyrillic
                ? (KeyboardPreferences.ukrainianCyrillicLayoutEnabled ? Self.ukCyrAlphaFlickMap : Self.stdCyrAlphaFlickMap)
                : Self.latinAlphaFlickMap
            if let hit = map[char] {
                return hit
            }
            if char == "@" || char == "." {
                // In email context, the trailing comma on Row 2 is replaced by '@'; in URL context, by '.'
                let isEmail = DemoStyleProvider.effectiveProxyKeyboardType(for: context) == .emailAddress
                    || (!DemoStyleProvider.isSandboxOverrideActive(for: context) && context.textDocumentProxy.textContentType == .emailAddress)
                let isURL = DemoStyleProvider.effectiveProxyKeyboardType(for: context) == .URL
                    || (!DemoStyleProvider.isSandboxOverrideActive(for: context) && context.textDocumentProxy.textContentType == .URL)
                if (isEmail && char == "@") || (isURL && char == ".") {
                    return isCyrillic ? Self.cyrTrailingFlickSymbol : Self.latinTrailingFlickSymbol
                }
            }
            return nil
        }

        if context.keyboardType == .numeric {
            let map = isCyrillic ? Self.cyrNumericFlickMap : Self.latinNumericFlickMap
            return map[char]
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
            return (KeyboardPreferences.isIPadAbvToggleKeyActive || context.locale.identifier.contains("Cyrl")) ? [.custom(named: "toggle_script")] : [.capsLock]
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
            if Self.isIPadPro5RowLayout(context) || (context.locale.identifier.contains("Cyrl") && KeyboardPreferences.ukrainianCyrillicLayoutEnabled) {
                result.append(.character("@"))
            }
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
            let totalRows = (Self.isIPadPro5RowLayout(context) && context.keyboardType.isAlphabetic) ? 5 : 4
            return DemoStyleProvider.itemEdgeInsets(forRowAt: row, totalRows: totalRows, context: context)
        }
    }

    override func itemSizeHeight(
        for action: KeyboardAction,
        row: Int,
        index: Int,
        context: KeyboardContext
    ) -> CGFloat {
        let totalRows = (Self.isIPadPro5RowLayout(context) && context.keyboardType.isAlphabetic) ? 5 : 4
        return DemoStyleProvider.rowHeight(forRowAt: row, totalRows: totalRows, context: context)
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
        let screen = DemoStyleProvider.effectiveScreenSize(for: context)
        let minDim = min(screen.width, screen.height)
        let maxDim = max(screen.width, screen.height)
        let isHomeButtonPad = (abs(minDim - 834.0) < 1.0 && abs(maxDim - 1112.0) < 1.0)
            || (abs(minDim - 768.0) < 1.0 && abs(maxDim - 1024.0) < 1.0)
        if isHomeButtonPad || DemoStyleProvider.usesClassicSystemKeyStyle || isSplitMode(context) || action == .dictation {
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
            if row == 2 || (row == 3 && Self.isIPadPro5RowLayout(context)) {
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
        let isCyrillic = context.locale.identifier.contains("Cyrl")
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
                    return .percentage(side + pitch)
                }
                if case .primary = action {
                    return .percentage(side)
                }
                return .percentage(pitch)
            }
            if row == 2 {
                if index == 0 {
                    return .percentage(isCyrillic ? (side + pitch) : side)
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

        if Self.isIPadPro5RowLayout(context) && context.keyboardType.isAlphabetic {
            let p = Self.proKeyPitch // 1.0 / 15.0
            if row == 0 {
                if action == .backspace { return .available }
                return .percentage(p)
            }
            if row == 1 {
                if index == 0 { return .percentage(1.5 * p) }
                if index >= 13 { return .available }
                if case .primary = action { return .available }
                return .percentage(p)
            }
            if row == 2 {
                if index == 0 { return .percentage(1.75 * p) }
                if case .primary = action { return .available }
                return .percentage(p)
            }
            if row == 3 {
                if index == 0 { return .percentage((isCyrillic ? 1.25 : 2.25) * p) }
                if case .shift = action { return .available }
                return .percentage(p)
            }
            // Row 4 (bottom row on 5-row iPad Pro)
            if action == .space || action == .custom(named: "url_domain") { return .available }
            if case .character = action { return isURLContext(context) ? .percentage(0.115) : .percentage(0.07) }
            if action == .nextKeyboard || action == .dismissKeyboard {
                return .percentage(1.0 * p)
            }
            return .percentage(1.25 * p)
        }

        // Standard 4-row Docked iPad (9.7" / 10.5" / 10.9" / 11"):
        // Uniform stagger across Portrait and Landscape so Q - A - Z (and Й - Ф - Я) lie on one straight diagonal line:
        // x(Q) = tab + 0.5*pitch, x(A) = tab + 1.0*pitch, x(Z) = tab + 1.5*pitch, with Â placed at [tab, tab + pitch] before Z in Latin.
        let isPortrait = context.interfaceOrientation.isPortrait
        let tab = Self.tabFraction
        let bs = Self.backspaceFraction
        let pitch = Self.letterPitch
        if row == 0 {
            if action == .tab { return .percentage(tab) }
            if action == .backspace { return .percentage(bs) }
            return .available
        }
        if row == 1 {
            if index == 0 {
                return .percentage(tab + pitch / 2.0)
            }
            if case .primary = action { return .available }
            return .percentage(pitch)
        }
        if row == 2 {
            if index == 0 {
                return .percentage(isCyrillic ? tab + pitch : tab)
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
        let leftBottomFrac = isPortrait ? 0.083942 : 0.092
        let rightBottomFrac = isPortrait ? 0.118005 : 0.131
        if action == .nextKeyboard || action == .keyboardType(.emojis) {
            return .percentage(leftBottomFrac)
        }
        if action == .dismissKeyboard {
            return .percentage(rightBottomFrac)
        }
        return .percentage(index <= 1 ? leftBottomFrac : rightBottomFrac)
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
