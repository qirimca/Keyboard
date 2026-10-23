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

public extension UITextDocumentProxy {

    /// Moves the cursor vertically across lines (hard newlines or soft-wrapped ~42-char visual lines)
    /// when dragging vertically in 2D spacebar trackpad mode.
    func adjustVerticalLinePosition(by lineDelta: Int) {
        guard lineDelta != 0 else { return }
        let steps = abs(lineDelta)
        let movingDown = lineDelta > 0
        for _ in 0..<steps {
            let before = documentContextBeforeInput ?? ""
            let after = documentContextAfterInput ?? ""
            if !movingDown {
                guard !before.isEmpty else { break }
                if let lastNewline = before.lastIndex(of: "\n") {
                    let currentCol = before.distance(from: before.index(after: lastNewline), to: before.endIndex)
                    if currentCol >= 48 {
                        adjustTextPosition(byCharacterOffset: -42)
                    } else {
                        let prefixBeforeNewline = before[..<lastNewline]
                        let prevLineStart = prefixBeforeNewline.lastIndex(of: "\n")
                            .map { prefixBeforeNewline.index(after: $0) }
                            ?? prefixBeforeNewline.startIndex
                        let prevLineLen = prefixBeforeNewline.distance(from: prevLineStart, to: prefixBeforeNewline.endIndex)
                        let targetCol = min(currentCol, prevLineLen)
                        let charsBack = currentCol + 1 + (prevLineLen - targetCol)
                        adjustTextPosition(byCharacterOffset: -max(charsBack, 1))
                    }
                } else {
                    adjustTextPosition(byCharacterOffset: -min(before.count, 42))
                }
            } else {
                guard !after.isEmpty else { break }
                let currentCol: Int = {
                    if let lastNewline = before.lastIndex(of: "\n") {
                        return before.distance(from: before.index(after: lastNewline), to: before.endIndex)
                    }
                    return before.count
                }()
                if let nextNewline = after.firstIndex(of: "\n") {
                    let charsToNewline = after.distance(from: after.startIndex, to: nextNewline)
                    if charsToNewline >= 48 {
                        adjustTextPosition(byCharacterOffset: 42)
                    } else {
                        let suffixAfterNewline = after[after.index(after: nextNewline)...]
                        let nextLineEnd = suffixAfterNewline.firstIndex(of: "\n") ?? suffixAfterNewline.endIndex
                        let nextLineLen = suffixAfterNewline.distance(from: suffixAfterNewline.startIndex, to: nextLineEnd)
                        let targetCol = min(currentCol, nextLineLen)
                        let charsForward = charsToNewline + 1 + targetCol
                        adjustTextPosition(byCharacterOffset: max(charsForward, 1))
                    }
                } else {
                    adjustTextPosition(byCharacterOffset: min(after.count, 42))
                }
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
    }
}
