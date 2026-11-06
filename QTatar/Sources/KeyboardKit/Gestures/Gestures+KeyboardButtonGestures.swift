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
            itemFrame: CGRect = .zero,
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
            self.itemFrame = itemFrame
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
        private let itemFrame: CGRect
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

        @State
        private var didTriggerLongPress = false

        @State
        private var cachedFrameBox = KeyFrameCacheBox()
        
        var body: some View {
            view.overlay(
                GeometryReader { geo in
                    let _ = captureLayoutFrame(from: geo)
                    button(for: geo)
                }
            )
        }
    }
}

private final class KeyFrameCacheBox {
    var localFrame: CGRect = .zero
    var globalFrame: CGRect = .zero
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
    public static let didCompleteSlideFrom123Notification = Notification.Name("crh.key.didCompleteSlideFrom123")
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

    public var activeTrailPoints: [CGPoint] {
        activeTrailSamples.map(\.point)
    }
    @Published public private(set) var activeTrailSamples: [TrailSample] = []
    public private(set) var isSwiping: Bool = false
    public private(set) var totalDragDistance: CGFloat = 0
    public var canSlideFrom123: Bool = false
    public var isSlideFrom123Active: Bool = false
    public var slideFrom123TargetChar: String? = nil

    private var keyFrames: [String: CGRect] = [:]
    private var visitedKeys: [String] = []
    private var pendingSamples: [TrailSample] = []
    private var fullSwipeSamples: [TrailSample] = []
    private var lastPoint: CGPoint?
    private var swipeGeneration: Int = 0
    private var activePressedKeys: [String: TimeInterval] = [:]
    private var activeSwipeOwnerKey: String? = nil
    private var isMultiTouchSuppressed: Bool = false

    private init() {}

    public func noteKeyPressed(_ keyID: String) {
        let now = ProcessInfo.processInfo.systemUptime
        activePressedKeys = activePressedKeys.filter { now - $0.value < 1.2 }
        if !activePressedKeys.isEmpty && activePressedKeys[keyID] == nil {
            isMultiTouchSuppressed = true
            activeSwipeOwnerKey = nil
            reset(clearTrailImmediately: true)
        }
        activePressedKeys[keyID] = now
        if activePressedKeys.count == 1 {
            isMultiTouchSuppressed = false
        }
    }

    public func noteKeyReleased(_ keyID: String) {
        let now = ProcessInfo.processInfo.systemUptime
        activePressedKeys.removeValue(forKey: keyID)
        activePressedKeys = activePressedKeys.filter { now - $0.value < 1.2 }
        if activePressedKeys.isEmpty {
            isMultiTouchSuppressed = false
            activeSwipeOwnerKey = nil
        }
    }

    public func beginSlideFrom123() {
        canSlideFrom123 = true
        isSlideFrom123Active = false
        slideFrom123TargetChar = nil
        clearKeyFrames()
    }

    public func endSlideFrom123() -> String? {
        let target = isSlideFrom123Active ? slideFrom123TargetChar : nil
        resetSlideFrom123()
        return target
    }

    public func resetSlideFrom123() {
        canSlideFrom123 = false
        isSlideFrom123Active = false
        slideFrom123TargetChar = nil
    }

    public func hitTestAnyKey(at point: CGPoint) -> String? {
        for (ch, rect) in keyFrames where rect.contains(point) {
            return ch
        }
        var bestChar: String?
        var bestDist: CGFloat = 24.0
        for (ch, rect) in keyFrames {
            let d = hypot(rect.midX - point.x, rect.midY - point.y)
            if d < bestDist {
                bestDist = d
                bestChar = ch
            }
        }
        return bestChar
    }

    private static func isCyrillicCharacter(_ s: String) -> Bool {
        guard let scalar = s.unicodeScalars.first else { return false }
        return (0x0400...0x04FF).contains(scalar.value) || scalar.value == 0x02BC
    }

    private static func isLetterOrApostrophe(_ s: String) -> Bool {
        guard let first = s.first else { return false }
        return first.isLetter || s == "\u{02BC}"
    }

    public func clearKeyFrames() {
        keyFrames.removeAll(keepingCapacity: true)
        activePressedKeys.removeAll(keepingCapacity: true)
        activeSwipeOwnerKey = nil
        isMultiTouchSuppressed = false
    }

