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
    var background: Color = .backgroundLight
    var action: () -> Void
    
    var body: some View {
        Button {
            withAnimation {
                HapticFeedback.playSelection()
                action()
            }
        } label: {
            Text(text)
                .mediumText()
                .padding(.vertical)
                .frame(maxWidth: .infinity)
                .background(Color.crayola)
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.black, lineWidth: 2)
                }
        }
    }
}
