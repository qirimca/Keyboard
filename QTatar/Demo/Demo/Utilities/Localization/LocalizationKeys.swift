//
//  LocalizationKeys.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 20.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

enum Home: String {
    case home_crimea_key // Crimean Tatar Keyboard — for you, with you.
    case home_getkeyboard_key // İlk olaraq Sistem Sazlamalarda klaviaturanı qoşıp, soñra yazğanda 🌐 vastasınen onı saylanız.
    
    case home_keyboard_visible_key // Клавиатура появилась
    case home_keyboard_hidden_key // Клавиатура не показывается
    case home_keyboard_on_key // Клавиатура подключена
    case home_keyboard_off_key // Клавиатура не подключена
    case home_full_on_key // Активирован полный доступ
    case home_full_off_key // Полный доступ не предоставлен
    
    case home_writearea_key // Metin meydanı
    case home_typing_key // Type something...
    
    case home_ok_key // âhşı
    case home_start_key // Get Started Now!
    
    var localized: String {
        NSLocalizedString(self.rawValue, tableName: "Home", comment: "")
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
    case about_feedback_key
    case about_rate_key
    case about_share_key
    case about_send_key
    case about_more_key
    
    var localized: String {
        NSLocalizedString(self.rawValue, tableName: "About", comment: "")
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
        NSLocalizedString(self.rawValue, tableName: "Onboarding", comment: "")
    }
}
