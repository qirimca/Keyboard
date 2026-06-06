//
//  KeyboardExtensionWarmup.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import SwiftUI

/// Triggers a one-time keyboard extension launch to pay the cold-start cost early.
enum KeyboardExtensionWarmup {
    
    private static let storageKey = "crh.key.didWarmKeyboardExtension"
    
    static var didWarm: Bool {
        UserDefaults.standard.bool(forKey: storageKey)
    }
    
    static func markWarm() {
        UserDefaults.standard.set(true, forKey: storageKey)
    }
    
    /// Briefly focuses the writing field once so iOS loads the keyboard extension.
    static func scheduleIfNeeded(
        isKeyboardEnabled: Bool,
        focus: @escaping (Bool) -> Void
    ) {
        guard !didWarm, isKeyboardEnabled else { return }
        markWarm()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            focus(true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                focus(false)
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        }
    }
}
