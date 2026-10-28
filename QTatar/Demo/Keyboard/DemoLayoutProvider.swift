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
            let isUkrainianCyr = isCyrillic && KeyboardPreferences.ukrainianCyrillicLayoutEnabled
            for row in 0...2 {
                // Keep .characterMargin in row 1 for 11-key Cyrillic (ФЫВА) so 'ф' is centered between 'й' and 'ц'
                let keepMargins = isCyrillic && !isUkrainianCyr && row == 1
                actions[row].removeAll { action in
                    switch action {
                    case .characterMargin: return !keepMargins
                    case .none: return true
                    case .character(let text):
                        return row == 2 && (text == "," || text == ".")
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
    
    override func lowerSystemButtonWidth(for context: KeyboardContext) -> KeyboardLayout.ItemWidth {
        if context.keyboardType.isAlphabetic {
            return .input
        }
        return .percentage(0.13)
    }
    
    override func bottomActions(
        for context: KeyboardContext
    ) -> KeyboardAction.Row {
        var result = KeyboardAction.Row()
        if let action = keyboardSwitchActionForBottomRow(for: context) {
            result.append(action)
        }
        // In iPad Floating mode, classic apps (e.g. Gmail) do not render a system bottom bar with a Globe button below the floating platter,
        // and an out-of-process UIInputViewController cannot inspect the host window's private floating chrome bar.
        // Always include .nextKeyboard in Floating mode so users can switch keyboards in every app.
        let shouldIncludeGlobe = context.isKeyboardFloating || context.needsInputModeSwitchKey
        let canShowPhoneEmoji = context.deviceType == .phone && !context.isKeyboardFloating && SystemKeyboardSettings.isEmojiKeyboardEnabled

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

        if shouldIncludeGlobe {
            result.append(.nextKeyboard)
        } else if !isURL && canShowPhoneEmoji {
            result.append(.keyboardType(.emojis))
        }
        
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
        if shouldIncludeGlobe {
            result.append(.nextKeyboard)
        } else if canShowPhoneEmoji {
            result.append(.keyboardType(.emojis))
        }
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
            return .percentage(0.12825)
        }
        let isPortrait = context.interfaceOrientation.isPortrait
        return .percentage(isPortrait ? 0.112 : 0.11)
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
                return .percentage(0.12825)
            }
            let isPortrait = context.interfaceOrientation.isPortrait
            return .percentage(isPortrait ? 0.112 : 0.095)
        case .keyboardType(let type):
            // Row 2 contains the #+= (symbolic) or 123 (numeric) switcher button
            if row != 3 {
                return lowerSystemButtonWidth(for: context)
            }
            if context.isKeyboardFloating {
                return .percentage(0.12825)
            }
            let isPortrait = context.interfaceOrientation.isPortrait
            if type == .emojis {
                return .percentage(isPortrait ? 0.112 : 0.095)
            }
            let shouldIncludeGlobe = context.isKeyboardFloating || context.needsInputModeSwitchKey
            let canShowPhoneEmoji = context.deviceType == .phone && !context.isKeyboardFloating && SystemKeyboardSettings.isEmojiKeyboardEnabled
            #if os(iOS) || os(tvOS) || os(visionOS)
            let effectiveType = DemoStyleProvider.effectiveProxyKeyboardType(for: context)
            let isSandbox = DemoStyleProvider.isSandboxOverrideActive(for: context)
            let isURL = effectiveType == .URL || (!isSandbox && context.textDocumentProxy.textContentType == .URL)
            #else
            let isURL = false
            #endif
            if !shouldIncludeGlobe && !canShowPhoneEmoji && !isURL {
                return .percentage(isPortrait ? 0.242 : 0.195)
            }
            return .percentage(isPortrait ? 0.112 : 0.11)
        case .primary:
            if context.isKeyboardFloating {
                return .percentage(0.2565)
            }
            let isPortrait = context.interfaceOrientation.isPortrait
            return .percentage(isPortrait ? 0.242 : 0.195)
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
        KeyboardPreferences.ukrainianCyrillicLayoutEnabled
            ? .crimeanTatarUkrainianCyrillic
            : .crimeanTatarStandardCyrillic
    }

    static var crimeanTatarStandardCyrillic: InputSet {
        .init(rows: [
            .init(lowercased: "йцукенгшщзхъ", uppercased: "ЙЦУКЕНГШЩЗХЪ"),
            .init(lowercased: "фывапролджэ", uppercased: "ФЫВАПРОЛДЖЭ"),
            .init(lowercased: "ячсмитьбюё,", uppercased: "ЯЧСМИТЬБЮЁ,")
        ])
    }

    /// Ukrainian-adapted Cyrillic layout (`ФІВА`) where `і -> i`, `ї -> yi`, `и -> ı`, `е -> e`, `є -> ye`, `г/гʼ -> ğ`, `ґ -> g`, `кʼ -> q`, `нʼ -> ñ`.
    /// Row 0 has 12 keys (`йцукенгшщзхї`) and Row 1 has 12 keys (`фівапролджєʼ`) on iPhone and iPad Floating.
    static var crimeanTatarUkrainianCyrillic: InputSet {
        .init(rows: [
            .init(lowercased: "йцукенгшщзхї", uppercased: "ЙЦУКЕНГШЩЗХЇ"),
            .init(lowercased: "фівапролджє\u{02BC}", uppercased: "ФІВАПРОЛДЖЄ\u{02BC}"),
            .init(lowercased: "ячсмитьбюґ,", uppercased: "ЯЧСМИТЬБЮҐ,")
        ])
    }

    /// Docked iPad Ukrainian-adapted Cyrillic layout (`ФІВА`) with 12 / 11 / 11 geometry so `й – ф – я` align on one diagonal line,
    /// placing `ʼ` on Row 2 col 10 (where `,` remains accessible via key-flick on `б`).
    static var crimeanTatarPadUkrainianCyrillic: InputSet {
        .init(rows: [
            .init(lowercased: "йцукенгшщзхї", uppercased: "ЙЦУКЕНГШЩЗХЇ"),
            .init(lowercased: "фівапролджє", uppercased: "ФІВАПРОЛДЖЄ"),
            .init(lowercased: "ячсмитьбюґ\u{02BC}", uppercased: "ЯЧСМИТЬБЮҐ\u{02BC}")
        ])
    }

    /// 5-row iPad Pro (12.9" / 13") Crimean Tatar Latin layout based on Turkish iPad Pro + `ñ` (with `â` on Row 0 Col 0).
    static var crimeanTatarPadProLatin: InputSet {
        .init(rows: [
            .init(lowercased: "qwertyuıopğü", uppercased: "QWERTYUIOPĞÜ"),
            .init(lowercased: "asdfghjklşi,", uppercased: "ASDFGHJKLŞİ,"),
            .init(lowercased: "zxcvbnmöçñ.", uppercased: "ZXCVBNMÖÇÑ.")
        ])
    }

    /// 5-row iPad Pro (12.9" / 13") Standard Cyrillic (`ФЫВА`) layout matching Russian iPad Pro (12 / 12 / 11).
    static var crimeanTatarPadProStandardCyrillic: InputSet {
        .init(rows: [
            .init(lowercased: "йцукенгшщзхъ", uppercased: "ЙЦУКЕНГШЩЗХЪ"),
            .init(lowercased: "фывапролджэ,", uppercased: "ФЫВАПРОЛДЖЭ,"),
            .init(lowercased: "ёячсмитьбю.", uppercased: "ЁЯЧСМИТЬБЮ.")
        ])
    }

    /// 5-row iPad Pro (12.9" / 13") Ukrainian-adapted Cyrillic (`ФІВА`) layout matching Ukrainian iPad Pro (12 / 12 / 11).
    static var crimeanTatarPadProUkrainianCyrillic: InputSet {
        .init(rows: [
            .init(lowercased: "йцукенгшщзхї", uppercased: "ЙЦУКЕНГШЩЗХЇ"),
            .init(lowercased: "фівапролджє,", uppercased: "ФІВАПРОЛДЖЄ,"),
            .init(lowercased: "ґячсмитьбю\u{02BC}", uppercased: "ҐЯЧСМИТЬБЮ\u{02BC}")
        ])
    }

    /// Standardized phone Latin numeric set (matching English iOS phone layout)
    static var crimeanTatarPhoneLatinNumeric: InputSet {
        .init(rows: [
            .init(chars: "1234567890"),
            .init(chars: "-/:;()$&@\""),
            .init(chars: ".,?!'")
        ])
    }

    /// Standardized phone Latin symbolic set (matching English iOS phone layout, with Turkish Lira ₺)
    static var crimeanTatarPhoneLatinSymbolic: InputSet {
        .init(rows: [
            .init(chars: "[]{}#%^*+="),
            .init(chars: "_\\|~<>€£₺•"),
            .init(chars: ".,?!'")
        ])
    }

    /// Standardized phone Cyrillic numeric set (matching Ukrainian iOS phone layout)
    static var crimeanTatarPhoneNumeric: InputSet {
        .init(rows: [
            .init(chars: "1234567890"),
            .init(chars: "-/:;()₴&@\""),
            .init(chars: ".,?!'")
        ])
    }
    
    /// Standardized phone Cyrillic symbolic set (matching Ukrainian iOS phone layout)
    static var crimeanTatarPhoneSymbolic: InputSet {
        .init(rows: [
            .init(chars: "[]{}#%^*+="),
            .init(chars: "_\\|~<>€$£•"),
            .init(chars: ".,?!'")
        ])
    }
    
    /// Docked iPad Latin numeric set (12 / 12 / 11 matching Latin alphabetic key counts and English symbol order)
    static var crimeanTatarPadNumeric: InputSet {
        .init(rows: [
            .init(chars: "1234567890—°"),
            .init(chars: "@#$₴&*_()'\"№"),
            .init(chars: "%-+=/;:,.!?")
        ])
    }
    
    /// Docked iPad Latin symbolic set (12 / 12 / 11 matching Latin alphabetic key counts and English symbol order, with Turkish Lira ₺)
    static var crimeanTatarPadSymbolic: InputSet {
        .init(rows: [
            .init(chars: "1234567890—°"),
            .init(chars: "€£₺•`^|[]{}±"),
            .init(chars: "§~…≠\\<>«»!?")
        ])
    }

    /// Docked iPad Cyrillic numeric set (12 / 11 / 11 matching Cyrillic alphabetic key counts and Ukrainian symbol order with zero empty slots)
    static var crimeanTatarPadCyrillicNumeric: InputSet {
        .init(rows: [
            .init(chars: "1234567890—°"),
            .init(chars: "@#₴№&*_()'\""),
            .init(chars: "%-+=/;:,.!?")
        ])
    }

    /// Docked iPad Cyrillic symbolic set (12 / 11 / 11 matching Cyrillic alphabetic key counts and Ukrainian symbol order with zero empty slots)
    static var crimeanTatarPadCyrillicSymbolic: InputSet {
        .init(rows: [
            .init(chars: "1234567890—°"),
            .init(chars: "€$£•`^|[]{}"),
            .init(chars: "§~…≠\\<>«»!?")
        ])
    }
}

