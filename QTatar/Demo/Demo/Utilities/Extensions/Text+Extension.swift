//
//  Text+Extension.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 17.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

typealias TextFonts = Text

private let globeEmojiSymbol = "🌐"

extension TextFonts {
    
    /// Renders localized copy with GeneralSans while replacing 🌐 with the system globe icon.
    static func customFontText(
        _ string: String,
        fontName: String,
        size: CGFloat,
        color: Color = .black
    ) -> Text {
        let fontSize = Device.iPad ? size + 4 : size
        let segments = string.components(separatedBy: globeEmojiSymbol)
        
        guard segments.count > 1 else {
            return Text(string)
                .font(.custom(fontName, size: fontSize))
                .foregroundStyle(color)
        }
        
        var text = Text(segments[0])
            .font(.custom(fontName, size: fontSize))
            .foregroundStyle(color)
        
        for segment in segments.dropFirst() {
            text = text
                + Text(Image(systemName: "globe"))
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(color)
                + Text(segment)
                    .font(.custom(fontName, size: fontSize))
                    .foregroundStyle(color)
        }
        
        return text
    }
    
    func titleText(size: CGFloat = 18) -> some View {
        return self
            .font(.custom("GeneralSans-Semibold", size: Device.iPad ? size + 4 : size))
            .foregroundStyle(.black)
    }
    
    func mediumText(size: CGFloat = 16, color: Color = .black) -> some View {
        return self
            .font(.custom("GeneralSans-Medium", size: Device.iPad ? size + 4 : size))
            .foregroundStyle(color)
    }
    
    func regularText(size: CGFloat = 12, color: Color = .black) -> some View {
        return self
            .font(.custom("GeneralSans-Regular", size: Device.iPad ? size + 4 : size))
            .foregroundStyle(color)
    }
}
