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

struct KeyboardStateIndicatorsRow: View {
    let states: [KeyboardState]
    var action: () -> Void
    
    private let rowHeight: CGFloat = Device.iPad ? 72 : 60
    private let spacing: CGFloat = Device.iPad ? 12 : 8
    private let baseFontSize: CGFloat = Device.iPad ? 20 : 14
    private let iconWidth: CGFloat = Device.iPad ? 28 : 22
    private let horizontalPadding: CGFloat = Device.iPad ? 10 : 8
    private let verticalPadding: CGFloat = Device.iPad ? 10 : 8
    private let maxLines = 2
    
    var body: some View {
        GeometryReader { geometry in
            let titles = states.map(\.title)
            let cellWidth = max((geometry.size.width - spacing * 2) / 3, 1)
            let textWidth = max(cellWidth - iconWidth - horizontalPadding * 2, 1)
            let textHeight = max(rowHeight - verticalPadding * 2, 1)
            let fontSize = String.uniformFontSize(
                for: titles,
                maxTextWidth: textWidth,
                maxTextHeight: textHeight,
                baseSize: baseFontSize,
                maxLines: maxLines
            )
            
            HStack(spacing: spacing) {
                ForEach(Array(states.enumerated()), id: \.offset) { _, state in
                    KeyboardStateItem(
                        state: state,
                        titleFontSize: fontSize,
                        action: action
                    )
                }
            }
        }
        .frame(height: rowHeight)
        .layoutPriority(2)
    }
}

struct KeyboardStateItem: View {
    let state: KeyboardState
    var titleFontSize: CGFloat = Device.iPad ? 20 : 13
    var action: () -> Void
    
    var body: some View {
        Button {
            withAnimation {
                HapticFeedback.playSelection()
                action()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: state.stateSymbol)
                    .font(.system(size: Device.iPad ? 22 : 18, weight: .semibold))
                    .foregroundStyle(Color.black, state.state ? Color.crayola : Color.coral)
                    .frame(width: Device.iPad ? 28 : 22)
                
                Text(state.title)
                    .font(.custom("GeneralSans-Medium", size: titleFontSize))
                    .foregroundStyle(.black)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Device.iPad ? 10 : 8)
            .padding(.vertical, Device.iPad ? 10 : 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.backgroundLight)
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.black, lineWidth: 2)
            }
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!state.state)
    }
}
