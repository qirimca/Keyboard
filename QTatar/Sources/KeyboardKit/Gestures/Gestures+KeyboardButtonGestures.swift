//
//  Gestures+KeyboardButtonGestures.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-01-10.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

#if os(iOS) || os(macOS) || os(watchOS)
import SwiftUI

extension Gestures {
    
    /// This view applies keyboard gestures to any view.
    struct KeyboardButtonGestures<Content: View>: View {
        
        /// Apply a set of action gestures to a view.
        ///
        /// - Parameters:
        ///   - view: The view to apply the gestures to.
        ///   - action: The keyboard action to trigger.
        ///   - calloutContext: The callout context to affect, if any.
        ///   - isPressed: An optional binding that can be used to observe the button pressed state.
        ///   - isInScrollView: Whether or not the gestures are used in a scroll view.
        ///   - releaseOutsideTolerance: The percentage of the button size outside its bounds that should count as a release, by default `1.0`.
        ///   - doubleTapAction: The action to trigger when the button is double tapped.
        ///   - longPressAction: The action to trigger when the button is long pressed.
        ///   - pressAction: The action to trigger when the button is pressed.
        ///   - releaseAction: The action to trigger when the button is released, regardless of where the gesture ends.
        ///   - repeatAction: The action to trigger when the button is pressed and held.
        ///   - dragAction: The action to trigger when the button is dragged.
        init(
            view: Content,
            action: KeyboardAction?,
            calloutContext: CalloutContext?,
            isPressed: Binding<Bool>,
            isInScrollView: Bool,
            releaseOutsideTolerance: Double? = nil,
            doubleTapAction: KeyboardGestureAction?,
            longPressAction: KeyboardGestureAction?,
            pressAction: KeyboardGestureAction?,
            releaseAction: KeyboardGestureAction?,
            repeatAction: KeyboardGestureAction?,
            dragAction: KeyboardDragGestureAction?
        ) {
            self.view = view
            self.action = action
            self.calloutContext = calloutContext
            self.isPressed = isPressed
            self.isInScrollView = isInScrollView
            self.releaseOutsideTolerance = releaseOutsideTolerance ?? 1.0
            self.doubleTapAction = doubleTapAction
            self.longPressAction = longPressAction
            self.pressAction = pressAction
            self.releaseAction = releaseAction
            self.repeatAction = repeatAction
            self.dragAction = dragAction
        }
        
        private let view: Content
        private let action: KeyboardAction?
        private let calloutContext: CalloutContext?
        private let isPressed: Binding<Bool>
        private let isInScrollView: Bool
        private let releaseOutsideTolerance: Double
        private let doubleTapAction: KeyboardGestureAction?
        private let longPressAction: KeyboardGestureAction?
        private let pressAction: KeyboardGestureAction?
        private let releaseAction: KeyboardGestureAction?
        private let repeatAction: KeyboardGestureAction?
        private let dragAction: KeyboardDragGestureAction?
        
        @State
        private var lastDragValue: DragGesture.Value?
        
        @State
        private var shouldApplyReleaseAction = true
        
        var body: some View {
            view.overlay(
                GeometryReader { geo in
                    button(for: geo)
                }
            )
        }
    }
}

private extension View {

    @ViewBuilder
    func optionalGesture<GestureType: Gesture>(_ gesture: GestureType?) -> some View {
        if let gesture = gesture {
            self.gesture(gesture)
        } else {
            self
        }
    }
}

private struct KeyFramePayload: Equatable {
    let character: String
    let frame: CGRect
}

private struct KeyFramePreferenceKey: PreferenceKey {
    static var defaultValue: KeyFramePayload = .init(character: "", frame: .zero)
    static func reduce(value: inout KeyFramePayload, nextValue: () -> KeyFramePayload) {
        value = nextValue()
    }
}

