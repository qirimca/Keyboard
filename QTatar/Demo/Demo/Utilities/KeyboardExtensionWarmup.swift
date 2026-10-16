//
//  KeyboardExtensionWarmup.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import SwiftUI

/// Keeps the keyboard extension process warm without prematurely resigning first responder.
enum KeyboardExtensionWarmup {
    
    static func scheduleIfNeeded(
        isKeyboardEnabled: Bool,
        focus: @escaping (Bool) -> Void
    ) {
        // HomeView focuses the SandboxTextView directly on appear;
        // we must NEVER call resignFirstResponder() after 0.2s because doing so interrupts
        // iOS while the KeyboardExtension XPC connection is launching, causing iOS to fall back
        // to the English system keyboard on the first try.
    }
}
