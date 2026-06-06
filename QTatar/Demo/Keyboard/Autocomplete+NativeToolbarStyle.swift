//
//  Autocomplete+NativeToolbarStyle.swift
//  Keyboard
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import KeyboardKit
import SwiftUI

extension Autocomplete.ToolbarStyle {
    
    static let native = Self(
        height: 44,
        item: .init(
            titleFont: .body,
            titleColor: .primary,
            horizontalPadding: 6,
            verticalPadding: 9,
            backgroundColor: .clear
        ),
        autocorrectItem: .init(
            titleFont: .body,
            titleColor: .primary,
            horizontalPadding: 6,
            verticalPadding: 9,
            backgroundColor: Color(uiColor: .systemBackground).opacity(0.72),
            backgroundCornerRadius: 5
        ),
        separator: .init(
            color: .secondary.opacity(0.35),
            width: 1,
            height: 22
        )
    )
}
