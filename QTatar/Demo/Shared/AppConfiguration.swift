//
//  AppConfiguration.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import Foundation
import SQLite3
import SwiftUI
import UIKit

enum KeyboardPreferences {
    static let suggestionsKey = "crh.key.suggestionsEnabled"
    static let wordLearningKey = "crh.key.wordLearningEnabled"
    static let cyrillicKey = "crh.key.cyrillicEnabled"
    static let ukrainianCyrillicLayoutKey = "crh.key.ukrainianCyrillicLayout"
    static let statsEnabledKey = "crh.key.statsEnabled"
    static let splitKeyboardKey = "crh.key.splitKeyboardEnabled"
    static let oneHandedModeKey = "crh.key.oneHandedMode"
    static let languageKey = "crh.key.interfaceLanguage"
    static let splitModeChangedNotification = "crh.key.splitKeyboardModeDidChange"
    static let oneHandedModeChangedNotification = "crh.key.oneHandedModeDidChange"
    static let ukrainianCyrillicLayoutChangedNotification = "crh.key.ukrainianCyrillicLayoutDidChange"
    /// Created once: `UserDefaults(suiteName:)` is expensive and used by the style provider for every key.
    static let defaults: UserDefaults = UserDefaults(suiteName: AppConfiguration.appGroupID) ?? .standard

    private static var cachedSuggestions: Bool?
    private static var cachedWordLearning: Bool?
    private static var cachedCyrillic: Bool?
    private static var cachedUkrainianCyrillicLayout: Bool?
    private static var cachedStatsEnabled: Bool?
    private static var cachedSplitKeyboard: Bool?
    private static var cachedOneHandedMode: String?

    static func refreshCachedPreferences() {
        cachedSuggestions = (defaults.object(forKey: suggestionsKey) as? Bool) ?? (UserDefaults.standard.object(forKey: suggestionsKey) as? Bool) ?? true
        cachedWordLearning = (defaults.object(forKey: wordLearningKey) as? Bool) ?? (UserDefaults.standard.object(forKey: wordLearningKey) as? Bool) ?? true
        cachedCyrillic = (defaults.object(forKey: cyrillicKey) as? Bool)
            ?? ((SystemKeyboardSettings.isCyrillicKeyboardExtensionEnabled || SystemKeyboardSettings.isUkrainianKeyboardExtensionEnabled) ? true : true)
        cachedUkrainianCyrillicLayout = (defaults.object(forKey: ukrainianCyrillicLayoutKey) as? Bool)
            ?? (SystemKeyboardSettings.isUkrainianKeyboardExtensionEnabled ? true : false)
        cachedStatsEnabled = (defaults.object(forKey: statsEnabledKey) as? Bool) ?? true
        cachedSplitKeyboard = defaults.object(forKey: splitKeyboardKey) as? Bool ?? false
        let rawOneHanded = resolveStoredOneHandedMode()
        cachedOneHandedMode = rawOneHanded
        SystemKeyboardSettings.refreshSystemEmojiKeyboardState()
    }

    private static func resolveStoredOneHandedMode() -> String {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return "off"
        }
        #endif
        let isHostApp = Bundle.main.bundleIdentifier == AppConfiguration.appBundleId
        let lastSeenStdKey = "crh.key.lastSeenStd.\(oneHandedModeKey)"
        if isHostApp,
           let stdVal = UserDefaults.standard.string(forKey: oneHandedModeKey),
           (stdVal == "left" || stdVal == "right" || stdVal == "off") {
            let lastSeenStd = defaults.string(forKey: lastSeenStdKey)
            if lastSeenStd != stdVal {
                // Settings.app (Root.plist) changed UserDefaults.standard since we last checked
                defaults.set(stdVal, forKey: oneHandedModeKey)
                defaults.set(stdVal, forKey: lastSeenStdKey)
                defaults.set(stdVal, forKey: "crh.key.lastSynced.\(oneHandedModeKey)")
                return stdVal
            }
            if let groupVal = defaults.string(forKey: oneHandedModeKey),
               (groupVal == "left" || groupVal == "right" || groupVal == "off"),
               groupVal != stdVal {
                // Keyboard extension changed App Group value; sync it back to UserDefaults.standard
                UserDefaults.standard.set(groupVal, forKey: oneHandedModeKey)
                defaults.set(groupVal, forKey: lastSeenStdKey)
                defaults.set(groupVal, forKey: "crh.key.lastSynced.\(oneHandedModeKey)")
                return groupVal
            }
        }
        if let groupVal = defaults.string(forKey: oneHandedModeKey),
           (groupVal == "left" || groupVal == "right" || groupVal == "off") {
            return groupVal
        }
        if let stdVal = UserDefaults.standard.string(forKey: oneHandedModeKey),
           (stdVal == "left" || stdVal == "right" || stdVal == "off") {
            defaults.set(stdVal, forKey: oneHandedModeKey)
            if isHostApp {
                defaults.set(stdVal, forKey: lastSeenStdKey)
            }
            return stdVal
        }
        for key in ["KeyboardBias", "OneHandedKeyboardMode"] {
            if let raw = CFPreferencesCopyAppValue(key as CFString, kCFPreferencesAnyApplication) {
                if let s = raw as? String {
                    let lower = s.lowercased()
                    if lower.contains("left") { return "left" }
                    if lower.contains("right") { return "right" }
                } else if let n = raw as? NSNumber {
                    if n.intValue == 1 { return "left" }
                    if n.intValue == 2 { return "right" }
                }
            }
        }
        return "off"
    }

    static var suggestionsEnabled: Bool {
        if let cached = cachedSuggestions { return cached }
        let val = (defaults.object(forKey: suggestionsKey) as? Bool) ?? (UserDefaults.standard.object(forKey: suggestionsKey) as? Bool) ?? true
        cachedSuggestions = val
        return val
    }

    static var wordLearningEnabled: Bool {
        if let cached = cachedWordLearning { return cached }
        let val = (defaults.object(forKey: wordLearningKey) as? Bool) ?? (UserDefaults.standard.object(forKey: wordLearningKey) as? Bool) ?? true
        cachedWordLearning = val
        return val
    }

    static var ukrainianCyrillicLayoutEnabled: Bool {
        let bundleId = Bundle.main.bundleIdentifier
        if AppConfiguration.isUkrainianCyrillicKeyboardExtensionBundleId(bundleId) { return true }
        if bundleId == AppConfiguration.cyrillicKeyboardBundleId {
            let isUITesting = defaults.bool(forKey: "crh.key.test.isUITesting")
            if !isUITesting && SystemKeyboardSettings.isUkrainianKeyboardExtensionEnabled {
                return false
            }
        }
        if let cached = cachedUkrainianCyrillicLayout { return cached }
        if let stored = defaults.object(forKey: ukrainianCyrillicLayoutKey) as? Bool {
            cachedUkrainianCyrillicLayout = stored
            return stored
        }
        let fallback = SystemKeyboardSettings.isUkrainianKeyboardExtensionEnabled
        cachedUkrainianCyrillicLayout = fallback
        return fallback
    }

    static var statsEnabled: Bool {
        if let cached = cachedStatsEnabled { return cached }
        let val = (defaults.object(forKey: statsEnabledKey) as? Bool) ?? true
        cachedStatsEnabled = val
        return val
    }

    static var splitKeyboardEnabled: Bool {
        if UIDevice.current.userInterfaceIdiom != .pad { return false }
        if let cached = cachedSplitKeyboard { return cached }
        let val = defaults.object(forKey: splitKeyboardKey) as? Bool ?? false
        cachedSplitKeyboard = val
        return val
    }

    static var oneHandedMode: String {
        if UIDevice.current.userInterfaceIdiom == .pad { return "off" }
        if let cached = cachedOneHandedMode { return cached }
        let normalized = resolveStoredOneHandedMode()
        cachedOneHandedMode = normalized
        return normalized
    }

    static func setStatsEnabled(_ enabled: Bool) {
        cachedStatsEnabled = enabled
        defaults.set(enabled, forKey: statsEnabledKey)
        defaults.set(enabled, forKey: "crh.key.lastSynced.\(statsEnabledKey)")
        UserDefaults.standard.set(enabled, forKey: statsEnabledKey)
        if !enabled {
            KeyboardUsageStats.reclaimResourcesWhenDisabled()
        }
    }

    static func setSuggestionsEnabled(_ enabled: Bool) {
        cachedSuggestions = enabled
        defaults.set(enabled, forKey: suggestionsKey)
    }

    static func setWordLearningEnabled(_ enabled: Bool) {
        cachedWordLearning = enabled
        defaults.set(enabled, forKey: wordLearningKey)
    }

    static func setCyrillicEnabled(_ enabled: Bool) {
        cachedCyrillic = enabled
        defaults.set(enabled, forKey: cyrillicKey)
        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
    }

    static func setUkrainianCyrillicLayoutEnabled(_ enabled: Bool) {
        cachedUkrainianCyrillicLayout = enabled
        defaults.set(enabled, forKey: ukrainianCyrillicLayoutKey)
        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(ukrainianCyrillicLayoutChangedNotification as CFString),
            nil,
            nil,
            true
        )
    }

    static func setSplitKeyboardEnabled(_ enabled: Bool) {
        cachedSplitKeyboard = enabled
        defaults.set(enabled, forKey: splitKeyboardKey)
        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(splitModeChangedNotification as CFString),
            nil,
            nil,
            true
        )
    }

    static func setOneHandedMode(_ mode: String) {
        let normalized = (mode == "left" || mode == "right") ? mode : "off"
        cachedOneHandedMode = normalized
        defaults.set(normalized, forKey: oneHandedModeKey)
        if Bundle.main.bundleIdentifier == AppConfiguration.appBundleId {
            defaults.set(normalized, forKey: "crh.key.lastSeenStd.\(oneHandedModeKey)")
            defaults.set(normalized, forKey: "crh.key.lastSynced.\(oneHandedModeKey)")
            UserDefaults.standard.set(normalized, forKey: oneHandedModeKey)
        }
        DispatchQueue.global(qos: .userInitiated).async {
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName(oneHandedModeChangedNotification as CFString),
                nil,
                nil,
                true
            )
        }
    }

    /// Only iPad has a place where the toggle matters (the абв/abc key); on iPhone the Cyrillic keyboard is always available,
    /// because iOS offers no way to hide it from the system list.
    static var cyrillicEnabled: Bool {
        if UIDevice.current.userInterfaceIdiom != .pad { return true }
        if let cached = cachedCyrillic { return cached }
        if let stored = defaults.object(forKey: cyrillicKey) as? Bool {
            cachedCyrillic = stored
            return stored
        }
        let val = ukrainianCyrillicLayoutEnabled
            || SystemKeyboardSettings.isCyrillicKeyboardExtensionEnabled
            || SystemKeyboardSettings.isUkrainianKeyboardExtensionEnabled
            || true
        cachedCyrillic = val
        return val
    }
    static var interfaceLanguage: String { defaults.string(forKey: languageKey) ?? "crh" }
    private static var bundleCacheLock = os_unfair_lock_s()
    private static var cachedContainerBundle: Bundle?
    private static var cachedLanguageBundles: [String: Bundle] = [:]

    static var localizationContainerBundle: Bundle {
        os_unfair_lock_lock(&bundleCacheLock)
        if let cached = cachedContainerBundle {
            os_unfair_lock_unlock(&bundleCacheLock)
            return cached
        }
        os_unfair_lock_unlock(&bundleCacheLock)

        let resolved: Bundle = {
            if let url = Bundle.main.url(forResource: "AppLocalizations", withExtension: "bundle"),
               let bundle = Bundle(url: url) {
                return bundle
            }
            let mainURL = Bundle.main.bundleURL
            if mainURL.pathExtension == "appex" {
                let hostAppURL = mainURL.deletingLastPathComponent().deletingLastPathComponent()
                let hostLocURL = hostAppURL.appendingPathComponent("AppLocalizations.bundle")
                if let bundle = Bundle(url: hostLocURL) {
                    return bundle
                }
            }
            return .main
        }()

        os_unfair_lock_lock(&bundleCacheLock)
        cachedContainerBundle = resolved
        os_unfair_lock_unlock(&bundleCacheLock)
        return resolved
    }
    static func localizationBundle(for language: String) -> Bundle {
        os_unfair_lock_lock(&bundleCacheLock)
        if let cached = cachedLanguageBundles[language] {
            os_unfair_lock_unlock(&bundleCacheLock)
            return cached
        }
        os_unfair_lock_unlock(&bundleCacheLock)

        let container = localizationContainerBundle
        let resolved: Bundle = {
            if let path = container.path(forResource: language, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
            if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
            return .main
        }()

        os_unfair_lock_lock(&bundleCacheLock)
        cachedLanguageBundles[language] = resolved
        os_unfair_lock_unlock(&bundleCacheLock)
        return resolved
    }
    static var interfaceBundle: Bundle {
        localizationBundle(for: interfaceLanguage)
    }
}