/// Coordinates continuous glide/swipe typing across character keys exclusively for iPhone and iPad Floating keyboards.
public final class SwipeTypingState: ObservableObject {
    public static let shared = SwipeTypingState()
    public static let didCompleteSwipeNotification = Notification.Name("crh.key.didCompleteSwipePath")
    public static let coordinateSpaceName = "SystemKeyboardZStack"
    private static let casingLocale = Locale(identifier: "tr")

    public struct TrailSample: Equatable {
        public let point: CGPoint
        public let timestamp: TimeInterval
    }

    public var isFormFactorEligible: Bool = false {
        didSet {
            if !isFormFactorEligible && (isSwiping || !visitedKeys.isEmpty) {
                reset(clearTrailImmediately: true)
            }
        }
    }

    public var isSlideToTypeSettingEnabled: Bool = true {
        didSet {
            if !isSlideToTypeSettingEnabled && (isSwiping || !visitedKeys.isEmpty) {
                reset(clearTrailImmediately: true)
            }
        }
    }

    public var isSwipeEnabled: Bool {
        isFormFactorEligible && isSlideToTypeSettingEnabled
    }

    @Published public private(set) var activeTrailPoints: [CGPoint] = []
    @Published public private(set) var activeTrailSamples: [TrailSample] = []
    public private(set) var isSwiping: Bool = false
    public private(set) var totalDragDistance: CGFloat = 0

    private var keyFrames: [String: CGRect] = [:]
    private var visitedKeys: [String] = []
    private var pendingSamples: [TrailSample] = []
    private var lastPoint: CGPoint?
    private var swipeGeneration: Int = 0

    private init() {}

    private static func isCyrillicCharacter(_ s: String) -> Bool {
        guard let scalar = s.unicodeScalars.first else { return false }
        return (0x0400...0x04FF).contains(scalar.value) || scalar.value == 0x02BC
    }

    public func clearKeyFrames() {
        keyFrames.removeAll(keepingCapacity: true)
    }

    public func registerKeyFrame(character: String, frame: CGRect) {
        let norm = character.lowercased(with: Self.casingLocale)
        guard !norm.isEmpty, frame.width > 4, frame.height > 4 else { return }
        let isCyr = Self.isCyrillicCharacter(norm)
        let overlapTestRect = frame.insetBy(dx: max(2, frame.width * 0.18), dy: max(2, frame.height * 0.18))
        let staleKeys = keyFrames.compactMap { existingChar, existingRect -> String? in
            guard existingChar != norm else { return nil }
            if Self.isCyrillicCharacter(existingChar) != isCyr {
                return existingChar
            }
            if existingRect.intersects(overlapTestRect) {
                return existingChar
            }
            let dist = hypot(existingRect.midX - frame.midX, existingRect.midY - frame.midY)
            return dist < 12.0 ? existingChar : nil
        }
        for stale in staleKeys {
            keyFrames.removeValue(forKey: stale)
        }
        keyFrames[norm] = frame
    }

    public func beginPotentialSwipe(startChar: String, pointInKeyboard: CGPoint) {
        let norm = startChar.lowercased(with: Self.casingLocale)
        guard isSwipeEnabled, norm.first?.isLetter == true else {
            reset(clearTrailImmediately: true)
            return
        }
        swipeGeneration &+= 1
        let now = ProcessInfo.processInfo.systemUptime
        visitedKeys = [norm]
        pendingSamples = [TrailSample(point: pointInKeyboard, timestamp: now)]
        lastPoint = pointInKeyboard
        totalDragDistance = 0
        isSwiping = false
    }