/**
 This demo-specific provider inherits the standard one, then
 configures custom iPhone and iPad layout providers for Crimean Tatar.
 */
class DemoLayoutProvider: StandardKeyboardLayoutProvider {

    private let isPadDevice: Bool
    private let isCyrillicOnlyOnPhone: Bool
    private let isLatinOnlyOnPhone: Bool

    init(
        isPadDevice: Bool = (UIDevice.current.userInterfaceIdiom == .pad),
        bundleId: String? = Bundle.main.bundleIdentifier
    ) {
        self.isPadDevice = isPadDevice
        self.isCyrillicOnlyOnPhone = !isPadDevice && AppConfiguration.isCyrillicKeyboardExtensionBundleId(bundleId)
        self.isLatinOnlyOnPhone = !isPadDevice && (bundleId == AppConfiguration.keyboardBundleId)

        let initialAlpha: InputSet = isCyrillicOnlyOnPhone ? .crimeanTatarCyrillic : .crimeanTatar
        let initialNum: InputSet = isPadDevice
            ? .crimeanTatarPadNumeric
            : (isCyrillicOnlyOnPhone ? .crimeanTatarPhoneNumeric : .crimeanTatarPhoneLatinNumeric)
        let initialSym: InputSet = isPadDevice
            ? .crimeanTatarPadSymbolic
            : (isCyrillicOnlyOnPhone ? .crimeanTatarPhoneSymbolic : .crimeanTatarPhoneLatinSymbolic)

        let baseProvider = InputSetBasedKeyboardLayoutProvider(
            alphabeticInputSet: initialAlpha,
            numericInputSet: initialNum,
            symbolicInputSet: initialSym
        )
        if isPadDevice {
            baseProvider.iPadProvider = CrimeanTatarIPadKeyboardLayoutProvider(
                alphabeticInputSet: initialAlpha,
                numericInputSet: .crimeanTatarPadNumeric,
                symbolicInputSet: .crimeanTatarPadSymbolic
            )
        }
        baseProvider.iPhoneProvider = CrimeanTatarIPhoneKeyboardLayoutProvider(
            alphabeticInputSet: initialAlpha,
            numericInputSet: initialNum,
            symbolicInputSet: initialSym
        )
        super.init(baseProvider: baseProvider)
    }