/// Shared usage telemetry & typing cadence tracker stored locally in the App Group (`group.crh.key.keyboardplus`).
enum KeyboardUsageStats {
    static let totalCharsKey = "crh.key.stats.totalCharacters"
    static let totalWordsKey = "crh.key.stats.totalWords"
    static let manualWordsKey = "crh.key.stats.manualWords"
    static let suggestedWordsKey = "crh.key.stats.suggestedWords"
    static let suggestedCharsKey = "crh.key.stats.suggestedCharacters"
    static let learnedWordsKey = "crh.key.stats.learnedWords"
    static let uniqueWordsKey = "crh.key.stats.uniqueWords"
    static let activeSecondsKey = "crh.key.stats.activeSeconds"
    static let peakWPMKey = "crh.key.stats.peakWPM"
    static let peakCPMKey = "crh.key.stats.peakCPM"
    static let lastWPMKey = "crh.key.stats.lastWPM"
    static let lastCPMKey = "crh.key.stats.lastCPM"
    static let phrasesInsertedKey = "crh.key.stats.phrasesInserted"
    static let lastInjectedTimestampKey = "crh.key.stats.lastInjectedTimestamp"

    static let statsUpdatedNotification = "crh.key.statsDidUpdate"
    static let statsResetNotification = "crh.key.statsDidReset"
    static let userLexiconChangedNotification = "crh.key.userLexiconDidChange"

    private static var recentKeystrokeTimes: [CFAbsoluteTime] = []
    private static var lastKeystrokeTime: CFAbsoluteTime = 0
    private static var hasCompletedWordInSession: Bool = false
    private static let syncQueue = DispatchQueue(label: "crh.key.statsSyncQueue", qos: .utility)
    private static var isCoalescedSyncPending = false

    static var totalCharacters: Int { KeyboardPreferences.defaults.integer(forKey: totalCharsKey) }
    static var manualWords: Int {
        let defaults = KeyboardPreferences.defaults
        if defaults.object(forKey: manualWordsKey) != nil || defaults.object(forKey: suggestedWordsKey) != nil {
            return defaults.integer(forKey: manualWordsKey)
        }
        return defaults.integer(forKey: totalWordsKey)
    }
    static var suggestedWords: Int { KeyboardPreferences.defaults.integer(forKey: suggestedWordsKey) }
    static var suggestedCharacters: Int { KeyboardPreferences.defaults.integer(forKey: suggestedCharsKey) }
    static var totalWords: Int {
        let defaults = KeyboardPreferences.defaults
        if defaults.object(forKey: manualWordsKey) != nil || defaults.object(forKey: suggestedWordsKey) != nil {
            return defaults.integer(forKey: manualWordsKey) + defaults.integer(forKey: suggestedWordsKey)
        }
        return defaults.integer(forKey: totalWordsKey)
    }
    static var learnedWords: Int { KeyboardPreferences.defaults.integer(forKey: learnedWordsKey) }
    static var uniqueWords: Int { KeyboardPreferences.defaults.integer(forKey: uniqueWordsKey) }
    static var activeSeconds: Double { KeyboardPreferences.defaults.double(forKey: activeSecondsKey) }
    static var peakWPM: Int { KeyboardPreferences.defaults.integer(forKey: peakWPMKey) }
    static var peakCPM: Int { KeyboardPreferences.defaults.integer(forKey: peakCPMKey) }
    static var lastWPM: Int { KeyboardPreferences.defaults.integer(forKey: lastWPMKey) }
    static var lastCPM: Int { KeyboardPreferences.defaults.integer(forKey: lastCPMKey) }
    static var phrasesInserted: Int { KeyboardPreferences.defaults.integer(forKey: phrasesInsertedKey) }

    /// Effective typing speed multiplier achieved by using the 3 predictive suggestion slots.
    static var suggestionSpeedMultiplier: Double {
        let suggestedW = suggestedWords
        guard suggestedW > 0 else { return 1.0 }
        let manualC = max(totalCharacters, 0)
        let savedC = max(suggestedCharacters, suggestedW * 4)
        guard manualC > 0 else {
            return min(Double(1 + suggestedW), 5.0)
        }
        let ratio = Double(manualC + savedC) / Double(manualC)
        return min(max((ratio * 10.0).rounded() / 10.0, 1.1), 9.9)
    }

    /// Returns speed tier index (0...5) and next tier target WPM (if any).
    static func speedTier(for wpm: Int) -> (level: Int, nextTargetWPM: Int?) {
        switch wpm {
        case ..<1: return (0, 15)
        case 1..<25: return (1, 25)
        case 25..<40: return (2, 40)
        case 40..<55: return (3, 55)
        case 55..<75: return (4, 75)
        default: return (5, nil)
        }
    }

    /// Returns word volume tier index (0...5) and next tier target words (if any).
    static func volumeTier(for words: Int) -> (level: Int, nextTargetWords: Int?) {
        switch words {
        case ..<1: return (0, 1)
        case 1..<50: return (1, 50)
        case 50..<250: return (2, 250)
        case 250..<1000: return (3, 1000)
        case 1000..<5000: return (4, 5000)
        default: return (5, nil)
        }
    }

    /// Empirical frequency-weighted average word length in the Crimean Tatar corpus (`qırım_tatar.db`),
    /// including the trailing space (`6.4` letters + `1` space = `7.4` chars/word).
    static let crhCharsPerWord: Double = 7.4

    /// Clears in-memory keystroke timing buffers and cancels coalesced sync work when statistics are disabled.
    static func reclaimResourcesWhenDisabled() {
        recentKeystrokeTimes.removeAll(keepingCapacity: false)
        lastKeystrokeTime = 0
        hasCompletedWordInSession = false
        isCoalescedSyncPending = false
    }

