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
    var availableKeyboardLanguages: [String] {
        Array(Set(UITextInputMode.activeInputModes.compactMap(\.primaryLanguage))).sorted()
    }

    /// Public input-mode APIs expose languages, not extension bundle identifiers.
    var canInspectKeyboardBundleIds: Bool { false }

    /// No bundle IDs can be verified through public UIKit APIs.
    var activeKeyboardBundleIds: [String] { [] }

    /// Retained for source compatibility. System preference keys are not a
    /// supported registry of keyboard extensions; an empty result means unknown.
    func enabledKeyboardBundleIds(
        defaults: UserDefaults = .standard
    ) -> [String] {
        []
    }

    /// Whether the full access is enabled in System Settings.
    var isFullAccessEnabled: Bool {
        FullAccessInspector.sharedHasFullAccess()
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

private final class FullAccessInspector: UIInputViewController {
    private static var cachedValue: Bool?
    private static var lastCheckUptime: TimeInterval = 0
    private static var didRegisterLifecycleObservers = false
    private static let appGroupSuiteName = "group.crh.key.keyboardplus"
    private static let extensionConfirmedFullAccessKey = "crh.key.extensionConfirmedFullAccess"
    private static let sharedSuiteDefaults = UserDefaults(suiteName: appGroupSuiteName)
    private static let isExtensionProcess = Bundle.main.bundlePath.hasSuffix(".appex")
    private static let processLaunchUptime: TimeInterval = ProcessInfo.processInfo.systemUptime
    private static var didResumeFromBackground = false
    private static var sharedInstance: FullAccessInspector?

    private static func registerLifecycleObserversIfNeeded() {
        guard !didRegisterLifecycleObservers else { return }
        didRegisterLifecycleObservers = true
        let nc = NotificationCenter.default
        for name in [
            UIApplication.didEnterBackgroundNotification,
            UIApplication.willEnterForegroundNotification,
            UIApplication.didBecomeActiveNotification,
            UIApplication.willResignActiveNotification,
            .NSExtensionHostDidEnterBackground,
            .NSExtensionHostWillEnterForeground
        ] {
            nc.addObserver(forName: name, object: nil, queue: .main) { _ in
                didResumeFromBackground = true
                cachedValue = nil
                lastCheckUptime = 0
                sharedInstance = nil
            }
        }
    }

    static func sharedHasFullAccess() -> Bool {
        guard Thread.isMainThread else {
            return cachedValue ?? (sharedSuiteDefaults?.bool(forKey: extensionConfirmedFullAccessKey) ?? false)
        }
        registerLifecycleObserversIfNeeded()
        let now = ProcessInfo.processInfo.systemUptime
        if let cached = cachedValue, (now - lastCheckUptime) < 0.45 {
            return cached
        }
        lastCheckUptime = now
        let inspector = FullAccessInspector()
        sharedInstance = inspector
        let directResult = inspector.hasFullAccess
        let result: Bool
        if directResult {
            result = true
            sharedSuiteDefaults?.set(true, forKey: extensionConfirmedFullAccessKey)
        } else if isExtensionProcess || didResumeFromBackground || (now - processLaunchUptime) >= 1.5 {
            result = false
            sharedSuiteDefaults?.set(false, forKey: extensionConfirmedFullAccessKey)
        } else {
            result = sharedSuiteDefaults?.bool(forKey: extensionConfirmedFullAccessKey) == true
        }
        cachedValue = result
        return result
    }
}
#endif
