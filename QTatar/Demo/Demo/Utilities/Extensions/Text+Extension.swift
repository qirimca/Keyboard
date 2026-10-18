//
//  Text+Extension.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 17.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI
import UIKit


/// Keep rendering and measurement on the same font when GeneralSans lacks the script.
enum InterfaceFont {
    static func usesSystem(for text: String = "") -> Bool {
        KeyboardPreferences.interfaceLanguage == "uk"
            || text.unicodeScalars.contains { (0x0400...0x04FF).contains($0.value) }
    }

    static func uiFont(_ name: String, size: CGFloat, text: String = "") -> UIFont {
        let weight: UIFont.Weight = name.contains("Semibold") ? .semibold : name.contains("Medium") ? .medium : .regular
        if usesSystem(for: text) { return .systemFont(ofSize: size, weight: weight) }
        return UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    static func font(_ name: String, size: CGFloat, text: String = "") -> Font {
        Font(uiFont(name, size: size, text: text))
    }
}

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
                .font(InterfaceFont.font(fontName, size: fontSize, text: string))
                .foregroundStyle(color)
        }
        
        var text = Text(segments[0])
            .font(InterfaceFont.font(fontName, size: fontSize, text: string))
            .foregroundStyle(color)
        
        for segment in segments.dropFirst() {
            text = text
                + Text(Image(systemName: "globe"))
                    .font(.system(size: fontSize, weight: .medium))
                    .foregroundStyle(color)
                + Text(segment)
                    .font(InterfaceFont.font(fontName, size: fontSize, text: string))
                    .foregroundStyle(color)
        }
        
        return text
    }
    
    func titleText(size: CGFloat = 18) -> some View {
        return self
            .font(InterfaceFont.font("GeneralSans-Semibold", size: Device.iPad ? size + 4 : size))
            .foregroundStyle(.black)
    }
    
    func mediumText(size: CGFloat = 16, color: Color = .black) -> some View {
        return self
            .font(InterfaceFont.font("GeneralSans-Medium", size: Device.iPad ? size + 4 : size))
            .foregroundStyle(color)
    }
    
    func regularText(size: CGFloat = 12, color: Color = .black) -> some View {
        return self
            .font(InterfaceFont.font("GeneralSans-Regular", size: Device.iPad ? size + 4 : size))
            .foregroundStyle(color)
    }
}
