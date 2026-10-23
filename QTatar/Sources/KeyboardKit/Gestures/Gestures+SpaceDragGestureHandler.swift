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
        
        /// The currently applied drag text position offset.
        public var currentDragTextPositionOffset: Int = 0

        /// The currently applied vertical line offset.
        public var currentDragVerticalLineOffset: Int = 0
        
        /// Handle a 2D drag gesture on space, which by default
        /// activates after a long press and moves the cursor horizontally and vertically.
        public func handleDragGesture(
            from startLocation: CGPoint,
            to currentLocation: CGPoint
        ) {
            tryStartNewDragGesture(from: startLocation, to: currentLocation)
            let dragDelta = startLocation.x - currentLocation.x
            let textPositionOffset = Int(dragDelta / CGFloat(sensitivity.points))
            if textPositionOffset != currentDragTextPositionOffset {
                let offsetDelta = textPositionOffset - currentDragTextPositionOffset
                currentDragTextPositionOffset = textPositionOffset
                #if os(iOS) || os(tvOS) || os(visionOS)
                UITextDocumentProxyVerticalState.resetPreferredX()
                #endif
                action(-offsetDelta)
            }
            let verticalDragDelta = currentLocation.y - startLocation.y
            let lineStepHeight: CGFloat = 22.0
            let verticalLineOffset = Int(verticalDragDelta / lineStepHeight)
            if verticalLineOffset != currentDragVerticalLineOffset {
                let lineDelta = verticalLineOffset - currentDragVerticalLineOffset
                currentDragVerticalLineOffset = verticalLineOffset
                verticalLineAction?(lineDelta)
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
        let endsWithHardNewline: Bool
    }

    static func glyphAdvancePt(for ch: Character) -> CGFloat {
        if ch == "\n" { return 0 }
        if ch == " " { return 4.6 }
        if ch.unicodeScalars.first?.properties.isEmojiPresentation == true { return 18.0 }
        switch ch {
        case "i", "l", "ı", "İ", "I", "j", "t", "f", "r", "і", "ї", ".", ",", ":", ";", "!", "|", "'", "ʼ", "’", "-", "(", ")":
            return 5.1
        case "m", "w", "M", "W", "Ш", "Щ", "Ю", "Ж", "Ф", "Ы", "ш", "щ", "ю", "ж", "ф", "ы", "Q", "Ğ", "Ö", "Ü":
            return 12.2
        default:
            if ch.isUppercase { return 10.6 }
            return 8.6
        }
    }

    static func visualXOffset(in chars: [Character], from start: Int, to index: Int) -> CGFloat {
        guard index > start else { return 0 }
        var x: CGFloat = 0
        let upper = min(index, chars.count)
        for i in start..<upper {
            x += glyphAdvancePt(for: chars[i])
        }
        return x
    }

    static func characterIndex(
        in chars: [Character],
        lineStart: Int,
        lineEnd: Int,
        matchingVisualXPt targetX: CGFloat
    ) -> Int {
        guard lineEnd > lineStart else { return lineStart }
        var x: CGFloat = 0
        var bestIdx = lineStart
        var bestDist = abs(targetX)
        for i in lineStart..<lineEnd {
            let adv = glyphAdvancePt(for: chars[i])
            x += adv
            let dist = abs(x - targetX)
            if dist <= bestDist {
                bestDist = dist
                bestIdx = i + 1
            } else {
                break
            }
        }
        if bestIdx == lineEnd && lineEnd < chars.count && chars[lineEnd - 1] == " " && chars[lineEnd] != "\n" {
            return max(lineStart, lineEnd - 1)
        }
        return bestIdx
    }

    static func computeWordWrappedVisualLines(
        chars: [Character],
        usableWidthPt: CGFloat
    ) -> [VisualLineSpan] {
        guard !chars.isEmpty else {
            return [VisualLineSpan(start: 0, end: 0, endsWithHardNewline: false)]
        }
        var lines: [VisualLineSpan] = []
        var lineStart = 0
        var lineWidth: CGFloat = 0
        var lastBreakCandidate: Int? = nil
        var widthAtLastBreak: CGFloat = 0
        var i = 0

        while i < chars.count {
            let ch = chars[i]
            if ch == "\n" {
                lines.append(VisualLineSpan(start: lineStart, end: i, endsWithHardNewline: true))
                i += 1
                lineStart = i
                lineWidth = 0
                lastBreakCandidate = nil
                widthAtLastBreak = 0
                continue
            }

            let adv = glyphAdvancePt(for: ch)
            if ch == " " || ch == "-" {
                lastBreakCandidate = i + 1
                widthAtLastBreak = lineWidth + adv
            }

            if lineWidth + adv > usableWidthPt && i > lineStart {
                if let breakIdx = lastBreakCandidate, breakIdx > lineStart && breakIdx <= i {
                    lines.append(VisualLineSpan(start: lineStart, end: breakIdx, endsWithHardNewline: false))
                    lineStart = breakIdx
                    lineWidth = (lineWidth + adv) - widthAtLastBreak
                    lastBreakCandidate = nil
                    widthAtLastBreak = 0
                    i += 1
                } else {
                    lines.append(VisualLineSpan(start: lineStart, end: i, endsWithHardNewline: false))
                    lineStart = i
                    lineWidth = adv
                    lastBreakCandidate = nil
                    widthAtLastBreak = 0
                    i += 1
                }
            } else {
                lineWidth += adv
                i += 1
            }
        }

        lines.append(VisualLineSpan(start: lineStart, end: chars.count, endsWithHardNewline: false))
        return lines
    }
}

