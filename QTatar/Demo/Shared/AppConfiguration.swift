//
//  AppConfiguration.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import Foundation
import SwiftUI
import UIKit

enum KeyboardPreferences {
    static let suggestionsKey = "crh.key.suggestionsEnabled"
    static let wordLearningKey = "crh.key.wordLearningEnabled"
    static let cyrillicKey = "crh.key.cyrillicEnabled"
    static let languageKey = "crh.key.interfaceLanguage"
    /// Created once: `UserDefaults(suiteName:)` is expensive and used by the style provider for every key.
    static let defaults: UserDefaults = UserDefaults(suiteName: AppConfiguration.appGroupID) ?? .standard
    static var suggestionsEnabled: Bool { defaults.object(forKey: suggestionsKey) as? Bool ?? true }
    static var wordLearningEnabled: Bool { defaults.object(forKey: wordLearningKey) as? Bool ?? true }
    /// Only iPad has a place where the toggle matters (the абв/abc key); on iPhone the Cyrillic keyboard is always available,
    /// because iOS offers no way to hide it from the system list.
    static var cyrillicEnabled: Bool {
        if UIDevice.current.userInterfaceIdiom != .pad { return true }
        return defaults.object(forKey: cyrillicKey) as? Bool ?? true
    }
    static var interfaceLanguage: String { defaults.string(forKey: languageKey) ?? "crh" }
    static var localizationContainerBundle: Bundle {
        if let url = Bundle.main.url(forResource: "AppLocalizations", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return .main
    }
    static func localizationBundle(for language: String) -> Bundle {
        let container = localizationContainerBundle
        if let path = container.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        if let path = Bundle.main.path(forResource: language, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
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
    static let activeSecondsKey = "crh.key.stats.activeSeconds"
    static let peakWPMKey = "crh.key.stats.peakWPM"
    static let peakCPMKey = "crh.key.stats.peakCPM"
    static let lastWPMKey = "crh.key.stats.lastWPM"
    static let lastCPMKey = "crh.key.stats.lastCPM"
    static let phrasesInsertedKey = "crh.key.stats.phrasesInserted"
    static let lastInjectedTimestampKey = "crh.key.stats.lastInjectedTimestamp"

    private static var recentKeystrokeTimes: [CFAbsoluteTime] = []
    private static var lastKeystrokeTime: CFAbsoluteTime = 0

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
        return min(max(ratio, 1.1), 9.9)
    }

    /// Returns speed tier index (0...5) and next tier target WPM (if any).
    static func speedTier(for wpm: Int) -> (level: Int, nextTargetWPM: Int?) {
        switch wpm {
        case ..<1: return (0, 1)
        case 1..<15: return (1, 15)
        case 15..<28: return (2, 28)
        case 28..<43: return (3, 43)
        case 43..<60: return (4, 60)
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

    /// Records a manual character keystroke and updates live WPM / CPM, peak speed, and active typing time.
    @discardableResult
    static func recordCharacterTyped(count: Int = 1) -> (wpm: Int, cpm: Int) {
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
            }
        } else {
            // Seed initial 1.2s of active time on first keystroke of a session
            let updatedActive = defaults.double(forKey: activeSecondsKey) + 1.2
            defaults.set(updatedActive, forKey: activeSecondsKey)
        }
        lastKeystrokeTime = now

        for _ in 0..<max(count, 1) {
            recentKeystrokeTimes.append(now)
        }
        recentKeystrokeTimes.removeAll { now - $0 > 12.0 }

        var cpm = 0
        var wpm = 0
        if recentKeystrokeTimes.count >= 2, let first = recentKeystrokeTimes.first {
            let span = max(now - first, 1.4)
            cpm = min(Int((Double(recentKeystrokeTimes.count) / span) * 60.0), 900)
            defaults.set(cpm, forKey: lastCPMKey)
            if cpm > defaults.integer(forKey: peakCPMKey) {
                defaults.set(cpm, forKey: peakCPMKey)
            }
            if recentKeystrokeTimes.count >= 8 && (now - first) >= 3.0 {
                wpm = max(1, Int((Double(cpm) / crhCharsPerWord).rounded()))
                defaults.set(wpm, forKey: lastWPMKey)
                if wpm > defaults.integer(forKey: peakWPMKey) {
                    defaults.set(wpm, forKey: peakWPMKey)
                }
            }
        }
        return (wpm, cpm)
    }

    static func recordManualWordCompleted() {
        let defaults = KeyboardPreferences.defaults
        let newManual = manualWords + 1
        let currentSuggested = defaults.integer(forKey: suggestedWordsKey)
        defaults.set(newManual, forKey: manualWordsKey)
        defaults.set(newManual + currentSuggested, forKey: totalWordsKey)
    }

    static func recordSuggestedWordCompleted(savedCharacters: Int = 4) {
        let defaults = KeyboardPreferences.defaults
        let currentManual = manualWords
        let newSuggested = defaults.integer(forKey: suggestedWordsKey) + 1
        let newSavedChars = defaults.integer(forKey: suggestedCharsKey) + max(savedCharacters, 2)
        defaults.set(currentManual, forKey: manualWordsKey)
        defaults.set(newSuggested, forKey: suggestedWordsKey)
        defaults.set(newSavedChars, forKey: suggestedCharsKey)
        defaults.set(currentManual + newSuggested, forKey: totalWordsKey)
        markInjectedText()
    }

    static func recordWordCompleted() {
        recordManualWordCompleted()
    }

    static func recordWordLearned() {
        let defaults = KeyboardPreferences.defaults
        defaults.set(defaults.integer(forKey: learnedWordsKey) + 1, forKey: learnedWordsKey)
    }

    static func markInjectedText(_ text: String = "") {
        KeyboardPreferences.defaults.set(CFAbsoluteTimeGetCurrent(), forKey: lastInjectedTimestampKey)
    }

    static func wasRecentlyInjected(within seconds: Double = 0.85) -> Bool {
        let ts = KeyboardPreferences.defaults.double(forKey: lastInjectedTimestampKey)
        guard ts > 0 else { return false }
        return abs(CFAbsoluteTimeGetCurrent() - ts) < seconds
    }

    static func recordPhraseInserted() {
        let defaults = KeyboardPreferences.defaults
        defaults.set(defaults.integer(forKey: phrasesInsertedKey) + 1, forKey: phrasesInsertedKey)
        markInjectedText()
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
        if let containerDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfiguration.appGroupID) {
            try? FileManager.default.removeItem(at: containerDir.appendingPathComponent("user_lexicon.sqlite"))
            try? FileManager.default.removeItem(at: containerDir.appendingPathComponent("user_lexicon.sqlite-wal"))
            try? FileManager.default.removeItem(at: containerDir.appendingPathComponent("user_lexicon.sqlite-shm"))
        }
        recentKeystrokeTimes.removeAll()
        lastKeystrokeTime = 0
    }
}

/// Vector Taraq Tamğa badge that snaps the 9×5 emblem to exact pixel-aligned coordinates so the header,
/// footer, and about logos have 100% left-right and top-bottom symmetry at every scale.
struct TaraqTamgaLogoBadge: View {
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 7
    @Environment(\.colorScheme) private var colorScheme

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color(red: 10.0 / 255.0, green: 10.0 / 255.0, blue: 10.0 / 255.0)
            : Color(red: 248.0 / 255.0, green: 245.0 / 255.0, blue: 236.0 / 255.0)
    }

