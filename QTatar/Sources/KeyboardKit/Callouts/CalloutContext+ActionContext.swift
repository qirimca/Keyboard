//
//  CalloutContext+ActionContext.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-01-06.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import Combine
import SwiftUI

public extension CalloutContext {
    
    /// This class provides observable action callout state.
    class ActionContext: ObservableObject {
        
        /// Create an action callout context instance.
        ///
        /// - Parameters:
        ///   - actionProvider: The action provider to use, if any.
        ///   - tapAction: The action to perform when tapping an action.
        public init(
            actionProvider: CalloutActionProvider?,
            tapAction: @escaping (KeyboardAction) -> Void
        ) {
            self.actionProvider = actionProvider
            self.tapAction = tapAction
        }
        
        
        /// The coordinate space to use for callout.
        public let coordinateSpace = "com.keyboardkit.coordinate.ActionCallout"
        
        
        /// The action handler to use when tapping buttons.
        public var tapAction: (KeyboardAction) -> Void
        
        /// The action provider to use for resolving actions.
        public var actionProvider: CalloutActionProvider?
        
        
        /// The currently active actions.
        @Published
        public private(set) var actions: [KeyboardAction] = []
        
        /// The callout bubble alignment.
        @Published
        public private(set) var alignment: HorizontalAlignment = .leading
        
        /// The frame of the currently pressed button.
        @Published
        public private(set) var buttonFrame: CGRect = .zero

        /// Width of the named coordinate-space container, including floating keyboards.
        public var containerWidth: CGFloat = 0

        /// Available vertical space above the key grid inside UIInputViewController.view (e.g. suggestion toolbar height).
        public var topAvailableSpace: CGFloat = 0
        
        /// The currently selected action index.
        @Published
        public private(set) var selectedIndex: Int = -1
    }
    
}


// MARK: - Public functionality

public extension CalloutContext.ActionContext {
    
    /// Whether or not the context has a selected action.
    var hasSelectedAction: Bool { selectedAction != nil }
    
    /// Whether or not the context currently has actions.
    var isActive: Bool { !actions.isEmpty }
    
    /// Whether or not the action callout is leading.
    var isLeading: Bool { !isTrailing }
    
    /// Whether or not the action callout is trailing.
    var isTrailing: Bool { alignment == .trailing }
    
    /// The currently selected callout action, if any.
    var selectedAction: KeyboardAction? {
        isIndexValid(selectedIndex) ? actions[selectedIndex] : nil
    }
    
    
    /// End the drag gesture by commiting and resetting.
    func endDragGesture() {
        handleSelectedAction()
        reset()
    }

    /// Explicitly select an action index and trigger it immediately.
    func selectAndTrigger(index: Int) {
        if isIndexValid(index) {
            selectedIndex = index
        }
        handleSelectedAction()
        reset()
    }
    
    /// Handle the currently selected action, if any.
    func handleSelectedAction() {
        guard let action = selectedAction else { return }
        tapAction(action)
    }
    
    /// Reset the context. This will dismiss the callout.
    func reset() {
        actions = []
        selectedIndex = -1
        buttonFrame = .zero
    }
    
    /// Trigger haptic feedback for selection change.
    func triggerHapticFeedbackForSelectionChange() {
        HapticFeedback.selectionChanged.trigger()
    }
    
    /// Update the input actions for a certain action.
    func updateInputs(for action: KeyboardAction?, in geo: GeometryProxy, alignment: HorizontalAlignment? = nil) {
        guard let action = action else { return reset() }
        guard let actions = actionProvider?.calloutActions(for: action) else { return }
        self.buttonFrame = geo.frame(in: .named(coordinateSpace))
        self.alignment = alignment ?? getAlignment(for: geo)
        if Self.isMenuCalloutActions(actions) {
            self.actions = actions
            self.selectedIndex = actions.isEmpty ? -1 : 0
        } else if Self.isOneHandedCalloutActions(actions) {
            self.actions = actions
            let suite = UserDefaults(suiteName: "group.crh.key.keyboardplus")
            let mode = suite?.string(forKey: "crh.key.oneHandedMode") ?? "off"
            switch mode {
            case "left": self.selectedIndex = 0
            case "right": self.selectedIndex = min(2, max(0, actions.count - 1))
            default: self.selectedIndex = min(1, max(0, actions.count - 1))
            }
        } else {
            self.actions = isLeading ? actions : actions.reversed()
            self.selectedIndex = startIndex
        }
        guard isActive else { return }
        triggerHapticFeedbackForSelectionChange()
    }
    
