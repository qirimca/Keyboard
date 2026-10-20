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

    var allLocalizedTitles: [String] {
        switch self {
        case .active(let value):
            return (value ? Home.home_keyboard_visible_key : Home.home_keyboard_hidden_key).allLocalizedVersions
        case .enable(let value):
            return (value ? Home.home_keyboard_on_key : Home.home_keyboard_off_key).allLocalizedVersions
        case .fullAccess(let value):
            return (value ? Home.home_full_on_key : Home.home_full_off_key).allLocalizedVersions
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
        switch self {
        case .active: return state ? "keyboard.fill" : "keyboard"
        case .enable: return state ? "checkmark.circle.fill" : "xmark.circle.fill"
        case .fullAccess: return state ? "lock.open.fill" : "lock.fill"
        }
    }
}

struct KeyboardStateIndicatorsRow: View {
    let states: [KeyboardState]
    var action: () -> Void
    
    private let rowHeight: CGFloat = Device.iPad ? 60 : 52
    private let spacing: CGFloat = Device.iPad ? 12 : 8
    private let baseFontSize: CGFloat = Device.iPad ? 15 : 12.5
    private let iconWidth: CGFloat = Device.iPad ? 32 : 26
    private let horizontalPadding: CGFloat = Device.iPad ? 12 : 8
    private let verticalPadding: CGFloat = Device.iPad ? 8 : 6
    private let maxLines = 2
    
    var body: some View {
        GeometryReader { geometry in
            let titles = states.flatMap(\.allLocalizedTitles)
            let cellWidth = max((geometry.size.width - spacing * 2) / 3, 1)
            let textWidth = max(cellWidth - iconWidth - horizontalPadding * 2 - 8, 1)
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
    var titleFontSize: CGFloat = Device.iPad ? 15 : 12.5
    var action: () -> Void
    
    private var tintColor: Color {
        state.state
            ? Color(red: 0.18, green: 0.72, blue: 0.34)
            : Color(red: 0.95, green: 0.55, blue: 0.15)
    }
    
    var body: some View {
        Button {
            withAnimation {
                HapticFeedback.playSelection()
                action()
            }
        } label: {
            HStack(spacing: Device.iPad ? 10 : 6) {
                ZStack {
                    Circle()
                        .fill(tintColor.opacity(0.14))
                        .frame(width: Device.iPad ? 32 : 26, height: Device.iPad ? 32 : 26)
                    Image(systemName: state.stateSymbol)
                        .font(.system(size: Device.iPad ? 15 : 13, weight: .semibold))
                        .foregroundStyle(tintColor)
                }
                
                Text(state.title)
                    .font(InterfaceFont.font("GeneralSans-Medium", size: titleFontSize, text: state.title))
                    .foregroundStyle(Color(.label))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Device.iPad ? 12 : 8)
            .padding(.vertical, Device.iPad ? 8 : 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!state.state)
    }
}