    /// Posts a Darwin notification immediately for an open `HomeView` while debouncing
    /// `CFPreferencesAppSynchronize` disk flushes to `1.2s` during rapid typing (or flushing
    /// immediately on word completion, word learning, phrase insertion, or keyboard hide).
    static func scheduleCrossProcessSync(immediate: Bool = false) {
        guard KeyboardPreferences.statsEnabled else { return }
        if immediate {
            syncQueue.async {
                CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                CFNotificationCenterPostNotification(
                    CFNotificationCenterGetDarwinNotifyCenter(),
                    CFNotificationName(statsUpdatedNotification as CFString),
                    nil,
                    nil,
                    true
                )
            }
            return
        }
        syncQueue.async {
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName(statsUpdatedNotification as CFString),
                nil,
                nil,
                true
            )
            guard !isCoalescedSyncPending else { return }
            isCoalescedSyncPending = true
            syncQueue.asyncAfter(deadline: .now() + 1.2) {
                isCoalescedSyncPending = false
                CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                CFNotificationCenterPostNotification(
                    CFNotificationCenterGetDarwinNotifyCenter(),
                    CFNotificationName(statsUpdatedNotification as CFString),
                    nil,
                    nil,
                    true
                )
            }
        }
    }

    /// Records a manual character keystroke and updates live WPM / CPM, peak speed, and active typing time.
    /// `count` is the number of characters inserted (e.g. 2 for a Cyrillic digraph `къ`), while `keystrokes`
    /// is the number of physical taps (default 1) so multi-character keys do not create zero-delta timestamp pairs.
    @discardableResult
    static func recordCharacterTyped(count: Int = 1, keystrokes: Int = 1) -> (wpm: Int, cpm: Int) {
        guard KeyboardPreferences.statsEnabled else { return (0, 0) }
        let now = CFAbsoluteTimeGetCurrent()
        let defaults = KeyboardPreferences.defaults

        let newTotal = defaults.integer(forKey: totalCharsKey) + max(count, 1)
        defaults.set(newTotal, forKey: totalCharsKey)

        if lastKeystrokeTime > 0 {
            let delta = now - lastKeystrokeTime
            if delta > 0 && delta <= 8.0 {
                let updatedActive = defaults.double(forKey: activeSecondsKey) + delta
                defaults.set(updatedActive, forKey: activeSecondsKey)
            } else if delta > 8.0 {
                recentKeystrokeTimes.removeAll()
                hasCompletedWordInSession = false
            }
        } else {
            // Seed initial 1.2s of active time on first keystroke of a session
            let updatedActive = defaults.double(forKey: activeSecondsKey) + 1.2
            defaults.set(updatedActive, forKey: activeSecondsKey)
        }
        lastKeystrokeTime = now

        for _ in 0..<max(keystrokes, 1) {
            recentKeystrokeTimes.append(now)
        }
        recentKeystrokeTimes.removeAll { now - $0 > 12.0 }

        var cpm = 0
        var wpm = 0
        if recentKeystrokeTimes.count >= 2, let first = recentKeystrokeTimes.first {
            let span = max(now - first, 1.2)
            cpm = min(Int((Double(recentKeystrokeTimes.count) / span * 60.0).rounded()), 750)
            defaults.set(cpm, forKey: lastCPMKey)
            if cpm > defaults.integer(forKey: peakCPMKey) {
                defaults.set(cpm, forKey: peakCPMKey)
            }
            if hasCompletedWordInSession || (recentKeystrokeTimes.count >= 8 && (now - first) >= 2.0) {
                wpm = max(1, Int((Double(cpm) / crhCharsPerWord).rounded()))
                defaults.set(wpm, forKey: lastWPMKey)
                if wpm > defaults.integer(forKey: peakWPMKey) {
                    defaults.set(wpm, forKey: peakWPMKey)
                }
            }
        }
        scheduleCrossProcessSync(immediate: false)
        return (wpm, cpm)
    }

    static func recordManualWordCompleted() {
        guard KeyboardPreferences.statsEnabled else { return }
        hasCompletedWordInSession = true
        let defaults = KeyboardPreferences.defaults
        let newManual = manualWords + 1
        let currentSuggested = defaults.integer(forKey: suggestedWordsKey)
        defaults.set(newManual, forKey: manualWordsKey)
        defaults.set(newManual + currentSuggested, forKey: totalWordsKey)

        let currentCPM = defaults.integer(forKey: lastCPMKey)
        if currentCPM > 0 {
            let wpm = max(1, Int((Double(currentCPM) / crhCharsPerWord).rounded()))
            defaults.set(wpm, forKey: lastWPMKey)
            if wpm > defaults.integer(forKey: peakWPMKey) {
                defaults.set(wpm, forKey: peakWPMKey)
            }
        }
        scheduleCrossProcessSync(immediate: true)
    }

    static func recordSuggestedWordCompleted(savedCharacters: Int = 4) {
        guard KeyboardPreferences.statsEnabled else { return }
        let defaults = KeyboardPreferences.defaults
        let currentManual = manualWords
        let newSuggested = defaults.integer(forKey: suggestedWordsKey) + 1
        let newSavedChars = defaults.integer(forKey: suggestedCharsKey) + max(savedCharacters, 2)
        defaults.set(currentManual, forKey: manualWordsKey)
        defaults.set(newSuggested, forKey: suggestedWordsKey)
        defaults.set(newSavedChars, forKey: suggestedCharsKey)
        defaults.set(currentManual + newSuggested, forKey: totalWordsKey)
        markInjectedText()
        scheduleCrossProcessSync(immediate: true)
    }

    static func recordWordCompleted() {
        recordManualWordCompleted()
    }

    static func recordWordLearned() {
        guard KeyboardPreferences.statsEnabled else { return }
        let defaults = KeyboardPreferences.defaults
        defaults.set(defaults.integer(forKey: learnedWordsKey) + 1, forKey: learnedWordsKey)
        scheduleCrossProcessSync(immediate: true)
    }

    static func updateLearnedWordsCount(_ count: Int) {
        guard KeyboardPreferences.statsEnabled else { return }
        setLearnedWordsCount(count)
    }

    static func setLearnedWordsCount(_ count: Int) {
        let defaults = KeyboardPreferences.defaults
        let clamped = max(0, count)
        if defaults.integer(forKey: learnedWordsKey) != clamped {
            defaults.set(clamped, forKey: learnedWordsKey)
            scheduleCrossProcessSync(immediate: true)
        }
    }

    static func setUniqueWordsCount(_ count: Int) {
        let defaults = KeyboardPreferences.defaults
        let clamped = max(0, count)
        if defaults.integer(forKey: uniqueWordsKey) != clamped {
            defaults.set(clamped, forKey: uniqueWordsKey)
            scheduleCrossProcessSync(immediate: true)
        }
    }

    /// When the user types in the in-app sandbox while Full Access is not yet enabled for the keyboard extension,
    /// the host app records the completed word count in App Group stats without auto-adding words to the Personal Dictionary.
    static func recordSandboxCommittedWordIfNeeded(oldText: String, newText: String, isFullAccessGranted: Bool) {
        guard !isFullAccessGranted else { return }
        guard newText.count == oldText.count + 1,
              newText.hasPrefix(oldText),
              let addedChar = newText.last else { return }
        let isDelimiter = addedChar.isWhitespace || ".!?,;:".contains(addedChar)
        guard isDelimiter else { return }
        guard let lastOldChar = oldText.last, lastOldChar.isLetter || lastOldChar.isNumber else { return }

        if KeyboardPreferences.statsEnabled {
            recordCharacterTyped(count: 1)
            recordManualWordCompleted()
        }
    }

    private static func writableUserLexiconDatabaseURL() -> URL? {
        let fm = FileManager.default
        if let containerDir = AppConfiguration.appGroupContainerURL {
            try? fm.createDirectory(at: containerDir, withIntermediateDirectories: true)
            if fm.isWritableFile(atPath: containerDir.path) {
                return containerDir.appendingPathComponent("user_lexicon.sqlite")
            }
        }
        if let supportDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? fm.createDirectory(at: supportDir, withIntermediateDirectories: true)
            return supportDir.appendingPathComponent("user_lexicon.sqlite")
        }
        return nil
    }

    private static func userLexiconDatabaseURL() -> URL? {
        if let containerDir = AppConfiguration.appGroupContainerURL {
            let url = containerDir.appendingPathComponent("user_lexicon.sqlite")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        if let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            let directURL = supportDir.appendingPathComponent("user_lexicon.sqlite")
            if FileManager.default.fileExists(atPath: directURL.path) {
                return directURL
            }
            let fallbackURL = supportDir
                .appendingPathComponent("QirimKeyUserLexicon", isDirectory: true)
                .appendingPathComponent("user_lexicon.sqlite")
            if FileManager.default.fileExists(atPath: fallbackURL.path) {
                return fallbackURL
            }
        }
        return AppConfiguration.appGroupContainerURL?.appendingPathComponent("user_lexicon.sqlite")
    }

    /// Reads the exact row count of custom personal-dictionary words (`is_custom = 1`) and total unique words (`user_unigrams`)
    /// from `user_lexicon.sqlite` in the shared App Group container so `learnedWords` and `uniqueWords` in `HomeView` stay synchronized.
    /// When called on the main thread, dispatches the SQLite read to `syncQueue` and returns the cached count immediately.
    @discardableResult
    static func syncLearnedWordsCountFromSQLite() -> Int {
        let defaults = KeyboardPreferences.defaults
        let stored = defaults.integer(forKey: learnedWordsKey)
        if Thread.isMainThread {
            syncQueue.async {
                _ = performSyncLearnedWordsCountFromSQLite()
            }
            return stored
        }
        return performSyncLearnedWordsCountFromSQLite()
    }

    @discardableResult
    private static func performSyncLearnedWordsCountFromSQLite() -> Int {
        let defaults = KeyboardPreferences.defaults
        let stored = defaults.integer(forKey: learnedWordsKey)
        let storedUnique = defaults.integer(forKey: uniqueWordsKey)
        let isDemoMode = CommandLine.arguments.contains("-qt_demo_stats") || CommandLine.arguments.contains("-qt_seed_demo_stats")
        guard let dbURL = userLexiconDatabaseURL(),
              FileManager.default.fileExists(atPath: dbURL.path) else {
            if !isDemoMode && (stored != 0 || storedUnique != 0) {
                defaults.set(0, forKey: learnedWordsKey)
                defaults.set(0, forKey: uniqueWordsKey)
                CFNotificationCenterPostNotification(
                    CFNotificationCenterGetDarwinNotifyCenter(),
                    CFNotificationName(statsUpdatedNotification as CFString),
                    nil,
                    nil,
                    true
                )
                return 0
            }
            return stored
        }
        var db: OpaquePointer?
        let openRC = sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX, nil)
        if openRC != SQLITE_OK {
            if let db { sqlite3_close_v2(db) }
            db = nil
            guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
                if let db { sqlite3_close_v2(db) }
                return stored
            }
        } else {
            sqlite3_exec(db, "PRAGMA wal_checkpoint(PASSIVE);", nil, nil, nil)
            sqlite3_exec(db, "ALTER TABLE user_unigrams ADD COLUMN is_custom INTEGER NOT NULL DEFAULT 0;", nil, nil, nil)
        }
        sqlite3_busy_timeout(db, 150)
        defer { sqlite3_close_v2(db) }

        var customCount = 0
        do {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM user_unigrams WHERE is_custom = 1;", -1, &stmt, nil) == SQLITE_OK,
               sqlite3_step(stmt) == SQLITE_ROW {
                customCount = Int(sqlite3_column_int(stmt, 0))
            }
        }

        var totalUniqueCount = 0
        do {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM user_unigrams;", -1, &stmt, nil) == SQLITE_OK,
               sqlite3_step(stmt) == SQLITE_ROW {
                totalUniqueCount = Int(sqlite3_column_int(stmt, 0))
            }
        }

        let isDemoSeeded = isDemoMode && customCount == 0
        let resolvedCustom = isDemoSeeded ? max(stored, customCount) : customCount
        let resolvedUnique = isDemoSeeded ? max(storedUnique, totalUniqueCount) : totalUniqueCount
        var didChange = false
        if resolvedCustom != stored {
            defaults.set(resolvedCustom, forKey: learnedWordsKey)
            didChange = true
        }
        if resolvedUnique != storedUnique {
            defaults.set(resolvedUnique, forKey: uniqueWordsKey)
            didChange = true
        }
        if didChange {
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName(statsUpdatedNotification as CFString),
                nil,
                nil,
                true
            )
        }
        return resolvedCustom
    }

    /// Returns the user's explicitly saved personal-dictionary words (`is_custom = 1`) from `user_unigrams` ordered by most recently used.
    static func fetchLearnedWords(limit: Int = 500) -> [(word: String, freq: Int, lastUsed: Int64)] {
        let isDemoMode = CommandLine.arguments.contains("-qt_demo_stats") || CommandLine.arguments.contains("-qt_seed_demo_stats")
        if isDemoMode {
            let currentStored = KeyboardPreferences.defaults.integer(forKey: learnedWordsKey)
            if currentStored == 18 {
                seedDemoLearnedWordsIfNeeded()
            }
        }
        guard let dbURL = userLexiconDatabaseURL(),
              FileManager.default.fileExists(atPath: dbURL.path) else {
            return []
        }
        var db: OpaquePointer?
        let openRC = sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX, nil)
        if openRC != SQLITE_OK {
            if let db { sqlite3_close_v2(db) }
            db = nil
            guard sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK else {
                if let db { sqlite3_close_v2(db) }
                return []
            }
        } else {
            sqlite3_exec(db, "PRAGMA wal_checkpoint(PASSIVE);", nil, nil, nil)
            sqlite3_exec(db, "ALTER TABLE user_unigrams ADD COLUMN is_custom INTEGER NOT NULL DEFAULT 0;", nil, nil, nil)
        }
        sqlite3_busy_timeout(db, 150)
        defer { sqlite3_close_v2(db) }
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        let sql = "SELECT word, freq, last_used FROM user_unigrams WHERE is_custom = 1 ORDER BY last_used DESC, freq DESC, word ASC LIMIT ?1;"
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK,
              sqlite3_bind_int(stmt, 1, Int32(max(1, limit))) == SQLITE_OK else {
            return []
        }
        var words: [(word: String, freq: Int, lastUsed: Int64)] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let ptr = sqlite3_column_text(stmt, 0) {
                let word = String(cString: ptr)
                let freq = Int(sqlite3_column_int(stmt, 1))
                let lastUsed = sqlite3_column_int64(stmt, 2)
                words.append((word: word, freq: max(1, freq), lastUsed: lastUsed))
            }
        }
        return words
    }

    /// Deletes a single learned word from `user_unigrams` and `user_bigrams`, updates `learnedWordsKey`, and returns the exact remaining count.
    @discardableResult
    static func deleteLearnedWord(_ word: String) -> Int {
        let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased(with: Locale(identifier: "crh-Latn"))
        guard !normalized.isEmpty,
              let dbURL = userLexiconDatabaseURL(),
              FileManager.default.fileExists(atPath: dbURL.path) else {
            return fetchLearnedWords().count
        }
        let sqlTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        var db: OpaquePointer?
        var remainingTotalUnique = 0
        if sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK {
            sqlite3_busy_timeout(db, 150)
            do {
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }
                if sqlite3_prepare_v2(db, "DELETE FROM user_unigrams WHERE word = ?1;", -1, &stmt, nil) == SQLITE_OK {
                    _ = normalized.withCString { cStr in
                        sqlite3_bind_text(stmt, 1, cStr, -1, sqlTransient)
                    }
                    sqlite3_step(stmt)
                }
            }
            do {
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }
                if sqlite3_prepare_v2(db, "DELETE FROM user_bigrams WHERE word1 = ?1 OR word2 = ?1;", -1, &stmt, nil) == SQLITE_OK {
                    _ = normalized.withCString { cStr in
                        sqlite3_bind_text(stmt, 1, cStr, -1, sqlTransient)
                    }
                    sqlite3_step(stmt)
                }
            }
            do {
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }
                if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM user_unigrams;", -1, &stmt, nil) == SQLITE_OK,
                   sqlite3_step(stmt) == SQLITE_ROW {
                    remainingTotalUnique = Int(sqlite3_column_int(stmt, 0))
                }
            }
        }
        if let db {
            sqlite3_close_v2(db)
        }
        let remainingCount = fetchLearnedWords().count
        setLearnedWordsCount(remainingCount)
        setUniqueWordsCount(remainingTotalUnique)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(userLexiconChangedNotification as CFString),
            nil,
            nil,
            true
        )
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(statsUpdatedNotification as CFString),
            nil,
            nil,
            true
        )
        return remainingCount
    }

    /// Clears all learned words from the personal dictionary without resetting general typing statistics.
    static func clearAllLearnedWords() {
        if let dbURL = userLexiconDatabaseURL(),
           FileManager.default.fileExists(atPath: dbURL.path) {
            var db: OpaquePointer?
            var remainingTotalUnique = 0
            if sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK {
                sqlite3_busy_timeout(db, 150)
                sqlite3_exec(db, "ALTER TABLE user_unigrams ADD COLUMN is_custom INTEGER NOT NULL DEFAULT 0;", nil, nil, nil)
                sqlite3_exec(db, "DELETE FROM user_unigrams WHERE is_custom = 1;", nil, nil, nil)
                var stmt: OpaquePointer?
                defer { sqlite3_finalize(stmt) }
                if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM user_unigrams;", -1, &stmt, nil) == SQLITE_OK,
                   sqlite3_step(stmt) == SQLITE_ROW {
                    remainingTotalUnique = Int(sqlite3_column_int(stmt, 0))
                }
            }
            if let db {
                sqlite3_close_v2(db)
            }
            setUniqueWordsCount(remainingTotalUnique)
        }
        setLearnedWordsCount(0)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(userLexiconChangedNotification as CFString),
            nil,
            nil,
            true
        )
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(statsUpdatedNotification as CFString),
            nil,
            nil,
            true
        )
    }

    static func clearLearnedWords() {
        clearAllLearnedWords()
    }

    /// Seeds demo learned words into `user_lexicon.sqlite` when `-qt_demo_stats` is active and the lexicon is empty.
    static func seedDemoLearnedWordsIfNeeded() {
        guard let dbURL = AppConfiguration.appGroupContainerURL?.appendingPathComponent("user_lexicon.sqlite") else { return }
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_NOMUTEX
        guard sqlite3_open_v2(dbURL.path, &db, flags, nil) == SQLITE_OK else {
            if let db { sqlite3_close_v2(db) }
            return
        }
        sqlite3_busy_timeout(db, 150)
        defer { sqlite3_close_v2(db) }
        let schema = """
        CREATE TABLE IF NOT EXISTS user_unigrams (
            word TEXT PRIMARY KEY,
            freq INTEGER NOT NULL DEFAULT 1,
            last_used INTEGER NOT NULL DEFAULT 0,
            is_custom INTEGER NOT NULL DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS user_bigrams (
            word1 TEXT NOT NULL,
            word2 TEXT NOT NULL,
            freq INTEGER NOT NULL DEFAULT 1,
            last_used INTEGER NOT NULL DEFAULT 0,
            PRIMARY KEY (word1, word2)
        );
        """
        sqlite3_exec(db, schema, nil, nil, nil)
        sqlite3_exec(db, "ALTER TABLE user_unigrams ADD COLUMN is_custom INTEGER NOT NULL DEFAULT 0;", nil, nil, nil)
        do {
            var countStmt: OpaquePointer?
            defer { sqlite3_finalize(countStmt) }
            if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM user_unigrams WHERE is_custom = 1 AND word = 'Spotify';", -1, &countStmt, nil) == SQLITE_OK,
               sqlite3_step(countStmt) == SQLITE_ROW,
               sqlite3_column_int(countStmt, 0) > 0 {
                return
            }
        }
        sqlite3_exec(db, "DELETE FROM user_unigrams WHERE is_custom = 1;", nil, nil, nil)
        let demoWords = [
            "Spotify", "Netflix", "Telegram", "WhatsApp", "GitHub",
            "LinkedIn", "Coursera", "Duolingo", "Airbnb", "PayPal",
            "Starlink", "OpenAI", "MacBook", "Bluetooth", "Grammarly",
            "Revolut", "Figma", "Cloudflare"
        ]
        let sqlTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        let now = Int64(Date().timeIntervalSince1970)
        for (idx, word) in demoWords.enumerated() {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "INSERT OR REPLACE INTO user_unigrams(word, freq, last_used, is_custom) VALUES (?1, ?2, ?3, 1);"
            if sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK {
                _ = word.withCString { cStr in
                    sqlite3_bind_text(stmt, 1, cStr, -1, sqlTransient)
                }
                sqlite3_bind_int(stmt, 2, Int32(max(1, 5 - (idx % 4))))
                sqlite3_bind_int64(stmt, 3, now - Int64(idx * 60))
                sqlite3_step(stmt)
            }
        }
    }

    static func markInjectedText(_ text: String = "") {
        guard KeyboardPreferences.statsEnabled else { return }
        KeyboardPreferences.defaults.set(CFAbsoluteTimeGetCurrent(), forKey: lastInjectedTimestampKey)
    }

    static func wasRecentlyInjected(within seconds: Double = 0.85) -> Bool {
        guard KeyboardPreferences.statsEnabled else { return false }
        let ts = KeyboardPreferences.defaults.double(forKey: lastInjectedTimestampKey)
        guard ts > 0 else { return false }
        return abs(CFAbsoluteTimeGetCurrent() - ts) < seconds
    }

    static func recordPhraseInserted() {
        guard KeyboardPreferences.statsEnabled else { return }
        let defaults = KeyboardPreferences.defaults
        defaults.set(defaults.integer(forKey: phrasesInsertedKey) + 1, forKey: phrasesInsertedKey)
        markInjectedText()
        scheduleCrossProcessSync(immediate: true)
    }

    static func clearUserLexiconDatabaseInPlace() {
        guard let dbURL = userLexiconDatabaseURL(),
              FileManager.default.fileExists(atPath: dbURL.path) else {
            return
        }
        var db: OpaquePointer?
        if sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_NOMUTEX, nil) == SQLITE_OK {
            sqlite3_busy_timeout(db, 150)
            sqlite3_exec(db, "DELETE FROM user_unigrams; DELETE FROM user_bigrams;", nil, nil, nil)
        }
        if let db {
            sqlite3_close_v2(db)
        }
    }

    static func resetAll() {
        let defaults = KeyboardPreferences.defaults
        let keys = [
            totalCharsKey,
            totalWordsKey,
            manualWordsKey,
            suggestedWordsKey,
            suggestedCharsKey,
            learnedWordsKey,
            uniqueWordsKey,
            activeSecondsKey,
            peakWPMKey,
            peakCPMKey,
            lastWPMKey,
            lastCPMKey,
            phrasesInsertedKey,
            lastInjectedTimestampKey
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        clearUserLexiconDatabaseInPlace()
        recentKeystrokeTimes.removeAll()
        lastKeystrokeTime = 0
        hasCompletedWordInSession = false
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(statsResetNotification as CFString),
            nil,
            nil,
            true
        )
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(statsUpdatedNotification as CFString),
            nil,
            nil,
            true
        )
    }
}

