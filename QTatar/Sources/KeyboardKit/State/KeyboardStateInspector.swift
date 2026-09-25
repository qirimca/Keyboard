//
//  KeyboardStateInspector.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2020-05-05.
//  Copyright © 2020-2024 Daniel Saidi. All rights reserved.
//

#if os(iOS) || os(tvOS) || os(visionOS)
import Foundation
import UIKit

/// This protocol can be implemented by classes that must be
/// able to check the enabled state of a keyboard extension.
///
/// It can check if a keyboard is enabled in System Settings,
/// if Full Access is enabled, if a keyboard is active, etc.
///
/// This type supports bundle ID wildcards, which means that
/// it can inspect multiple keyboards at once, for instance:
///
/// ```
/// @StateObject
/// var state = KeyboardStateContext(bundleId: "com.myapp.*")
/// ```
///
/// The easiest way to observe a keyboard's enabled state is
/// to use an observable ``KeyboardStateContext``.
public protocol KeyboardStateInspector {}

public extension KeyboardStateInspector {

    /// Get a list of all active keyboard bundle IDs.
    var activeKeyboardBundleIds: [String] {
        let modes = UITextInputMode.activeInputModes
        let displayed = modes.filter { ($0.value(forKey: "isDisplayed") as? Int) == 1 }
        var ids = displayed.compactMap { $0.value(forKey: "identifier") as? String }
        if ids.isEmpty {
            for mode in modes {
                if mode.primaryLanguage?.hasPrefix("crh") == true {
                    if let id = mode.value(forKey: "identifier") as? String {
                        ids.append(id)
                    } else {
                        ids.append("crh.key.keyboard.keyboard")
                    }
                }
            }
        }
        return ids
    }

    /// Get a list of all enabled keyboard bundle IDs.
    func enabledKeyboardBundleIds(
        defaults: UserDefaults = .standard
    ) -> [String] {
        var ids = defaults.object(forKey: "AppleKeyboards") as? [String] ?? []
        let modeIds = UITextInputMode.activeInputModes.compactMap { $0.value(forKey: "identifier") as? String }
        ids.append(contentsOf: modeIds)
        for mode in UITextInputMode.activeInputModes {
            if mode.primaryLanguage?.hasPrefix("crh") == true {
                ids.append("crh.key.keyboard.keyboard")
                ids.append("crh.key.keyboard")
            }
        }
        return Array(Set(ids))
    }
    
    /// Whether the full access is enabled in System Settings.
    var isFullAccessEnabled: Bool {
        FullAccessInspector().hasFullAccess
    }
    
    /// Whether a certain keyboard extension is active.
    func isKeyboardActive(
        withBundleId bundleId: String
    ) -> Bool {
        let ids = activeKeyboardBundleIds
        return isKeyboardActive(withId: bundleId, in: ids)
    }
    
    /// Whether a certain keyboard extension is enabled.
    func isKeyboardEnabled(
        withBundleId bundleId: String,
        defaults: UserDefaults = .standard
    ) -> Bool {
        let ids = enabledKeyboardBundleIds(defaults: defaults)
        return isKeyboardEnabled(withId: bundleId, in: ids)
    }
}

extension KeyboardStateInspector {

    func isKeyboardActive(
        withId bundleId: String,
        in ids: [String]
    ) -> Bool {
        ids.first?.matchesBundleId(bundleId) ?? false
    }

    func isKeyboardEnabled(
        withId bundleId: String,
        in ids: [String]
    ) -> Bool {
        ids.contains { $0.matchesBundleId(bundleId) }
    }
}

extension String {

    func matchesBundleId(_ bundleId: String) -> Bool {
        if self == bundleId { return true }
        let pattern = bundleId.replacingOccurrences(of: "*", with: "")
        if self.contains(pattern) || pattern.contains(self) { return true }
        return false
    }
}

private class FullAccessInspector: UIInputViewController {}
#endif
