//
//  Keyboard+ChromeBackground.swift
//  KeyboardKit
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

public extension Keyboard {
    
    /// A native-style keyboard chrome background.
    struct ChromeBackground: View {
        
        public init(isDark: Bool) {
            self.isDark = isDark
        }
        
        private let isDark: Bool
        
        public var body: some View {
            ZStack {
                #if os(iOS)
                ChromeVisualEffect(isDark: isDark)
                #else
                Color.keyboardBackground
                #endif
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        
        private var gradientColors: [Color] {
            if isDark {
                [Color.white.opacity(0.05), Color.clear]
            } else {
                [Color.white.opacity(0.28), Color.black.opacity(0.025)]
            }
        }
    }
}

#if os(iOS)
private struct ChromeVisualEffect: UIViewRepresentable {
    
    let isDark: Bool
    
    func makeUIView(context: Context) -> UIVisualEffectView {
        let view = UIVisualEffectView(effect: blurEffect)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }
    
    func updateUIView(_ view: UIVisualEffectView, context: Context) {
        view.effect = blurEffect
    }
    
    private var blurEffect: UIBlurEffect {
        if #available(iOS 13.0, *) {
            let style: UIBlurEffect.Style = isDark
                ? .systemChromeMaterialDark
                : .systemChromeMaterial
            return UIBlurEffect(style: style)
        }
        return UIBlurEffect(style: isDark ? .dark : .extraLight)
    }
}
#endif