/// App icon badge (`Image("logo")` / `qirim_logo.png` & `qirim_logo_dark.png`) adapted natively to the active Light/Dark app theme.
struct TaraqTamgaLogoBadge: View {
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 7
    @Environment(\.colorScheme) private var colorScheme

    private var lightGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 247.0 / 255.0, green: 228.0 / 255.0, blue: 217.0 / 255.0),
                Color(red: 187.0 / 255.0, green: 191.0 / 255.0, blue: 223.0 / 255.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var darkGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 15.0 / 255.0, green: 26.0 / 255.0, blue: 38.0 / 255.0),
                Color(red: 21.0 / 255.0, green: 37.0 / 255.0, blue: 54.0 / 255.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Flat key silhouette around the Tamga (same geometry as the app icon, light and dark).
    @ViewBuilder
    private var keyCap: some View {
        let box = size * 0.727
        let corner = size * 0.164
        let isDark = colorScheme == .dark
        ZStack {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .fill(isDark ? Color(red: 33.0 / 255.0, green: 50.0 / 255.0, blue: 70.0 / 255.0) : Color.white)
                .shadow(color: Color.black.opacity(isDark ? 0.35 : 0.14), radius: size * 0.02, x: 0, y: size * 0.015)
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(
                    isDark ? Color(red: 84.0 / 255.0, green: 108.0 / 255.0, blue: 138.0 / 255.0) : Color(red: 206.0 / 255.0, green: 209.0 / 255.0, blue: 228.0 / 255.0),
                    lineWidth: max(0.5, size * 0.005)
                )
            SharedTaraqTamgaShape()
                .fill(isDark ? Color.white : Color.black)
                .frame(width: size * 0.469, height: size * 0.261)
        }
        .frame(width: box, height: box)
    }

    private static let hasLogoAsset: Bool = (UIImage(named: "logo") != nil)

    private var unitSize: CGFloat {
        (size * (702.0 / 1024.0)) / 9.0
    }

    var body: some View {
        Group {
            if Self.hasLogoAsset {
                Image("logo")
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(colorScheme == .dark ? darkGradient : lightGradient)
                    keyCap
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.22 : 0.14), lineWidth: 0.75)
        )
    }
}

