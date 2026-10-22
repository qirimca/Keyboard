//
//  BuildInfo.swift
//  QTatar
//
//  Generated automatically - do not edit
//

import Foundation

struct BuildInfo {
    static let buildDate = "2026-10-22 11:13"
    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    
    static var fullVersion: String {
        return "\(version) (\(buildNumber)) • \(buildDate)"
    }
}