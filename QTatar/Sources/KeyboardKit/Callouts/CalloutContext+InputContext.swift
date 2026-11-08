//
//  CalloutContext+InputContext.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-01-06.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import Combine
import Foundation
import SwiftUI

public extension CalloutContext {
    
    /// This class provides observable input callout state.
    class InputContext: ObservableObject {
        
        /// Create an input callout context instance.
        ///
        /// - Parameters:
        ///   - isEnabled: Whether or not input callouts are enabled.
        public init(isEnabled: Bool) {
            self.isEnabled = isEnabled
        }
        
        
        /// The coordinate space to use for callout.
        public let coordinateSpace = "com.keyboardkit.coordinate.InputCallout"
        
        
        /// The last time an action became active.
        public var lastActionDate = Date()
        
        /// The minimum callout duration.
        public var minimumVisibleDuration: TimeInterval = 0.09
        
        
        /// Whether or not input callouts are enabled.
        @Published
        public var isEnabled: Bool
        
        /// The currently active action, if any.
        @Published
        public private(set) var action: KeyboardAction?
        
        /// The frame of the currently active button.
        @Published
        public private(set) var buttonFrame: CGRect = .zero

        /// Width of the named coordinate-space container.
        public var containerWidth: CGFloat = 0

        /// Origin of the named coordinate-space container in global coordinates.
        public var containerGlobalOrigin: CGPoint = .zero

        /// Available vertical space above the key grid inside UIInputViewController.view (e.g. suggestion toolbar height).
        public var topAvailableSpace: CGFloat = 0
    }
}


// MARK: - Public Functionality

public extension CalloutContext.InputContext {
    
    /// Whether or not the context currently has an input.
    var hasInput: Bool {
        input != nil
    }
    
    /// Get an optional input of the currently active action.
    var input: String? {
        action?.inputCalloutText
    }

    /// Whether or not the context has input and is enabled.
    var isActive: Bool {
        hasInput && isEnabled && buttonFrame.midX > 0 && buttonFrame.midY > 0
    }
    
    /// Reset the context. This will dismiss the callout.
    func reset() {
        action = nil
        buttonFrame = .zero
    }
    
    /// Reset the context with a slight delay.
    func resetWithDelay() {
        let defaults = UserDefaults(suiteName: "group.crh.key.keyboardplus")
        let extend = ProcessInfo.processInfo.arguments.contains("-qt_extend_input_callout")
            || ProcessInfo.processInfo.arguments.contains("-qt_hold_callout")
            || defaults?.bool(forKey: "crh.key.test.extendInputCalloutDuration") == true
            || defaults?.bool(forKey: "crh.key.test.holdCallout") == true
        let delay = extend ? max(1.60, minimumVisibleDuration) : minimumVisibleDuration
        let date = Date()
        lastActionDate = date
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if self.lastActionDate > date { return }
            self.reset()
        }
    }
    
    /// Update the current input for a certain action with an explicit button frame.
    func updateInput(for action: KeyboardAction?, buttonFrame: CGRect) {
        self.lastActionDate = Date()
        self.action = action
        self.buttonFrame = buttonFrame
    }

    /// Update the current input for a certain action.
    func updateInput(for action: KeyboardAction?, in geo: GeometryProxy, fallbackFrame: CGRect? = nil) {
        if let fallbackFrame = fallbackFrame, fallbackFrame.width > 1 && fallbackFrame.height > 1 {
            self.lastActionDate = Date()
            self.action = action
            self.buttonFrame = fallbackFrame
            return
        }
        let namedFrame = geo.frame(in: .named(coordinateSpace))
        if namedFrame.width > 1 && namedFrame.height > 1,
           namedFrame.origin.x >= -1 && namedFrame.origin.y >= -1 {
            self.lastActionDate = Date()
            self.action = action
            self.buttonFrame = namedFrame
            return
        }
        let zStackFrame = geo.frame(in: .named("SystemKeyboardZStack"))
        if zStackFrame.width > 1 && zStackFrame.height > 1,
           zStackFrame.origin.x >= -1 && zStackFrame.origin.y >= -1 {
            self.lastActionDate = Date()
            self.action = action
            self.buttonFrame = zStackFrame
            return
        }
        let globalFrame = geo.frame(in: .global)
        if globalFrame.width > 1 && globalFrame.height > 1 {
            self.lastActionDate = Date()
            self.action = action
            self.buttonFrame = CGRect(
                x: globalFrame.origin.x - containerGlobalOrigin.x,
                y: globalFrame.origin.y - containerGlobalOrigin.y,
                width: globalFrame.width,
                height: globalFrame.height
            )
            return
        }
    }
}


// MARK: - Context Builders

public extension CalloutContext.InputContext {
    
    /// This context can be used to disable input callouts.
    static var disabled: CalloutContext.InputContext {
        .init(isEnabled: false)
    }
}
