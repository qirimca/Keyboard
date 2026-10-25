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

/// Tri-state observation for keyboard extension installation or activation.
/// When UIKit does not expose extension bundle identifiers (`canInspectKeyboardBundleIds == false`),
/// the state is `.unknown` rather than `.verifiedMissing`.
public enum KeyboardBundleState: String, Equatable, Sendable {
    case verifiedInstalled
    case verifiedMissing
    case unknown
}

/// Inspects public keyboard capabilities. UIKit does not expose installed or
/// currently displayed extension bundle IDs. Bundle-ID methods are retained for
/// compatibility and report no verified IDs; false means unverified, not proof
/// that a keyboard is absent. A language cannot identify a particular extension.
/// Use ``KeyboardStateContext`` for observable compatibility values.
public protocol KeyboardStateInspector {}

public extension KeyboardStateInspector {

    /// Public language observations, with nil/undetermined languages omitted.
    /// These do not prove installation or activation of a specific bundle.
    var availableKeyboardLanguages: [String] {
        Array(Set(UITextInputMode.activeInputModes.compactMap(\.primaryLanguage))).sorted()
    }

    /// False because UIKit provides no public extension bundle-ID enumeration.
    var canInspectKeyboardBundleIds: Bool { false }

    /// No active bundle IDs can be verified through public APIs.
    var activeKeyboardBundleIds: [String] { [] }

    /// No enabled bundle IDs can be verified through public APIs. The argument
    /// remains for source compatibility; Apple preferences are never queried.
    func enabledKeyboardBundleIds(
        defaults: UserDefaults = .standard
    ) -> [String] { [] }

    /// Whether the full access is enabled in System Settings.
    var isFullAccessEnabled: Bool {
        FullAccessInspector().hasFullAccess
    }

    /// Tri-state active status for a keyboard extension bundle identifier.
    func keyboardActiveState(
        withBundleId bundleId: String
    ) -> KeyboardBundleState {
        guard canInspectKeyboardBundleIds else { return .unknown }
        return isKeyboardActive(withBundleId: bundleId) ? .verifiedInstalled : .verifiedMissing
    }

    /// Tri-state enabled status for a keyboard extension bundle identifier.
    func keyboardEnabledState(
        withBundleId bundleId: String,
        defaults: UserDefaults = .standard
    ) -> KeyboardBundleState {
        guard canInspectKeyboardBundleIds else { return .unknown }
        return isKeyboardEnabled(withBundleId: bundleId, defaults: defaults) ? .verifiedInstalled : .verifiedMissing
    }
    
    /// Whether an active extension bundle ID has been verified (currently false).
    func isKeyboardActive(
        withBundleId bundleId: String
    ) -> Bool {
        let ids = activeKeyboardBundleIds
        return isKeyboardActive(withId: bundleId, in: ids)
    }
    
    /// Whether an enabled extension bundle ID has been verified (currently false).
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
