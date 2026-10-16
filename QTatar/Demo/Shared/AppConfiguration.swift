//
//  AppConfiguration.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import Foundation

enum KeyboardPreferences {
    static let suggestionsKey = "crh.key.suggestionsEnabled"
    static let cyrillicKey = "crh.key.cyrillicEnabled"
    static let languageKey = "crh.key.interfaceLanguage"
    static var defaults: UserDefaults { UserDefaults(suiteName: AppConfiguration.appGroupID) ?? .standard }
    static var suggestionsEnabled: Bool { defaults.object(forKey: suggestionsKey) as? Bool ?? true }
    static var cyrillicEnabled: Bool { defaults.object(forKey: cyrillicKey) as? Bool ?? true }
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
    static let keyboardBundleId = "crh.key.keyboard.keyboard"
    static let cyrillicKeyboardBundleId = "crh.key.keyboard.KeyboardCyrillic"
    static let keyboardBundleIdPattern = "crh.key.keyboard*"
}
