//
//  SpaceBarLabel.swift
//  Keyboard
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import Combine
import SwiftUI
import UIKit

/// Observable space bar controller that coordinates displaying the full localized language name
/// when the keyboard appears or switches script, then smoothly fading into the center Taraq Tamğa
/// and bottom-trailing 2-letter language code ("QT" / "КЪ").
/// Also drives the "soul" of QırımKey: a continuous resting breath on the Tamğa that smoothly
/// accelerates as the user types characters and gently decelerates back to rest when typing stops.
final class SpaceBarState: ObservableObject {
    static let shared = SpaceBarState()

    @Published var isShowingFullName: Bool = true
    let keystrokeSubject = PassthroughSubject<Void, Never>()

    private var dismissTimer: Timer?

    func prepareForAppearance() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isShowingFullName = true
        }
        scheduleCollapseTimer()
    }

    func triggerSwitchAnimation() {
        if !isShowingFullName {
            isShowingFullName = true
        }
        scheduleCollapseTimer()
    }

    private func scheduleCollapseTimer() {
        dismissTimer?.invalidate()
        let timer = Timer(timeInterval: 1.5, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                guard let self, self.isShowingFullName else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
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

    /// Records a character keystroke so the spacebar Tamğa smoothly quickens its breathing rate.
    func recordKeystroke() {
        keystrokeSubject.send(())
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

/// CoreAnimation-driven Taraq Tamğa view that breathes continuously at rest and smoothly accelerates/decelerates
/// its breathing rate in response to character typing without phase jumps or blocking XCUITest idling.
struct BreathingTamgaView: UIViewRepresentable {
    let isDark: Bool
    var minOpacity: Float = 0.25
    var maxOpacity: Float = 0.52

    func makeUIView(context: Context) -> BreathingTamgaUIView {
        let view = BreathingTamgaUIView()
        view.updateAppearance(isDark: isDark, minOpacity: minOpacity, maxOpacity: maxOpacity)
        return view
    }

    func updateUIView(_ uiView: BreathingTamgaUIView, context: Context) {
        uiView.updateAppearance(isDark: isDark, minOpacity: minOpacity, maxOpacity: maxOpacity)
    }
}

final class BreathingTamgaUIView: UIView {
    private let shapeLayer = CAShapeLayer()
    private var cancellable: AnyCancellable?
    private var exertionTimer: Timer?
    private var currentExertion: CGFloat = 0
    private var targetExertion: CGFloat = 0
    private var isDark: Bool = false
    private var minOpacity: Float = 0.25
    private var maxOpacity: Float = 0.52

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(shapeLayer)
        startContinuousBreathIfNeeded()

        cancellable = SpaceBarState.shared.keystrokeSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.registerCharacterExertion()
            }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        exertionTimer?.invalidate()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startContinuousBreathIfNeeded()
        } else {
            exertionTimer?.invalidate()
            exertionTimer = nil
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.frame = bounds
        shapeLayer.path = TaraqTamgaShape().path(in: bounds).cgPath
        CATransaction.commit()
        startContinuousBreathIfNeeded()
    }

    func updateAppearance(isDark: Bool, minOpacity: Float = 0.25, maxOpacity: Float = 0.52) {
        let rangeChanged = abs(self.minOpacity - minOpacity) > 0.01 || abs(self.maxOpacity - maxOpacity) > 0.01
        self.isDark = isDark
        self.minOpacity = minOpacity
        self.maxOpacity = maxOpacity
        let baseColor = isDark ? UIColor.white : UIColor.black
        shapeLayer.fillColor = baseColor.cgColor
        if rangeChanged {
            shapeLayer.removeAnimation(forKey: "continuousBreath")
        }
        startContinuousBreathIfNeeded()
    }

    private func startContinuousBreathIfNeeded() {
        shapeLayer.opacity = (minOpacity + maxOpacity) * 0.5
        guard window != nil, shapeLayer.animation(forKey: "continuousBreath") == nil else { return }

        let opacityAnim = CABasicAnimation(keyPath: "opacity")
        opacityAnim.fromValue = minOpacity
        opacityAnim.toValue = maxOpacity
        opacityAnim.duration = 2.2
        opacityAnim.autoreverses = true
        opacityAnim.repeatCount = .infinity
        opacityAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
        scaleAnim.fromValue = 0.975
        scaleAnim.toValue = 1.045
        scaleAnim.duration = 2.2
        scaleAnim.autoreverses = true
        scaleAnim.repeatCount = .infinity
        scaleAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        let group = CAAnimationGroup()
        group.animations = [opacityAnim, scaleAnim]
        group.duration = 4.4
        group.repeatCount = .infinity
        group.isRemovedOnCompletion = false

        shapeLayer.speed = 1.0
        shapeLayer.timeOffset = 0.0
        shapeLayer.beginTime = 0.0
        shapeLayer.add(group, forKey: "continuousBreath")
    }

    private func updateBreathingSpeed(_ newSpeed: Float) {
        guard abs(shapeLayer.speed - newSpeed) > 0.01 else { return }
        let now = CACurrentMediaTime()
        let pausedTime = shapeLayer.convertTime(now, from: nil)
        shapeLayer.speed = newSpeed
        shapeLayer.timeOffset = pausedTime
        shapeLayer.beginTime = now
    }

    private func registerCharacterExertion() {
        guard !KeyboardPreferences.defaults.bool(forKey: "crh.key.test.isUITesting") else { return }
        startContinuousBreathIfNeeded()
        targetExertion = min(1.0, targetExertion + 0.14)
        guard exertionTimer == nil else { return }
        let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.stepExertion()
        }
        RunLoop.main.add(timer, forMode: .common)
        exertionTimer = timer
        stepExertion()
    }

    private func stepExertion() {
        currentExertion += (targetExertion - currentExertion) * 0.28
        targetExertion *= 0.90
        if currentExertion < 0.005 && targetExertion < 0.005 {
            currentExertion = 0
            targetExertion = 0
            updateBreathingSpeed(1.0)
            exertionTimer?.invalidate()
            exertionTimer = nil
            return
        }
        let speed = 1.0 + Float(currentExertion) * 1.9
        updateBreathingSpeed(speed)
    }
}