struct SharedTaraqTamgaShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / 9.0, rect.height / 5.0)
        let drawWidth = scale * 9.0
        let drawHeight = scale * 5.0
        let originX = rect.minX + (rect.width - drawWidth) * 0.5
        let originY = rect.minY + (rect.height - drawHeight) * 0.5
        let cornerRadius = scale * 0.045

        func pt(_ gx: CGFloat, _ gy: CGFloat) -> CGPoint {
            CGPoint(x: originX + gx * scale, y: originY + gy * scale)
        }

        let vertices: [CGPoint] = [
            pt(1, 0), pt(8, 0),
            pt(8, 3), pt(9, 3),
            pt(9, 4), pt(7, 4),
            pt(7, 1), pt(5, 1),
            pt(5, 4), pt(6, 4),
            pt(6, 5), pt(3, 5),
            pt(3, 4), pt(4, 4),
            pt(4, 1), pt(2, 1),
            pt(2, 4), pt(0, 4),
            pt(0, 3), pt(1, 3)
        ]

        var path = Path()
        let count = vertices.count
        let startMid = CGPoint(
            x: (vertices[count - 1].x + vertices[0].x) * 0.5,
            y: (vertices[count - 1].y + vertices[0].y) * 0.5
        )
        path.move(to: startMid)
        for i in 0..<count {
            let current = vertices[i]
            let next = vertices[(i + 1) % count]
            path.addArc(tangent1End: current, tangent2End: next, radius: cornerRadius)
        }
        path.closeSubpath()
        return path
    }
}

enum AppConfiguration {
    static let appGroupID = "group.crh.key.keyboardplus"
    static let appDeepLink = "kkdemo://dictation"
    static let appBundleId = "crh.key.keyboard"
    static let keyboardBundleId = "crh.key.keyboard.keyboard"
    static let cyrillicKeyboardBundleId = "crh.key.keyboard.KeyboardCyrillic"
    static let ukrainianKeyboardBundleId = "crh.key.keyboard.KeyboardUkrainian"
    static let ukrainianDeviceKeyboardBundleId = "crh.key.keyboard.pro"
    static let keyboardBundleIdPattern = "crh.key.keyboard*"
    static let fallbackDocumentID = UUID()
    static var lastValidDocumentIdentifier: UUID?

    static func isUkrainianCyrillicKeyboardExtensionBundleId(_ bundleId: String?) -> Bool {
        bundleId == ukrainianKeyboardBundleId || bundleId == ukrainianDeviceKeyboardBundleId
    }

    static func isCyrillicKeyboardExtensionBundleId(_ bundleId: String?) -> Bool {
        bundleId == cyrillicKeyboardBundleId || isUkrainianCyrillicKeyboardExtensionBundleId(bundleId)
    }

    static var appGroupContainerURL: URL? {
        guard let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID),
              FileManager.default.isWritableFile(atPath: url.path) else {
            return nil
        }
        return url
    }
}

extension UITextDocumentProxy {
    /// Safely reads `documentIdentifier` via KVC so a temporarily `nil` Objective-C return during an XPC transition
    /// does not trap in `UUID._unconditionallyBridgeFromObjectiveC` or reset session state mid-typing.
    var safeDocumentIdentifier: UUID {
        if let id = (self as AnyObject).value(forKey: "documentIdentifier") as? UUID {
            AppConfiguration.lastValidDocumentIdentifier = id
            return id
        }
        return AppConfiguration.lastValidDocumentIdentifier ?? AppConfiguration.fallbackDocumentID
    }
}

/// Reads live iOS/iPadOS system keyboard settings (`Settings → General → Keyboards`)
/// from system keyboard preferences controllers, `CFPreferences`, `UserDefaults`, App Group cache, and `UITextDocumentProxy`.
enum SystemKeyboardSettings {

    enum Feature: String {
        case capsLock, periodShortcut, keyFlicks, slideToType, deleteSlideToTypeByWord
        case smartPunctuation, predictiveText, autoCorrection, autoCapitalization
        case mathResults, emojiPicker

        var preferenceKey: String { "crh.key.feature.\(rawValue)" }
    }

    static func isFeatureEnabled(_ feature: Feature) -> Bool {
        KeyboardPreferences.defaults.object(forKey: feature.preferenceKey) as? Bool ?? true
    }

    static func setFeature(_ feature: Feature, enabled: Bool) {
        KeyboardPreferences.defaults.set(enabled, forKey: feature.preferenceKey)
    }

    private static var cacheLock = os_unfair_lock_s()
    private static var cachedValues: [String: Bool] = [:]
    private static var lastSyncTimestamp: TimeInterval = 0
    private static var isRefreshing = false
    private static let refreshQueue = DispatchQueue(label: "crh.key.sysPrefsRefresh", qos: .utility)

    private static let knownKeyGroups: [([String], Bool)] = [
        (["KeyboardCapsLock", "UIKeyboardCapsLock"], true),
        (["KeyboardPeriodShortcut", "UIKeyboardPeriodShortcut"], true),
        (["KeyboardAutocapitalization", "UIKeyboardAutocapitalization"], true),
        (["KeyboardAutocorrection", "UIKeyboardAutocorrection"], true),
        (["KeyboardPrediction", "UIKeyboardPrediction", "KeyboardPredictions", "KeyboardShowPredictionBar"], true),
        (["KeyboardCheckSpelling", "UIKeyboardCheckSpelling"], true),
        (["KeyboardPullDown", "UIKeyboardGesturePullDown", "KeyboardKeyFlicksEnabled"], true),
        (["KeyboardContinuousPathEnabled", "UIKeyboardContinuousPathEnabled"], true),
        (["KeyboardFloatingContinuousPathEnabled", "UIKeyboardFloatingContinuousPathEnabled", "KeyboardContinuousPathEnabled"], true),
        (["KeyboardContinuousPathDeleteWholeWord", "UIKeyboardContinuousPathDeleteWholeWord"], true),
        (["KeyboardSmartPunctuation", "UIKeyboardSmartPunctuation", "SmartQuotesEnabled", "KeyboardSmartQuotesEnabled", "UIKeyboardSmartQuotesEnabled"], true),
        (["SmartDashesEnabled", "KeyboardSmartDashesEnabled", "UIKeyboardSmartDashesEnabled"], true),
        (["KeyboardMathExpressionCompletion", "UIKeyboardMathExpressionCompletion", "ShowMathResults"], true),
        (["KeyboardPlaysAudio", "UIKeyboardPlaysAudio"], true)
    ]

