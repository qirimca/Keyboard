//
//  SpaceBarLabel.swift
//  Keyboard
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import SwiftUI
import UIKit

/// Native-style space bar label:
/// Displays the full language name ("Qırımtatarca") centered on appear in primary letter color,
/// then smoothly fades out while the 2-letter abbreviation ("QT") fades into the bottom-trailing corner,
/// mimicking the exact Apple iOS native keyboard animation.
struct SpaceBarLabel: View {
    
    let fullName: String
    let languageCode: String
    
    @State private var isShowingFullName: Bool = true
    
    init(fullName: String = "Qırımtatarca", languageCode: String = "QT") {
        self.fullName = fullName
        self.languageCode = languageCode
    }
    
    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    
    private var centerFontSize: CGFloat {
        isPad ? 16 : 14
    }
    
    private var cornerFontSize: CGFloat {
        isPad ? 12 : 11
    }
    
    var body: some View {
        ZStack {
            // Centered full localized language name ("Qırımtatarca") matching letter key color
            Text(fullName)
                .font(.system(size: centerFontSize, weight: .regular, design: .default))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .opacity(isShowingFullName ? 1 : 0)
                .animation(.easeInOut(duration: 0.35), value: isShowingFullName)
            
            // Pinned corner abbreviation ("QT")
            Text(languageCode)
                .font(.system(size: cornerFontSize, weight: .regular, design: .default))
                .foregroundStyle(Color.secondary.opacity(0.85))
                .lineLimit(1)
                .padding(.trailing, 8)
                .padding(.bottom, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .opacity(isShowingFullName ? 0 : 1)
                .animation(.easeInOut(duration: 0.35), value: isShowingFullName)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            isShowingFullName = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    isShowingFullName = false
                }
            }
        }
    }
}
