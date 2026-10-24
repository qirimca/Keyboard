//
//  Gestures+SpaceDragGestureHandler.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-04-01.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import CoreGraphics

public extension Gestures {
    
    /// This custom gesture handler can handle the space key
    /// gesture that moves the input cursor.
    ///
    /// KeyboardKit will create an instance of the class and
    /// inject it into ``KeyboardInputViewController/state``.
    class SpaceDragGestureHandler: DragGestureHandler {
        
        /// Create a space drag gesture handler instance.
        ///
        /// - Parameters:
        ///   - sensitivity: The drag sensitivity, by default `.medium`.
        ///   - verticalThreshold: The vertical threshold in points, by default `50`.
        ///   - action: The action to perform when the offset changes.
        public init(
            sensitivity: Gestures.SpaceDragSensitivity = .medium,
            verticalThreshold: Double = 50,
            action: @escaping (Int) -> Void,
            verticalLineAction: ((Int) -> Void)? = nil
        ) {
            self.sensitivity = sensitivity
            self.verticalThreshold = verticalThreshold
            self.action = action
            self.verticalLineAction = verticalLineAction
        }
        
        
        /// The drag sensitivity.
        public var sensitivity: Gestures.SpaceDragSensitivity
        
        /// The vertical threshold in points.
        public var verticalThreshold: Double
        
        /// The action to perform when the horizontal character offset changes.
        public var action: (Int) -> Void

        /// The action to perform when the vertical line offset changes.
        public var verticalLineAction: ((Int) -> Void)?
        
        
        /// The location where the current drag stated.
        public var currentDragStartLocation: CGPoint?

        /// The last sampled location during the active drag gesture.
        private var lastDragSampleLocation: CGPoint?
        
        /// The currently applied drag text position offset.
        public var currentDragTextPositionOffset: Int = 0

        /// The currently applied vertical line offset.
        public var currentDragVerticalLineOffset: Int = 0

        private var accumulatedHorizontalDistance: CGFloat = 0
        private var accumulatedVerticalDistance: CGFloat = 0
        
        /// Handle a 2D drag gesture on space, which by default
        /// activates after a long press and moves the cursor horizontally and vertically.
        /// Uses dominant-axis locking per sample so vertical line movement goes straight up/down
        /// without horizontal drift or resetting `preferredXPt`.
        public func handleDragGesture(
            from startLocation: CGPoint,
            to currentLocation: CGPoint
        ) {
            tryStartNewDragGesture(from: startLocation, to: currentLocation)
            let prev = lastDragSampleLocation ?? startLocation
            lastDragSampleLocation = currentLocation
            let stepDX = currentLocation.x - prev.x
            let stepDY = currentLocation.y - prev.y

            if abs(stepDY) > abs(stepDX) * 1.15 {
                accumulatedVerticalDistance += stepDY
                let lineStepHeight: CGFloat = 22.0
                let verticalLineOffset = Int(accumulatedVerticalDistance / lineStepHeight)
                if verticalLineOffset != currentDragVerticalLineOffset {
                    let lineDelta = verticalLineOffset - currentDragVerticalLineOffset
                    currentDragVerticalLineOffset = verticalLineOffset
                    verticalLineAction?(lineDelta)
                }
            } else {
                accumulatedHorizontalDistance += stepDX
                let textPositionOffset = Int(accumulatedHorizontalDistance / CGFloat(sensitivity.points))
                if textPositionOffset != currentDragTextPositionOffset {
                    let offsetDelta = textPositionOffset - currentDragTextPositionOffset
                    currentDragTextPositionOffset = textPositionOffset
                    #if os(iOS) || os(tvOS) || os(visionOS)
                    UITextDocumentProxyVerticalState.resetPreferredX()
                    #endif
                    action(offsetDelta)
                }
            }
        }
    }
}

#if os(iOS) || os(tvOS) || os(visionOS)
import UIKit

enum UITextDocumentProxyVerticalState {
    static var preferredXPt: CGFloat?
    static var lastStepTimestamp: TimeInterval = 0

    static func resetPreferredX() {
        preferredXPt = nil
        lastStepTimestamp = 0
    }

    struct VisualLineSpan {
        let start: Int
        let end: Int
        let rect: CGRect
        let endsWithHardNewline: Bool
    }

