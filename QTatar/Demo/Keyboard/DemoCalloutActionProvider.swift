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
        if action == .dismissKeyboard,
           keyboardContext.deviceType == .pad,
           !keyboardContext.isKeyboardFloating {
            if keyboardContext.deviceSupportsSplitKeyboard {
                let splitOrMerge = keyboardContext.isKeyboardSplit ? "merge_keyboard" : "split_keyboard"
                return [
                    .custom(named: "floating_keyboard"),
                    .custom(named: splitOrMerge)
                ]
            }
            return [
                .custom(named: "floating_keyboard")
            ]
        }
        return super.calloutActions(for: action)
    }

    override func calloutActions(
        for char: String
    ) -> [KeyboardAction] {
        guard let alternatives = Self.alternatives(for: char) else { return [] }
        return alternatives.map {
            .character(keyboardContext.keyboardType.isAlphabeticCapsLocked ? $0.uppercased() : $0)
        }
    }
}

private extension DemoCalloutActionProvider {

    static func alternatives(for char: String) -> [String]? {
        switch char {
        case ",": return ["."]
        case ".": return [","]
        default: return nil
        }
    }
}