    override func keyboardLayout(for context: KeyboardContext) -> KeyboardLayout {
        guard let base = baseProvider as? InputSetBasedKeyboardLayoutProvider else {
            return super.keyboardLayout(for: context)
        }
        let isCyrillic: Bool = {
            if isLatinOnlyOnPhone { return false }
            if isCyrillicOnlyOnPhone { return true }
            return context.locale.identifier.contains("Cyrl")
        }()

        if context.isKeyboardFloating || context.deviceType == .phone || !isPadDevice {
            if let phone = base.iPhoneProvider as? BaseKeyboardLayoutProvider {
                if isLatinOnlyOnPhone {
                    phone.alphabeticInputSet = .crimeanTatar
                    phone.numericInputSet = .crimeanTatarPhoneLatinNumeric
                    phone.symbolicInputSet = .crimeanTatarPhoneLatinSymbolic
                } else if isCyrillicOnlyOnPhone {
                    phone.alphabeticInputSet = .crimeanTatarCyrillic
                    phone.numericInputSet = .crimeanTatarPhoneNumeric
                    phone.symbolicInputSet = .crimeanTatarPhoneSymbolic
                } else {
                    phone.alphabeticInputSet = isCyrillic ? .crimeanTatarCyrillic : .crimeanTatar
                    phone.numericInputSet = isCyrillic ? .crimeanTatarPhoneNumeric : .crimeanTatarPhoneLatinNumeric
                    phone.symbolicInputSet = isCyrillic ? .crimeanTatarPhoneSymbolic : .crimeanTatarPhoneLatinSymbolic
                }
            }
            return base.iPhoneProvider.keyboardLayout(for: context)
        }

        if let pad = base.iPadProvider as? BaseKeyboardLayoutProvider {
            let isPro5Row = CrimeanTatarIPadKeyboardLayoutProvider.isIPadPro5RowLayout(context)
            let padInputSet: InputSet
            if isPro5Row {
                padInputSet = isCyrillic
                    ? (KeyboardPreferences.ukrainianCyrillicLayoutEnabled ? .crimeanTatarPadProUkrainianCyrillic : .crimeanTatarPadProStandardCyrillic)
                    : .crimeanTatarPadProLatin
            } else {
                padInputSet = isCyrillic
                    ? (KeyboardPreferences.ukrainianCyrillicLayoutEnabled ? .crimeanTatarPadUkrainianCyrillic : .crimeanTatarStandardCyrillic)
                    : .crimeanTatar
            }
            pad.alphabeticInputSet = padInputSet
            pad.numericInputSet = isCyrillic ? .crimeanTatarPadCyrillicNumeric : .crimeanTatarPadNumeric
            pad.symbolicInputSet = isCyrillic ? .crimeanTatarPadCyrillicSymbolic : .crimeanTatarPadSymbolic
        }
        let layout = base.iPadProvider.keyboardLayout(for: context)
        layout.applyNativeRowInsets(for: context)

        return layout
    }
}

private extension KeyboardLayout {
    
    func applyNativeRowInsets(for context: KeyboardContext) {
        // Row 3 on Docked iPad now uses KeyboardAdaptiveGeometry.bottomTopBottomInset directly
        // so the bottom keycap margin matches Native iPadOS (10.0 pt total bottom margin).
    }
}