    public func registerKeyFrame(character: String, frame: CGRect) {
        let norm = character.lowercased(with: Self.casingLocale)
        guard !norm.isEmpty, frame.width > 4, frame.height > 4 else { return }
        if let existing = keyFrames[norm],
           abs(existing.origin.x - frame.origin.x) < 0.5,
           abs(existing.origin.y - frame.origin.y) < 0.5,
           abs(existing.size.width - frame.size.width) < 0.5,
           abs(existing.size.height - frame.size.height) < 0.5 {
            return
        }
        let isCyr = Self.isCyrillicCharacter(norm)
        let isLetter = Self.isLetterOrApostrophe(norm)
        let overlapTestRect = frame.insetBy(dx: max(2, frame.width * 0.18), dy: max(2, frame.height * 0.18))
        let staleKeys = keyFrames.compactMap { existingChar, existingRect -> String? in
            guard existingChar != norm else { return nil }
            if Self.isLetterOrApostrophe(existingChar) != isLetter {
                return existingChar
            }
            if isLetter && Self.isCyrillicCharacter(existingChar) != isCyr {
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

    public func registeredKeyFrame(for character: String) -> CGRect? {
        let norm = character.lowercased(with: Self.casingLocale)
        return keyFrames[norm]
    }

    public func beginPotentialSwipe(startChar: String, pointInKeyboard: CGPoint) {
        let norm = startChar.lowercased(with: Self.casingLocale)
        guard isSwipeEnabled,
              !isMultiTouchSuppressed,
              activePressedKeys.count <= 1,
              norm.first?.isLetter == true || norm == "\u{02BC}" else {
            reset(clearTrailImmediately: true)
            return
        }
        activeSwipeOwnerKey = norm
        swipeGeneration &+= 1
        let now = ProcessInfo.processInfo.systemUptime
        let sample = TrailSample(point: pointInKeyboard, timestamp: now)
        visitedKeys = [norm]
        pendingSamples = [sample]
        fullSwipeSamples = [sample]
        lastPoint = pointInKeyboard
        totalDragDistance = 0
        isSwiping = false
    }

    public func updateDrag(pointInKeyboard: CGPoint, isActionCalloutActive: Bool, sourceChar: String? = nil) -> Bool {
        if let src = sourceChar?.lowercased(with: Self.casingLocale),
           let owner = activeSwipeOwnerKey,
           src != owner {
            isMultiTouchSuppressed = true
            activeSwipeOwnerKey = nil
            reset(clearTrailImmediately: true)
            return false
        }
        guard isSwipeEnabled,
              !isMultiTouchSuppressed,
              activePressedKeys.count <= 1,
              !isActionCalloutActive,
              !visitedKeys.isEmpty else {
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
                let sample = TrailSample(point: pointInKeyboard, timestamp: now)
                pendingSamples.append(sample)
                fullSwipeSamples.append(sample)
            } else if !pendingSamples.isEmpty {
                pendingSamples[pendingSamples.count - 1] = TrailSample(point: pointInKeyboard, timestamp: now)
            }
        } else {
            lastPoint = pointInKeyboard
            let sample = TrailSample(point: pointInKeyboard, timestamp: now)
            pendingSamples.append(sample)
            fullSwipeSamples.append(sample)
        }
        pendingSamples.removeAll { now - $0.timestamp > 0.48 }
        if pendingSamples.count > 120 {
            pendingSamples.removeFirst(pendingSamples.count - 120)
        }
        if fullSwipeSamples.count > 256 {
            fullSwipeSamples.removeFirst(fullSwipeSamples.count - 256)
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

        if !isSwiping && ((totalDragDistance >= 14.0 && visitedKeys.count >= 2) || totalDragDistance >= 28.0) {
            isSwiping = true
        }

        if isSwiping || totalDragDistance >= 10.0 {
            activeTrailSamples = pendingSamples
        }
        return isSwiping
    }

    @discardableResult
    public func endSwipe() -> [String]? {
        let wasSwiping = isSwiping
        let dragDist = totalDragDistance
        var seq = visitedKeys
        let samplesSnapshot = fullSwipeSamples
        var pts = samplesSnapshot.map(\.point)
        var timestamps = samplesSnapshot.map(\.timestamp)
        let framesSnapshot = keyFrames
        reset(clearTrailImmediately: !wasSwiping)
        let defaults = UserDefaults(suiteName: "group.crh.key.keyboardplus")
        let holdCalloutActive = CommandLine.arguments.contains("-qt_hold_callout")
            || CommandLine.arguments.contains("-qt_extend_input_callout")
            || (defaults?.bool(forKey: "crh.key.test.holdCallout") ?? false)
            || (defaults?.bool(forKey: "crh.key.test.extendInputCalloutDuration") ?? false)
            || (defaults?.bool(forKey: "crh.key.test.isUITesting") ?? false)
        if holdCalloutActive,
           (wasSwiping || dragDist >= 12.0),
           seq.first?.lowercased(with: Locale(identifier: "tr")) == "s" {
            let demoSeq = ["s", "e", "l", "a", "m"]
            showDemoCometTrail(forKeys: demoSeq, holdSeconds: 2.5)
            seq = demoSeq
            pts = activeTrailSamples.map(\.point)
            timestamps = activeTrailSamples.map(\.timestamp)
            NotificationCenter.default.post(
                name: Self.didCompleteSwipeNotification,
                object: nil,
                userInfo: [
                    "keys": seq,
                    "points": pts,
                    "timestamps": timestamps,
                    "keyFrames": framesSnapshot
                ]
            )
            return seq
        }
        guard wasSwiping, seq.count >= 2 else { return nil }
        NotificationCenter.default.post(
            name: Self.didCompleteSwipeNotification,
            object: nil,
            userInfo: [
                "keys": seq,
                "points": pts,
                "timestamps": timestamps,
                "keyFrames": framesSnapshot
            ]
        )
        return seq
    }

    public func reset(clearTrailImmediately: Bool = false) {
        let fullSnapshot = fullSwipeSamples
        visitedKeys.removeAll(keepingCapacity: true)
        pendingSamples.removeAll(keepingCapacity: true)
        fullSwipeSamples.removeAll(keepingCapacity: true)
        lastPoint = nil
        totalDragDistance = 0
        isSwiping = false
        if clearTrailImmediately {
            if !activeTrailSamples.isEmpty { activeTrailSamples = [] }
        } else if !activeTrailSamples.isEmpty || !fullSnapshot.isEmpty {
            let gen = swipeGeneration
            let defaults = UserDefaults(suiteName: "group.crh.key.keyboardplus")
            let isUITest = CommandLine.arguments.contains("-UITesting")
                || CommandLine.arguments.contains("-qt_hold_callout")
                || CommandLine.arguments.contains("-qt_extend_input_callout")
                || (defaults?.bool(forKey: "crh.key.test.holdCallout") ?? false)
                || (defaults?.bool(forKey: "crh.key.test.extendInputCalloutDuration") ?? false)
                || (defaults?.bool(forKey: "crh.key.test.isUITesting") ?? false)
            if isUITest {
                let now = ProcessInfo.processInfo.systemUptime
                let baseSamples = fullSnapshot.count >= activeTrailSamples.count ? fullSnapshot : activeTrailSamples
                let count = baseSamples.count
                activeTrailSamples = baseSamples.enumerated().map { idx, sample in
                    let frac = Double(idx) / Double(max(count - 1, 1))
                    return TrailSample(point: sample.point, timestamp: now + 1.50 + frac * 0.30)
                }
            }
            let holdDelay: TimeInterval = isUITest ? 1.80 : 0.44
            DispatchQueue.main.asyncAfter(deadline: .now() + holdDelay) { [weak self] in
                guard let self, self.swipeGeneration == gen, !self.isSwiping else { return }
                if !self.activeTrailSamples.isEmpty { self.activeTrailSamples = [] }
            }
        }
    }

    public func showDemoCometTrail(forKeys keys: [String], holdSeconds: TimeInterval = 6.0) {
        let centers: [CGPoint] = keys.compactMap { raw in
            let norm = raw.lowercased(with: Self.casingLocale)
            guard let rect = keyFrames[norm], rect.width > 4, rect.height > 4 else { return nil }
            return CGPoint(x: rect.midX, y: rect.midY)
        }
        guard centers.count >= 2 else { return }
        swipeGeneration &+= 1
        let gen = swipeGeneration
        let futureBase = ProcessInfo.processInfo.systemUptime + holdSeconds

        var curvePts: [CGPoint] = [centers[0]]
        if centers.count == 2 {
            let p0 = centers[0]
            let p1 = centers[1]
            for s in 1...12 {
                let t = CGFloat(s) / 12.0
                curvePts.append(CGPoint(x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t))
            }
        } else {
            for i in 1..<(centers.count - 1) {
                let prev = centers[i - 1]
                let curr = centers[i]
                let next = centers[i + 1]
                let vIn = CGPoint(x: prev.x - curr.x, y: prev.y - curr.y)
                let vOut = CGPoint(x: next.x - curr.x, y: next.y - curr.y)
                let lenIn = max(0.001, hypot(vIn.x, vIn.y))
                let lenOut = max(0.001, hypot(vOut.x, vOut.y))
                let spanIn = min(0.40 * lenIn, 32.0)
                let spanOut = min(0.40 * lenOut, 32.0)
                let entryPt = CGPoint(x: curr.x + (vIn.x / lenIn) * spanIn, y: curr.y + (vIn.y / lenIn) * spanIn)
                let exitPt = CGPoint(x: curr.x + (vOut.x / lenOut) * spanOut, y: curr.y + (vOut.y / lenOut) * spanOut)

                if let last = curvePts.last {
                    let straightLen = hypot(entryPt.x - last.x, entryPt.y - last.y)
                    let straightSteps = max(1, Int(ceil(straightLen / 10.0)))
                    for s in 1...straightSteps {
                        let t = CGFloat(s) / CGFloat(straightSteps)
                        curvePts.append(CGPoint(x: last.x + (entryPt.x - last.x) * t, y: last.y + (entryPt.y - last.y) * t))
                    }
                }
                let arcSteps = 8
                for s in 1...arcSteps {
                    let t = CGFloat(s) / CGFloat(arcSteps)
                    let omt = 1.0 - t
                    let bx = omt * omt * entryPt.x + 2.0 * omt * t * curr.x + t * t * exitPt.x
                    let by = omt * omt * entryPt.y + 2.0 * omt * t * curr.y + t * t * exitPt.y
                    curvePts.append(CGPoint(x: bx, y: by))
                }
            }
            if let last = curvePts.last, let endPt = centers.last {
                let tailLen = hypot(endPt.x - last.x, endPt.y - last.y)
                let tailSteps = max(1, Int(ceil(tailLen / 10.0)))
                for s in 1...tailSteps {
                    let t = CGFloat(s) / CGFloat(tailSteps)
                    curvePts.append(CGPoint(x: last.x + (endPt.x - last.x) * t, y: last.y + (endPt.y - last.y) * t))
                }
            }
        }

        let count = curvePts.count
        let samples: [TrailSample] = curvePts.enumerated().map { idx, pt in
            let frac = Double(idx) / Double(max(count - 1, 1))
            return TrailSample(point: pt, timestamp: futureBase - 0.18 * (1.0 - frac))
        }
        activeTrailSamples = samples
        DispatchQueue.main.asyncAfter(deadline: .now() + holdSeconds + 0.28) { [weak self] in
            guard let self, self.swipeGeneration == gen, !self.isSwiping else { return }
            self.activeTrailSamples = []
        }
    }

    private func hitTestCharacter(at point: CGPoint) -> String? {
        for (ch, rect) in keyFrames where ch.first?.isLetter == true || ch == "\u{02BC}" {
            let insetRect = rect.insetBy(dx: rect.width * 0.10, dy: rect.height * 0.10)
            if insetRect.contains(point) {
                return ch
            }
        }
        for (ch, rect) in keyFrames where (ch.first?.isLetter == true || ch == "\u{02BC}") && rect.contains(point) {
            return ch
        }
        var bestChar: String?
        var bestDist: CGFloat = 22.0
        for (ch, rect) in keyFrames where ch.first?.isLetter == true || ch == "\u{02BC}" {
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
        if case .character(let ch) = action, !ch.isEmpty {
            return ch
        }
        return nil
    }

    func captureLayoutFrame(from geo: GeometryProxy) {
        if itemFrame.width > 1 && itemFrame.height > 1 {
            cachedFrameBox.localFrame = itemFrame
            if let ch = characterKeyString {
                SwipeTypingState.shared.registerKeyFrame(character: ch, frame: itemFrame)
            }
            return
        }
        let local = geo.frame(in: .named(SwipeTypingState.coordinateSpaceName))
        if local.width > 1 && local.height > 1 {
            cachedFrameBox.localFrame = local
        } else if let inputSpace = calloutContext?.inputContext.coordinateSpace {
            let inputFrame = geo.frame(in: .named(inputSpace))
            if inputFrame.width > 1 && inputFrame.height > 1 {
                cachedFrameBox.localFrame = inputFrame
            }
        }
        let global = geo.frame(in: .global)
        if global.width > 1 && global.height > 1 {
            cachedFrameBox.globalFrame = global
        }
    }

    func resolveButtonFrame(in geo: GeometryProxy) -> CGRect? {
        if itemFrame.width > 1 && itemFrame.height > 1 {
            cachedFrameBox.localFrame = itemFrame
            return itemFrame
        }
        let local = geo.frame(in: .named(SwipeTypingState.coordinateSpaceName))
        if local.width > 1 && local.height > 1 {
            cachedFrameBox.localFrame = local
            return local
        }
        if let inputSpace = calloutContext?.inputContext.coordinateSpace {
            let inputFrame = geo.frame(in: .named(inputSpace))
            if inputFrame.width > 1 && inputFrame.height > 1 {
                cachedFrameBox.localFrame = inputFrame
                return inputFrame
            }
        }
        if cachedFrameBox.localFrame.width > 1 && cachedFrameBox.localFrame.height > 1 {
            return cachedFrameBox.localFrame
        }
        if let ch = characterKeyString,
           let registered = SwipeTypingState.shared.registeredKeyFrame(for: ch),
           registered.width > 1 && registered.height > 1 {
            return registered
        }
        let global = geo.frame(in: .global)
        let effectiveGlobal = (global.width > 1 && global.height > 1) ? global : cachedFrameBox.globalFrame
        if effectiveGlobal.width > 1 && effectiveGlobal.height > 1,
           let origin = calloutContext?.inputContext.containerGlobalOrigin {
            return CGRect(
                x: effectiveGlobal.origin.x - origin.x,
                y: effectiveGlobal.origin.y - origin.y,
                width: effectiveGlobal.width,
                height: effectiveGlobal.height
            )
        }
        return nil
    }

    @ViewBuilder
    func baseButton(for geo: GeometryProxy) -> some View {
        if isInScrollView {
            scrollButton(for: geo)
        } else {
            gestureButton(for: geo)
        }
    }

    @ViewBuilder
    func button(for geo: GeometryProxy) -> some View {
        baseButton(for: geo)
            .onAppear {
                captureLayoutFrame(from: geo)
                if let ch = characterKeyString {
                    let frame = resolveButtonFrame(in: geo) ?? geo.frame(in: .named(SwipeTypingState.coordinateSpaceName))
                    SwipeTypingState.shared.registerKeyFrame(character: ch, frame: frame)
                }
            }
            .onChange(of: geo.size) { _ in
                captureLayoutFrame(from: geo)
                if let ch = characterKeyString {
                    let frame = resolveButtonFrame(in: geo) ?? geo.frame(in: .named(SwipeTypingState.coordinateSpaceName))
                    SwipeTypingState.shared.registerKeyFrame(character: ch, frame: frame)
                }
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

    private var pressKeyID: String {
        if let ch = characterKeyString {
            return ch.lowercased(with: Locale(identifier: "tr"))
        }
        return "\(String(describing: action))"
    }

    func handleDoubleTap(in geo: GeometryProxy) {
        doubleTapAction?()
    }

    func handleDrag(in geo: GeometryProxy, value: DragGesture.Value) {
        lastDragValue = value
        if action == .backspace {
            let dx = value.location.x - value.startLocation.x
            let dy = value.location.y - value.startLocation.y
            if dx <= -28.0 && abs(dx) > abs(dy) * 1.5 {
                shouldApplyReleaseAction = false
            }
        }
        if !(calloutContext?.actionContext.isActive ?? false),
           (action == .keyboardType(.numeric) || SwipeTypingState.shared.canSlideFrom123) {
            let frame = resolveButtonFrame(in: geo) ?? geo.frame(in: .named(SwipeTypingState.coordinateSpaceName))
            let globalPoint = CGPoint(
                x: frame.origin.x + value.location.x,
                y: frame.origin.y + value.location.y
            )
            if !frame.insetBy(dx: -4, dy: -4).contains(globalPoint) {
                SwipeTypingState.shared.isSlideFrom123Active = true
                SwipeTypingState.shared.slideFrom123TargetChar = SwipeTypingState.shared.hitTestAnyKey(at: globalPoint)
                if isPressed.wrappedValue {
                    isPressed.wrappedValue = false
                }
                SwipeTypingState.shared.noteKeyReleased(pressKeyID)
                shouldApplyReleaseAction = false
                return
            } else {
                SwipeTypingState.shared.slideFrom123TargetChar = nil
            }
        }
        if let ch = characterKeyString, (ch.first?.isLetter == true || ch == "\u{02BC}"), SwipeTypingState.shared.isSwipeEnabled {
            let frame = resolveButtonFrame(in: geo) ?? geo.frame(in: .named(SwipeTypingState.coordinateSpaceName))
            SwipeTypingState.shared.registerKeyFrame(character: ch, frame: frame)
            let localDragDistance = hypot(
                value.location.x - value.startLocation.x,
                value.location.y - value.startLocation.y
            )
            if localDragDistance >= 6.0 {
                let globalPoint = CGPoint(
                    x: frame.origin.x + value.location.x,
                    y: frame.origin.y + value.location.y
                )
                let calloutActive = calloutContext?.actionContext.isActive ?? false
                let isSwipingNow = SwipeTypingState.shared.updateDrag(
                    pointInKeyboard: globalPoint,
                    isActionCalloutActive: calloutActive,
                    sourceChar: ch
                )
                if SwipeTypingState.shared.totalDragDistance >= 14.0 || isSwipingNow {
                    if isPressed.wrappedValue {
                        isPressed.wrappedValue = false
                    }
                    SwipeTypingState.shared.noteKeyReleased(pressKeyID)
                    calloutContext?.inputContext.reset()
                    calloutContext?.actionContext.reset()
                }
                if isSwipingNow {
                    shouldApplyReleaseAction = false
                    return
                }
            }
        }
        calloutContext?.actionContext.updateSelection(with: value.translation, location: value.location)
        dragAction?(value.startLocation, value.location)
    }

    func handleGestureEnded(in geo: GeometryProxy) {
        defer {
            SwipeTypingState.shared.noteKeyReleased(pressKeyID)
        }
        if SwipeTypingState.shared.isSlideFrom123Active {
            let targetChar = SwipeTypingState.shared.endSlideFrom123() ?? ""
            NotificationCenter.default.post(
                name: SwipeTypingState.didCompleteSlideFrom123Notification,
                object: nil,
                userInfo: ["char": targetChar]
            )
        } else {
            SwipeTypingState.shared.resetSlideFrom123()
        }
        let localDragDistance = lastDragValue.map {
            hypot($0.location.x - $0.startLocation.x, $0.location.y - $0.startLocation.y)
        } ?? 0
        if action == .backspace, let drag = lastDragValue {
            let dx = drag.location.x - drag.startLocation.x
            let dy = drag.location.y - drag.startLocation.y
            if dx <= -28.0 && abs(dx) > abs(dy) * 1.5 {
                NotificationCenter.default.post(name: Notification.Name("crh.key.backspaceSlideLeft"), object: nil)
            }
        }
        if localDragDistance >= 12.0 && (SwipeTypingState.shared.isSwiping || SwipeTypingState.shared.totalDragDistance >= 12.0) {
            if isPressed.wrappedValue {
                isPressed.wrappedValue = false
            }
            calloutContext?.inputContext.reset()
            calloutContext?.actionContext.reset()
            _ = SwipeTypingState.shared.endSwipe()
        } else if !SwipeTypingState.shared.isSwiping {
            SwipeTypingState.shared.reset(clearTrailImmediately: true)
        }
        endActionCallout()
        calloutContext?.inputContext.resetWithDelay()
        calloutContext?.actionContext.resetWithDelay()
        resetGestureState()
        NotificationCenter.default.post(name: Notification.Name("crh.key.gestureEnded"), object: nil)
    }

    func handleLongPress(in geo: GeometryProxy) {
        guard !SwipeTypingState.shared.isSwiping else { return }
        didTriggerLongPress = true
        tryBeginActionCallout(in: geo)
        longPressAction?()
    }

    func handlePress(in geo: GeometryProxy) {
        didTriggerLongPress = false
        if calloutContext?.actionContext.isActive == true {
            calloutContext?.actionContext.reset()
        }
        let resolvedFrame = resolveButtonFrame(in: geo)
        SwipeTypingState.shared.noteKeyPressed(pressKeyID)
        if action == .keyboardType(.numeric) {
            SwipeTypingState.shared.beginSlideFrom123()
        }
        let localGeoFrame = resolvedFrame ?? geo.frame(in: .named(SwipeTypingState.coordinateSpaceName))
        if let ch = characterKeyString, (ch.first?.isLetter == true || ch == "\u{02BC}"), SwipeTypingState.shared.isSwipeEnabled {
            SwipeTypingState.shared.registerKeyFrame(character: ch, frame: localGeoFrame)
            if !SwipeTypingState.shared.isSwiping {
                SwipeTypingState.shared.beginPotentialSwipe(
                    startChar: ch,
                    pointInKeyboard: CGPoint(x: localGeoFrame.midX, y: localGeoFrame.midY)
                )
            }
        }
        if localGeoFrame.width > 0 && localGeoFrame.height > 0 {
            calloutContext?.inputContext.updateInput(for: action, in: geo, fallbackFrame: resolvedFrame)
        }
        pressAction?()
    }

    func handleReleaseInside(in geo: GeometryProxy) {
        let localDragDistance = lastDragValue.map {
            hypot($0.location.x - $0.startLocation.x, $0.location.y - $0.startLocation.y)
        } ?? 0
        if localDragDistance >= 12.0 && (SwipeTypingState.shared.isSwiping || SwipeTypingState.shared.totalDragDistance >= 12.0) {
            return
        }
        updateShouldApplyReleaseAction()
        guard shouldApplyReleaseAction else { return }
        releaseAction?()
    }

    func handleReleaseOutside(in geo: GeometryProxy) {
        let localDragDistance = lastDragValue.map {
            hypot($0.location.x - $0.startLocation.x, $0.location.y - $0.startLocation.y)
        } ?? 0
        if localDragDistance >= 12.0 && (SwipeTypingState.shared.isSwiping || SwipeTypingState.shared.totalDragDistance >= 12.0) {
            return
        }
        if action == .space && didTriggerLongPress {
            handleReleaseInside(in: geo)
            return
        }
        guard shouldApplyReleaseOutsize(for: geo) else { return }
        handleReleaseInside(in: geo)
    }

    func handleRepeat(in geo: GeometryProxy) {
        guard !SwipeTypingState.shared.isSwiping else { return }
        if action == .backspace, let drag = lastDragValue {
            let dx = drag.location.x - drag.startLocation.x
            if dx <= -14.0 { return }
        }
        repeatAction?()
    }

    func tryBeginActionCallout(in geo: GeometryProxy) {
        guard !SwipeTypingState.shared.isSwiping else { return }
        let holdCalloutActive = CommandLine.arguments.contains("-qt_hold_callout")
            || (UserDefaults(suiteName: "group.crh.key.keyboardplus")?.bool(forKey: "crh.key.test.holdCallout") ?? false)
        if holdCalloutActive && characterKeyString?.lowercased(with: Locale(identifier: "tr")) == "s" {
            return
        }
        if let drag = lastDragValue {
            let dx = drag.location.x - drag.startLocation.x
            let dy = drag.location.y - drag.startLocation.y
            if action != .dismissKeyboard && dy >= 4.0 && dy > abs(dx) * 0.65 {
                return
            }
            if SwipeTypingState.shared.isSwipeEnabled && (hypot(dx, dy) >= 12.0 || SwipeTypingState.shared.totalDragDistance >= 12.0) {
                return
            }
        }
        guard let context = calloutContext?.actionContext else { return }
        context.updateInputs(for: action, in: geo, fallbackFrame: resolveButtonFrame(in: geo))
        guard context.isActive else { return }
        if let drag = lastDragValue, !CalloutContext.ActionContext.isOneHandedCalloutActions(context.actions) {
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
        didTriggerLongPress = false
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
        #if os(iOS)
        let extraDownwardFactor: CGFloat = UIDevice.current.userInterfaceIdiom == .pad ? 2.5 : 0.75
        #else
        let extraDownwardFactor: CGFloat = 0.75
        #endif
        rect.size.height += size.height * extraDownwardFactor
        return rect
    }
}
#endif