    public func updateDrag(pointInKeyboard: CGPoint, isActionCalloutActive: Bool) -> Bool {
        guard isSwipeEnabled, !isActionCalloutActive, !visitedKeys.isEmpty else {
            if isSwiping || !visitedKeys.isEmpty {
                reset(clearTrailImmediately: true)
            }
            return false
        }

        let now = ProcessInfo.processInfo.systemUptime
        let previousPoint = lastPoint
        if let prev = previousPoint {
            let step = hypot(pointInKeyboard.x - prev.x, pointInKeyboard.y - prev.y)
            if step >= 1.5 {
                totalDragDistance += step
                lastPoint = pointInKeyboard
                pendingSamples.append(TrailSample(point: pointInKeyboard, timestamp: now))
            }
        } else {
            lastPoint = pointInKeyboard
            pendingSamples.append(TrailSample(point: pointInKeyboard, timestamp: now))
        }
        pendingSamples.removeAll { now - $0.timestamp > 0.38 }
        if pendingSamples.count > 56 {
            pendingSamples.removeFirst(pendingSamples.count - 56)
        }

        if let prev = previousPoint {
            let step = hypot(pointInKeyboard.x - prev.x, pointInKeyboard.y - prev.y)
            let subdivisions = max(1, min(8, Int(ceil(step / 10.0))))
            for i in 1...subdivisions {
                let t = CGFloat(i) / CGFloat(subdivisions)
                let interp = CGPoint(
                    x: prev.x + (pointInKeyboard.x - prev.x) * t,
                    y: prev.y + (pointInKeyboard.y - prev.y) * t
                )
                if let hitChar = hitTestCharacter(at: interp), visitedKeys.last != hitChar {
                    visitedKeys.append(hitChar)
                }
            }
        } else if let hitChar = hitTestCharacter(at: pointInKeyboard), visitedKeys.last != hitChar {
            visitedKeys.append(hitChar)
        }

        if !isSwiping && ((totalDragDistance >= 20.0 && visitedKeys.count >= 2) || totalDragDistance >= 42.0) {
            isSwiping = true
        }

        if isSwiping {
            activeTrailSamples = pendingSamples
            activeTrailPoints = pendingSamples.map(\.point)
        }
        return isSwiping
    }

    @discardableResult
    public func endSwipe() -> [String]? {
        let wasSwiping = isSwiping
        let seq = visitedKeys
        reset(clearTrailImmediately: !wasSwiping)
        guard wasSwiping, seq.count >= 2 else { return nil }
        NotificationCenter.default.post(
            name: Self.didCompleteSwipeNotification,
            object: nil,
            userInfo: ["keys": seq]
        )
        return seq
    }

    public func reset(clearTrailImmediately: Bool = false) {
        visitedKeys.removeAll(keepingCapacity: true)
        pendingSamples.removeAll(keepingCapacity: true)
        lastPoint = nil
        totalDragDistance = 0
        isSwiping = false
        if clearTrailImmediately {
            if !activeTrailPoints.isEmpty { activeTrailPoints = [] }
            if !activeTrailSamples.isEmpty { activeTrailSamples = [] }
        } else if !activeTrailSamples.isEmpty {
            let gen = swipeGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.37) { [weak self] in
                guard let self, self.swipeGeneration == gen, !self.isSwiping else { return }
                if !self.activeTrailPoints.isEmpty { self.activeTrailPoints = [] }
                if !self.activeTrailSamples.isEmpty { self.activeTrailSamples = [] }
            }
        }
    }

    private func hitTestCharacter(at point: CGPoint) -> String? {
        for (ch, rect) in keyFrames {
            let insetRect = rect.insetBy(dx: rect.width * 0.10, dy: rect.height * 0.10)
            if insetRect.contains(point) {
                return ch
            }
        }
        for (ch, rect) in keyFrames where rect.contains(point) {
            return ch
        }
        var bestChar: String?
        var bestDist: CGFloat = 22.0
        for (ch, rect) in keyFrames {
            let d = hypot(rect.midX - point.x, rect.midY - point.y)
            if d < bestDist {
                bestDist = d
                bestChar = ch
            }
        }
        return bestChar
    }
}

// MARK: - Views

private extension Gestures.KeyboardButtonGestures {

    var characterKeyString: String? {
        if case .character(let ch) = action, ch.first?.isLetter == true {
            return ch
        }
        return nil
    }