public extension UITextDocumentProxy {

    /// Moves the cursor vertically across lines (hard newlines and word-wrapped visual lines sized
    /// dynamically to the active window/container width and proportional glyph advances) when dragging
    /// vertically in 2D spacebar trackpad mode.
    func adjustVerticalLinePosition(by lineDelta: Int, containerWidth: CGFloat = 0) {
        guard lineDelta != 0 else { return }
        let now = ProcessInfo.processInfo.systemUptime
        if now - UITextDocumentProxyVerticalState.lastStepTimestamp > 1.2 {
            UITextDocumentProxyVerticalState.preferredXPt = nil
        }
        UITextDocumentProxyVerticalState.lastStepTimestamp = now

        let rawWidth = containerWidth > 0 ? containerWidth : UIScreen.main.bounds.width
        let usableLineWidthPt = max(140.0, rawWidth - 36.0)
        let steps = abs(lineDelta)
        let movingDown = lineDelta > 0

        for _ in 0..<steps {
            let fullBefore = documentContextBeforeInput ?? ""
            let fullAfter = documentContextAfterInput ?? ""
            if !movingDown && fullBefore.isEmpty { break }
            if movingDown && fullAfter.isEmpty { break }

            let beforeSlice = String(fullBefore.suffix(600))
            let afterSlice = String(fullAfter.prefix(600))
            let combined = Array(beforeSlice + afterSlice)
            let cursorIdx = beforeSlice.count

            let lines = UITextDocumentProxyVerticalState.computeWordWrappedVisualLines(chars: combined, usableWidthPt: usableLineWidthPt)
            guard !lines.isEmpty else { break }

            var currentLineIdx = 0
            for (idx, line) in lines.enumerated() {
                if cursorIdx >= line.start && cursorIdx <= line.end {
                    currentLineIdx = idx
                    if cursorIdx < line.end || idx == lines.count - 1 || line.endsWithHardNewline {
                        break
                    }
                }
            }

            let currentLine = lines[currentLineIdx]
            let currentXPt = UITextDocumentProxyVerticalState.visualXOffset(in: combined, from: currentLine.start, to: min(cursorIdx, currentLine.end))
            let targetXPt = UITextDocumentProxyVerticalState.preferredXPt ?? currentXPt
            UITextDocumentProxyVerticalState.preferredXPt = targetXPt

            let targetLineIdx = movingDown ? (currentLineIdx + 1) : (currentLineIdx - 1)
            guard targetLineIdx >= 0 && targetLineIdx < lines.count else {
                let edgeDelta = movingDown ? afterSlice.count : -beforeSlice.count
                if edgeDelta != 0 {
                    adjustTextPosition(byCharacterOffset: edgeDelta)
                }
                break
            }

            let targetLine = lines[targetLineIdx]
            let targetCharIdx = UITextDocumentProxyVerticalState.characterIndex(
                in: combined,
                lineStart: targetLine.start,
                lineEnd: targetLine.end,
                matchingVisualXPt: targetXPt
            )
            let charDelta = targetCharIdx - cursorIdx
            if charDelta != 0 {
                adjustTextPosition(byCharacterOffset: charDelta)
            } else {
                adjustTextPosition(byCharacterOffset: movingDown ? 1 : -1)
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
        currentDragTextPositionOffset = 0
        currentDragVerticalLineOffset = 0
        #if os(iOS) || os(tvOS) || os(visionOS)
        UITextDocumentProxyVerticalState.resetPreferredX()
        #endif
    }
}
