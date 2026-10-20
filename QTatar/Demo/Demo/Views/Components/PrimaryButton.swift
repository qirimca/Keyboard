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
                .background(Color(red: 0.0, green: 0.53, blue: 0.86), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color(red: 0.0, green: 0.53, blue: 0.86).opacity(0.25), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}