    @ViewBuilder
    func button(for geo: GeometryProxy) -> some View {
        let base: AnyView = isInScrollView ? AnyView(scrollButton(for: geo)) : AnyView(gestureButton(for: geo))
        if let ch = characterKeyString {
            let currentFrame = geo.frame(in: .named(SwipeTypingState.coordinateSpaceName))
            let _ = SwipeTypingState.shared.registerKeyFrame(character: ch, frame: currentFrame)
            base
                .background(
                    Color.clear.preference(
                        key: KeyFramePreferenceKey.self,
                        value: KeyFramePayload(character: ch, frame: currentFrame)
                    )
                )
                .onPreferenceChange(KeyFramePreferenceKey.self) { payload in
                    SwipeTypingState.shared.registerKeyFrame(character: payload.character, frame: payload.frame)
                }
                .onChange(of: currentFrame) { newFrame in
                    SwipeTypingState.shared.registerKeyFrame(character: ch, frame: newFrame)
                }
                .onAppear {
                    SwipeTypingState.shared.registerKeyFrame(
                        character: ch,
                        frame: geo.frame(in: .named(SwipeTypingState.coordinateSpaceName))
                    )
                }
        } else {
            base
        }
    }

    func gestureButton(for geo: GeometryProxy) -> some View {
        Gestures.GestureButton(
            isPressed: isPressed,
            pressAction: { handlePress(in: geo) },
            releaseInsideAction: { handleReleaseInside(in: geo) },
            releaseOutsideAction: { handleReleaseOutside(in: geo) },
            longPressAction: { handleLongPress(in: geo) },
            doubleTapAction: { handleDoubleTap(in: geo) },
            repeatAction: { handleRepeat(in: geo) },
            dragAction: { handleDrag(in: geo, value: $0) },
            endAction: { handleGestureEnded(in: geo) },
            label: { _ in Color.clearInteractable }
        )
    }

    func scrollButton(for geo: GeometryProxy) -> some View {
        Gestures.ScrollViewGestureButton(
            isPressed: isPressed,
            pressAction: { handlePress(in: geo) },
            releaseInsideAction: { handleReleaseInside(in: geo) },
            releaseOutsideAction: { handleReleaseOutside(in: geo) },
            longPressAction: { handleLongPress(in: geo) },
            doubleTapAction: { handleDoubleTap(in: geo) },
            repeatAction: { handleRepeat(in: geo) },
            dragAction: { handleDrag(in: geo, value: $0) },
            endAction: { handleGestureEnded(in: geo) },
            label: { _ in Color.clearInteractable }
        )
    }
}


// MARK: - Actions

private extension Gestures.KeyboardButtonGestures {

    func handleDoubleTap(in geo: GeometryProxy) {
        doubleTapAction?()
    }

    func handleDrag(in geo: GeometryProxy, value: DragGesture.Value) {
        lastDragValue = value
        if let ch = characterKeyString, SwipeTypingState.shared.isSwipeEnabled {
            let frame = geo.frame(in: .named(SwipeTypingState.coordinateSpaceName))
            SwipeTypingState.shared.registerKeyFrame(character: ch, frame: frame)
            let globalPoint = CGPoint(
                x: frame.origin.x + value.location.x,
                y: frame.origin.y + value.location.y
            )
            let calloutActive = calloutContext?.actionContext.isActive ?? false
            let isSwipingNow = SwipeTypingState.shared.updateDrag(pointInKeyboard: globalPoint, isActionCalloutActive: calloutActive)
            if SwipeTypingState.shared.totalDragDistance >= 14.0 || isSwipingNow {
                calloutContext?.inputContext.reset()
                calloutContext?.actionContext.reset()
            }
            if isSwipingNow {
                shouldApplyReleaseAction = false
                return
            }
        }
        calloutContext?.actionContext.updateSelection(with: value.translation, location: value.location)
        dragAction?(value.startLocation, value.location)
    }

