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
    static let localization = "Loading localization data..."
    
    // Social media 
    static let website = "https://ctcorpus.org/index.php/uk/"
    static let instagram = "https://www.instagram.com/crimeantatar_corpora/"
    static let facebook = "https://www.facebook.com/OnlineTerciman/"
    static let github = "https://github.com/qirimca"
    static let telegram = "https://t.me/qirim_young"
    static let donatello = "https://donatello.to/crimeantatar_corpora"
    
    // Projects
    static let quizlet = "https://quizlet.com/class/18053920/materials"
    static let languagetool = "https://languagetool.org/ios"
}
