//
//  Autocomplete+NativeToolbarStyle.swift
//  Keyboard
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import KeyboardKit
import SwiftUI

extension Autocomplete.ToolbarStyle {
    
    static func native(for context: KeyboardContext) -> Self {
        let isFloating = context.isKeyboardFloating
        let height: CGFloat = isFloating ? 34 : (context.deviceType == .pad ? 44 : 42)
        return Self(
            height: height,
            item: .init(
                titleFont: isFloating ? .subheadline : .system(size: 16, weight: .regular),
                titleColor: .primary,
                horizontalPadding: isFloating ? 4 : 10,
                verticalPadding: isFloating ? 2 : 6,
                backgroundColor: .clear
            ),
            autocorrectItem: .init(
                titleFont: isFloating ? .subheadline : .system(size: 16, weight: .regular),
                titleColor: .primary,
                horizontalPadding: isFloating ? 4 : 12,
                verticalPadding: isFloating ? 2 : 6,
                backgroundColor: Color.primary.opacity(0.10),
                backgroundCornerRadius: 6
            ),
            separator: .init(
                color: Color.secondary.opacity(0.25),
                width: 0.5,
                height: isFloating ? 16 : 20
            )
        )
    }
    
    static var native: Self {
        Self(
            height: 42,
            item: .init(
                titleFont: .system(size: 16, weight: .regular),
                titleColor: .primary,
                horizontalPadding: 10,
                verticalPadding: 6,
                backgroundColor: .clear
            ),
            autocorrectItem: .init(
                titleFont: .system(size: 16, weight: .regular),
                titleColor: .primary,
                horizontalPadding: 12,
                verticalPadding: 6,
                backgroundColor: Color.primary.opacity(0.10),
                backgroundCornerRadius: 6
            ),
            separator: .init(
                color: Color.secondary.opacity(0.25),
                width: 0.5,
                height: 20
            )
        )
    }
}