    func handleGestureEnded(in geo: GeometryProxy) {
        if SwipeTypingState.shared.isSwiping {
            _ = SwipeTypingState.shared.endSwipe()
        } else {
            SwipeTypingState.shared.reset(clearTrailImmediately: true)
        }
        endActionCallout()
        calloutContext?.inputContext.resetWithDelay()
        calloutContext?.actionContext.reset()
        resetGestureState()
        NotificationCenter.default.post(name: Notification.Name("crh.key.gestureEnded"), object: nil)
    }

    func handleLongPress(in geo: GeometryProxy) {
        guard !SwipeTypingState.shared.isSwiping else { return }
        tryBeginActionCallout(in: geo)
        longPressAction?()
    }

    func handlePress(in geo: GeometryProxy) {
        if let ch = characterKeyString, SwipeTypingState.shared.isSwipeEnabled {
            let frame = geo.frame(in: .named(SwipeTypingState.coordinateSpaceName))
            SwipeTypingState.shared.registerKeyFrame(character: ch, frame: frame)
            SwipeTypingState.shared.beginPotentialSwipe(
                startChar: ch,
                pointInKeyboard: CGPoint(x: frame.midX, y: frame.midY)
            )
        }
        pressAction?()
        calloutContext?.inputContext.updateInput(for: action, in: geo)
    }

    func handleReleaseInside(in geo: GeometryProxy) {
        guard !SwipeTypingState.shared.isSwiping else { return }
        updateShouldApplyReleaseAction()
        guard shouldApplyReleaseAction else { return }
        releaseAction?()
    }

    func handleReleaseOutside(in geo: GeometryProxy) {
        guard !SwipeTypingState.shared.isSwiping else { return }
        guard shouldApplyReleaseOutsize(for: geo) else { return }
        handleReleaseInside(in: geo)
    }

    func handleRepeat(in geo: GeometryProxy) {
        guard !SwipeTypingState.shared.isSwiping else { return }
        repeatAction?()
    }

    func tryBeginActionCallout(in geo: GeometryProxy) {
        guard !SwipeTypingState.shared.isSwiping else { return }
        if let drag = lastDragValue {
            let dx = drag.location.x - drag.startLocation.x
            let dy = drag.location.y - drag.startLocation.y
            if action != .dismissKeyboard && dy >= 12 && dy > abs(dx) {
                return
            }
            if SwipeTypingState.shared.isSwipeEnabled && hypot(dx, dy) > 24 {
                return
            }
        }
        guard let context = calloutContext?.actionContext else { return }
        context.updateInputs(for: action, in: geo)
        guard context.isActive else { return }
        if let drag = lastDragValue {
            context.updateSelection(with: drag.translation, location: drag.location)
        }
        calloutContext?.inputContext.reset()
    }

    func endActionCallout() {
        if let drag = lastDragValue, let context = calloutContext?.actionContext, context.isActive {
            context.updateSelection(with: drag.translation, location: drag.location)
        }
        calloutContext?.actionContext.endDragGesture()
    }

    func resetGestureState() {
        lastDragValue = nil
        shouldApplyReleaseAction = true
    }

    func shouldApplyReleaseOutsize(for geo: GeometryProxy) -> Bool {
        guard let dragValue = lastDragValue else { return false }
        let rect = CGRect.releaseOutsideToleranceArea(for: geo, tolerance: releaseOutsideTolerance)
        let isInsideRect = rect.contains(dragValue.location)
        return isInsideRect
    }

    func updateShouldApplyReleaseAction() {
        guard let context = calloutContext?.actionContext else { return }
        shouldApplyReleaseAction = shouldApplyReleaseAction && !context.hasSelectedAction
    }
}

extension CGRect {

    /// Return a rect with release outside tolerance padding.
    static func releaseOutsideToleranceArea(
        for geo: GeometryProxy,
        tolerance: Double
    ) -> CGRect {
        let size = geo.size
        var rect = CGRect(origin: .zero, size: geo.size)
            .insetBy(dx: -size.width * tolerance, dy: -size.height * tolerance)
        rect.size.height += size.height * 0.75
        return rect
    }
}
#endif
