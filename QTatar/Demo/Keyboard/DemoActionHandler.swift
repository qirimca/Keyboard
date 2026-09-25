//
//  DemoActionHandler.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import UIKit

/**
 Action handler that performs standard keyboard actions and autocomplete triggers.
 */
class DemoActionHandler: StandardKeyboardActionHandler {

    override func handle(
        _ gesture: Gestures.KeyboardGesture,
        on action: KeyboardAction,
        replaced: Bool = false
    ) {
        super.handle(gesture, on: action, replaced: replaced)
        
        guard gesture == .release else { return }
        if action.isInputAction || action.isShiftAction || action == .capsLock {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.keyboardController?.performAutocomplete()
            }
        }
    }
}
