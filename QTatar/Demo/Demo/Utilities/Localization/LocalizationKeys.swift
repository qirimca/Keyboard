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

//enum About: String {
//    case about_onb1_key
//    case about_onb2_key
//    case about_onb3_key
//    case about_onb3_key
//    case about_onb4_key
//    case about_open_key
//    case about_check_key
//    case about_back_key
//    case about_next_key
//    case about_finish_key
//    case about_settings_key
//    
//    
//    var localized: String {
//        NSLocalizedString(self.rawValue, tableName: "About", comment: "")
//    }
//}
//
//enum Onboarding: String {
//    case about_onb1_key
//    case about_onb2_key
//    case about_onb3_key
//    case about_onb3_key
//    case about_onb4_key
//    case about_open_key
//    case about_check_key
//    case about_back_key
//    case about_next_key
//    case about_finish_key
//    case about_settings_key
//    
//    var localized: String {
//        NSLocalizedString(self.rawValue, tableName: "Onboarding", comment: "")
//    }
//}
