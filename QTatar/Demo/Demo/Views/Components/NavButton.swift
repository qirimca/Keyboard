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
    
    private let size: CGFloat = 34
    
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
                        .strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
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