/// Native-style space bar label:
/// Displays the full language name ("Qırımtatarca" / "Къырымтатарджа" / "Кʼиримтатарджа") centered when the keyboard appears
/// or switches script, then smoothly fades into the centered breathing Taraq Tamğa emblem and the 2-letter
/// abbreviation ("QT" / "КЪ" / "Кʼ") in the bottom-trailing corner.
struct SpaceBarLabel: View {

    let fullName: String
    let languageCode: String
    let isCompact: Bool
    var isDarkOverride: Bool? = nil
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject private var spaceBarState = SpaceBarState.shared

    init(
        fullName: String = "Qırımtatarca",
        languageCode: String = "QT",
        isCompact: Bool = UIDevice.current.userInterfaceIdiom != .pad,
        isDarkOverride: Bool? = nil
    ) {
        self.fullName = fullName
        self.languageCode = languageCode
        self.isCompact = isCompact
        self.isDarkOverride = isDarkOverride
    }

    private var effectiveIsDark: Bool {
        isDarkOverride ?? (colorScheme == .dark)
    }

    private var centerFontSize: CGFloat {
        isCompact ? 14 : 16
    }

    private var cornerFontSize: CGFloat {
        isCompact ? 10.5 : 11.5
    }

    var body: some View {
        let primaryColor = effectiveIsDark ? Color.white : Color.black
        ZStack {
            // Centered full localized language name when appearing / switching script
            Text(fullName)
                .font(.system(size: centerFontSize, weight: .regular, design: .default))
                .foregroundStyle(primaryColor.opacity(0.65))
                .lineLimit(1)
                .opacity(spaceBarState.isShowingFullName ? 1 : 0)

            // Centered breathing & typing-responsive Taraq Tamğa emblem in resting state (exact 9:5 aspect ratio)
            BreathingTamgaView(isDark: effectiveIsDark)
                .frame(width: isCompact ? 18.0 : 22.5, height: isCompact ? 10.0 : 12.5)
                .opacity(spaceBarState.isShowingFullName ? 0 : 1)

            // Pinned bottom-trailing 2-letter code ("QT" / "КЪ" / "Кʼ") in resting state
            Text(languageCode)
                .font(.system(size: cornerFontSize, weight: .regular).width(.condensed))
                .foregroundStyle(primaryColor.opacity(0.55))
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
