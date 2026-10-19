//
//  Autocomplete+NativeToolbarStyle.swift
//  Keyboard
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import KeyboardKit
import SwiftUI

/// A native-style autocomplete toolbar that always renders 3 equal-width slots separated
/// by 2 vertical dividers (matching native iOS/iPadOS predictive bars) and makes each entire
/// slot a solid hit-target.
struct NativeAutocompleteToolbar: View {
    
    @ObservedObject var autocompleteContext: AutocompleteContext
    let keyboardContext: KeyboardContext
    let autocompleteAction: (Autocomplete.Suggestion) -> Void
    
    private var isFloating: Bool {
        keyboardContext.isKeyboardFloating
    }
    
    private var isDockedPad: Bool {
        keyboardContext.deviceType == .pad && !isFloating
    }
    
    private var height: CGFloat {
        isFloating ? 42 : (isDockedPad ? 37 : 42)
    }
    
    var body: some View {
        let suggestions = Array(autocompleteContext.suggestions.prefix(3))
        let slotCount = 3
        
        GeometryReader { geo in
            let totalWidth = max(geo.size.width, 1)
            let sideInset: CGFloat = isDockedPad ? round(totalWidth * 0.17) : 0
            let centerWidth = max(totalWidth - (sideInset * 2), 1)
            let slotWidth = max((centerWidth - 1.0) / CGFloat(slotCount), 1)
            
            HStack(spacing: 0) {
                if sideInset > 0 {
                    Color.clear
                        .frame(width: sideInset, height: height)
                }
                
                ForEach(0..<slotCount, id: \.self) { index in
                    let suggestion: Autocomplete.Suggestion? = index < suggestions.count ? suggestions[index] : nil
                    
                    ZStack {
                        // Non-zero alpha fill ensures the entire slot rectangle is a solid hit-target
                        Color.black.opacity(0.0001)
                        
                        if let suggestion {
                            Text(suggestion.isUnknown ? "“\(suggestion.title)”" : suggestion.title)
                                .font(isFloating ? .subheadline : .system(size: 16, weight: suggestion.isAutocorrect ? .semibold : .regular))
                                .foregroundStyle(Color.primary)
                                .lineLimit(1)
                                .padding(.horizontal, isFloating ? 6 : 12)
                                .padding(.vertical, isFloating ? 3 : 5)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(suggestion.isAutocorrect ? Color.primary.opacity(0.12) : Color.clear)
                                )
                        }
                    }
                    .frame(width: slotWidth, height: height)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let suggestion {
                            autocompleteAction(suggestion)
                        }
                    }
                    
                    if index < slotCount - 1 {
                        Color.secondary.opacity(0.28)
                            .frame(width: 0.5, height: isFloating ? 16 : 24)
                    }
                }
                
                if sideInset > 0 {
                    Color.clear
                        .frame(width: sideInset, height: height)
                }
            }
            .frame(width: totalWidth, height: height)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
    }
}

extension Autocomplete.ToolbarStyle {
    
    static var nativeClean: Autocomplete.ToolbarStyle {
        .init(
            height: 42,
            item: .init(
                titleFont: .system(size: 16),
                titleColor: .primary,
                subtitleFont: .footnote,
                subtitleColor: .secondary
            ),
            separator: .init(
                color: Color.secondary.opacity(0.25),
                width: 0.5,
                height: 22
            )
        )
    }
}
