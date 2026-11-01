//
//  PrimaryButton.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 18.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

struct PrimaryButton: View {
    var text: String
    var background: Color
    var action: () -> Void
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    private var buttonColor: Color {
        colorSchemeContrast == .increased
            ? Color(red: 0.0, green: 0.42, blue: 0.72)
            : Color(red: 0.0, green: 0.53, blue: 0.86)
    }
    
    var body: some View {
        Button {
            withAnimation {
                HapticFeedback.playSelection()
                action()
            }
        } label: {
            Text(text)
                .font(InterfaceFont.font("GeneralSans-Semibold", size: Device.iPad ? 17 : 15, text: text))
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .background(buttonColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    if colorSchemeContrast == .increased {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    }
                }
                .shadow(color: buttonColor.opacity(0.25), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(text)
    }
}
