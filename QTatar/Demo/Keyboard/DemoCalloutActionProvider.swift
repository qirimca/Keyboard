//
//  DemoCalloutActionProvider.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import KeyboardKit

/// Long-press pairs for the official Crimean Tatar Latin alphabet.
class DemoCalloutActionProvider: BaseCalloutActionProvider {
    
    override func calloutActions(
        for char: String
    ) -> [KeyboardAction] {
        guard let alternatives = Self.alternatives(for: char) else { return [] }
        return alternatives.map { .character($0) }
    }
}

private extension DemoCalloutActionProvider {
    
    /// Only official Crimean Tatar letter pairs — no extra diacritics.
    static func alternatives(for char: String) -> [String]? {
        switch char {
        case "c": return ["c", "ç"]
        case "C": return ["C", "Ç"]
        case "ç": return ["ç", "c"]
        case "Ç": return ["Ç", "C"]
        case "g": return ["g", "ğ"]
        case "G": return ["G", "Ğ"]
        case "ğ": return ["ğ", "g"]
        case "Ğ": return ["Ğ", "G"]
        case "ı": return ["ı", "I"]
        case "I": return ["I", "ı"]
        case "i": return ["i", "İ"]
        case "İ": return ["İ", "i"]
        case "n": return ["n", "ñ"]
        case "N": return ["N", "Ñ"]
        case "ñ": return ["ñ", "n"]
        case "Ñ": return ["Ñ", "N"]
        case "o": return ["o", "ö"]
        case "O": return ["O", "Ö"]
        case "ö": return ["ö", "o"]
        case "Ö": return ["Ö", "O"]
        case "s": return ["s", "ş"]
        case "S": return ["S", "Ş"]
        case "ş": return ["ş", "s"]
        case "Ş": return ["Ş", "S"]
        case "u": return ["u", "ü"]
        case "U": return ["U", "Ü"]
        case "ü": return ["ü", "u"]
        case "Ü": return ["Ü", "U"]
        default: return nil
        }
    }
}