    /// Update the selected action for a drag gesture.
    func updateSelection(with dragTranslation: CGSize?, location: CGPoint? = nil) {
        guard let value = dragTranslation, buttonFrame != .zero, !actions.isEmpty else { return }
        if shouldReset(for: value) { return reset() }
        if Self.isMenuCalloutActions(actions) {
            guard actions.count > 1 else {
                self.selectedIndex = 0
                return
            }
            let standardStyle = Callouts.ActionCalloutStyle.standard
            let singleRowHeight: CGFloat = 42 + 2 * standardStyle.verticalTextPadding
            let bubbleBottomLocalY: CGFloat = standardStyle.verticalOffset - standardStyle.callout.buttonInset.height
            let localY: CGFloat = location?.y ?? (buttonFrame.height * 0.5 + value.height)
            let distanceAboveBubbleBottom = bubbleBottomLocalY - localY

            let currentIndex = isIndexValid(self.selectedIndex) ? self.selectedIndex : 0
            var newIndex = currentIndex

            if actions.count == 2 {
                if currentIndex == 0 {
                    if localY <= -28 {
                        newIndex = 1
                    }
                } else {
                    if localY > -20 {
                        newIndex = 0
                    }
                }
            } else {
                let upwardHysteresis: CGFloat = 2
                let downwardHysteresis: CGFloat = 8
                while newIndex < actions.count - 1 {
                    let divider = CGFloat(newIndex + 1) * singleRowHeight
                    if distanceAboveBubbleBottom >= divider + upwardHysteresis {
                        newIndex += 1
                    } else {
                        break
                    }
                }
                while newIndex > 0 {
                    let divider = CGFloat(newIndex) * singleRowHeight
                    if distanceAboveBubbleBottom < divider - downwardHysteresis {
                        newIndex -= 1
                    } else {
                        break
                    }
                }
            }

            if self.selectedIndex != newIndex {
                triggerHapticFeedbackForSelectionChange()
            }
            self.selectedIndex = newIndex
            return
        }
        if Self.isOneHandedCalloutActions(actions) {
            guard abs(value.width) > 4 || value.height < -8 || (location?.y ?? 0) < -4 else { return }
            let limitedWidth = min(buttonFrame.width, Callouts.ActionCalloutStyle.standard.maxButtonSize.width)
            let cellPitch: CGFloat = max(limitedWidth * 1.12, 46)
            let clamped: Int
            if let loc = location {
                if isLeading {
                    if loc.x < cellPitch {
                        clamped = 0
                    } else if loc.x < cellPitch * 2.0 {
                        clamped = min(1, actions.count - 1)
                    } else {
                        clamped = actions.count - 1
                    }
                } else {
                    let distFromRight = buttonFrame.width - loc.x
                    if distFromRight < cellPitch {
                        clamped = actions.count - 1
                    } else if distFromRight < cellPitch * 2.0 {
                        clamped = max(0, actions.count - 2)
                    } else {
                        clamped = 0
                    }
                }
            } else {
                let deltaCells = Int((value.width / cellPitch).rounded())
                let baseIndex = isLeading ? 0 : actions.count - 1
                clamped = min(max(baseIndex + deltaCells, 0), actions.count - 1)
            }
            if self.selectedIndex != clamped {
                triggerHapticFeedbackForSelectionChange()
            }
            self.selectedIndex = clamped
            return
        }
        guard shouldUpdateSelection(for: value) else { return }
        let translation = value.width
        let standardStyle = Callouts.ActionCalloutStyle.standard
        let maxButtonSize = standardStyle.maxButtonSize
        let buttonSize = buttonFrame.size.limited(to: maxButtonSize)
        let indexWidth = 0.9 * buttonSize.width
        let offset = Int(abs(translation) / max(indexWidth, 1))
        let rawIndex = isLeading ? offset : actions.count - offset - 1
        let clampedIndex = min(max(rawIndex, 0), actions.count - 1)
        let currentIndex = self.selectedIndex
        let newIndex = isIndexValid(clampedIndex) ? clampedIndex : startIndex
        if currentIndex != newIndex { triggerHapticFeedbackForSelectionChange() }
        self.selectedIndex = newIndex
    }
}


// MARK: - Context builders

public extension CalloutContext.ActionContext {
    
    /// This context can be used to disable action callouts.
    static var disabled: CalloutContext.ActionContext {
        .init(
            actionProvider: nil,
            tapAction: { _ in }
        )
    }

    static func isMenuCalloutActions(_ actions: [KeyboardAction]) -> Bool {
        actions.contains {
            if case .custom(let name) = $0 {
                return name == "floating_keyboard" || name == "split_keyboard" || name == "merge_keyboard" || name == "dock_keyboard"
            }
            return false
        }
    }

    static func isOneHandedCalloutActions(_ actions: [KeyboardAction]) -> Bool {
        actions.contains {
            if case .custom(let name) = $0 {
                return name == "one_handed_left" || name == "one_handed_right" || name == "one_handed_off"
            }
            return false
        }
    }
}


// MARK: - Private functionality

private extension CalloutContext.ActionContext {
    
    var startIndex: Int {
        isLeading ? 0 : actions.count - 1
    }
    
    func isIndexValid(_ index: Int) -> Bool {
        index >= 0 && index < actions.count
    }
    
    func getAlignment(for geo: GeometryProxy) -> HorizontalAlignment {
        #if os(iOS)
        if containerWidth > 0 {
            return (buttonFrame.midX > containerWidth / 2) ? .trailing : .leading
        }
        let width = UIScreen.main.bounds.size.width
        let suite = UserDefaults(suiteName: "group.crh.key.keyboardplus")
        let mode = suite?.string(forKey: "crh.key.oneHandedMode") ?? "off"
        let midpoint: CGFloat
        switch mode {
        case "left": midpoint = width * 0.41
        case "right": midpoint = width * 0.59
        default: midpoint = width * 0.5
        }
        let isTrailing = buttonFrame.midX > midpoint
        return isTrailing ? .trailing : .leading
        #else
        return .leading
        #endif
    }
    
    func shouldReset(for dragTranslation: CGSize) -> Bool {
        if Self.isMenuCalloutActions(actions) || Self.isOneHandedCalloutActions(actions) {
            return dragTranslation.height > buttonFrame.height * 1.5
        }
        return dragTranslation.height > buttonFrame.height
    }
    
    func shouldUpdateSelection(for dragTranslation: CGSize) -> Bool {
        let translation = dragTranslation.width
        if Self.isOneHandedCalloutActions(actions) {
            return abs(translation) >= 6
        }
        if translation == 0 { return true }
        return isLeading ? translation > 0 : translation < 0
    }
}