    private static func pollSystemPreferenceFromOS(_ keys: [String], shouldSync: Bool, default defaultValue: Bool) -> Bool {
        for className in [["TIPreferences", "Controller"].joined(), ["UIKeyboardPreferences", "Controller"].joined()] {
            guard let cls: AnyClass = NSClassFromString(className) else { continue }
            let sharedSel = NSSelectorFromString("sharedPreferencesController")
            guard cls.responds(to: sharedSel),
                  let controller = (cls as AnyObject).perform(sharedSel)?.takeUnretainedValue() else { continue }
            let syncSel = NSSelectorFromString("synchronizePreferences")
            if shouldSync, controller.responds(to: syncSel) {
                _ = controller.perform(syncSel)
            }
            let valSel = NSSelectorFromString("valueForPreferenceKey:")
            for key in keys {
                if controller.responds(to: valSel),
                   let raw = controller.perform(valSel, with: key as NSString)?.takeUnretainedValue(),
                   let num = raw as? NSNumber {
                    KeyboardPreferences.defaults.set(num.boolValue, forKey: "crh.key.cachedSysPref.\(keys[0])")
                    return num.boolValue
                }
            }
        }
        let domains: [CFString] = [
            "com.apple.keyboard.preferences" as CFString,
            "com.apple.Preferences" as CFString,
            kCFPreferencesAnyApplication
        ]
        for key in keys {
            for domain in domains {
                if let val = CFPreferencesCopyAppValue(key as CFString, domain) as? NSNumber {
                    KeyboardPreferences.defaults.set(val.boolValue, forKey: "crh.key.cachedSysPref.\(keys[0])")
                    return val.boolValue
                }
            }
            if let num = UserDefaults.standard.object(forKey: key) as? NSNumber {
                KeyboardPreferences.defaults.set(num.boolValue, forKey: "crh.key.cachedSysPref.\(keys[0])")
                return num.boolValue
            }
        }
        if let appGroupCached = KeyboardPreferences.defaults.object(forKey: "crh.key.cachedSysPref.\(keys[0])") as? Bool {
            return appGroupCached
        }
        return defaultValue
    }

    static func triggerAsyncRefreshIfNeeded(force: Bool = false) {
        let now = ProcessInfo.processInfo.systemUptime
        os_unfair_lock_lock(&cacheLock)
        let needsRefresh = !isRefreshing && (force || cachedValues.isEmpty || (now - lastSyncTimestamp) >= 1.5)
        if needsRefresh {
            isRefreshing = true
            lastSyncTimestamp = now
        }
        os_unfair_lock_unlock(&cacheLock)
        guard needsRefresh else { return }

        refreshQueue.async {
            var updated: [String: Bool] = [:]
            for (index, entry) in knownKeyGroups.enumerated() {
                if let primaryKey = entry.0.first {
                    updated[primaryKey] = pollSystemPreferenceFromOS(entry.0, shouldSync: index == 0, default: entry.1)
                }
            }
            _ = enabledSystemKeyboardIdentifiers(forceRefresh: true)
            os_unfair_lock_lock(&cacheLock)
            for (k, v) in updated {
                cachedValues[k] = v
            }
            isRefreshing = false
            os_unfair_lock_unlock(&cacheLock)
        }
    }

    private static func readSystemPreferenceBool(_ keys: [String], default defaultValue: Bool = true) -> Bool {
        for key in keys {
            if let testOverride = KeyboardPreferences.defaults.object(forKey: "crh.key.test.sysPref.\(key)") as? Bool {
                let ts = KeyboardPreferences.defaults.double(forKey: "crh.key.test.uiTestingTimestamp")
                if CommandLine.arguments.contains("-UITesting")
                    || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
                    || (ts > 0 && abs(Date().timeIntervalSince1970 - ts) < 600.0) {
                    return testOverride
                }
            }
        }
        guard let primaryKey = keys.first else { return defaultValue }
        os_unfair_lock_lock(&cacheLock)
        let cached = cachedValues[primaryKey]
        os_unfair_lock_unlock(&cacheLock)
        triggerAsyncRefreshIfNeeded()
        if let cached {
            return cached
        }
        if let appGroupCached = KeyboardPreferences.defaults.object(forKey: "crh.key.cachedSysPref.\(primaryKey)") as? Bool {
            return appGroupCached
        }
        return pollSystemPreferenceFromOS(keys, shouldSync: false, default: defaultValue)
    }

    static var isCapsLockEnabled: Bool {
        guard isFeatureEnabled(.capsLock) else { return false }
        return readSystemPreferenceBool(["KeyboardCapsLock", "UIKeyboardCapsLock"], default: true)
    }

    static var isPeriodShortcutEnabled: Bool {
        guard isFeatureEnabled(.periodShortcut) else { return false }
        return readSystemPreferenceBool(["KeyboardPeriodShortcut", "UIKeyboardPeriodShortcut"], default: true)
    }

    static var isKeyFlicksEnabled: Bool {
        guard isFeatureEnabled(.keyFlicks) else { return false }
        return readSystemPreferenceBool(["KeyboardPullDown", "UIKeyboardGesturePullDown", "KeyboardKeyFlicksEnabled"], default: true)
    }

