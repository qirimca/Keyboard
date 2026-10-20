//
//  AppConfiguration.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import Foundation
import UIKit

enum KeyboardPreferences {
    static let suggestionsKey = "crh.key.suggestionsEnabled"
    static let wordLearningKey = "crh.key.wordLearningEnabled"
    static let cyrillicKey = "crh.key.cyrillicEnabled"
    static let languageKey = "crh.key.interfaceLanguage"
    /// Created once: `UserDefaults(suiteName:)` is expensive and used by the style provider for every key.
    static let defaults: UserDefaults = UserDefaults(suiteName: AppConfiguration.appGroupID) ?? .standard
    static var suggestionsEnabled: Bool { defaults.object(forKey: suggestionsKey) as? Bool ?? true }
    static var wordLearningEnabled: Bool { defaults.object(forKey: wordLearningKey) as? Bool ?? true }
    /// Only iPad has a place where the toggle matters (the абв/abc key); on iPhone the Cyrillic keyboard is always available,
    /// because iOS offers no way to hide it from the system list.
    static var cyrillicEnabled: Bool {
        if UIDevice.current.userInterfaceIdiom != .pad { return true }
        return defaults.object(forKey: cyrillicKey) as? Bool ?? true
    }
    static var interfaceLanguage: String { defaults.string(forKey: languageKey) ?? "crh" }
    static var interfaceBundle: Bundle {
        guard let path = Bundle.main.path(forResource: interfaceLanguage, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}

enum AppConfiguration {
    static let appGroupID = "group.crh.key.keyboardplus"
    static let appDeepLink = "kkdemo://dictation"
    static let appBundleId = "crh.key.keyboard"
    static let keyboardBundleId = "crh.key.keyboard.keyboard"
    static let cyrillicKeyboardBundleId = "crh.key.keyboard.KeyboardCyrillic"
    static let keyboardBundleIdPattern = "crh.key.keyboard*"
    static let fallbackDocumentID = UUID()
}

extension UITextDocumentProxy {
    /// Safely reads `documentIdentifier` via KVC so a temporarily `nil` Objective-C return during an XPC transition
    /// does not trap in `UUID._unconditionallyBridgeFromObjectiveC`.
    var safeDocumentIdentifier: UUID {
        ((self as AnyObject).value(forKey: "documentIdentifier") as? UUID) ?? AppConfiguration.fallbackDocumentID
    }
}
