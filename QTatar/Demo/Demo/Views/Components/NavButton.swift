//
//  NavButton.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 18.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

struct NavButton: View {
    var symbol: String
    var action: () -> Void
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    private let size: CGFloat = 34
    
    private var defaultAccessibilityLabel: String {
        switch symbol {
        case "chevron.backward", "chevron.left":
            return Onboarding.onb_back_key.localized
        case "questionmark":
            return Onboarding.onb_settings_key.localized
        case "info", "info.circle":
            return About.about_title_key.localized
        default:
            return symbol
        }
    }
    
    var body: some View {
        Button {
            withAnimation {
                HapticFeedback.playSelection()
                action()
            }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color(.label))
                .frame(width: size, height: size)
                .background(Color(.secondarySystemGroupedBackground), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(
                            Color.primary.opacity(colorSchemeContrast == .increased ? 0.28 : 0.10),
                            lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                        )
                }
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(defaultAccessibilityLabel)
    }
}

/// Toolbar wrapper that keeps NavButton circular on iOS 26+ toolbars.
struct NavToolbarItem: ToolbarContent {
    var placement: ToolbarItemPlacement
    var symbol: String
    var action: () -> Void
    
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: placement) {
                NavButton(symbol: symbol, action: action)
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement) {
                NavButton(symbol: symbol, action: action)
            }
        }
    }
}