    static var isSlideToTypeEnabled: Bool {
        guard isFeatureEnabled(.slideToType) else { return false }
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return readSystemPreferenceBool(
                ["KeyboardFloatingContinuousPathEnabled", "UIKeyboardFloatingContinuousPathEnabled", "KeyboardContinuousPathEnabled", "UIKeyboardContinuousPathEnabled"],
                default: true
            )
        }
        #endif
        return readSystemPreferenceBool(["KeyboardContinuousPathEnabled", "UIKeyboardContinuousPathEnabled"], default: true)
    }

    static var isDeleteSlideToTypeByWordEnabled: Bool {
        guard isFeatureEnabled(.deleteSlideToTypeByWord) else { return false }
        return readSystemPreferenceBool(["KeyboardContinuousPathDeleteWholeWord", "UIKeyboardContinuousPathDeleteWholeWord"], default: true)
    }

    static var isSmartPunctuationEnabled: Bool { isSmartPunctuationEnabled(for: nil) }

    static func isSmartPunctuationEnabled(for proxy: UITextDocumentProxy?) -> Bool {
        guard isFeatureEnabled(.smartPunctuation) else { return false }
        if let proxy, proxy.smartQuotesType == .no && proxy.smartDashesType == .no {
            return false
        }
        return readSystemPreferenceBool(
            ["KeyboardSmartPunctuation", "UIKeyboardSmartPunctuation", "SmartQuotesEnabled", "KeyboardSmartQuotesEnabled", "UIKeyboardSmartQuotesEnabled"],
            default: true
        )
    }

    static var isPredictiveTextEnabled: Bool { isPredictiveTextEnabled(for: nil) }

    static func isPredictiveTextEnabled(for proxy: UITextDocumentProxy?) -> Bool {
        guard KeyboardPreferences.suggestionsEnabled, isFeatureEnabled(.predictiveText) else { return false }
        if proxy?.isSecureTextEntry == true { return false }
        return readSystemPreferenceBool(["KeyboardPrediction", "UIKeyboardPrediction", "KeyboardPredictions", "KeyboardShowPredictionBar"], default: true)
    }

    static var isAutoCorrectionEnabled: Bool { isAutoCorrectionEnabled(for: nil) }

    static func isAutoCorrectionEnabled(for proxy: UITextDocumentProxy?) -> Bool {
        guard isPredictiveTextEnabled(for: proxy), isFeatureEnabled(.autoCorrection) else { return false }
        if let proxy, proxy.autocorrectionType == .no { return false }
        return readSystemPreferenceBool(["KeyboardAutocorrection", "UIKeyboardAutocorrection"], default: true)
    }

    static var isAutoCapitalizationEnabled: Bool { isAutoCapitalizationEnabled(for: nil) }

    static func isAutoCapitalizationEnabled(for proxy: UITextDocumentProxy?) -> Bool {
        guard isFeatureEnabled(.autoCapitalization) else { return false }
        if let proxy, let cap = proxy.autocapitalizationType, cap == .none { return false }
        return readSystemPreferenceBool(["KeyboardAutocapitalization", "UIKeyboardAutocapitalization"], default: true)
    }

    static var isShowMathResultsEnabled: Bool { isShowMathResultsEnabled(for: nil) }

    static func isShowMathResultsEnabled(for proxy: UITextDocumentProxy?) -> Bool {
        guard isFeatureEnabled(.mathResults), proxy?.isSecureTextEntry != true else { return false }
        if #available(iOS 18.0, *), proxy?.mathExpressionCompletionType == .no {
            return false
        }
        return readSystemPreferenceBool(["KeyboardMathExpressionCompletion", "UIKeyboardMathExpressionCompletion", "ShowMathResults"], default: true)
    }

    private static var lastEmojiCheckTime: TimeInterval = 0
    private static var cachedEmojiEnabled: Bool?
    private static var lastKeyboardsCheckTime: TimeInterval = 0
    private static var cachedEnabledKeyboardIds: [String]?
    static let cachedEmojiKeyboardEnabledKey = "crh.key.cachedEmojiKeyboardEnabled"
    static let cachedEnabledKeyboardsKey = "crh.key.cachedEnabledKeyboards"

    /// Reads the list of enabled keyboard identifiers from system preferences (`AppleKeyboards`),
    /// `TIPreferencesController`, `UITextInputMode.activeInputModes`, and the App Group cache.
    @discardableResult
    static func enabledSystemKeyboardIdentifiers(forceRefresh: Bool = false) -> [String] {
        let now = ProcessInfo.processInfo.systemUptime
        if !forceRefresh, let cached = cachedEnabledKeyboardIds, (now - lastKeyboardsCheckTime) < 1.5 {
            return cached
        }
        lastKeyboardsCheckTime = now

        var collected: [String] = []
        var didReadAuthoritativeList = false

        if let stdList = UserDefaults.standard.stringArray(forKey: "AppleKeyboards"), !stdList.isEmpty {
            collected.append(contentsOf: stdList)
            didReadAuthoritativeList = true
        }
        let domains: [CFString] = [
            "com.apple.keyboard.preferences" as CFString,
            "com.apple.Preferences" as CFString,
            kCFPreferencesAnyApplication
        ]
        for domain in domains {
            if let list = CFPreferencesCopyAppValue("AppleKeyboards" as CFString, domain) as? [String], !list.isEmpty {
                collected.append(contentsOf: list)
                didReadAuthoritativeList = true
            }
        }
        for className in [["TIPreferences", "Controller"].joined(), ["UIKeyboardPreferences", "Controller"].joined()] {
            guard let cls: AnyClass = NSClassFromString(className) else { continue }
            let sharedSel = NSSelectorFromString("sharedPreferencesController")
            guard cls.responds(to: sharedSel),
                  let controller = (cls as AnyObject).perform(sharedSel)?.takeUnretainedValue() else { continue }
            let valSel = NSSelectorFromString("valueForPreferenceKey:")
            for key in ["Keyboards", "AppleKeyboards"] {
                if controller.responds(to: valSel),
                   let list = controller.perform(valSel, with: key as NSString)?.takeUnretainedValue() as? [String],
                   !list.isEmpty {
                    collected.append(contentsOf: list)
                    didReadAuthoritativeList = true
                }
            }
        }

        let activeModes = UITextInputMode.activeInputModes
        for mode in activeModes {
            if let id = (mode as AnyObject).value(forKey: "identifier") as? String, !id.isEmpty {
                collected.append(id)
            }
            if let lang = mode.primaryLanguage?.replacingOccurrences(of: "_", with: "-").lowercased() {
                if lang.hasPrefix("crh-cyrl-ua") {
                    collected.append(AppConfiguration.ukrainianCyrillicKeyboardBundleId)
                } else if lang.hasPrefix("crh-cyrl") {
                    collected.append(AppConfiguration.cyrillicKeyboardBundleId)
                } else if lang == "crh" || lang.hasPrefix("crh-latn") {
                    collected.append(AppConfiguration.keyboardBundleId)
                }
            }
        }

        if didReadAuthoritativeList {
            let unique = Array(Set(collected))
            cachedEnabledKeyboardIds = unique
            KeyboardPreferences.defaults.set(unique, forKey: cachedEnabledKeyboardsKey)
            return unique
        }

        if let stored = KeyboardPreferences.defaults.stringArray(forKey: cachedEnabledKeyboardsKey), !stored.isEmpty {
            let merged = Array(Set(stored + collected))
            cachedEnabledKeyboardIds = merged
            return merged
        }

        let unique = Array(Set(collected))
        cachedEnabledKeyboardIds = unique
        return unique
    }

    static func hasAuthoritativeSystemKeyboardsList() -> Bool {
        if let stdList = UserDefaults.standard.stringArray(forKey: "AppleKeyboards"), !stdList.isEmpty {
            return true
        }
        let domains: [CFString] = [
            "com.apple.keyboard.preferences" as CFString,
            "com.apple.Preferences" as CFString,
            kCFPreferencesAnyApplication
        ]
        for domain in domains {
            if let list = CFPreferencesCopyAppValue("AppleKeyboards" as CFString, domain) as? [String], !list.isEmpty {
                return true
            }
        }
        for className in [["TIPreferences", "Controller"].joined(), ["UIKeyboardPreferences", "Controller"].joined()] {
            guard let cls: AnyClass = NSClassFromString(className) else { continue }
            let sharedSel = NSSelectorFromString("sharedPreferencesController")
            guard cls.responds(to: sharedSel),
                  let controller = (cls as AnyObject).perform(sharedSel)?.takeUnretainedValue() else { continue }
            let valSel = NSSelectorFromString("valueForPreferenceKey:")
            for key in ["Keyboards", "AppleKeyboards"] {
                if controller.responds(to: valSel),
                   let list = controller.perform(valSel, with: key as NSString)?.takeUnretainedValue() as? [String],
                   !list.isEmpty {
                    return true
                }
            }
        }
        return false
    }

    /// Refreshes and persists whether the system Emoji keyboard is in the user's enabled keyboards list (`Settings → General → Keyboard → Keyboards`).
    @discardableResult
    static func refreshSystemEmojiKeyboardState() -> Bool {
        if Bundle.main.bundleIdentifier == AppConfiguration.appBundleId {
            let args = CommandLine.arguments
            if args.contains("-qt_emoji_disabled") {
                KeyboardPreferences.defaults.set(false, forKey: "crh.key.test.sysPref.EmojiEnabled")
            } else if args.contains("-qt_emoji_enabled") || args.contains("-UITesting") {
                KeyboardPreferences.defaults.set(true, forKey: "crh.key.test.sysPref.EmojiEnabled")
            } else {
                KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.sysPref.EmojiEnabled")
            }
        }
        lastEmojiCheckTime = 0
        cachedEmojiEnabled = nil
        lastKeyboardsCheckTime = 0
        cachedEnabledKeyboardIds = nil
        triggerAsyncRefreshIfNeeded(force: true)
        return isEmojiKeyboardEnabled
    }

    /// Checks whether the Emoji keyboard is enabled in the user's keyboard list (`Settings → General → Keyboard → Keyboards`).
    static var isEmojiKeyboardEnabled: Bool {
        let args = CommandLine.arguments
        if args.contains("-qt_emoji_disabled") {
            return false
        }
        if args.contains("-qt_emoji_enabled") {
            return true
        }
        if let testOverride = KeyboardPreferences.defaults.object(forKey: "crh.key.test.sysPref.EmojiEnabled") as? Bool {
            let ts = KeyboardPreferences.defaults.double(forKey: "crh.key.test.uiTestingTimestamp")
            if args.contains("-UITesting") || (ts > 0 && abs(Date().timeIntervalSince1970 - ts) < 120.0) {
                return testOverride
            }
        }
        if let explicitFeature = KeyboardPreferences.defaults.object(forKey: Feature.emojiPicker.preferenceKey) as? Bool,
           !explicitFeature {
            return false
        }
        let now = ProcessInfo.processInfo.systemUptime
        if let cached = cachedEmojiEnabled, (now - lastEmojiCheckTime) < 2.0 {
            return cached
        }
        lastEmojiCheckTime = now

        let ids = enabledSystemKeyboardIdentifiers()
        if !ids.isEmpty {
            let hasEmoji = ids.contains { $0.localizedCaseInsensitiveContains("emoji") }
            cachedEmojiEnabled = hasEmoji
            KeyboardPreferences.defaults.set(hasEmoji, forKey: cachedEmojiKeyboardEnabledKey)
            return hasEmoji
        }

        let fallback = KeyboardPreferences.defaults.object(forKey: cachedEmojiKeyboardEnabledKey) as? Bool ?? false
        cachedEmojiEnabled = fallback
        return fallback
    }

    /// Returns true when the Standard Latin keyboard extension (`Qırımtatarca`, `crh-Latn`) is enabled in iOS Settings.
    static var isPrimaryKeyboardExtensionEnabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-qt_keyboard_missing") { return false }
        if args.contains("-qt_keyboard_added") { return true }
        let bundleId = Bundle.main.bundleIdentifier
        if bundleId == AppConfiguration.keyboardBundleId { return true }
        if KeyboardPreferences.defaults.bool(forKey: "crh.key.test.isUITesting") {
            if KeyboardPreferences.defaults.object(forKey: "crh.key.primaryExtensionSeen") != nil {
                return KeyboardPreferences.defaults.bool(forKey: "crh.key.primaryExtensionSeen")
            }
            return true
        }
        let ids = enabledSystemKeyboardIdentifiers()
        let matchesLatin = ids.contains { id in
            let lower = id.lowercased()
            return lower == AppConfiguration.keyboardBundleId.lowercased()
                || lower.contains("crh.key.keyboard.keyboard")
                || lower.hasPrefix("crh.key.keyboard.keyboard@")
        }
        if matchesLatin { return true }
        let languages = UITextInputMode.activeInputModes.compactMap(\.primaryLanguage)
            .map { $0.replacingOccurrences(of: "_", with: "-").lowercased() }
        if languages.contains(where: { $0 == "crh" || $0.hasPrefix("crh-latn") }) {
            return true
        }
        if hasAuthoritativeSystemKeyboardsList() {
            return false
        }
        return KeyboardPreferences.defaults.bool(forKey: "crh.key.primaryExtensionSeen")
    }

    /// Returns true when the Standard Cyrillic keyboard extension (`Къырымтатарджа`, `crh-Cyrl`) is enabled in iOS Settings.
    static var isCyrillicKeyboardExtensionEnabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-qt_cyrillic_missing") || (args.contains("-qt_keyboard_missing") && !args.contains("-qt_cyrillic_added")) {
            return false
        }
        if args.contains("-qt_cyrillic_added") { return true }
        let bundleId = Bundle.main.bundleIdentifier
        if bundleId == AppConfiguration.cyrillicKeyboardBundleId { return true }
        if KeyboardPreferences.defaults.bool(forKey: "crh.key.test.isUITesting") {
            return KeyboardPreferences.defaults.bool(forKey: "crh.key.cyrillicExtensionSeen")
        }
        let ids = enabledSystemKeyboardIdentifiers()
        let matchesCyrillic = ids.contains { id in
            let lower = id.lowercased()
            return lower == AppConfiguration.cyrillicKeyboardBundleId.lowercased()
                || lower.contains("crh.key.keyboard.keyboardcyrillic")
        }
        if matchesCyrillic { return true }
        let languages = UITextInputMode.activeInputModes.compactMap(\.primaryLanguage)
            .map { $0.replacingOccurrences(of: "_", with: "-").lowercased() }
        if languages.contains(where: { $0 == "crh-cyrl" || ($0.hasPrefix("crh-cyrl") && !$0.hasPrefix("crh-cyrl-ua")) }) {
            return true
        }
        if hasAuthoritativeSystemKeyboardsList() {
            return false
        }
        return KeyboardPreferences.defaults.bool(forKey: "crh.key.cyrillicExtensionSeen")
    }

    /// Returns true when the Ukrainian Cyrillic keyboard extension (`Кʼиримтатарджа`, `crh-Cyrl-UA`) is enabled in iOS Settings.
    static var isUkrainianKeyboardExtensionEnabled: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-qt_ukrainian_missing") || args.contains("-qt_cyrillic_missing") || (args.contains("-qt_keyboard_missing") && !args.contains("-qt_ukrainian_added") && !args.contains("-qt_ukrainian_fiva")) {
            return false
        }
        if args.contains("-qt_ukrainian_added") || args.contains("-qt_ukrainian_fiva") { return true }
        let bundleId = Bundle.main.bundleIdentifier
        if AppConfiguration.isUkrainianCyrillicKeyboardExtensionBundleId(bundleId) { return true }
        if KeyboardPreferences.defaults.bool(forKey: "crh.key.test.isUITesting") {
            return KeyboardPreferences.defaults.bool(forKey: "crh.key.ukrainianExtensionSeen")
        }
        let ids = enabledSystemKeyboardIdentifiers()
        let matchesUkrainian = ids.contains { id in
            let lower = id.lowercased()
            return lower == AppConfiguration.ukrainianCyrillicKeyboardBundleId.lowercased()
                || lower == AppConfiguration.ukrainianCyrillicDeviceBundleId.lowercased()
                || lower.contains("crh.key.keyboard.keyboardukrainian")
                || lower.contains("crh.key.keyboard.pro")
        }
        if matchesUkrainian { return true }
        let languages = UITextInputMode.activeInputModes.compactMap(\.primaryLanguage)
            .map { $0.replacingOccurrences(of: "_", with: "-").lowercased() }
        if languages.contains(where: { $0.hasPrefix("crh-cyrl-ua") }) {
            return true
        }
        if hasAuthoritativeSystemKeyboardsList() {
            return false
        }
        return KeyboardPreferences.defaults.bool(forKey: "crh.key.ukrainianExtensionSeen")
    }
}

