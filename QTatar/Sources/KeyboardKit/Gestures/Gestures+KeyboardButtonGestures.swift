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

private struct KeyFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

/// Coordinates continuous glide/swipe typing across character keys exclusively for iPhone and iPad Floating keyboards.
public final class SwipeTypingState: ObservableObject {
    public static let shared = SwipeTypingState()
    public static let didCompleteSwipeNotification = Notification.Name("crh.key.didCompleteSwipePath")
    public static let coordinateSpaceName = "SystemKeyboardZStack"

    public var isFormFactorEligible: Bool = false {
        didSet {
            if !isFormFactorEligible && (isSwiping || !visitedKeys.isEmpty) {
                reset()
            }
        }
    }

    public var isSlideToTypeSettingEnabled: Bool = true {
        didSet {
            if !isSlideToTypeSettingEnabled && (isSwiping || !visitedKeys.isEmpty) {
                reset()
            }
        }
    }

    public var isSwipeEnabled: Bool {
        isFormFactorEligible && isSlideToTypeSettingEnabled
    }

    @Published public private(set) var activeTrailPoints: [CGPoint] = []
    public private(set) var isSwiping: Bool = false

    private var keyFrames: [String: CGRect] = [:]
    private var visitedKeys: [String] = []
    private var pendingPoints: [CGPoint] = []
    private var lastPoint: CGPoint?
    private var totalDistance: CGFloat = 0

    private init() {}

    public func registerKeyFrame(character: String, frame: CGRect) {
        guard !character.isEmpty, frame.width > 4, frame.height > 4 else { return }
        keyFrames[character] = frame
    }

    public func beginPotentialSwipe(startChar: String, pointInKeyboard: CGPoint) {
        guard isSwipeEnabled, startChar.first?.isLetter == true else {
            reset()
            return
        }
        visitedKeys = [startChar]
        pendingPoints = [pointInKeyboard]
        lastPoint = pointInKeyboard
        totalDistance = 0
        isSwiping = false
    }

    public func updateDrag(pointInKeyboard: CGPoint, isActionCalloutActive: Bool) -> Bool {
        guard isSwipeEnabled, !isActionCalloutActive, !visitedKeys.isEmpty else {
            if isSwiping || !visitedKeys.isEmpty {
                reset()
            }
            return false
        }

        if let prev = lastPoint {
            let step = hypot(pointInKeyboard.x - prev.x, pointInKeyboard.y - prev.y)
            if step >= 2.0 {
                totalDistance += step
                lastPoint = pointInKeyboard
                pendingPoints.append(pointInKeyboard)
                if pendingPoints.count > 40 {
                    pendingPoints.removeFirst(pendingPoints.count - 40)
                }
            }
        } else {
            lastPoint = pointInKeyboard
            pendingPoints.append(pointInKeyboard)
        }

        if let hitChar = hitTestCharacter(at: pointInKeyboard), visitedKeys.last != hitChar {
            visitedKeys.append(hitChar)
        }

        if !isSwiping && totalDistance >= 36.0 && visitedKeys.count >= 2 {
            isSwiping = true
        }

        if isSwiping {
            activeTrailPoints = Array(pendingPoints.suffix(28))
        }
        return isSwiping
    }

    @discardableResult
    public func endSwipe() -> [String]? {
        defer { reset() }
        guard isSwiping, visitedKeys.count >= 2 else { return nil }
        let seq = visitedKeys
        NotificationCenter.default.post(
            name: Self.didCompleteSwipeNotification,
            object: nil,
            userInfo: ["keys": seq]
        )
        return seq
    }

    public func reset() {
        visitedKeys.removeAll(keepingCapacity: true)
        pendingPoints.removeAll(keepingCapacity: true)
        lastPoint = nil
        totalDistance = 0
        isSwiping = false
        if !activeTrailPoints.isEmpty {
            activeTrailPoints = []
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
        return nil
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
            base
                .background(
                    Color.clear.preference(
                        key: KeyFramePreferenceKey.self,
                        value: geo.frame(in: .named(SwipeTypingState.coordinateSpaceName))
                    )
                )
                .onPreferenceChange(KeyFramePreferenceKey.self) { frame in
                    SwipeTypingState.shared.registerKeyFrame(character: ch, frame: frame)
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
            if SwipeTypingState.shared.updateDrag(pointInKeyboard: globalPoint, isActionCalloutActive: calloutActive) {
                shouldApplyReleaseAction = false
                calloutContext?.inputContext.reset()
                return
            }
        }
        calloutContext?.actionContext.updateSelection(with: value.translation)
        dragAction?(value.startLocation, value.location)
    }

    func handleGestureEnded(in geo: GeometryProxy) {
        if SwipeTypingState.shared.isSwiping {
            _ = SwipeTypingState.shared.endSwipe()
        } else {
            SwipeTypingState.shared.reset()
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
            if dy >= 12 && dy > abs(dx) {
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
            context.updateSelection(with: drag.translation)
        }
        calloutContext?.inputContext.reset()
    }

    func endActionCallout() {
        if let drag = lastDragValue, let context = calloutContext?.actionContext, context.isActive {
            context.updateSelection(with: drag.translation)
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
