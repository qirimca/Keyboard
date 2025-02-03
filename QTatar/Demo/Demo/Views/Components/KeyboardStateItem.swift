//
//  KeyboardStateItem.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 17.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

enum KeyboardState {
    case active(Bool)
    case enable(Bool)
    case fullAccess(Bool)
    
    var title: String {
        switch self {
        case .active(let value):
            return value ? Home.home_keyboard_visible_key.localized : Home.home_keyboard_hidden_key.localized
        case .enable(let value):
            return value ? Home.home_keyboard_on_key.localized : Home.home_keyboard_off_key.localized
        case .fullAccess(let value):
            return value ? Home.home_full_on_key.localized : Home.home_full_off_key.localized
        }
    }
    
    var state: Bool {
        switch self {
        case .active(let value):
            return value
        case .enable(let value):
            return value
        case .fullAccess(let value):
            return value
        }
    }
    
    var stateSymbol: String {
        state ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
}

struct KeyboardStateItem: View {
    let state: KeyboardState
    var action: () -> Void
    
    var body: some View {
        Button {
            withAnimation {
                HapticFeedback.playSelection()
                action()
            }
        } label: {
            HStack {
                Image(systemName: state.stateSymbol)
                    .imageScale(Device.iPhone ? .medium : .large)
                    .foregroundStyle(Color.black, state.state ? Color.crayola : Color.coral)
                
                Text(state.title)
                    .mediumText()
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 2)
            }
        }.disabled(state.state)
    }
}