#if canImport(MetricKit) && os(iOS)
import MetricKit

/// Lightweight MetricKit subscriber that records any `MXHangDiagnostic` or `MXCPUExceptionDiagnostic` payloads
/// into the shared App Group container (`Diagnostics/metrickit_diag_*.json`) for continuous performance auditing.
@available(iOS 14.0, *)
final class QirimKeyDiagnosticsSubscriber: NSObject, MXMetricManagerSubscriber {
    static let shared = QirimKeyDiagnosticsSubscriber()
    private static let logQueue = DispatchQueue(label: "crh.key.diagnosticsLogQueue", qos: .utility)
    private var isRegistered = false

    func start() {
        guard !isRegistered else { return }
        isRegistered = true
        MXMetricManager.shared.add(self)
    }

    static func recordLifecycleEvent(_ event: String, details: [String: String] = [:]) {
        logQueue.async {
            guard let containerURL = AppConfiguration.appGroupContainerURL else { return }
            let diagDir = containerURL.appendingPathComponent("Diagnostics", isDirectory: true)
            try? FileManager.default.createDirectory(at: diagDir, withIntermediateDirectories: true)
            let logURL = diagDir.appendingPathComponent("keyboard_lifecycle.jsonl")
            var payload = details
            payload["event"] = event
            payload["ts"] = String(format: "%.3f", Date().timeIntervalSince1970)
            payload["bundle"] = Bundle.main.bundleIdentifier ?? "unknown"
            guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys]),
                  var line = String(data: data, encoding: .utf8) else { return }
            line.append("\n")
            guard let lineData = line.data(using: .utf8) else { return }
            if let attrs = try? FileManager.default.attributesOfItem(atPath: logURL.path),
               let size = attrs[.size] as? UInt64, size > 262_144 {
                try? lineData.write(to: logURL, options: .atomic)
            } else if FileManager.default.fileExists(atPath: logURL.path),
                      let handle = try? FileHandle(forWritingTo: logURL) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: lineData)
            } else {
                try? lineData.write(to: logURL, options: .atomic)
            }
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        guard let containerURL = AppConfiguration.appGroupContainerURL else { return }
        let diagDir = containerURL.appendingPathComponent("Diagnostics", isDirectory: true)
        try? FileManager.default.createDirectory(at: diagDir, withIntermediateDirectories: true)
        let timestamp = Int(Date().timeIntervalSince1970)
        for (idx, payload) in payloads.enumerated() {
            let fileURL = diagDir.appendingPathComponent("metrickit_diag_\(timestamp)_\(idx).json")
            try? payload.jsonRepresentation().write(to: fileURL, options: .atomic)
        }
    }
}
#endif

/// Evaluates trailing arithmetic expressions ending with `=` (iOS "Show Maths Results" / `mathExpressionCompletionType`).
enum MathExpressionEvaluator {

    static func trailingMathQuery(in beforeInput: String?) -> String? {
        guard let eval = evaluateTrailingExpressionWithLiteral(in: beforeInput) else { return nil }
        return eval.expression
    }

    static func evaluateTrailingExpression(in beforeInput: String?) -> String? {
        evaluateTrailingExpressionWithLiteral(in: beforeInput)?.result
    }

    /// Returns both the literal trailing expression (e.g. `"2+2="` or `"2+2^4="`) and its formatted result (`"4"` or `"18"`).
    static func evaluateTrailingExpressionWithLiteral(in beforeInput: String?) -> (expression: String, result: String)? {
        guard let before = beforeInput else { return nil }
        let trimmedRight = before.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
        guard trimmedRight.hasSuffix("="), !trimmedRight.hasSuffix("=="),
              !trimmedRight.hasSuffix("!="), !trimmedRight.hasSuffix("<="), !trimmedRight.hasSuffix(">=") else {
            return nil
        }
        let withoutEquals = String(trimmedRight.dropLast())
        let allowedChars = CharacterSet(charactersIn: "0123456789.,+-−*×/÷^() ")
        var exprChars: [Character] = []
        for ch in withoutEquals.reversed() {
            if ch.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) {
                exprChars.append(ch)
            } else {
                break
            }
        }
        let rawExpr = String(exprChars.reversed()).trimmingCharacters(in: .whitespaces)
        guard rawExpr.count >= 3, rawExpr.count <= 64 else { return nil }
        let hasOperator = rawExpr.dropFirst().contains(where: { "+-−*×/÷^".contains($0) })
        guard hasOperator else { return nil }
        let usesCommaDecimal = rawExpr.contains(",") && !rawExpr.contains(".")
        let normalized = rawExpr
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: " ", with: "")
        var parser = Parser(Array(normalized))
        guard let value = parser.parseExpression(),
              parser.isAtEnd,
              value.isFinite,
              abs(value) < 1e15 else {
            return nil
        }
        let formattedResult = formatResult(value, usesCommaDecimal: usesCommaDecimal)
        return (expression: rawExpr + "=", result: formattedResult)
    }

    private static func formatResult(_ value: Double, usesCommaDecimal: Bool) -> String {
        let roundedInt = value.rounded()
        if abs(value - roundedInt) < 1e-9, abs(roundedInt) < 1e15 {
            return String(Int64(roundedInt))
        }
        let scaled = (value * 1_000_000).rounded() / 1_000_000
        var text = String(format: "%.6f", scaled)
        while text.hasSuffix("0") { text.removeLast() }
        if text.hasSuffix(".") { text.removeLast() }
        if usesCommaDecimal {
            text = text.replacingOccurrences(of: ".", with: ",")
        }
        return text
    }

    private struct Parser {
        let chars: [Character]
        var index: Int = 0

        init(_ chars: [Character]) {
            self.chars = chars
        }

        var isAtEnd: Bool { index >= chars.count }

        mutating func parseExpression() -> Double? {
            guard var lhs = parseTerm() else { return nil }
            while !isAtEnd {
                let op = chars[index]
                if op == "+" || op == "-" {
                    index += 1
                    guard let rhs = parseTerm() else { return nil }
                    lhs = (op == "+") ? (lhs + rhs) : (lhs - rhs)
                } else {
                    break
                }
            }
            return lhs
        }

        mutating func parseTerm() -> Double? {
            guard var lhs = parsePower() else { return nil }
            while !isAtEnd {
                let op = chars[index]
                if op == "*" || op == "/" {
                    index += 1
                    guard let rhs = parsePower() else { return nil }
                    if op == "/" {
                        guard abs(rhs) > 1e-12 else { return nil }
                        lhs /= rhs
                    } else {
                        lhs *= rhs
                    }
                } else {
                    break
                }
            }
            return lhs
        }

        mutating func parsePower() -> Double? {
            guard let base = parseUnary() else { return nil }
            if !isAtEnd && chars[index] == "^" {
                index += 1
                guard let exp = parsePower() else { return nil }
                return pow(base, exp)
            }
            return base
        }

        mutating func parseUnary() -> Double? {
            guard !isAtEnd else { return nil }
            if chars[index] == "+" {
                index += 1
                return parseUnary()
            }
            if chars[index] == "-" {
                index += 1
                guard let v = parseUnary() else { return nil }
                return -v
            }
            return parsePrimary()
        }

        mutating func parsePrimary() -> Double? {
            guard !isAtEnd else { return nil }
            if chars[index] == "(" {
                index += 1
                guard let val = parseExpression(), !isAtEnd, chars[index] == ")" else { return nil }
                index += 1
                return val
            }
            let start = index
            var dotCount = 0
            while !isAtEnd {
                let c = chars[index]
                if c.isWholeNumber {
                    index += 1
                } else if c == "." {
                    dotCount += 1
                    if dotCount > 1 { return nil }
                    index += 1
                } else {
                    break
                }
            }
            guard index > start else { return nil }
            return Double(String(chars[start..<index]))
        }
    }
}

