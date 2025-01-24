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
            return (value ? TextConst.keyboardVisible : .keyboardHidden).rawValue
        case .enable(let value):
            return (value ? TextConst.keyboardOn : .keyboardOff).rawValue
        case .fullAccess(let value):
            return (value ? TextConst.fullAccessOn : .fullAccessOff).rawValue
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
        state ? "checkmark.circle.fill" : "circle"
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
                    .foregroundStyle(state.state ? Color.crayola : Color.black)
                
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
