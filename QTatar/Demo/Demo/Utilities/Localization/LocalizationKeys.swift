//
//  LocalizationKeys.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 20.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

enum Home: String {
    case home_crimea_key
    case home_getkeyboard_key
    case home_keyboard_visible_key
    case home_keyboard_hidden_key
    case home_keyboard_on_key
    case home_keyboard_off_key
    case home_full_on_key
    case home_full_off_key
    case home_cyrillic_on_key
    case home_cyrillic_off_key
    case home_writearea_key
    case home_typing_key
    case home_ok_key
    case home_start_key
    
    var localized: String {
        L10n.tr(self.rawValue, table: "Home")
    }

    var allLocalizedVersions: [String] {
        ["crh", "uk", "en"].map { lang in
            let bundle = KeyboardPreferences.localizationBundle(for: lang)
            return NSLocalizedString(self.rawValue, tableName: "Home", bundle: bundle, comment: "")
        }
    }
}

enum L10n {
    static func tr(_ key: String, table: String = "Interface") -> String {
        KeyboardPreferences.interfaceBundle.localizedString(forKey: key, value: key, table: table)
    }

    static func label(_ key: String, table: String = "Interface") -> Text {
        Text(LocalizedStringKey(key), tableName: table, bundle: KeyboardPreferences.interfaceBundle)
    }

    static func dailyPhrase(_ key: String, language: String = KeyboardPreferences.interfaceLanguage) -> String {
        let bundle = KeyboardPreferences.localizationBundle(for: language)
        return bundle.localizedString(forKey: key, value: key, table: "DailyPhrases")
    }
}

enum About: String {
    case about_title_key
    case about_first_key
    case about_description_key
    case about_init_key
    case about_spell_title_key
    case about_spell_description_key
    case about_language_title_key
    case about_language_description_key
    case about_join_key
    case about_website_key
    case about_feedback_key
    case about_rate_key
    case about_share_key
    case about_send_key
    case about_more_key
    case about_rights_key
    
    var localized: String {
        L10n.tr(self.rawValue, table: "About")
    }
}

enum Onboarding: String {
    case onb_onb1_key
    case onb_onb2_key
    case onb_onb3_key
    case onb_onb4_key
    case onb_open_key
    case onb_check_key
    case onb_back_key
    case onb_next_key
    case onb_finish_key
    case onb_settings_key
    
    var localized: String {
        L10n.tr(self.rawValue, table: "Onboarding")
    }
}


