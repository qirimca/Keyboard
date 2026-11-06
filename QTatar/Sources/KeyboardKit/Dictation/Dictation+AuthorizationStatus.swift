//
//  Dictation+AuthorizationStatus.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2023-03-21.
//  Copyright © 2023-2024 Daniel Saidi. All rights reserved.
//

public extension Dictation {
    
    /// This enum defines various dictation statuses.
    enum AuthorizationStatus: Int {
        
        case disabledService = -1
        case notDetermined = 0
        case denied = 1
        case restricted = 2
        case authorized = 3
    }
}
