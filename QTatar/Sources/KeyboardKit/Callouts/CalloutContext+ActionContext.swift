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
            let standardStyle = Callouts.ActionCalloutStyle.standard
            let singleRowHeight: CGFloat = 44 + 2 * standardStyle.verticalTextPadding
            let bubbleBottomLocalY: CGFloat = standardStyle.verticalOffset - standardStyle.callout.buttonInset.height
            let localY: CGFloat = location?.y ?? (buttonFrame.height * 0.5 + value.height)
            let distanceAboveBubbleBottom = bubbleBottomLocalY - localY

            let currentIndex = isIndexValid(self.selectedIndex) ? self.selectedIndex : 0
            var newIndex = currentIndex
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

            if self.selectedIndex != newIndex {
                triggerHapticFeedbackForSelectionChange()
            }
            self.selectedIndex = newIndex
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
}


// MARK: - Private functionality

private extension CalloutContext.ActionContext {

    static func isMenuCalloutActions(_ actions: [KeyboardAction]) -> Bool {
        actions.contains {
            if case .custom(let name) = $0 {
                return name == "floating_keyboard" || name == "split_keyboard" || name == "merge_keyboard"
            }
            return false
        }
    }
    
    var startIndex: Int {
        isLeading ? 0 : actions.count - 1
    }
    
    func isIndexValid(_ index: Int) -> Bool {
        index >= 0 && index < actions.count
    }
    
    func getAlignment(for geo: GeometryProxy) -> HorizontalAlignment {
        #if os(iOS)
        let width = containerWidth > 0 ? containerWidth : UIScreen.main.bounds.size.width
        let isTrailing = buttonFrame.midX > width / 2
        return isTrailing ? .trailing : .leading
        #else
        return .leading
        #endif
    }
    
    func shouldReset(for dragTranslation: CGSize) -> Bool {
        dragTranslation.height > buttonFrame.height
    }
    
    func shouldUpdateSelection(for dragTranslation: CGSize) -> Bool {
        let translation = dragTranslation.width
        if translation == 0 { return true }
        return isLeading ? translation > 0 : translation < 0
    }
}
