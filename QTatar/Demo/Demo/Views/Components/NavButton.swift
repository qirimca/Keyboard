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
    
    private let size: CGFloat = 36
    
    var body: some View {
        Button {
            HapticFeedback.playSelection()
            action()
        } label: {
            Image(systemName: symbol)
                .imageScale(.medium)
                .foregroundStyle(.black)
                .frame(width: size, height: size)
                .overlay {
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                }
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

