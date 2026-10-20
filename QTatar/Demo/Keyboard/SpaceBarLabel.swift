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
        if !isShowingFullName {
            isShowingFullName = true
        }
        let timer = Timer(timeInterval: 1.8, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.isShowingFullName else { return }
                withAnimation(.easeInOut(duration: 0.2)) {
                    self.isShowingFullName = false
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

/// Traditional Crimean Tatar Taraq Tamğa filled polygon matching the exact 9×5 grid geometry of `qirimlogo.png`.
struct TaraqTamgaShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / 9.0, rect.height / 5.0)
        let drawWidth = scale * 9.0
        let drawHeight = scale * 5.0
        let originX = rect.minX + (rect.width - drawWidth) * 0.5
        let originY = rect.minY + (rect.height - drawHeight) * 0.5
        let cornerRadius = scale * 0.045

        func pt(_ gx: CGFloat, _ gy: CGFloat) -> CGPoint {
            CGPoint(x: originX + gx * scale, y: originY + gy * scale)
        }

        let vertices: [CGPoint] = [
            pt(1, 0), pt(8, 0),
            pt(8, 3), pt(9, 3),
            pt(9, 4), pt(7, 4),
            pt(7, 1), pt(5, 1),
            pt(5, 4), pt(6, 4),
            pt(6, 5), pt(3, 5),
            pt(3, 4), pt(4, 4),
            pt(4, 1), pt(2, 1),
            pt(2, 4), pt(0, 4),
            pt(0, 3), pt(1, 3)
        ]

        var path = Path()
        let count = vertices.count
        let startMid = CGPoint(
            x: (vertices[count - 1].x + vertices[0].x) * 0.5,
            y: (vertices[count - 1].y + vertices[0].y) * 0.5
        )
        path.move(to: startMid)
        for i in 0..<count {
            let current = vertices[i]
            let next = vertices[(i + 1) % count]
            path.addArc(tangent1End: current, tangent2End: next, radius: cornerRadius)
        }
        path.closeSubpath()
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

            // Centered Taraq Tamğa emblem in resting state (exact 9:5 aspect ratio from app icon)
            TaraqTamgaShape()
                .fill(Color.primary.opacity(0.30))
                .frame(width: isCompact ? 19.8 : 23.4, height: isCompact ? 11.0 : 13.0)
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
