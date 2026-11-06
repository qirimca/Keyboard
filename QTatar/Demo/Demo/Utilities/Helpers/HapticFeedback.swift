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
    private static let sharedSelectionGenerator = UISelectionFeedbackGenerator()
    private static let isUITesting: Bool = {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-UITesting")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || args.contains(where: { $0.hasPrefix("-qt_") || $0.hasPrefix("-ui_testing") })
    }()
    static func playSelection() {
        guard UIDevice.current.userInterfaceIdiom == .phone,
              !isUITesting else { return }
        sharedSelectionGenerator.selectionChanged()
    }
#else
    static func playSelection() {
        // No-op
    }
#endif
}