    private var foregroundColor: Color {
        colorScheme == .dark
            ? Color(red: 248.0 / 255.0, green: 245.0 / 255.0, blue: 236.0 / 255.0)
            : Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 26.0 / 255.0)
    }

    /// Snaps the 9:5 unit scale to a half-point multiple so 9×unit and 5×unit land on integer pixels on @2x/@3x displays.
    private var unitSize: CGFloat {
        let rawUnit = (size * 0.68) / 9.0
        return max((rawUnit * 2.0).rounded() / 2.0, 1.5)
    }

    var body: some View {
        let unit = unitSize
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(backgroundColor)
            SharedTaraqTamgaShape()
                .fill(foregroundColor)
                .frame(width: unit * 9.0, height: unit * 5.0)
        }
        .frame(width: size, height: size)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.75)
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
    static let keyboardBundleIdPattern = "crh.key.keyboard*"
    static let fallbackDocumentID = UUID()
}

extension UITextDocumentProxy {
    /// Safely reads `documentIdentifier` via KVC so a temporarily `nil` Objective-C return during an XPC transition
    /// does not trap in `UUID._unconditionallyBridgeFromObjectiveC`.
    var safeDocumentIdentifier: UUID {
        ((self as AnyObject).value(forKey: "documentIdentifier") as? UUID) ?? AppConfiguration.fallbackDocumentID
    }
}
