//
//  SpaceBarLabel.swift
//  Keyboard
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import SwiftUI

/// Native-style space bar label aligned to the trailing edge.
struct SpaceBarLabel: View {
    
    let title: String
    
    var body: some View {
        HStack {
            Spacer(minLength: 0)
            Text(title)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(Color.primary.opacity(0.32))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.trailing, 7)
                .padding(.bottom, 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
