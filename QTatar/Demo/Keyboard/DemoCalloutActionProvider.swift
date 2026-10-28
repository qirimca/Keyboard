//
//  DemoCalloutActionProvider.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import KeyboardKit

/// Long-press callout provider for QırımKey.
/// Additional Crimean Tatar letters (â, ñ, ç, ş, ğ, ö, ü, ı, i, ё, ъ, ж) are present
/// as dedicated keys on the main layout, so letter long-press callouts are disabled.
class DemoCalloutActionProvider: BaseCalloutActionProvider {
    private let keyboardContext: KeyboardContext

    init(keyboardContext: KeyboardContext) {
        self.keyboardContext = keyboardContext
        super.init()
    }

    override func calloutActions(
        for action: KeyboardAction
    ) -> [KeyboardAction] {
        if action == .custom(named: "url_domain") {
            return [".com", ".ua", ".org", ".net", ".edu"].map { .character($0) }
        }
        if keyboardContext.deviceType == .phone,
           !keyboardContext.isKeyboardFloating,
           keyboardContext.interfaceOrientation.isPortrait {
            switch action {
            case .keyboardType(.emojis), .keyboardType(.numeric), .primary, .characterMargin(""):
                return [
                    .custom(named: "one_handed_left"),
                    .custom(named: "one_handed_off"),
                    .custom(named: "one_handed_right")
                ]
            default:
                break
            }
        }
        return super.calloutActions(for: action)
    }

    override func calloutActions(
        for char: String
    ) -> [KeyboardAction] {
        guard let alternatives = Self.alternatives(for: char, keyboardType: keyboardContext.keyboardType) else { return [] }
        return alternatives.map {
            .character(keyboardContext.keyboardType.isAlphabeticCapsLocked ? $0.uppercased() : $0)
        }
    }
}

private extension DemoCalloutActionProvider {

    static func alternatives(for char: String, keyboardType: Keyboard.KeyboardType) -> [String]? {
        switch char {
        case ",":
            return ["."]
        case ".":
            return keyboardType.isAlphabetic ? [","] : [".", "…", ","]
        case "\u{02BC}":
            return ["\u{02BC}", "ъ", "ь"]
        case "$":
            return ["$", "₴", "€", "₺", "£", "¥", "¢"]
        case "₴":
            return ["₴", "$", "€", "₺", "£", "¥", "¢"]
        case "€":
            return ["€", "₴", "$", "₺", "£", "¥", "¢"]
        case "₺":
            return ["₺", "₴", "$", "€", "£", "¥", "¢"]
        case "£":
            return ["£", "₴", "$", "€", "₺", "¥", "¢"]
        case "¥":
            return ["¥", "₴", "$", "€", "₺", "£", "¢"]
        case "-":
            return ["-", "–", "—", "•"]
        case "/":
            return ["/", "\\"]
        case "&":
            return ["&", "§"]
        case "\"":
            return ["\"", "«", "»", "„", "“", "”"]
        case "'":
            return ["'", "\u{02BC}", "‘", "’", "`"]
        case "?":
            return ["?", "¿"]
        case "!":
            return ["!", "¡"]
        case "%":
            return ["%", "‰"]
        case "=":
            return ["=", "≠", "≈", "±"]
        case "+":
            return ["+", "±"]
        case "0":
            return ["0", "°"]
        default:
            return nil
        }
    }
}
