//
//  AppStoreReviewManager.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 23.10.2026.
//

import Foundation
import StoreKit
import SwiftUI
import UIKit

/// Coordinates non-intrusive App Store review prompts at moments of peak user satisfaction
/// while maintaining full backward compatibility across iOS 16, 17, 18, 26, and 27.
@MainActor
enum AppStoreReviewManager {
    private static let sessionCountKey = "crh.key.review.sessionCount"
    private static let lastSessionTimestampKey = "crh.key.review.lastSessionTimestamp"
    private static let lastPromptedVersionKey = "crh.key.review.lastPromptedVersion"
    private static let lastPromptTimestampKey = "crh.key.review.lastPromptTimestamp"
    private static let highestVolumeTierKey = "crh.key.review.highestVolumeTier"
    private static let highestSpeedTierKey = "crh.key.review.highestSpeedTier"

    private static let minimumSessionsRequired = 3
    private static let minimumWordsRequired = 100
    private static let minimumLearnedWordsAlternative = 15
    private static let minimumCooldownSeconds: TimeInterval = 90 * 24 * 60 * 60 // 90 days

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

    /// Evaluates whether the user has just reached a meaningful typing milestone (new speed/volume tier or >= 100 words across >= 3 sessions)
    /// and requests an in-app App Store review at most once per app version.
    static func evaluateAndRequestReviewIfAppropriate(
        totalWords: Int,
        learnedWords: Int,
        bestWPM: Int,
        isKeyboardReady: Bool,
        isTypingActive: Bool
    ) {
        guard !isAutomatedTesting else { return }
        guard isKeyboardReady, !isTypingActive else { return }
        guard UIApplication.shared.applicationState == .active else { return }

        let defaults = KeyboardPreferences.defaults
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? BuildInfo.version
        let lastPromptedVersion = defaults.string(forKey: lastPromptedVersionKey)
        guard lastPromptedVersion != currentVersion else { return }

        let now = Date().timeIntervalSince1970
        let lastPromptTime = defaults.double(forKey: lastPromptTimestampKey)
        if lastPromptTime > 0 && (now - lastPromptTime) < minimumCooldownSeconds {
            return
        }

        let sessions = defaults.integer(forKey: sessionCountKey)
        let currentVolumeTier = KeyboardUsageStats.volumeTier(for: totalWords).level
        let currentSpeedTier = KeyboardUsageStats.speedTier(for: bestWPM).level
        let prevVolumeTier = defaults.integer(forKey: highestVolumeTierKey)
        let prevSpeedTier = defaults.integer(forKey: highestSpeedTierKey)

        if currentVolumeTier > prevVolumeTier {
            defaults.set(currentVolumeTier, forKey: highestVolumeTierKey)
        }
        if currentSpeedTier > prevSpeedTier {
            defaults.set(currentSpeedTier, forKey: highestSpeedTierKey)
        }

        let unlockedNewHighTier = (currentVolumeTier >= 2 && currentVolumeTier > prevVolumeTier)
            || (currentSpeedTier >= 3 && currentSpeedTier > prevSpeedTier && totalWords >= 50)
        let reachedSteadyEngagement = sessions >= minimumSessionsRequired
            && (totalWords >= minimumWordsRequired || learnedWords >= minimumLearnedWordsAlternative)

        guard unlockedNewHighTier || reachedSteadyEngagement else { return }

        defaults.set(currentVersion, forKey: lastPromptedVersionKey)
        defaults.set(now, forKey: lastPromptTimestampKey)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard !isAutomatedTesting,
                  UIApplication.shared.applicationState == .active,
                  let windowScene = activeWindowScene() else { return }
            requestSystemReview(in: windowScene)
        }
    }

    /// Invokes the modern StoreKit `AppStore.requestReview(in:)` on iOS 18+ with automatic fallback to `SKStoreReviewController` on iOS 16–17.
    static func requestSystemReview(in windowScene: UIWindowScene) {
        if #available(iOS 18.0, *) {
            AppStore.requestReview(in: windowScene)
        } else {
            SKStoreReviewController.requestReview(in: windowScene)
        }
    }

    private static func activeWindowScene() -> UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }
}
