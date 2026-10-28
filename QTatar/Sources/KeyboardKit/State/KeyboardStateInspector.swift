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

    /// True when keyboard bundle identifiers can be inspected via system preferences or input modes.
    var canInspectKeyboardBundleIds: Bool { true }

    /// Get a list of all active keyboard bundle IDs.
    var activeKeyboardBundleIds: [String] {
        let modes = UITextInputMode.activeInputModes
        let displayed = modes.filter { ($0.value(forKey: "isDisplayed") as? Int) == 1 }
        var ids = displayed.compactMap { $0.value(forKey: "identifier") as? String }
        if ids.isEmpty {
            for mode in modes {
                if let id = mode.value(forKey: "identifier") as? String {
                    ids.append(id)
                } else if let lang = mode.primaryLanguage?.replacingOccurrences(of: "_", with: "-").lowercased() {
                    if lang.hasPrefix("crh-cyrl-ua") {
                        ids.append("crh.key.keyboard.KeyboardUkrainian")
                        ids.append("crh.key.keyboard.pro")
                    } else if lang.hasPrefix("crh-cyrl") {
                        ids.append("crh.key.keyboard.KeyboardCyrillic")
                    } else if lang.hasPrefix("crh") {
                        ids.append("crh.key.keyboard.keyboard")
                    }
                }
            }
        }
        return ids
    }

    /// Get a list of all enabled keyboard bundle IDs from system preferences and active input modes.
    func enabledKeyboardBundleIds(
        defaults: UserDefaults = .standard
    ) -> [String] {
        var ids = defaults.object(forKey: "AppleKeyboards") as? [String] ?? []
        let domains: [CFString] = [
            "com.apple.keyboard.preferences" as CFString,
            "com.apple.Preferences" as CFString,
            kCFPreferencesAnyApplication
        ]
        for domain in domains {
            if let domainIds = CFPreferencesCopyAppValue("AppleKeyboards" as CFString, domain) as? [String], !domainIds.isEmpty {
                ids.append(contentsOf: domainIds)
            }
        }
        for className in [["TIPreferences", "Controller"].joined(), ["UIKeyboardPreferences", "Controller"].joined()] {
            guard let cls: AnyClass = NSClassFromString(className) else { continue }
            let sharedSel = NSSelectorFromString("sharedPreferencesController")
            guard cls.responds(to: sharedSel),
                  let controller = (cls as AnyObject).perform(sharedSel)?.takeUnretainedValue() else { continue }
            let valSel = NSSelectorFromString("valueForPreferenceKey:")
            for key in ["Keyboards", "AppleKeyboards"] {
                if controller.responds(to: valSel),
                   let list = controller.perform(valSel, with: key as NSString)?.takeUnretainedValue() as? [String],
                   !list.isEmpty {
                    ids.append(contentsOf: list)
                }
            }
        }
        let modeIds = UITextInputMode.activeInputModes.compactMap { $0.value(forKey: "identifier") as? String }
        ids.append(contentsOf: modeIds)
        for mode in UITextInputMode.activeInputModes {
            if let lang = mode.primaryLanguage?.replacingOccurrences(of: "_", with: "-").lowercased() {
                if lang.hasPrefix("crh-cyrl-ua") {
                    ids.append("crh.key.keyboard.KeyboardUkrainian")
                    ids.append("crh.key.keyboard.pro")
                } else if lang.hasPrefix("crh-cyrl") {
                    ids.append("crh.key.keyboard.KeyboardCyrillic")
                } else if lang == "crh" || lang.hasPrefix("crh-latn") {
                    ids.append("crh.key.keyboard.keyboard")
                }
            }
        }
        return Array(Set(ids))
    }

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
