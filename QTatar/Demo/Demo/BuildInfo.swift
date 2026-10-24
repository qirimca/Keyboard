//
//  BuildInfo.swift
//  QTatar
//
//  Generated automatically - do not edit
//

import Foundation

struct BuildInfo {
    static let fallbackBuildDate = "2026-10-24 12:55"

    static var buildDate: String {
        if let execURL = Bundle.main.executableURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: execURL.path),
           let modDate = attrs[.modificationDate] as? Date {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: modDate)
        }
        return fallbackBuildDate
    }

    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

    static var fullVersion: String {
        return "\(version) (\(buildNumber)) • \(buildDate)"
    }
}
