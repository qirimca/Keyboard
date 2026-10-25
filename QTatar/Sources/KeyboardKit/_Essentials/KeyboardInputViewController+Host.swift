//
//  KeyboardViewController+Host.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2023-03-27.
//  Copyright © 2023-2024 Daniel Saidi. All rights reserved.
//

#if os(iOS) || os(tvOS) || os(visionOS)
import SwiftUI
import UIKit

public extension KeyboardInputViewController {

    /// The host application's bundle ID is unavailable through public keyboard
    /// extension APIs. This compatibility property therefore always returns nil.
    /// Use the text document proxy's public traits to adapt to the current field.
    var hostBundleId: String? { nil }

    /// Retained for source compatibility. Public APIs expose no host-ID cache.
    func resetHostBundleIdCache() {}
}
#endif
