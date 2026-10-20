//
//  SpaceBarLabel.swift
//  Keyboard
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import SwiftUI
import UIKit

/// Observable space bar controller that coordinates displaying the full localized language name
/// when the keyboard appears or switches script, then smoothly fading into the center Taraq Tamğa
/// and bottom-trailing 2-letter language code ("QT" / "КЪ").
final class SpaceBarState: ObservableObject {
    static let shared = SpaceBarState()

    @Published var isShowingFullName: Bool = true
    private var dismissTimer: Timer?

    func prepareForAppearance() {
        dismissTimer?.invalidate()
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isShowingFullName = true
        }
    }

    func triggerSwitchAnimation() {
        dismissTimer?.invalidate()
        isShowingFullName = true
        let timer = Timer(timeInterval: 1.3, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.4)) {
                    self?.isShowingFullName = false
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        dismissTimer = timer
    }

    func fadeToResting() {
        guard isShowingFullName else { return }
        dismissTimer?.invalidate()
        withAnimation(.easeInOut(duration: 0.35)) {
            isShowingFullName = false
        }
    }
}

/// Traditional Crimean Tatar Taraq Tamğa outline shape matching the QırımKey app icon.
struct TaraqTamgaShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var path = Path()

        // Top horizontal beam with left and right upward prongs
        path.move(to: CGPoint(x: 0.08 * w, y: 0.06 * h))
        path.addLine(to: CGPoint(x: 0.08 * w, y: 0.27 * h))
        path.addLine(to: CGPoint(x: 0.92 * w, y: 0.27 * h))
        path.addLine(to: CGPoint(x: 0.92 * w, y: 0.06 * h))

        // Center vertical pillar from top prong to bottom base
        path.move(to: CGPoint(x: 0.50 * w, y: 0.06 * h))
        path.addLine(to: CGPoint(x: 0.50 * w, y: 0.93 * h))

        // Bottom horizontal base of center pillar
        path.move(to: CGPoint(x: 0.35 * w, y: 0.93 * h))
        path.addLine(to: CGPoint(x: 0.65 * w, y: 0.93 * h))

        // Left downward leg with outward bottom hook
        path.move(to: CGPoint(x: 0.22 * w, y: 0.27 * h))
        path.addLine(to: CGPoint(x: 0.22 * w, y: 0.72 * h))
        path.addLine(to: CGPoint(x: 0.05 * w, y: 0.72 * h))

        // Right downward leg with outward bottom hook
        path.move(to: CGPoint(x: 0.78 * w, y: 0.27 * h))
        path.addLine(to: CGPoint(x: 0.78 * w, y: 0.72 * h))
        path.addLine(to: CGPoint(x: 0.95 * w, y: 0.72 * h))

        return path
    }
}

/// Native-style space bar label:
/// Displays the full language name ("Qırımtatarca" / "Къырымтатарджа") centered when the keyboard appears
/// or switches script, then smoothly fades into the centered Taraq Tamğa emblem and the 2-letter
/// abbreviation ("QT" / "КЪ") in the bottom-trailing corner.
struct SpaceBarLabel: View {

    let fullName: String
    let languageCode: String
    let isCompact: Bool

    @ObservedObject private var spaceBarState = SpaceBarState.shared

    init(
        fullName: String = "Qırımtatarca",
        languageCode: String = "QT",
        isCompact: Bool = UIDevice.current.userInterfaceIdiom != .pad
    ) {
        self.fullName = fullName
        self.languageCode = languageCode
        self.isCompact = isCompact
    }

    private var centerFontSize: CGFloat {
        isCompact ? 14 : 16
    }

    private var cornerFontSize: CGFloat {
        isCompact ? 10.5 : 11.5
    }

    var body: some View {
        ZStack {
            // Centered full localized language name when appearing / switching script
            Text(fullName)
                .font(.system(size: centerFontSize, weight: .regular, design: .default))
                .foregroundStyle(Color.primary.opacity(0.65))
                .lineLimit(1)
                .opacity(spaceBarState.isShowingFullName ? 1 : 0)

            // Centered subtle Taraq Tamğa outline in resting state
            TaraqTamgaShape()
                .stroke(
                    Color.primary.opacity(0.28),
                    style: StrokeStyle(
                        lineWidth: isCompact ? 1.25 : 1.35,
                        lineCap: .round,
                        lineJoin: .round
                    )
                )
                .frame(width: isCompact ? 15 : 17, height: isCompact ? 12.5 : 14)
                .opacity(spaceBarState.isShowingFullName ? 0 : 1)

            // Pinned bottom-trailing 2-letter code ("QT" / "КЪ") in resting state
            Text(languageCode)
                .font(.system(size: cornerFontSize, weight: .regular).width(.condensed))
                .foregroundStyle(Color.secondary.opacity(0.85))
                .lineLimit(1)
                .padding(.trailing, isCompact ? 4.5 : 5.5)
                .padding(.bottom, isCompact ? 3.5 : 5.0)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .opacity(spaceBarState.isShowingFullName ? 0 : 1)
        }
        .animation(.easeInOut(duration: 0.4), value: spaceBarState.isShowingFullName)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
