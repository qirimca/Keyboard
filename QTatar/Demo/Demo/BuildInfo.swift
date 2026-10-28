//
//  BuildInfo.swift
//  QTatar
//
//  Generated automatically - do not edit
//

import Foundation

struct BuildInfo {
    static let fallbackBuildDate = "2026-10-27 19:30"

    static var buildDate: String {
        if let locBundleURL = Bundle.main.url(forResource: "AppLocalizations", withExtension: "bundle") {
            let timestampURL = locBundleURL.appendingPathComponent("BuildTimestamp.txt")
            if let raw = try? String(contentsOf: timestampURL, encoding: .utf8) {
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }
        var candidateDates: [Date] = []
        if let execURL = Bundle.main.executableURL,
           let attrs = try? FileManager.default.attributesOfItem(atPath: execURL.path),
           let modDate = attrs[.modificationDate] as? Date {
            candidateDates.append(modDate)
        }
        if let locBundleURL = Bundle.main.url(forResource: "AppLocalizations", withExtension: "bundle"),
           let attrs = try? FileManager.default.attributesOfItem(atPath: locBundleURL.path),
           let modDate = attrs[.modificationDate] as? Date {
            candidateDates.append(modDate)
        }
        if let latestDate = candidateDates.max() {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = "yyyy-MM-dd HH:mm"
            return formatter.string(from: latestDate)
        }
        return fallbackBuildDate
    }

    static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

    static var fullVersion: String {
        return "\(version) (\(buildNumber)) • \(buildDate)"
    }
}
