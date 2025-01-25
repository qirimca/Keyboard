//
//  HapticFeedback.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 18.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

class HapticFeedback {
#if os(iOS)
    // iOS implementation
    let selectionFeedbackGenerator = UISelectionFeedbackGenerator()
    static func playSelection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
#else
    static func playSelection() {
        // No-op
    }
#endif
}
