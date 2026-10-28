//
//  AppStoreReviewManager.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 23.10.2026.
//

import Foundation
import SwiftUI
import UIKit

/// Coordinates App Store review deep-link navigation without linking StoreKit or triggering
/// automatic background storekitd/itunesstored network requests (which otherwise cause iOS
/// symptomsd to register the app in CellularUsage.db and show a Cellular Data toggle).
@MainActor
enum AppStoreReviewManager {
    private static let sessionCountKey = "crh.key.review.sessionCount"
    private static let lastSessionTimestampKey = "crh.key.review.lastSessionTimestamp"

    static var appStoreURL: URL {
        URL(string: "https://apps.apple.com/app/id\(Configurations.appID)")!
    }

    static var writeReviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(Configurations.appID)?action=write-review")!
    }

    private static var isAutomatedTesting: Bool {
        KeyboardPreferences.defaults.bool(forKey: "crh.key.test.isUITesting")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.arguments.contains("-qt_reset_text")
    }

    /// Opens the App Store "Write a Review" sheet directly when the user explicitly taps "Rate on the App Store" in `AboutView`.
    static func openWriteReviewPage(using openURL: OpenURLAction? = nil) {
        let url = writeReviewURL
        if let openURL {
            openURL(url)
        } else {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }

    /// Increments the foreground session counter (throttled to distinct sessions >= 30 minutes apart).
    static func recordForegroundSession() {
        guard !isAutomatedTesting else { return }
        let defaults = KeyboardPreferences.defaults
        let now = Date().timeIntervalSince1970
        let lastSession = defaults.double(forKey: lastSessionTimestampKey)
        if now - lastSession >= 30 * 60 {
            let updated = defaults.integer(forKey: sessionCountKey) + 1
            defaults.set(updated, forKey: sessionCountKey)
            defaults.set(now, forKey: lastSessionTimestampKey)
        }
    }

    /// No-op for automatic background StoreKit review prompts so iOS never attributes background cellular traffic to QırımKey.
    static func evaluateAndRequestReviewIfAppropriate(
        totalWords: Int,
        learnedWords: Int,
        bestWPM: Int,
        isKeyboardReady: Bool,
        isTypingActive: Bool
    ) {
        _ = (totalWords, learnedWords, bestWPM, isKeyboardReady, isTypingActive)
    }
}
