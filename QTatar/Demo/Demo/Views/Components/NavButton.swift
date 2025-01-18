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
    
    var body: some View {
        Button {
            withAnimation {
                HapticFeedback.playSelection()
                action()
            }
        } label: {
            Image(systemName: symbol)
                .imageScale(.medium)
                .foregroundStyle(.black)
                .padding()
                .overlay {
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 36)
                }
        }
    }
}

