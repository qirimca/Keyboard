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
}