    /// Uses UIKit's real TextKit engine (`NSTextStorage` + `NSLayoutManager` + `NSTextContainer`)
    /// with the standard iOS body font (`UIFont.systemFont(ofSize: 17)`) to compute exact word-wrapped
    /// visual line spans and glyph X coordinates matching `UITextView` / `UITextField`.
    static func computeWordWrappedVisualLines(
        text: String,
        usableWidthPt: CGFloat,
        layoutManagerOut: inout NSLayoutManager?,
        textContainerOut: inout NSTextContainer?
    ) -> [VisualLineSpan] {
        let font = UIFont.systemFont(ofSize: 17.0)
        let storage = NSTextStorage(string: text, attributes: [.font: font])
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: max(120.0, usableWidthPt), height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layoutManager.addTextContainer(container)
        storage.addLayoutManager(layoutManager)
        layoutManager.ensureLayout(for: container)

        layoutManagerOut = layoutManager
        textContainerOut = container

        let nsString = text as NSString
        guard nsString.length > 0 else {
            return [VisualLineSpan(start: 0, end: 0, rect: CGRect(x: 0, y: 0, width: usableWidthPt, height: 22), endsWithHardNewline: false)]
        }

        var lines: [VisualLineSpan] = []
        let glyphRange = layoutManager.glyphRange(for: container)
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, lineGlyphRange, _ in
            let charRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
            let start = charRange.location
            var end = charRange.location + charRange.length
            var hardNL = false
            if end > start && nsString.character(at: end - 1) == 10 {
                end -= 1
                hardNL = true
            }
            lines.append(VisualLineSpan(start: start, end: end, rect: rect, endsWithHardNewline: hardNL))
        }

        if nsString.character(at: nsString.length - 1) == 10 {
            let lastY = lines.last?.rect.maxY ?? 0
            lines.append(VisualLineSpan(start: nsString.length, end: nsString.length, rect: CGRect(x: 0, y: lastY, width: usableWidthPt, height: 22), endsWithHardNewline: false))
        }
        return lines
    }
}

public extension UITextDocumentProxy {

    /// Moves the cursor vertically across lines using UIKit's real `NSLayoutManager` + `NSTextContainer`
    /// (`computeWordWrappedVisualLines`) and locked `preferredXPt` so vertical movement goes straight
    /// up/down without left/right drift.
    func adjustVerticalLinePosition(by lineDelta: Int, containerWidth: CGFloat = 0) {
        guard lineDelta != 0 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - UITextDocumentProxyVerticalState.lastStepTimestamp > 1.5 {
            UITextDocumentProxyVerticalState.preferredXPt = nil
        }
        UITextDocumentProxyVerticalState.lastStepTimestamp = now

        let rawWidth = containerWidth > 0 ? containerWidth : UIScreen.main.bounds.width
        let usableLineWidthPt = max(140.0, rawWidth - 56.0)
        let steps = abs(lineDelta)
        let movingDown = lineDelta > 0

        for _ in 0..<steps {
            let fullBefore = documentContextBeforeInput ?? ""
            let fullAfter = documentContextAfterInput ?? ""
            if !movingDown && fullBefore.isEmpty { break }
            if movingDown && fullAfter.isEmpty { break }

            let combinedString = fullBefore + fullAfter
            let nsCombined = combinedString as NSString
            let cursorUTF16 = (fullBefore as NSString).length

            var lm: NSLayoutManager?
            var tc: NSTextContainer?
            let lines = UITextDocumentProxyVerticalState.computeWordWrappedVisualLines(
                text: combinedString,
                usableWidthPt: usableLineWidthPt,
                layoutManagerOut: &lm,
                textContainerOut: &tc
            )
            guard !lines.isEmpty, let layoutManager = lm, let textContainer = tc else { break }

            var currentLineIdx = 0
            for (idx, line) in lines.enumerated() {
                if cursorUTF16 >= line.start && cursorUTF16 <= line.end {
                    currentLineIdx = idx
                    if cursorUTF16 < line.end || idx == lines.count - 1 || line.endsWithHardNewline {
                        break
                    }
                }
            }

            let currentLine = lines[currentLineIdx]
            let currentXPt: CGFloat = {
                guard cursorUTF16 > currentLine.start else { return 0 }
                let clampedCharIdx = min(cursorUTF16, max(0, nsCombined.length - 1))
                let glyphIdx = layoutManager.glyphIndexForCharacter(at: clampedCharIdx)
                let loc = layoutManager.location(forGlyphAt: glyphIdx)
                if cursorUTF16 == nsCombined.length && !currentLine.endsWithHardNewline {
                    let prevRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIdx, length: 1), in: textContainer)
                    return prevRect.maxX
                }
                return loc.x
            }()

