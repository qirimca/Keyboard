//
//  Configurations.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 18.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import Foundation

enum Configurations {
    static var appName: String = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "Unknown App Name"
    static let appID = 6739430313
    static let appGroupID = "group.crh.key.boardplus"
    static let appDeepLink = "kkdemo://dictation"
    static let defaults = UserDefaults(suiteName: "group.com.sun.vpn.app")
    static let localization = "Loading localization data..."
    
    // Social media 
    static let website = "https://example.com"
    static let instagram = "https://www.instagram.com/crimeantatar_corpora/"
    static let facebook = "https://facebook.com"
    static let tiktok = "https://tiktok.com"
    static let linkedin = "https://linkedin.com"
    static let github = "https://github.com"
    static let telegram = "https://t.me"
    
    // Projects
    static let quizlet = "https://quizlet.com/class/18053920/materials"
    static let languagetool = "https://languagetool.org/ios"
}
