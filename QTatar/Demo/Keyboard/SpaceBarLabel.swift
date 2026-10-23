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
        let timer = Timer(timeInterval: 3.0, repeats: false) { [weak self] _ in
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
    private var environmentObservers: [NSObjectProtocol] = []
    private var exertionTimer: Timer?
    private var idleStopWorkItem: DispatchWorkItem?
    private var currentExertion: CGFloat = 0
    private var targetExertion: CGFloat = 0
    private var isDark: Bool = false
    private var minOpacity: Float = 0.25
    private var maxOpacity: Float = 0.52

    private var shouldSuppressAnimation: Bool {
        UIAccessibility.isReduceMotionEnabled
            || ProcessInfo.processInfo.isLowPowerModeEnabled
            || KeyboardPreferences.defaults.bool(forKey: "crh.key.test.isUITesting")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        layer.addSublayer(shapeLayer)
        startContinuousBreathIfNeeded(scheduleIdleStop: true)

        cancellable = SpaceBarState.shared.keystrokeSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.registerCharacterExertion()
            }

        let nc = NotificationCenter.default
        environmentObservers.append(
            nc.addObserver(forName: UIAccessibility.reduceMotionStatusDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                self?.refreshAnimationPolicy()
            }
        )
        environmentObservers.append(
            nc.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in
                self?.refreshAnimationPolicy()
            }
        )
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        exertionTimer?.invalidate()
        idleStopWorkItem?.cancel()
        for obs in environmentObservers {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startContinuousBreathIfNeeded(scheduleIdleStop: true)
        } else {
            exertionTimer?.invalidate()
            exertionTimer = nil
            idleStopWorkItem?.cancel()
            idleStopWorkItem = nil
            shapeLayer.removeAnimation(forKey: "continuousBreath")
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.frame = bounds
        shapeLayer.path = TaraqTamgaShape().path(in: bounds).cgPath
        CATransaction.commit()
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
            startContinuousBreathIfNeeded(scheduleIdleStop: true)
        } else {
            refreshAnimationPolicy()
        }
    }

    private func refreshAnimationPolicy() {
        if shouldSuppressAnimation {
            idleStopWorkItem?.cancel()
            idleStopWorkItem = nil
            exertionTimer?.invalidate()
            exertionTimer = nil
            shapeLayer.removeAnimation(forKey: "continuousBreath")
            shapeLayer.removeAnimation(forKey: "settleToRest")
            shapeLayer.opacity = (minOpacity + maxOpacity) * 0.5
        }
    }

    private func pauseAtRest() {
        idleStopWorkItem?.cancel()
        idleStopWorkItem = nil
        let restOpacity = (minOpacity + maxOpacity) * 0.5
        if let presentation = shapeLayer.presentation(),
           shapeLayer.animation(forKey: "continuousBreath") != nil,
           !shouldSuppressAnimation,
           window != nil {
            let currentOpacity = presentation.opacity
            let currentScale = presentation.value(forKeyPath: "transform.scale") as? CGFloat ?? 1.0
            shapeLayer.removeAnimation(forKey: "continuousBreath")
            shapeLayer.speed = 1.0
            shapeLayer.timeOffset = 0.0
            shapeLayer.beginTime = 0.0
            shapeLayer.opacity = restOpacity

            let settleOpacity = CABasicAnimation(keyPath: "opacity")
            settleOpacity.fromValue = currentOpacity
            settleOpacity.toValue = restOpacity

            let settleScale = CABasicAnimation(keyPath: "transform.scale")
            settleScale.fromValue = currentScale
            settleScale.toValue = 1.0

            let settleGroup = CAAnimationGroup()
            settleGroup.animations = [settleOpacity, settleScale]
            settleGroup.duration = 3.5
            settleGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
            settleGroup.isRemovedOnCompletion = true
            if #available(iOS 15.0, *) {
                settleGroup.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 24)
            }
            shapeLayer.add(settleGroup, forKey: "settleToRest")
        } else {
            shapeLayer.removeAnimation(forKey: "continuousBreath")
            shapeLayer.removeAnimation(forKey: "settleToRest")
            shapeLayer.speed = 1.0
            shapeLayer.timeOffset = 0.0
            shapeLayer.beginTime = 0.0
            shapeLayer.opacity = restOpacity
        }
    }

    private func scheduleIdleStopTimer(after seconds: TimeInterval = 8.0) {
        idleStopWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.exertionTimer == nil, self.currentExertion < 0.005 else { return }
            self.pauseAtRest()
        }
        idleStopWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func startContinuousBreathIfNeeded(scheduleIdleStop: Bool = false) {
        shapeLayer.opacity = (minOpacity + maxOpacity) * 0.5
        if shouldSuppressAnimation {
            shapeLayer.removeAnimation(forKey: "continuousBreath")
            shapeLayer.removeAnimation(forKey: "settleToRest")
            return
        }
        guard window != nil else { return }

        if shapeLayer.animation(forKey: "continuousBreath") == nil {
            shapeLayer.removeAnimation(forKey: "settleToRest")
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
            if #available(iOS 15.0, *) {
                group.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 24)
            }

            shapeLayer.speed = 1.0
            shapeLayer.timeOffset = 0.0
            shapeLayer.beginTime = 0.0
            shapeLayer.add(group, forKey: "continuousBreath")
        }

        if scheduleIdleStop && exertionTimer == nil {
            scheduleIdleStopTimer(after: 8.0)
        }
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
        guard !shouldSuppressAnimation else { return }
        idleStopWorkItem?.cancel()
        idleStopWorkItem = nil
        startContinuousBreathIfNeeded(scheduleIdleStop: false)
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
            exertionTimer?.invalidate()
            exertionTimer = nil
            updateBreathingSpeed(1.0)
            scheduleIdleStopTimer(after: 8.0)
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
    var isSpaceDragActive: Bool = false
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject private var spaceBarState = SpaceBarState.shared

    init(
        fullName: String = "Qırımtatarca",
        languageCode: String = "QT",
        isCompact: Bool = UIDevice.current.userInterfaceIdiom != .pad,
        isDarkOverride: Bool? = nil,
        isSpaceDragActive: Bool = false
    ) {
        self.fullName = fullName
        self.languageCode = languageCode
        self.isCompact = isCompact
        self.isDarkOverride = isDarkOverride
        self.isSpaceDragActive = isSpaceDragActive
    }

    private var effectiveIsDark: Bool {
        isDarkOverride ?? (colorScheme == .dark)
    }

    private var centerFontSize: CGFloat {
        isCompact ? 14 : 16
    }

    private var cornerFontSize: CGFloat {
        isCompact ? 12.0 : 12.8
    }

    private var cornerFont: Font {
        if #available(iOS 16.0, *) {
            return .system(size: cornerFontSize, weight: .semibold, design: .default).width(.condensed)
        } else {
            return .system(size: cornerFontSize, weight: .semibold, design: .default)
        }
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

            // Pinned bottom-trailing 2-letter code ("QT" / "КЪ" / "Кʼ") in resting state, condensed to match native iOS "УК"
            Text(languageCode)
                .font(cornerFont)
                .kerning(-0.3)
                .scaleEffect(x: 0.85, y: 1.0, anchor: .bottomTrailing)
                .foregroundStyle(primaryColor.opacity(0.55))
                .lineLimit(1)
                .padding(.trailing, isCompact ? 8.5 : 9.5)
                .padding(.bottom, isCompact ? 4.5 : 5.5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .opacity(spaceBarState.isShowingFullName ? 0 : 1)
        }
        .opacity(isSpaceDragActive ? 0 : 1)
        .animation(.easeOut(duration: 0.15), value: isSpaceDragActive)
        .animation(.easeInOut(duration: 0.4), value: spaceBarState.isShowingFullName)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
