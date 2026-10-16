//
//  DemoCalloutActionProvider.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import KeyboardKit

/// Long-press pairs for the official Crimean Tatar Latin alphabet.
/// Returns only the specific additional letter (no redundant original letter).
/// Letters that have dedicated physical keys on the keyboard (â, ñ, ç, ş, ğ, ö, ü, ı, i)
/// have no long-press callout.
class DemoCalloutActionProvider: BaseCalloutActionProvider {
    
    override func calloutActions(
        for char: String
    ) -> [KeyboardAction] {
        guard let alternatives = Self.alternatives(for: char) else { return [] }
        return alternatives.map { .character($0) }
    }
}

private extension DemoCalloutActionProvider {
    
    /// Proposes only the single additional letter.
    static func alternatives(for char: String) -> [String]? {
        switch char {
        case "г": return ["гъ"]
        case "Г": return ["Гъ"]
        case "к": return ["къ"]
        case "К": return ["Къ"]
        case "н": return ["нъ"]
        case "Н": return ["Нъ"]
        case "д": return ["дж"]
        case "Д": return ["Дж"]
        case "е": return ["ё"]
        case "Е": return ["Ё"]
        case "a": return ["â"]
        case "A": return ["Â"]
        case "c": return ["ç"]
        case "C": return ["Ç"]
        case "g": return ["ğ"]
        case "G": return ["Ğ"]
        case "n": return ["ñ"]
        case "N": return ["Ñ"]
        case "o": return ["ö"]
        case "O": return ["Ö"]
        case "s": return ["ş"]
        case "S": return ["Ş"]
        case "u": return ["ü"]
        case "U": return ["Ü"]
        case ",": return ["."]
        case ".": return [","]
        // All letters with dedicated keys (â, ñ, ç, ş, ğ, ö, ü, ı, i) have no long press
        default: return nil
        }
    }
}
