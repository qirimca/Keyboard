//
//  BuildInfo.swift
//  QTatar
//
//  Generated automatically - do not edit
//

import Foundation

struct BuildInfo {
    static let buildDate = "2025-08-13 11:21:35"
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    
    static var fullVersion: String {
        return "\(version) (\(buildNumber)) - \(buildDate)"
    }
}