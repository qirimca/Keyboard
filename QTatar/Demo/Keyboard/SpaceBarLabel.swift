//
//  SpaceBarLabel.swift
//  Keyboard
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import SwiftUI
import UIKit

/// Observable space bar controller that coordinates displaying the full localized language name
/// when the user switches to this keyboard, and animating smoothly into the corner abbreviation.
final class SpaceBarState: ObservableObject {
    static let shared = SpaceBarState()

    /// Opening a text field uses the resting abbreviation. Only an observed switch animates.
    @Published var isShowingFullName: Bool = false
    private var dismissTimer: Timer?

    func triggerSwitchAnimation() {
        dismissTimer?.invalidate()
        isShowingFullName = true
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.35)) {
                    self?.isShowingFullName = false
                }
            }
        }
    }

    func resetToResting() {
        dismissTimer?.invalidate()
        isShowingFullName = false
    }
}

/// Native-style space bar label:
/// Displays the full language name ("Qırımtatarca") centered when switching to this keyboard,
/// then smoothly fades into the 2-letter abbreviation ("QT") in the bottom-trailing corner,
/// matching Apple's native keyboard animation.
struct SpaceBarLabel: View {

    let fullName: String
    let languageCode: String
    let spaceText: String
    let isCompact: Bool
    let isClassic: Bool

    @ObservedObject private var spaceBarState = SpaceBarState.shared

    init(
        fullName: String = "Qırımtatarca",
        languageCode: String = "QT",
        spaceText: String = "Boşluq",
        isCompact: Bool = UIDevice.current.userInterfaceIdiom != .pad,
        isClassic: Bool = false
    ) {
        self.fullName = fullName
        self.languageCode = languageCode
        self.spaceText = spaceText
        self.isCompact = isCompact
        self.isClassic = isClassic
    }

    private var centerFontSize: CGFloat {
        isCompact ? 14 : 16
    }

    private var cornerFontSize: CGFloat {
        isCompact ? 11 : 12
    }

    var body: some View {
        ZStack {
            // Centered full localized language name ("Qırımtatarca" / "Къырымтатарджа") matching letter key color
            Text(fullName)
                .font(.system(size: centerFontSize, weight: .regular, design: .default))
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .opacity(spaceBarState.isShowingFullName ? 1 : 0)
                .animation(.easeInOut(duration: 0.35), value: spaceBarState.isShowingFullName)

            if isClassic {
                if isCompact {
                    Text(spaceText)
                        .font(.system(size: centerFontSize, weight: .regular, design: .default))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                        .opacity(spaceBarState.isShowingFullName ? 0 : 1)
                        .animation(.easeInOut(duration: 0.35), value: spaceBarState.isShowingFullName)
                }
            } else {
                // Pinned corner abbreviation ("QT" / "КЪТ") in Liquid Glass mode
                Text(languageCode)
                    .font(.system(size: cornerFontSize, weight: .regular).width(.condensed))
                    .foregroundStyle(Color.secondary.opacity(0.85))
                    .lineLimit(1)
                    .padding(.trailing, isCompact ? 4.5 : 5)
                    .padding(.bottom, isCompact ? 4 : 5.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .opacity(spaceBarState.isShowingFullName ? 0 : 1)
                    .animation(.easeInOut(duration: 0.35), value: spaceBarState.isShowingFullName)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