            let targetXPt = UITextDocumentProxyVerticalState.preferredXPt ?? currentXPt
            UITextDocumentProxyVerticalState.preferredXPt = targetXPt

            let targetLineIdx = movingDown ? (currentLineIdx + 1) : (currentLineIdx - 1)
            guard targetLineIdx >= 0 && targetLineIdx < lines.count else {
                let edgeCharDelta = movingDown ? fullAfter.count : -fullBefore.count
                if edgeCharDelta != 0 {
                    adjustTextPosition(byCharacterOffset: edgeCharDelta)
                }
                break
            }

            let targetLine = lines[targetLineIdx]
            let targetPoint = CGPoint(x: targetXPt, y: targetLine.rect.midY)
            var fraction: CGFloat = 0
            var targetUTF16 = layoutManager.characterIndex(
                for: targetPoint,
                in: textContainer,
                fractionOfDistanceBetweenInsertionPoints: &fraction
            )
            if fraction >= 0.5 && targetUTF16 < targetLine.end {
                targetUTF16 += 1
            }
            targetUTF16 = max(targetLine.start, min(targetUTF16, targetLine.end))
            if targetUTF16 == targetLine.end && targetLine.end > targetLine.start && !targetLine.endsWithHardNewline && targetLineIdx < lines.count - 1 {
                if nsCombined.character(at: targetLine.end - 1) == 32 {
                    targetUTF16 = max(targetLine.start, targetLine.end - 1)
                }
            }

            let cursorCharIdx = fullBefore.count
            let targetStringPrefix = nsCombined.substring(to: min(targetUTF16, nsCombined.length))
            let targetCharIdx = targetStringPrefix.count
            let charDelta = targetCharIdx - cursorCharIdx
            if charDelta != 0 {
                adjustTextPosition(byCharacterOffset: charDelta)
            }
        }
    }

    /// This drag offset is used when the gesture moves over
    /// a combined emoji.
    func spaceDragOffset(for rawOffset: Int) -> Int? {
        let multiplier = spaceDragOffsetMultiplier(for: rawOffset)
        return rawOffset * (multiplier ?? 1)
    }

    /// This offset muliplier is used when the gesture moves
    /// over a combined emoji.
    func spaceDragOffsetMultiplier(for offset: Int) -> Int? {
        let char = spaceDragOffsetMultiplierCharacter(for: offset)
        return char?.spaceDragOffsetMultiplier
    }

    /// This character is used when the gesture moves over a
    /// combined emoji.
    func spaceDragOffsetMultiplierCharacter(for offset: Int) -> String.Element? {
        if offset == 1 { return documentContextAfterInput?.first }
        if offset == -1 { return documentContextBeforeInput?.last }
        return nil
    }
}
#endif

extension String.Element {

    /// This offset muliplier is used when the gesture moves
    /// over a combined emoji.
    var spaceDragOffsetMultiplier: Int {
        guard isEmoji else { return 1 }
        return Int(floor(Double(utf8.count)/2))
    }
}

private extension Gestures.SpaceDragGestureHandler {

    func tryStartNewDragGesture(
        from startLocation: CGPoint,
        to currentLocation: CGPoint
    ) {
        let isNewDrag = currentDragStartLocation != startLocation
        currentDragStartLocation = startLocation
        guard isNewDrag else { return }
        lastDragSampleLocation = startLocation
        currentDragTextPositionOffset = 0
        currentDragVerticalLineOffset = 0
        accumulatedHorizontalDistance = 0
        accumulatedVerticalDistance = 0
        #if os(iOS) || os(tvOS) || os(visionOS)
        UITextDocumentProxyVerticalState.resetPreferredX()
        #endif
    }
}
