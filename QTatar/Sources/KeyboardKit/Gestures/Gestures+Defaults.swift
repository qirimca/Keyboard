//
//  Gestures+Defaults.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2022-11-24.
//  Copyright © 2022-2024 Daniel Saidi. All rights reserved.
//

import Foundation

public extension Gestures {
    
    /// This type defines default gesture values.
    struct Defaults {
        
        /// The max time between two taps for them to count as a double tap, by default `0.2`.
        public static var doubleTapTimeout = 0.2
        
        /// The time it takes for a press to count as a long press, by default `0.5`.
        public static var longPressDelay = 0.3
        
        /// The time it takes for a press to count as a repeat trigger, by default `0.5`.
        public static var repeatDelay = 0.5
    }
}
