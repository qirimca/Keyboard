//
//  HomeView.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI
import KeyboardKit
import UIKit

enum KeyboardTestFieldMode: String, CaseIterable, Identifiable {
    case standard = "field.standard"
    case search = "field.search"
    case email = "field.email"
    case url = "field.url"
    case numbers = "field.numbers"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .standard: return "character.cursor.ibeam"
        case .search: return "magnifyingglass"
        case .email: return "at"
        case .url: return "globe"
        case .numbers: return "textformat.123"
        }
    }

    var badgeText: String {
        switch self {
        case .standard: return "Aa"
        case .search: return "🔍"
        case .email: return "@ ."
        case .url: return ". / .com"
        case .numbers: return "123"
        }
    }

    var keyboardType: UIKeyboardType {
        switch self {
        case .standard: return .default
        case .search: return .webSearch
        case .email: return .emailAddress
        case .url: return .URL
        case .numbers: return .numbersAndPunctuation
        }
    }

    var returnKeyType: UIReturnKeyType {
        switch self {
        case .standard: return .default
        case .search: return .search
        case .email: return .default
        case .url: return .go
        case .numbers: return .done
        }
    }

    var textContentType: UITextContentType? {
        switch self {
        case .email: return .emailAddress
        case .url: return .URL
        default: return nil
        }
    }
}

enum KeyboardTestThemeMode: String, CaseIterable, Identifiable {
    case ios26White = "theme.modernLight"
    case dark = "theme.modernDark"

    var id: String { rawValue }

    var isDark: Bool { self == .dark }

    static func mode(isDark: Bool) -> Self {
        isDark ? .dark : .ios26White
    }

    var icon: String {
        switch self {
        case .ios26White: return "sun.max.fill"
        case .dark: return "moon.fill"
        }
    }

    var keyboardAppearance: UIKeyboardAppearance {
        switch self {
        case .dark: return .dark
        case .ios26White: return .light
        }
    }
}

/**
 This is the main app screen.

 This screen has a text field, an interactive testing sandbox for keyboard modes & color themes,
 and list items that show various keyboard-specific states.
 */
struct HomeView: View {
    @Binding var navigationPath: NavigationPath

    @AppStorage("crh.key.text") private var text = ""
    @AppStorage(KeyboardPreferences.languageKey, store: KeyboardPreferences.defaults) private var language = "crh"
    @AppStorage(KeyboardPreferences.cyrillicKey, store: KeyboardPreferences.defaults) private var cyrillicEnabled = true
    @AppStorage(KeyboardPreferences.ukrainianCyrillicLayoutKey, store: KeyboardPreferences.defaults) private var ukrainianCyrillicLayout = false
    @AppStorage(KeyboardPreferences.suggestionsKey, store: KeyboardPreferences.defaults) private var suggestionsEnabled = true
    @AppStorage(KeyboardPreferences.wordLearningKey, store: KeyboardPreferences.defaults) private var wordLearningEnabled = true
    @AppStorage(KeyboardPreferences.statsEnabledKey, store: KeyboardPreferences.defaults) private var statsEnabled = true

    @AppStorage(KeyboardUsageStats.totalWordsKey, store: KeyboardPreferences.defaults) private var totalWords = 0
    @AppStorage(KeyboardUsageStats.manualWordsKey, store: KeyboardPreferences.defaults) private var manualWords = 0
    @AppStorage(KeyboardUsageStats.suggestedWordsKey, store: KeyboardPreferences.defaults) private var suggestedWords = 0
    @AppStorage(KeyboardUsageStats.suggestedCharsKey, store: KeyboardPreferences.defaults) private var suggestedCharacters = 0
    @AppStorage(KeyboardUsageStats.totalCharsKey, store: KeyboardPreferences.defaults) private var totalCharacters = 0
    @AppStorage(KeyboardUsageStats.learnedWordsKey, store: KeyboardPreferences.defaults) private var learnedWordsCount = 0
    @AppStorage(KeyboardUsageStats.activeSecondsKey, store: KeyboardPreferences.defaults) private var activeSeconds: Double = 0
    @AppStorage(KeyboardUsageStats.peakWPMKey, store: KeyboardPreferences.defaults) private var peakWPM = 0
    @AppStorage(KeyboardUsageStats.peakCPMKey, store: KeyboardPreferences.defaults) private var peakCPM = 0
    @AppStorage(KeyboardUsageStats.lastWPMKey, store: KeyboardPreferences.defaults) private var lastWPM = 0
    @AppStorage(KeyboardUsageStats.lastCPMKey, store: KeyboardPreferences.defaults) private var lastCPM = 0
    @AppStorage(KeyboardUsageStats.phrasesInsertedKey, store: KeyboardPreferences.defaults) private var phrasesInserted = 0

    @State private var liveWPM = 0
    @State private var liveCPM = 0
    @State private var canSandboxUndo = false
    @State private var canSandboxRedo = false
    @State private var isStatsExpanded = false
    @State private var showResetStatsConfirmation = false

    private static let statsPollTimer = Timer.publish(every: 0.6, on: .main, in: .common).autoconnect()

    @State private var selectedFieldMode: KeyboardTestFieldMode = {
        if let value = UserDefaults.standard.string(forKey: "qt_field"),
           let mode = KeyboardTestFieldMode(rawValue: "field.\(value)") {
            return mode
        }
        return .standard
    }()
    @State private var selectedThemeMode: KeyboardTestThemeMode = {
        if let value = UserDefaults.standard.string(forKey: "qt_theme") {
            return value.lowercased().contains("dark") ? .dark : .ios26White
        }
        return UITraitCollection.current.userInterfaceStyle == .dark ? .dark : .ios26White
    }()

    @StateObject private var keyboardState = KeyboardStateContext(bundleId: AppConfiguration.keyboardBundleIdPattern)

    @State private var showIndicatorSheet = false
    @State private var showCyrillicGuideAlert = false
    @State private var isTestingExpanded = true
    @State private var shouldAutoFocusSandbox: Bool = {
        let args = ProcessInfo.processInfo.arguments
        return args.contains("-qt_reset_text") || args.contains("-qt_field") || args.contains("-qt_theme")
    }()
    @State private var isKeyboardVisible = false
    @State private var cyrillicStatus = CyrillicStatus.unknown
    @State private var cachedIsFullAccessEnabled = false
    @State private var cachedIsRtl = false
    @State private var viewportSize = CGSize.zero
    @State private var isWritingFieldFocused = false
    @State private var didInitializeThemeFromSystem = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme

    private enum CyrillicStatus { case enabled, missing, unknown }

    private var shouldShowStartOverlay: Bool {
        !areAllIndicatorsEnabled && !isWritingFieldFocused && !isKeyboardVisible
    }

    var body: some View {
        let _ = language // Observe interface language changes immediately
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            GeometryReader { geometry in
                ScrollViewReader { scroll in
                    ScrollView(.vertical, showsIndicators: false) {
                        let twoColumns = Self.usesTwoColumns(viewportSize, containerSize: geometry.size)
                        let layout = twoColumns
                            ? AnyLayout(HomeTwoColumnLayout(spacing: 16))
                            : AnyLayout(VStackLayout(spacing: geometry.size.height < 360 ? 10 : 14))
                        layout {
                            // Child 0: Status indicators (only shown when setup has issues / is incomplete)
                            if !areAllIndicatorsEnabled {
                                statusIndicatorsSection
                                    .id("statusIndicators")
                            }

                            // Child 1: Top Basic Statistics (expandable) + Keyboard settings (left column in 2-col, below status indicators in 1-col)
                            VStack(alignment: .leading, spacing: geometry.size.height < 360 ? 10 : 14) {
                                if statsEnabled {
                                    statisticsAndAchievementsSection
                                        .id("statsSection")
                                }
                                keyboardSettingsSection
                            }

                            // Child 2: Try Keyboard + Writing Area (right column in 2-col, below settings in 1-col)
                            testingAndWritingSection
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, (Device.iPhone || (viewportSize.width > 0 && viewportSize.width < 520)) ? 12 : 24)
                        .padding(.top, Device.iPhone ? 12 : 16)
                        .padding(.bottom, shouldShowStartOverlay ? 76 : (Device.iPhone ? 16 : 24))
                    }
                    .onChange(of: isStatsExpanded) { _, expanded in
                        if expanded {
                            refreshStatsFromAppGroup(syncSQLite: true)
                            withAnimation(.easeInOut(duration: 0.25)) {
                                scroll.scrollTo("statsSection", anchor: .top)
                            }
                        }
                    }
                    .onChange(of: geometry.size.height < 420) { _, isCompactHeight in
                        if isCompactHeight && Self.usesTwoColumns(viewportSize, containerSize: geometry.size) {
                            if isWritingFieldFocused {
                                scroll.scrollTo("writingArea", anchor: .bottom)
                            } else if !areAllIndicatorsEnabled {
                                scroll.scrollTo("statusIndicators", anchor: .top)
                            }
                        }
                    }
                    .onChange(of: isWritingFieldFocused) { _, focused in
                        syncSandboxFocusToAppGroup(focused)
                    }
                    .onChange(of: text) { _, _ in
                        if isWritingFieldFocused {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                scroll.scrollTo("writingArea", anchor: .bottom)
                            }
                        }
                    }
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidShowNotification)) { _ in
                        if isWritingFieldFocused && !isStatsExpanded {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                scroll.scrollTo("writingArea", anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: isTestingExpanded) { _, expanded in
                        if expanded {
                            shouldAutoFocusSandbox = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scroll.scrollTo("writingArea", anchor: .bottom)
                                }
                            }
                        } else {
                            shouldAutoFocusSandbox = false
                            clearThemeOverride()
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: language)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: cyrillicEnabled)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: statsEnabled)
        }
        .background {
            // Measure the window before keyboard avoidance; a docked keyboard must not
            // make a portrait window appear to be landscape.
            GeometryReader { geometry in
                Color.clear
                    .onAppear { viewportSize = geometry.size }
                    .onChange(of: geometry.size) { _, size in viewportSize = size }
            }
            .ignoresSafeArea(.keyboard)
        }
        .overlay(alignment: .bottom, content: {
            if shouldShowStartOverlay {
                PrimaryButton(text: Home.home_start_key.localized, background: Color.crayola) {
                    navigationPath.append(DemoRoute.onboarding)
                }
                .padding((Device.iPhone || (viewportSize.width > 0 && viewportSize.width < 520)) ? 12 : 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        })
        .animation(.easeInOut(duration: 0.25), value: shouldShowStartOverlay)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .toolbar {
            NavToolbarItem(placement: .navigationBarLeading, symbol: "questionmark") {
                navigationPath.append(DemoRoute.onboarding)
            }
            NavToolbarItem(placement: .navigationBarTrailing, symbol: "info") {
                navigationPath.append(DemoRoute.about)
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    TaraqTamgaLogoBadge(size: 28, cornerRadius: 7)
                        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.06), radius: 3, x: 0, y: 1)
                    Text("QırımKey")
                        .font(InterfaceFont.font("GeneralSans-Semibold", size: Device.iPad ? 22 : 19))
                        .foregroundStyle(Color(.label))
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
        }
        .sheet(isPresented: $showIndicatorSheet) {
            OnboardingView()
                .presentationCornerRadius(20)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .alert(localizedInterfaceString("settings.cyrillicGuideTitle"), isPresented: $showCyrillicGuideAlert) {
            Button(localizedInterfaceString("settings.cyrillicAddAction")) {
                Self.openKeyboardSettings()
            }
            Button(Home.home_start_key.localized) {
                showIndicatorSheet = true
            }
            Button(localizedInterfaceString("stats.resetCancel"), role: .cancel) {}
        } message: {
            Text(localizedInterfaceString("settings.missingCyrillic"))
        }
        .onAppear {
            Self.registerFloatingRequestObserverIfNeeded()
            Self.registerStatsSyncObserverIfNeeded()
            Self.enforceFullScreenWindowIfNeeded()
            if !didInitializeThemeFromSystem {
                didInitializeThemeFromSystem = true
                selectedThemeMode = .mode(isDark: colorScheme == .dark)
            }
            applyLaunchArguments()
            if UIApplication.shared.applicationState == .active && (isWritingFieldFocused || shouldAutoFocusSandbox) {
                syncThemeToAppGroup(selectedThemeMode)
            } else {
                clearThemeOverride()
            }
            refreshCyrillicStatus()
            keyboardState.refresh()
            refreshStatsFromAppGroup(syncSQLite: true, synchronizePreferences: true)
            Self.updateHostSplitBackdropMask()
        }
        .onReceive(NotificationCenter.default.publisher(for: Self.localStatsRefreshNotification)) { _ in
            let now = CFAbsoluteTimeGetCurrent()
            let elapsed = now - Self.lastPreferencesSyncTime
            if elapsed >= 0.4 {
                refreshStatsFromAppGroup(syncSQLite: false, synchronizePreferences: true)
            } else {
                refreshStatsFromAppGroup(syncSQLite: false, synchronizePreferences: false)
                if !Self.isTrailingPreferencesSyncPending {
                    Self.isTrailingPreferencesSyncPending = true
                    let delay = max(0.05, 0.4 - elapsed)
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        Self.isTrailingPreferencesSyncPending = false
                        NotificationCenter.default.post(name: Self.localStatsRefreshNotification, object: nil)
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            refreshCyrillicStatus()
            keyboardState.refresh()
            refreshStatsFromAppGroup(syncSQLite: true, synchronizePreferences: true)
            Self.updateHostSplitBackdropMask()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            refreshCyrillicStatus()
            keyboardState.refresh()
            refreshStatsFromAppGroup(syncSQLite: true, synchronizePreferences: true)
            Self.updateHostSplitBackdropMask()
        }
        .onReceive(Self.statsPollTimer) { _ in
            if statsEnabled && scenePhase != .background {
                refreshStatsFromAppGroup(syncSQLite: false, synchronizePreferences: false)
            }
        }
        .onChange(of: colorScheme) { _, newScheme in
            guard UIApplication.shared.applicationState == .active else { return }
            let args = ProcessInfo.processInfo.arguments
            if !args.contains("-qt_theme") {
                selectedThemeMode = .mode(isDark: newScheme == .dark)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            shouldAutoFocusSandbox = false
            clearThemeOverride()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            shouldAutoFocusSandbox = false
            clearThemeOverride()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = true
            }
            Self.syncHostSystemSplitStateIfNeeded()
            Self.updateHostSplitBackdropMask()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { _ in
            Self.syncHostSystemSplitStateIfNeeded()
            Self.updateHostSplitBackdropMask()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidChangeFrameNotification)) { _ in
            Self.syncHostSystemSplitStateIfNeeded()
            Self.updateHostSplitBackdropMask()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = false
            }
            Self.updateHostSplitBackdropMask()
        }
        .onReceive(NotificationCenter.default.publisher(for: UITextInputMode.currentInputModeDidChangeNotification)) { _ in
            refreshCyrillicStatus()
        }
        .onChange(of: selectedThemeMode) { _, newTheme in
            guard UIApplication.shared.applicationState == .active else { return }
            syncThemeToAppGroup(newTheme)
        }
        .onChange(of: selectedFieldMode) { _, _ in
            guard UIApplication.shared.applicationState == .active else { return }
            syncThemeToAppGroup(selectedThemeMode)
        }
        .onChange(of: cyrillicEnabled) { _, newValue in
            KeyboardPreferences.defaults.set(newValue, forKey: KeyboardPreferences.cyrillicKey)
            KeyboardPreferences.defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            KeyboardPreferences.refreshCachedPreferences()
            notifySandboxTraitsChanged()
        }
        .onChange(of: ukrainianCyrillicLayout) { _, newValue in
            KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(newValue)
            KeyboardPreferences.defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            KeyboardPreferences.refreshCachedPreferences()
            notifySandboxTraitsChanged()
        }
        .onChange(of: suggestionsEnabled) { _, newValue in
            KeyboardPreferences.defaults.set(newValue, forKey: KeyboardPreferences.suggestionsKey)
            KeyboardPreferences.defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            KeyboardPreferences.refreshCachedPreferences()
            notifySandboxTraitsChanged()
        }
        .onChange(of: wordLearningEnabled) { _, newValue in
            KeyboardPreferences.defaults.set(newValue, forKey: KeyboardPreferences.wordLearningKey)
            KeyboardPreferences.defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            KeyboardPreferences.refreshCachedPreferences()
            notifySandboxTraitsChanged()
        }
        .onChange(of: statsEnabled) { _, newValue in
            KeyboardPreferences.defaults.set(newValue, forKey: KeyboardPreferences.statsEnabledKey)
            KeyboardPreferences.defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            KeyboardPreferences.refreshCachedPreferences()
            notifySandboxTraitsChanged()
            if !newValue {
                isStatsExpanded = false
                liveWPM = 0
                liveCPM = 0
            } else {
                refreshStatsFromAppGroup(syncSQLite: true, synchronizePreferences: true)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Self.enforceFullScreenWindowIfNeeded()
                if isWritingFieldFocused || shouldAutoFocusSandbox {
                    syncThemeToAppGroup(selectedThemeMode)
                } else {
                    clearThemeOverride()
                }
                refreshCyrillicStatus()
                keyboardState.refresh()
                refreshStatsFromAppGroup(syncSQLite: true, synchronizePreferences: true)
            } else if newPhase == .inactive {
                shouldAutoFocusSandbox = false
                clearThemeOverride()
                refreshStatsFromAppGroup(syncSQLite: false, synchronizePreferences: true)
            } else {
                shouldAutoFocusSandbox = false
                clearThemeOverride()
            }
        }
        .onDisappear {
            shouldAutoFocusSandbox = false
            clearThemeOverride()
        }
    }

    private static let localStatsRefreshNotification = Notification.Name("crh.key.localStatsRefresh")
    private static var didRegisterFloatingObserver = false
    private static var didRegisterStatsObserver = false
    private static var lastPreferencesSyncTime: CFAbsoluteTime = 0
    private static var isTrailingPreferencesSyncPending = false

    private static func registerStatsSyncObserverIfNeeded() {
        guard !didRegisterStatsObserver else { return }
        didRegisterStatsObserver = true
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: HomeView.localStatsRefreshNotification, object: nil)
                }
            },
            KeyboardUsageStats.statsUpdatedNotification as CFString,
            nil,
            .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            center,
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: HomeView.localStatsRefreshNotification, object: nil)
                }
            },
            KeyboardUsageStats.statsResetNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func refreshStatsFromAppGroup(syncSQLite: Bool = false, synchronizePreferences: Bool = false) {
        guard statsEnabled else { return }
        if synchronizePreferences {
            Self.lastPreferencesSyncTime = CFAbsoluteTimeGetCurrent()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        }
        if syncSQLite {
            KeyboardUsageStats.syncLearnedWordsCountFromSQLite()
        }
        let d = KeyboardPreferences.defaults
        let newTotalWords = d.integer(forKey: KeyboardUsageStats.totalWordsKey)
        let newManualWords = d.integer(forKey: KeyboardUsageStats.manualWordsKey)
        let newSuggestedWords = d.integer(forKey: KeyboardUsageStats.suggestedWordsKey)
        let newSuggestedChars = d.integer(forKey: KeyboardUsageStats.suggestedCharsKey)
        let newTotalChars = d.integer(forKey: KeyboardUsageStats.totalCharsKey)
        let newLearnedWords = d.integer(forKey: KeyboardUsageStats.learnedWordsKey)
        let newActiveSeconds = d.double(forKey: KeyboardUsageStats.activeSecondsKey)
        let newPeakWPM = d.integer(forKey: KeyboardUsageStats.peakWPMKey)
        let newPeakCPM = d.integer(forKey: KeyboardUsageStats.peakCPMKey)
        let newLastWPM = d.integer(forKey: KeyboardUsageStats.lastWPMKey)
        let newLastCPM = d.integer(forKey: KeyboardUsageStats.lastCPMKey)
        let newPhrasesInserted = d.integer(forKey: KeyboardUsageStats.phrasesInsertedKey)

        if totalWords != newTotalWords { totalWords = newTotalWords }
        if manualWords != newManualWords { manualWords = newManualWords }
        if suggestedWords != newSuggestedWords { suggestedWords = newSuggestedWords }
        if suggestedCharacters != newSuggestedChars { suggestedCharacters = newSuggestedChars }
        if totalCharacters != newTotalChars { totalCharacters = newTotalChars }
        if learnedWordsCount != newLearnedWords { learnedWordsCount = newLearnedWords }
        if abs(activeSeconds - newActiveSeconds) > 0.3 { activeSeconds = newActiveSeconds }
        if peakWPM != newPeakWPM { peakWPM = newPeakWPM }
        if peakCPM != newPeakCPM { peakCPM = newPeakCPM }
        if lastWPM != newLastWPM { lastWPM = newLastWPM }
        if lastCPM != newLastCPM { lastCPM = newLastCPM }
        if phrasesInserted != newPhrasesInserted { phrasesInserted = newPhrasesInserted }
    }

    private static func registerFloatingRequestObserverIfNeeded() {
        guard !didRegisterFloatingObserver else { return }
        didRegisterFloatingObserver = true
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        CFNotificationCenterAddObserver(
            center,
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    HomeView.invokeHostSetFloating(true)
                }
            },
            "crh.key.requestFloatingKeyboard" as CFString,
            nil,
            .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            center,
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    HomeView.invokeHostSetFloating(false)
                }
            },
            "crh.key.requestDockedKeyboard" as CFString,
            nil,
            .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            center,
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    HomeView.invokeHostSetSplit(true)
                }
            },
            "crh.key.requestSplitKeyboard" as CFString,
            nil,
            .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            center,
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    HomeView.invokeHostSetSplit(false)
                }
            },
            "crh.key.requestMergedKeyboard" as CFString,
            nil,
            .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            center,
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                    KeyboardPreferences.refreshCachedPreferences()
                    HomeView.updateHostSplitBackdropMask()
                }
            },
            KeyboardPreferences.splitModeChangedNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    private static func invokeHostSetSplit(_ split: Bool) {
        if let implClass: AnyClass = NSClassFromString("UIKeyboardImpl") {
            let rivenSel = NSSelectorFromString("setRivenPreference:")
            if let method = class_getClassMethod(implClass, rivenSel) {
                typealias SetRivenFn = @convention(c) (AnyObject, Selector, Bool) -> Void
                let fn = unsafeBitCast(method_getImplementation(method), to: SetRivenFn.self)
                fn(implClass, rivenSel, split)
            }
            let splitSel = NSSelectorFromString("setSplit:")
            if let method = class_getClassMethod(implClass, splitSel) {
                typealias SetSplitFn = @convention(c) (AnyObject, Selector, Bool) -> Void
                let fn = unsafeBitCast(method_getImplementation(method), to: SetSplitFn.self)
                fn(implClass, splitSel, split)
            }
        }
        if let hostClass: AnyClass = NSClassFromString("UIPeripheralHost") {
            let sharedSel = NSSelectorFromString("sharedInstance")
            if let sharedMethod = class_getClassMethod(hostClass, sharedSel) {
                typealias SharedFn = @convention(c) (AnyObject, Selector) -> AnyObject?
                let sharedFn = unsafeBitCast(method_getImplementation(sharedMethod), to: SharedFn.self)
                if let hostInstance = sharedFn(hostClass, sharedSel) {
                    let setSplitSel = NSSelectorFromString("setSplit:")
                    if hostInstance.responds(to: setSplitSel),
                       let m = class_getInstanceMethod(type(of: hostInstance), setSplitSel) {
                        typealias SetInstSplitFn = @convention(c) (AnyObject, Selector, Bool) -> Void
                        let fn = unsafeBitCast(method_getImplementation(m), to: SetInstSplitFn.self)
                        fn(hostInstance, setSplitSel, split)
                    }
                }
            }
        }
        updateHostSplitBackdropMask()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            updateHostSplitBackdropMask()
        }
    }

    private static func queryHostSystemIsSplit() -> Bool? {
        guard Device.iPad else { return nil }
        if let hostClass: AnyClass = NSClassFromString("UIPeripheralHost") {
            let sharedSel = NSSelectorFromString("sharedInstance")
            if let sharedMethod = class_getClassMethod(hostClass, sharedSel) {
                typealias SharedFn = @convention(c) (AnyObject, Selector) -> AnyObject?
                let sharedFn = unsafeBitCast(method_getImplementation(sharedMethod), to: SharedFn.self)
                if let hostInstance = sharedFn(hostClass, sharedSel) {
                    for selName in ["isSplit", "isSplitting"] {
                        let sel = NSSelectorFromString(selName)
                        if hostInstance.responds(to: sel),
                           let m = class_getInstanceMethod(type(of: hostInstance), sel) {
                            typealias BoolFn = @convention(c) (AnyObject, Selector) -> Bool
                            let fn = unsafeBitCast(method_getImplementation(m), to: BoolFn.self)
                            if fn(hostInstance, sel) { return true }
                        }
                    }
                }
            }
        }
        if let implClass: AnyClass = NSClassFromString("UIKeyboardImpl") {
            let sel = NSSelectorFromString("isSplit")
            if let method = class_getClassMethod(implClass, sel) {
                typealias BoolFn = @convention(c) (AnyObject, Selector) -> Bool
                let fn = unsafeBitCast(method_getImplementation(method), to: BoolFn.self)
                if fn(implClass, sel) { return true }
            }
        }
        var windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
        if let effectsClass: AnyClass = NSClassFromString("UITextEffectsWindow") {
            let sharedSel = NSSelectorFromString("sharedTextEffectsWindow")
            if let method = class_getClassMethod(effectsClass, sharedSel) {
                typealias SharedWinFn = @convention(c) (AnyObject, Selector) -> UIWindow?
                let fn = unsafeBitCast(method_getImplementation(method), to: SharedWinFn.self)
                if let win = fn(effectsClass, sharedSel), !windows.contains(win) {
                    windows.append(win)
                }
            }
        }
        for win in windows {
            if let rootVC = win.rootViewController {
                let placementSel = NSSelectorFromString("placement")
                if rootVC.responds(to: placementSel),
                   let placementObj = rootVC.perform(placementSel)?.takeUnretainedValue() {
                    let placementClassName = String(describing: type(of: placementObj))
                    if placementClassName.contains("Split") {
                        return true
                    }
                    let isSplitSel = NSSelectorFromString("isSplit")
                    if placementObj.responds(to: isSplitSel),
                       let m = class_getInstanceMethod(type(of: placementObj), isSplitSel) {
                        typealias BoolFn = @convention(c) (AnyObject, Selector) -> Bool
                        let fn = unsafeBitCast(method_getImplementation(m), to: BoolFn.self)
                        if fn(placementObj, isSplitSel) { return true }
                    }
                }
            }
        }
        return nil
    }

    private static func hostDeviceSupportsSplitKeyboard() -> Bool {
        guard Device.iPad else { return false }
        if let sym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "UIKeyboardDeviceSupportsSplit") {
            typealias SupportsSplitFn = @convention(c) () -> Bool
            let fn = unsafeBitCast(sym, to: SupportsSplitFn.self)
            return fn()
        }
        let modelIdentifier: String = {
            if let simModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"], !simModel.isEmpty {
                return simModel
            }
            var sysinfo = utsname()
            uname(&sysinfo)
            return withUnsafePointer(to: &sysinfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(cString: $0)
                }
            }
        }()
        let supportedModels: Set<String> = [
            "iPad11,3", "iPad11,4",
            "iPad11,1", "iPad11,2", "iPad14,1", "iPad14,2", "iPad16,1", "iPad16,2",
            "iPad6,11", "iPad6,12", "iPad7,5", "iPad7,6", "iPad7,11", "iPad7,12",
            "iPad11,6", "iPad11,7", "iPad12,1", "iPad12,2",
            "iPad6,3", "iPad6,4", "iPad7,3", "iPad7,4",
            "iPad5,1", "iPad5,2", "iPad5,3", "iPad5,4"
        ]
        return supportedModels.contains(modelIdentifier)
    }

    private static func syncHostSystemSplitStateIfNeeded() {
        // Split state is managed directly by the keyboard extension via `⌄⌨` callout and pinch gesture.
    }

    static func openKeyboardSettings() {
        let candidates = [
            "App-Prefs:root=General&path=Keyboard/KEYBOARDS",
            "App-Prefs:root=General&path=Keyboard",
            "prefs:root=General&path=Keyboard/KEYBOARDS",
            "prefs:root=General&path=Keyboard",
            UIApplication.openSettingsURLString
        ]
        func tryNext(_ index: Int) {
            guard index < candidates.count else { return }
            guard let url = URL(string: candidates[index]) else {
                tryNext(index + 1)
                return
            }
            UIApplication.shared.open(url, options: [:]) { success in
                if !success {
                    tryNext(index + 1)
                }
            }
        }
        tryNext(0)
    }

    private static func updateHostSplitBackdropMask() {
        // Do not alter or unhide system keyboard backdrop/platter views.
    }

    private static func invokeHostSetFloating(_ floating: Bool) {
        var alreadyMatching = false
        var didInvokeImpl = false
        if let implClass: AnyClass = NSClassFromString("UIKeyboardImpl") {
            let isFloatingSel = NSSelectorFromString("isFloating")
            if let checkMethod = class_getClassMethod(implClass, isFloatingSel) {
                typealias IsFloatingFn = @convention(c) (AnyObject, Selector) -> Bool
                let checkFn = unsafeBitCast(method_getImplementation(checkMethod), to: IsFloatingFn.self)
                alreadyMatching = (checkFn(implClass, isFloatingSel) == floating)
            }
            if !alreadyMatching {
                let implSel = NSSelectorFromString("setFloating:")
                if let method = class_getClassMethod(implClass, implSel) {
                    typealias SetFloatingFn = @convention(c) (AnyObject, Selector, Bool) -> Void
                    let fn = unsafeBitCast(method_getImplementation(method), to: SetFloatingFn.self)
                    fn(implClass, implSel, floating)
                    didInvokeImpl = true
                }
            }
        }
        if !alreadyMatching && !didInvokeImpl, let hostClass: AnyClass = NSClassFromString("UIPeripheralHost") {
            let hostSel = NSSelectorFromString("setFloating:onCompletion:")
            if let method = class_getClassMethod(hostClass, hostSel) {
                typealias SetHostFloatingFn = @convention(c) (AnyObject, Selector, Bool, AnyObject?) -> Void
                let fn = unsafeBitCast(method_getImplementation(method), to: SetHostFloatingFn.self)
                fn(hostClass, hostSel, floating, nil)
            }
        }
        updateHostSplitBackdropMask()
    }

    private static func clampFloatingKeyboardToScreenBounds() {
        // System floating platter positioning is managed natively by UIKit.
    }

    private func refreshCyrillicStatus() {
        cachedIsFullAccessEnabled = keyboardState.isFullAccessEnabled
        cachedIsRtl = keyboardState.activeKeyboardBundleIds.first?.hasSuffix("rtl") ?? false
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-qt_cyrillic_missing") {
            cyrillicStatus = .missing
            return
        }
        if args.contains("-qt_cyrillic_added") {
            cyrillicStatus = .enabled
            return
        }
        let appleKeyboards = (UserDefaults.standard.object(forKey: "AppleKeyboards") as? [String]) ?? []
        let modes = UITextInputMode.activeInputModes
        let modeIdentifiers = modes.compactMap { $0.value(forKey: "identifier") as? String }
        let extensionIdentifiers = modes.compactMap {
            ($0.value(forKey: "extension") as? NSObject)?.value(forKey: "identifier") as? String
        }
        let identifiers = appleKeyboards + modeIdentifiers + extensionIdentifiers
        let languages = modes.compactMap(\.primaryLanguage)
            .map { $0.replacingOccurrences(of: "_", with: "-").lowercased() }
        let cyrillicByIdentifier = identifiers.contains {
            $0.contains(AppConfiguration.cyrillicKeyboardBundleId) || $0.localizedCaseInsensitiveContains("KeyboardCyrillic")
        }
        let cyrillicByLanguage = languages.contains { $0.hasPrefix("crh-cyrl") }
        if cyrillicByIdentifier || cyrillicByLanguage {
            cyrillicStatus = .enabled
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.cyrillicExtensionSeen")
        } else if !modes.isEmpty || !appleKeyboards.isEmpty {
            cyrillicStatus = .missing
            KeyboardPreferences.defaults.set(false, forKey: "crh.key.cyrillicExtensionSeen")
        } else if KeyboardPreferences.defaults.bool(forKey: "crh.key.cyrillicExtensionSeen") {
            cyrillicStatus = .enabled
        } else {
            cyrillicStatus = .missing
        }
    }

    private func notifySandboxTraitsChanged() {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName("crh.key.sandboxTraitsChanged" as CFString),
            nil,
            nil,
            true
        )
    }

    private func syncSandboxFocusToAppGroup(_ focused: Bool) {
        let isActiveFocus = focused && UIApplication.shared.applicationState == .active
        let defaults = KeyboardPreferences.defaults
        defaults.set(isActiveFocus, forKey: "crh.key.test.sandboxFocused")
        if isActiveFocus {
            defaults.set(selectedThemeMode.isDark, forKey: "crh.key.test.isDark")
            defaults.set(selectedFieldMode.rawValue, forKey: "crh.key.test.fieldMode")
            defaults.set(Date().timeIntervalSince1970, forKey: "crh.key.test.overrideTimestamp")
        } else {
            defaults.removeObject(forKey: "crh.key.test.isDark")
            defaults.removeObject(forKey: "crh.key.test.fieldMode")
            defaults.removeObject(forKey: "crh.key.test.overrideTimestamp")
        }
        defaults.synchronize()
        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        notifySandboxTraitsChanged()
    }

    private func syncThemeToAppGroup(_ theme: KeyboardTestThemeMode) {
        guard UIApplication.shared.applicationState == .active else { return }
        let defaults = KeyboardPreferences.defaults
        if isWritingFieldFocused || shouldAutoFocusSandbox {
            defaults.set(theme.isDark, forKey: "crh.key.test.isDark")
            defaults.set(selectedFieldMode.rawValue, forKey: "crh.key.test.fieldMode")
            defaults.set(true, forKey: "crh.key.test.sandboxFocused")
            defaults.set(Date().timeIntervalSince1970, forKey: "crh.key.test.overrideTimestamp")
            defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            notifySandboxTraitsChanged()
        }
    }

    private static var didApplyLaunchArguments = false

    /// Test hook: `-qt_field email -qt_theme modernDark` preselects the sandbox state at launch (no-op otherwise).
    private func applyLaunchArguments() {
        guard !Self.didApplyLaunchArguments else { return }
        Self.didApplyLaunchArguments = true
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            let defaults = UserDefaults.standard
            let args = ProcessInfo.processInfo.arguments
            if let value = defaults.string(forKey: "qt_field"),
               let mode = KeyboardTestFieldMode(rawValue: "field.\(value)") {
                selectedFieldMode = mode
                isTestingExpanded = true
                shouldAutoFocusSandbox = true
            }
            if let value = defaults.string(forKey: "qt_theme") {
                if value.lowercased().contains("dark") {
                    selectedThemeMode = .dark
                } else {
                    selectedThemeMode = .ios26White
                }
                isTestingExpanded = true
                shouldAutoFocusSandbox = true
            }
            let isUITestLaunch = args.contains("-qt_reset_text") || args.contains("-qt_field") || args.contains("-qt_theme") || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            KeyboardPreferences.defaults.set(isUITestLaunch, forKey: "crh.key.test.isUITesting")
            KeyboardPreferences.defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            if isUITestLaunch {
                UIView.setAnimationsEnabled(false)
                isTestingExpanded = true
                shouldAutoFocusSandbox = true
            }
            if args.contains("-qt_reset_text") {
                let startSplit = args.contains("-qt_split")
                text = ""
                language = "crh"
                suggestionsEnabled = true
                wordLearningEnabled = true
                cyrillicEnabled = true
                ukrainianCyrillicLayout = false
                statsEnabled = true
                KeyboardPreferences.defaults.set("crh", forKey: KeyboardPreferences.languageKey)
                KeyboardPreferences.defaults.set(true, forKey: KeyboardPreferences.suggestionsKey)
                KeyboardPreferences.defaults.set(true, forKey: KeyboardPreferences.wordLearningKey)
                KeyboardPreferences.defaults.set(true, forKey: KeyboardPreferences.cyrillicKey)
                KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(false)
                KeyboardPreferences.defaults.set(startSplit, forKey: KeyboardPreferences.splitKeyboardKey)
                KeyboardPreferences.defaults.set(true, forKey: KeyboardPreferences.statsEnabledKey)
                KeyboardPreferences.defaults.set(args.contains("-qt_cyrillic_added"), forKey: "crh.key.cyrillicExtensionSeen")
                KeyboardPreferences.defaults.synchronize()
                KeyboardPreferences.refreshCachedPreferences()
                KeyboardUsageStats.resetAll()
                refreshStatsFromAppGroup(syncSQLite: false)
            } else if args.contains("-qt_split") {
                KeyboardPreferences.setSplitKeyboardEnabled(true)
            }
            if shouldAutoFocusSandbox {
                syncThemeToAppGroup(selectedThemeMode)
            }
        }
    }

    /// The sandbox override must only apply while this app is in the foreground; otherwise it leaks into every other app.
    private func clearThemeOverride() {
        let defaults = KeyboardPreferences.defaults
        defaults.removeObject(forKey: "crh.key.test.isDark")
        defaults.removeObject(forKey: "crh.key.test.fieldMode")
        defaults.removeObject(forKey: "crh.key.test.overrideTimestamp")
        defaults.set(false, forKey: "crh.key.test.sandboxFocused")
        defaults.synchronize()
        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        notifySandboxTraitsChanged()
    }

    /// Allows flexible window resizing across Slide Over, Split View, Stage Manager, and full screen.
    static func enforceFullScreenWindowIfNeeded() {
        guard Device.iPad else { return }
        for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
            scene.sizeRestrictions?.minimumSize = CGSize(width: 280, height: 320)
            scene.sizeRestrictions?.maximumSize = CGSize(width: 4096, height: 4096)
        }
    }

    /// Use the window's actual dimensions independently of device orientation or keyboard height,
    /// so narrow Slide Over / Split View windows on a landscape iPad always render in 1 column.
    static func usesTwoColumns(_ size: CGSize, containerSize: CGSize = .zero) -> Bool {
        guard Device.iPad else { return false }
        let windowSize = (size.width > 0 && size.height > 0) ? size : containerSize
        return windowSize.width > windowSize.height && windowSize.width >= 560
    }
}

/// Top row: child 0 (status indicators + top expandable basic statistics bar) spanning full width.
/// Bottom row: child 1 (settings) in the left column, and child 2 (Try Keyboard + Writing Area) in the right column.
private struct HomeTwoColumnLayout: Layout {
    var spacing: CGFloat = 16
    var leftFraction: CGFloat = 0.46

    private func widths(_ total: CGFloat) -> (left: CGFloat, right: CGFloat) {
        let usable = max(total - spacing, 0)
        let left = (usable * leftFraction).rounded()
        return (left, usable - left)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let totalWidth = proposal.width ?? 800
        let w = widths(totalWidth)
        if subviews.count == 2 {
            let h0 = subviews[0].sizeThatFits(.init(width: w.left, height: nil)).height
            let h1 = subviews[1].sizeThatFits(.init(width: w.right, height: nil)).height
            return CGSize(width: totalWidth, height: max(h0, h1))
        }
        guard subviews.count >= 3 else { return .zero }
        let h0 = subviews[0].sizeThatFits(.init(width: totalWidth, height: nil)).height
        let h1 = subviews[1].sizeThatFits(.init(width: w.left, height: nil)).height
        let h2 = subviews[2].sizeThatFits(.init(width: w.right, height: nil)).height
        let topOffset = h0 > 0 ? (h0 + spacing) : 0
        return CGSize(width: totalWidth, height: topOffset + max(h1, h2))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let totalWidth = bounds.width
        let w = widths(totalWidth)
        if subviews.count == 2 {
            let h0 = subviews[0].sizeThatFits(.init(width: w.left, height: nil)).height
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                anchor: .topLeading,
                proposal: .init(width: w.left, height: h0)
            )
            let h1 = subviews[1].sizeThatFits(.init(width: w.right, height: nil)).height
            subviews[1].place(
                at: CGPoint(x: bounds.minX + w.left + spacing, y: bounds.minY),
                anchor: .topLeading,
                proposal: .init(width: w.right, height: h1)
            )
            return
        }
        guard subviews.count >= 3 else { return }
        let h0 = subviews[0].sizeThatFits(.init(width: totalWidth, height: nil)).height
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: .init(width: totalWidth, height: h0)
        )
        let rowY = bounds.minY + (h0 > 0 ? (h0 + spacing) : 0)
        let h1 = subviews[1].sizeThatFits(.init(width: w.left, height: nil)).height
        subviews[1].place(
            at: CGPoint(x: bounds.minX, y: rowY),
            anchor: .topLeading,
            proposal: .init(width: w.left, height: h1)
        )
        let h2 = subviews[2].sizeThatFits(.init(width: w.right, height: nil)).height
        subviews[2].place(
            at: CGPoint(x: bounds.minX + w.left + spacing, y: rowY),
            anchor: .topLeading,
            proposal: .init(width: w.right, height: h2)
        )
    }
}

private extension HomeView {

    private var appleGreen: Color { Color(red: 0.20, green: 0.78, blue: 0.35) }
    private var brandBlue: Color { Color(red: 0.0, green: 0.53, blue: 0.86) }
    private var primaryInk: Color { Color(.label) }
    private var secondaryInk: Color { Color(.secondaryLabel) }
    private var segmentedTrackColor: Color { Color(.tertiarySystemFill) }

    func interfaceLabel(_ key: String) -> Text {
        Text(LocalizedStringKey(key), tableName: "Interface", bundle: KeyboardPreferences.interfaceBundle)
    }

    func localizedInterfaceString(_ key: String) -> String {
        let _ = language
        return KeyboardPreferences.interfaceBundle.localizedString(forKey: key, value: key, table: "Interface")
    }

    func settingsIconBadge(_ systemName: String, color: Color, isEnabled: Bool = true) -> some View {
        let effectiveColor = isEnabled ? color : Color(.systemGray2)
        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(effectiveColor.gradient)
                .frame(width: 28, height: 28)
            Image(systemName: systemName)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    func cyrillicKeycapIconBadge(color: Color, isEnabled: Bool = true) -> some View {
        let effectiveColor = isEnabled ? color : Color(.systemGray2)
        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(effectiveColor.gradient)
                .frame(width: 28, height: 28)
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .strokeBorder(.white.opacity(0.45), lineWidth: 1)
                .frame(width: 21, height: 19)
            Text("Къ")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    func ukrainianKeycapIconBadge(isEnabled: Bool) -> some View {
        ZStack {
            if isEnabled {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.42, blue: 0.85),
                                Color(red: 0.96, green: 0.78, blue: 0.04)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 28, height: 28)
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(.systemGray2).gradient)
                    .frame(width: 28, height: 28)
            }
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .strokeBorder(.white.opacity(0.55), lineWidth: 1)
                .frame(width: 21, height: 19)
            Text("К\u{02BC}")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(isEnabled ? 0.25 : 0), radius: 1, x: 0, y: 0.5)
        }
    }

    func walnutBrainIconBadge(color: Color, isEnabled: Bool = true) -> some View {
        let effectiveColor = isEnabled ? color : Color(.systemGray2)
        return ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(effectiveColor.gradient)
                .frame(width: 28, height: 28)
            WalnutBrainIcon(color: .white, size: 16.5)
        }
    }

    var statusIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let states: [KeyboardState] = {
                var list: [KeyboardState] = [
                    .active(keyboardState.isKeyboardActive),
                    .enable(keyboardState.isKeyboardEnabled),
                    .fullAccess(cachedIsFullAccessEnabled)
                ]
                if shouldIncludeCyrillicStatusTile {
                    list.append(.cyrillic(isCyrillicKeyboardAdded))
                }
                return list
            }()
            KeyboardStateIndicatorsRow(states: states) {
                showIndicatorSheet = true
            }

            if userUsesCyrillicEnvironment && !isCyrillicKeyboardAdded {
                cyrillicRecommendationBanner
            }

            if !keyboardState.isKeyboardActive {
                StableLocalizedText(
                    key: Home.home_getkeyboard_key.rawValue,
                    table: "Home",
                    font: InterfaceFont.font("GeneralSans-Regular", size: 12),
                    color: secondaryInk
                )
                .padding(.horizontal, 4)
            }
        }
    }

    var cyrillicRecommendationBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            cyrillicKeycapIconBadge(color: Color(red: 0.35, green: 0.34, blue: 0.84))
            VStack(alignment: .leading, spacing: 2) {
                interfaceLabel("settings.cyrillicPromoTitle")
                    .font(InterfaceFont.font("GeneralSans-Semibold", size: 13.5))
                    .foregroundStyle(primaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                interfaceLabel("settings.cyrillicPromoDesc")
                    .font(InterfaceFont.font("GeneralSans-Regular", size: 12))
                    .foregroundStyle(secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 6)
            Button {
                Self.openKeyboardSettings()
            } label: {
                interfaceLabel("settings.cyrillicAddAction")
                    .font(InterfaceFont.font("GeneralSans-Semibold", size: 12.5))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(brandBlue, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("status.cyrillicPromoAddButton")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color(.secondarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color(red: 0.35, green: 0.34, blue: 0.84).opacity(0.32), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("status.cyrillicPromoBanner")
    }

    /// Keyboard Settings displayed directly on the Home screen in a clean Apple Settings card style.
    var keyboardSettingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language selector row
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    settingsIconBadge("globe", color: brandBlue)
                    interfaceLabel("settings.language")
                        .font(InterfaceFont.font("GeneralSans-Medium", size: 15))
                        .foregroundStyle(primaryInk)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer(minLength: 10)
                    languageSegmentedControl(fullWidth: false)
                        .fixedSize(horizontal: true, vertical: false)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        settingsIconBadge("globe", color: brandBlue)
                        interfaceLabel("settings.language")
                            .font(InterfaceFont.font("GeneralSans-Medium", size: 15))
                            .foregroundStyle(primaryInk)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                    }
                    languageSegmentedControl(fullWidth: true)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider().padding(.leading, 54)

            // Cyrillic row: iPad has an in-place script key (абв/abc) toggle;
            // iPhone has no in-keyboard script key and shows a status row with a "Додати" button when missing, or a static "✓ Додано" badge when added.
            if Device.iPad {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        cyrillicKeycapIconBadge(color: Color(red: 0.35, green: 0.34, blue: 0.84), isEnabled: cyrillicEnabled)
                        interfaceLabel("settings.cyrillic")
                            .font(InterfaceFont.font("GeneralSans-Medium", size: 15))
                            .foregroundStyle(primaryInk)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Toggle("", isOn: $cyrillicEnabled.animation(.spring(response: 0.32, dampingFraction: 0.85)))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityIdentifier("settings.cyrillic.toggle")
                    }

                    if cyrillicEnabled && !isCyrillicKeyboardAdded {
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: "globe")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(brandBlue)
                            StableLocalizedText(
                                key: "settings.cyrillic.ipadFloatingNote",
                                font: InterfaceFont.font("GeneralSans-Regular", size: 12),
                                color: secondaryInk
                            )
                            Spacer(minLength: 6)
                            Button {
                                Self.openKeyboardSettings()
                            } label: {
                                interfaceLabel("settings.cyrillicAddAction")
                                    .font(InterfaceFont.font("GeneralSans-Semibold", size: 12))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(brandBlue, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("settings.cyrillic.addButton")
                        }
                        .padding(.leading, 40)
                        .padding(.top, 2)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            } else {
                HStack(spacing: 12) {
                    cyrillicKeycapIconBadge(color: Color(red: 0.35, green: 0.34, blue: 0.84), isEnabled: isCyrillicKeyboardAdded)
                    interfaceLabel("settings.cyrillic")
                        .font(InterfaceFont.font("GeneralSans-Medium", size: 15))
                        .foregroundStyle(primaryInk)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    if isCyrillicKeyboardAdded {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(appleGreen)
                            interfaceLabel("settings.cyrillicStatusAdded")
                                .font(InterfaceFont.font("GeneralSans-Semibold", size: 13))
                                .foregroundStyle(appleGreen)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(
                            appleGreen.opacity(0.12),
                            in: Capsule()
                        )
                    } else {
                        Button {
                            Self.openKeyboardSettings()
                        } label: {
                            interfaceLabel("settings.cyrillicAddAction")
                                .font(InterfaceFont.font("GeneralSans-Semibold", size: 12.5))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(brandBlue, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.cyrillic.addButton")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings.cyrillic.statusRow")
            }

            if !Device.iPad && cyrillicStatus == .missing {
                Button {
                    showCyrillicGuideAlert = true
                } label: {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.orange)
                        StableLocalizedText(
                            key: "settings.missingCyrillic",
                            font: InterfaceFont.font("GeneralSans-Regular", size: 12),
                            color: secondaryInk
                        )
                    }
                    .padding(.leading, 54)
                    .padding(.trailing, 14)
                    .padding(.bottom, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.cyrillicWarning")
            }

            if (cyrillicEnabled || !Device.iPad) && (language == "uk" || Locale.preferredLanguages.first?.lowercased().hasPrefix("uk") == true) {
                Divider().padding(.leading, 54)

                HStack(spacing: 12) {
                    ukrainianKeycapIconBadge(isEnabled: ukrainianCyrillicLayout)
                    VStack(alignment: .leading, spacing: 2) {
                        interfaceLabel("settings.ukrainianCyrillic")
                            .font(InterfaceFont.font("GeneralSans-Medium", size: 15))
                            .foregroundStyle(primaryInk)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        interfaceLabel("settings.ukrainianCyrillic.desc")
                            .font(InterfaceFont.font("GeneralSans-Regular", size: 12))
                            .foregroundStyle(secondaryInk)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Toggle("", isOn: $ukrainianCyrillicLayout.animation(.spring(response: 0.32, dampingFraction: 0.85)))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("settings.ukrainianCyrillic.toggle")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            Divider().padding(.leading, 54)

            // Autocomplete suggestions toggle
            HStack(spacing: 12) {
                settingsIconBadge("sparkles", color: appleGreen, isEnabled: suggestionsEnabled)
                interfaceLabel("settings.suggestions")
                    .font(InterfaceFont.font("GeneralSans-Medium", size: 15))
                    .foregroundStyle(primaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Toggle("", isOn: $suggestionsEnabled.animation(.spring(response: 0.32, dampingFraction: 0.85)))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.suggestions.toggle")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().padding(.leading, 54)

            // Personalized word & bigram learning toggle
            HStack(spacing: 12) {
                walnutBrainIconBadge(color: Color(red: 0.96, green: 0.58, blue: 0.04), isEnabled: wordLearningEnabled)
                interfaceLabel("settings.wordLearning")
                    .font(InterfaceFont.font("GeneralSans-Medium", size: 15))
                    .foregroundStyle(primaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Toggle("", isOn: $wordLearningEnabled.animation(.spring(response: 0.32, dampingFraction: 0.85)))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.wordLearning.toggle")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider().padding(.leading, 54)

            // Typing statistics & progression levels toggle
            HStack(spacing: 12) {
                settingsIconBadge("chart.bar.xaxis", color: Color(red: 0.58, green: 0.29, blue: 0.92), isEnabled: statsEnabled)
                interfaceLabel("settings.stats")
                    .font(InterfaceFont.font("GeneralSans-Medium", size: 15))
                    .foregroundStyle(primaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Toggle("", isOn: $statsEnabled.animation(.spring(response: 0.32, dampingFraction: 0.85)))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.stats.toggle")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 3)
    }

    func languageSegmentedControl(fullWidth: Bool) -> some View {
        NativeSegmentedControl(
            items: [
                .init(id: "crh", title: "Qırımtatarca", accessibilityIdentifier: "settings.lang.crh"),
                .init(id: "uk", title: "Українська", accessibilityIdentifier: "settings.lang.uk"),
                .init(id: "en", title: "English", accessibilityIdentifier: "settings.lang.en")
            ],
            selection: $language,
            apportionsWidthsByContent: !fullWidth,
            expandsToFillWidth: fullWidth
        )
        .frame(height: 32)
    }

    /// Combines the expandable "Try Keyboard" controls and the writing area into a single unified Apple card.
    var testingAndWritingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
                    isTestingExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    settingsIconBadge("keyboard.badge.eye", color: brandBlue)
                    Text(Onboarding.onb_check_key.localized)
                        .font(InterfaceFont.font("GeneralSans-Semibold", size: 15))
                        .foregroundStyle(primaryInk)
                        .lineLimit(1)
                    Spacer()
                    ZStack {
                        Circle()
                            .fill(segmentedTrackColor)
                            .frame(width: 26, height: 26)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(secondaryInk)
                            .rotationEffect(.degrees(isTestingExpanded ? 180 : 0))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("testing.toggle")
            .id("testingSection")

            if isTestingExpanded {
                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 12) {
                    testingSandboxSection
                    writingAreaSection
                        .id("writingArea")
                }
                .padding(14)
                .transition(.opacity)
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 3)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    var testingSandboxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Leading mode icon badge + Native iOS 27 Segmented Field Mode strip
            HStack(spacing: 10) {
                settingsIconBadge(selectedFieldMode.icon, color: brandBlue)
                NativeSegmentedControl(
                    items: KeyboardTestFieldMode.allCases.map { mode in
                        .init(
                            id: mode.rawValue,
                            title: localizedInterfaceString(mode.rawValue),
                            accessibilityIdentifier: mode.rawValue
                        )
                    },
                    selection: Binding(
                        get: { selectedFieldMode.rawValue },
                        set: { newValue in
                            if let mode = KeyboardTestFieldMode(rawValue: newValue) {
                                shouldAutoFocusSandbox = true
                                selectedFieldMode = mode
                            }
                        }
                    ),
                    apportionsWidthsByContent: false
                )
                .frame(height: 32)
            }

            // Row 2: Leading theme icon badge + Native iOS 27 Segmented Theme switcher (Light / Dark)
            HStack(spacing: 10) {
                settingsIconBadge(
                    selectedThemeMode.icon,
                    color: selectedThemeMode.isDark
                        ? Color(red: 0.35, green: 0.34, blue: 0.84)
                        : Color(red: 0.96, green: 0.58, blue: 0.04)
                )
                NativeSegmentedControl(
                    items: [
                        .init(
                            id: KeyboardTestThemeMode.ios26White.rawValue,
                            title: localizedInterfaceString("theme.light"),
                            accessibilityIdentifier: "theme.light"
                        ),
                        .init(
                            id: KeyboardTestThemeMode.dark.rawValue,
                            title: localizedInterfaceString("theme.dark"),
                            accessibilityIdentifier: "theme.dark"
                        )
                    ],
                    selection: Binding(
                        get: { selectedThemeMode.rawValue },
                        set: { newValue in
                            if let mode = KeyboardTestThemeMode(rawValue: newValue) {
                                shouldAutoFocusSandbox = true
                                selectedThemeMode = mode
                            }
                        }
                    ),
                    apportionsWidthsByContent: false
                )
                .frame(height: 32)
            }
        }
    }

    var writingAreaSection: some View {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let displayWPM = (statsEnabled && hasText) ? liveWPM : 0
        let displayCPM = (statsEnabled && hasText) ? liveCPM : 0

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: selectedFieldMode.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(brandBlue)
                Text(Home.home_writearea_key.localized)
                    .font(InterfaceFont.font("GeneralSans-Medium", size: 13))
                    .foregroundStyle(secondaryInk)
                    .lineLimit(1)

                if statsEnabled && (displayCPM > 0 || displayWPM > 0) {
                    HStack(spacing: 3) {
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(brandBlue)
                        Text(
                            displayWPM > 0
                                ? "\(displayWPM) \(localizedInterfaceString("stats.wpmUnit")) · \(displayCPM) \(localizedInterfaceString("stats.cpmUnit"))"
                                : "\(displayCPM) \(localizedInterfaceString("stats.cpmUnit"))"
                        )
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(brandBlue)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(brandBlue.opacity(0.12), in: Capsule())
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("sandbox.speedBadge")
                }

                Spacer(minLength: 4)

                Button {
                    text = ""
                    NotificationCenter.default.post(name: Notification.Name("crh.key.clearSandboxText"), object: nil)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 17))
                        .foregroundStyle(secondaryInk.opacity(0.75))
                        .frame(width: 26, height: 26)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(text.isEmpty ? 0 : 1)
                .disabled(text.isEmpty)
                .accessibilityIdentifier("sandbox.clear")
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(Home.home_typing_key.localized)
                        .font(InterfaceFont.font("GeneralSans-Regular", size: Device.iPad ? 16 : 15))
                        .foregroundStyle(Color(.placeholderText))
                        .padding(.horizontal, 13)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                }
                SandboxTextView(
                    text: $text,
                    currentText: text,
                    isFocused: $isWritingFieldFocused,
                    canUndo: $canSandboxUndo,
                    canRedo: $canSandboxRedo,
                    liveWPM: $liveWPM,
                    liveCPM: $liveCPM,
                    autoFocusOnAppear: shouldAutoFocusSandbox,
                    placeholder: Home.home_typing_key.localized,
                    fieldMode: selectedFieldMode,
                    themeMode: selectedThemeMode,
                    preferencesToken: "\(cyrillicEnabled)-\(suggestionsEnabled)-\(wordLearningEnabled)-\(statsEnabled)",
                    fontSize: Device.iPad ? 16 : 15
                )
                .frame(height: Device.iPad ? 96 : 82)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .environment(\.layoutDirection, isRtl ? .rightToLeft : .leftToRight)
            }
        }
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    var formattedActiveTime: String {
        let totalSecs = Int(max(activeSeconds, 0))
        let mins = totalSecs / 60
        let secs = totalSecs % 60
        if mins == 0 {
            return "\(secs) \(localizedInterfaceString("stats.secUnit"))"
        }
        return "\(mins) \(localizedInterfaceString("stats.minUnit"))"
    }

    func compactStatPill(icon: String, color: Color, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(primaryInk)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    func walnutBrainStatPill(color: Color, value: String) -> some View {
        HStack(spacing: 4) {
            WalnutBrainIcon(color: color, size: 12.5)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(primaryInk)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    /// Top Basic Statistics bar with expandable Extended Statistics & Achievements card.
    var statisticsAndAchievementsSection: some View {
        let bestWPM = max(peakWPM, max(lastWPM, liveWPM))
        let bestCPM = max(peakCPM, max(lastCPM, liveCPM))
        let recentWPM = liveWPM > 0 ? liveWPM : lastWPM
        let recentCPM = liveCPM > 0 ? liveCPM : lastCPM
        let effectiveManualWords = (manualWords == 0 && suggestedWords == 0 && totalWords > 0)
            ? totalWords
            : manualWords
        let typedChars = max(totalCharacters, 0)
        let savedChars = max(suggestedCharacters, 0)
        let boostMultiplier: Double = {
            guard typedChars > 0, savedChars > 0 else { return 1.0 }
            let raw = Double(typedChars + savedChars) / Double(typedChars)
            return min(max((raw * 10.0).rounded() / 10.0, 1.1), 9.9)
        }()
        let speedTier = KeyboardUsageStats.speedTier(for: bestWPM)
        let volumeTier = KeyboardUsageStats.volumeTier(for: totalWords)
        let wpmUnit = localizedInterfaceString("stats.wpmUnit")
        let cpmUnit = localizedInterfaceString("stats.cpmUnit")

        let speedSubtitle: String = {
            if recentWPM > 0 || recentCPM > 0 {
                return String(
                    format: localizedInterfaceString("stats.speedSubtitle"),
                    recentWPM,
                    wpmUnit,
                    recentCPM,
                    cpmUnit
                )
            }
            return localizedInterfaceString("stats.speedPeakSubtitle")
        }()

        let speedTierSubtitle: String = {
            if let nextTarget = speedTier.nextTargetWPM, speedTier.level < 5 {
                let nextName = localizedInterfaceString("stats.speedTier\(speedTier.level + 1)")
                let remaining = max(nextTarget - bestWPM, 1)
                return String(
                    format: localizedInterfaceString("stats.speedNextFormat"),
                    nextName,
                    nextTarget,
                    wpmUnit,
                    remaining
                )
            }
            return localizedInterfaceString("stats.speedMaxReached")
        }()

        let volumeTierSubtitle: String = {
            if let nextTarget = volumeTier.nextTargetWords, volumeTier.level < 5 {
                let nextName = localizedInterfaceString("stats.volumeTier\(volumeTier.level + 1)")
                let remaining = max(nextTarget - totalWords, 1)
                return String(
                    format: localizedInterfaceString("stats.volumeNextFormat"),
                    nextName,
                    nextTarget,
                    remaining
                )
            }
            return localizedInterfaceString("stats.volumeMaxReached")
        }()

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                HapticFeedback.playSelection()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    isStatsExpanded.toggle()
                }
            } label: {
                if isStatsExpanded {
                    HStack(spacing: 8) {
                        settingsIconBadge("chart.bar.xaxis", color: Color(red: 0.58, green: 0.29, blue: 0.92))
                        interfaceLabel("stats.title")
                            .font(InterfaceFont.font("GeneralSans-Semibold", size: 14.5))
                            .foregroundStyle(primaryInk)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.up")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(secondaryInk)
                            .frame(width: 24, height: 24)
                            .background(Color(.tertiarySystemFill), in: Circle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            settingsIconBadge("chart.bar.xaxis", color: Color(red: 0.58, green: 0.29, blue: 0.92))
                            interfaceLabel("stats.title")
                                .font(InterfaceFont.font("GeneralSans-Semibold", size: 14.5))
                                .foregroundStyle(primaryInk)
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)

                            Spacer(minLength: 6)

                            HStack(spacing: 6) {
                                compactStatPill(icon: "text.word.spacing", color: brandBlue, value: "\(totalWords)")
                                compactStatPill(icon: "bolt.heart.fill", color: Color(red: 0.95, green: 0.32, blue: 0.38), value: "\(bestWPM) \(wpmUnit)")
                                compactStatPill(icon: "clock.fill", color: appleGreen, value: formattedActiveTime)
                                walnutBrainStatPill(color: Color(red: 0.96, green: 0.58, blue: 0.04), value: "\(learnedWordsCount)")
                            }

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(secondaryInk)
                                .frame(width: 24, height: 24)
                                .background(Color(.tertiarySystemFill), in: Circle())
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 8) {
                                settingsIconBadge("chart.bar.xaxis", color: Color(red: 0.58, green: 0.29, blue: 0.92))
                                interfaceLabel("stats.title")
                                    .font(InterfaceFont.font("GeneralSans-Semibold", size: 14.5))
                                    .foregroundStyle(primaryInk)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12.5, weight: .semibold))
                                    .foregroundStyle(secondaryInk)
                                    .frame(width: 24, height: 24)
                                    .background(Color(.tertiarySystemFill), in: Circle())
                            }
                            HStack(spacing: 6) {
                                compactStatPill(icon: "text.word.spacing", color: brandBlue, value: "\(totalWords)")
                                compactStatPill(icon: "bolt.heart.fill", color: Color(red: 0.95, green: 0.32, blue: 0.38), value: "\(bestWPM) \(wpmUnit)")
                                compactStatPill(icon: "clock.fill", color: appleGreen, value: formattedActiveTime)
                                walnutBrainStatPill(color: Color(red: 0.96, green: 0.58, blue: 0.04), value: "\(learnedWordsCount)")
                                Spacer(minLength: 0)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .contentShape(Rectangle())
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("stats.expandToggle")

            if isStatsExpanded {
                Divider()

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        statTile(
                            icon: "text.word.spacing",
                            color: brandBlue,
                            title: localizedInterfaceString("stats.words"),
                            value: "\(totalWords)",
                            subtitle: String(format: localizedInterfaceString("stats.charsSubtitle"), typedChars)
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("stats.wordsTile")

                        statTile(
                            icon: "bolt.heart.fill",
                            color: Color(red: 0.95, green: 0.32, blue: 0.38),
                            title: localizedInterfaceString("stats.speed"),
                            value: "\(bestWPM) \(wpmUnit) · \(bestCPM) \(cpmUnit)",
                            subtitle: speedSubtitle
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("stats.speedTile")
                    }

                    HStack(spacing: 10) {
                        statTile(
                            icon: "keyboard.fill",
                            color: brandBlue,
                            title: localizedInterfaceString("stats.manualWords"),
                            value: "\(effectiveManualWords)",
                            subtitle: localizedInterfaceString("stats.manualWordsSubtitle")
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("stats.manualWordsTile")

                        statTile(
                            icon: "sparkles",
                            color: appleGreen,
                            title: localizedInterfaceString("stats.suggestedWords"),
                            value: "\(suggestedWords) · \(String(format: "×%.1f", boostMultiplier))",
                            subtitle: String(format: localizedInterfaceString("stats.suggestedWordsSubtitle"), savedChars)
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("stats.suggestedWordsTile")
                    }

                    HStack(spacing: 10) {
                        statTile(
                            icon: "gauge.with.dots.needle.67percent",
                            color: Color(red: 0.95, green: 0.32, blue: 0.38),
                            title: localizedInterfaceString("stats.speedLevel"),
                            value: localizedInterfaceString("stats.speedTier\(speedTier.level)"),
                            subtitle: speedTierSubtitle
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("stats.speedTierTile")

                        statTile(
                            icon: "flame.fill",
                            color: Color(red: 0.58, green: 0.29, blue: 0.92),
                            title: localizedInterfaceString("stats.volumeLevel"),
                            value: localizedInterfaceString("stats.volumeTier\(volumeTier.level)"),
                            subtitle: volumeTierSubtitle
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("stats.volumeTierTile")
                    }

                    HStack(spacing: 10) {
                        statTile(
                            icon: "clock.fill",
                            color: appleGreen,
                            title: localizedInterfaceString("stats.activeTime"),
                            value: formattedActiveTime,
                            subtitle: localizedInterfaceString("stats.activeTimeSubtitle")
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("stats.activeTimeTile")

                        walnutBrainStatTile(
                            color: Color(red: 0.96, green: 0.58, blue: 0.04),
                            title: localizedInterfaceString("stats.learnedWords"),
                            value: "\(learnedWordsCount)",
                            subtitle: localizedInterfaceString("stats.learnedWordsSubtitle")
                        )
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("stats.learnedWordsTile")
                    }
                }

                Divider()

                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(red: 0.96, green: 0.58, blue: 0.04))
                    interfaceLabel("stats.achievements")
                        .font(InterfaceFont.font("GeneralSans-Medium", size: 13))
                        .foregroundStyle(secondaryInk)
                    Spacer()

                    Button(role: .destructive) {
                        HapticFeedback.playSelection()
                        showResetStatsConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 11, weight: .semibold))
                            interfaceLabel("stats.reset")
                                .font(InterfaceFont.font("GeneralSans-Medium", size: 12))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.red)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.10), in: Capsule())
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("stats.resetButton")
                }

                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        achievementBadge(
                            icon: "flag.checkered",
                            title: localizedInterfaceString("stats.ach.firstStep"),
                            subtitle: localizedInterfaceString("stats.ach.firstStep.desc"),
                            progress: min(Double(totalWords) / 10.0, 1.0),
                            unlocked: totalWords >= 10
                        )
                        achievementBadge(
                            icon: "bolt.heart.fill",
                            title: localizedInterfaceString("stats.ach.speed"),
                            subtitle: localizedInterfaceString("stats.ach.speed.desc"),
                            progress: min(Double(bestWPM) / 30.0, 1.0),
                            unlocked: bestWPM >= 30
                        )
                    }
                    HStack(spacing: 10) {
                        achievementBadge(
                            icon: "book.closed.fill",
                            title: localizedInterfaceString("stats.ach.scholar"),
                            subtitle: localizedInterfaceString("stats.ach.scholar.desc"),
                            progress: min(max(Double(totalWords) / 100.0, Double(learnedWordsCount) / 10.0), 1.0),
                            unlocked: totalWords >= 100 || learnedWordsCount >= 10
                        )
                        achievementBadge(
                            icon: "sparkles",
                            title: localizedInterfaceString("stats.ach.wisdom"),
                            subtitle: localizedInterfaceString("stats.ach.wisdom.desc"),
                            progress: phrasesInserted >= 1 ? 1.0 : 0.0,
                            unlocked: phrasesInserted >= 1
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
        .alert(localizedInterfaceString("stats.resetConfirmTitle"), isPresented: $showResetStatsConfirmation) {
            Button(localizedInterfaceString("stats.resetConfirmAction"), role: .destructive) {
                KeyboardUsageStats.resetAll()
                liveWPM = 0
                liveCPM = 0
                learnedWordsCount = 0
                refreshStatsFromAppGroup(syncSQLite: false)
            }
            Button(localizedInterfaceString("stats.cancel"), role: .cancel) {}
        } message: {
            Text(localizedInterfaceString("stats.resetConfirmMessage"))
        }
    }

    func statTile(icon: String, color: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(InterfaceFont.font("GeneralSans-Medium", size: 12))
                    .foregroundStyle(secondaryInk)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                .foregroundStyle(primaryInk)
                .lineLimit(1)
                .contentTransition(.numericText())
            Text(subtitle)
                .font(InterfaceFont.font("GeneralSans-Regular", size: 11))
                .foregroundStyle(secondaryInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func walnutBrainStatTile(color: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                WalnutBrainIcon(color: color, size: 13)
                Text(title)
                    .font(InterfaceFont.font("GeneralSans-Medium", size: 12))
                    .foregroundStyle(secondaryInk)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: 14.5, weight: .bold, design: .rounded))
                .foregroundStyle(primaryInk)
                .lineLimit(1)
                .contentTransition(.numericText())
            Text(subtitle)
                .font(InterfaceFont.font("GeneralSans-Regular", size: 11))
                .foregroundStyle(secondaryInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func achievementBadge(icon: String, title: String, subtitle: String, progress: Double, unlocked: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: unlocked ? "checkmark.seal.fill" : icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(unlocked ? appleGreen : brandBlue)
                Text(title)
                    .font(InterfaceFont.font("GeneralSans-Semibold", size: 12.5))
                    .foregroundStyle(primaryInk)
                    .lineLimit(1)
                Spacer(minLength: 2)
            }
            Text(subtitle)
                .font(InterfaceFont.font("GeneralSans-Regular", size: 11))
                .foregroundStyle(secondaryInk)
                .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(unlocked ? appleGreen : brandBlue)
                        .frame(width: max(geo.size.width * CGFloat(min(max(progress, 0.06), 1.0)), 4))
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(.tertiarySystemGroupedBackground),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(unlocked ? appleGreen.opacity(0.45) : Color.clear, lineWidth: 1)
        )
    }

    var isRtl: Bool {
        cachedIsRtl
    }

    var isCyrillicKeyboardAdded: Bool {
        cyrillicStatus == .enabled
    }

    var userUsesCyrillicEnvironment: Bool {
        if language == "uk" { return true }
        let cyrillicPrefixes = [
            "uk", "ru", "be", "bg", "kk", "ky", "mk", "sr",
            "mn", "tg", "uz-cyrl", "tt", "ba", "cv", "sah",
            "os", "ce", "crh-cyrl"
        ]
        for pref in Locale.preferredLanguages {
            let norm = pref.replacingOccurrences(of: "_", with: "-").lowercased()
            if cyrillicPrefixes.contains(where: { norm == $0 || norm.hasPrefix($0 + "-") }) {
                return true
            }
        }
        for mode in UITextInputMode.activeInputModes {
            if let lang = mode.primaryLanguage?.replacingOccurrences(of: "_", with: "-").lowercased() {
                if cyrillicPrefixes.contains(where: { lang == $0 || lang.hasPrefix($0 + "-") }) {
                    return true
                }
            }
        }
        return false
    }

    var shouldIncludeCyrillicStatusTile: Bool {
        if Device.iPad {
            return cyrillicEnabled || userUsesCyrillicEnvironment
        } else {
            return !isCyrillicKeyboardAdded || userUsesCyrillicEnvironment
        }
    }

    var areAllIndicatorsEnabled: Bool {
        let baseOk = keyboardState.isKeyboardActive &&
            keyboardState.isKeyboardEnabled &&
            cachedIsFullAccessEnabled
        let cyrillicRequiredOnPad = Device.iPad && cyrillicEnabled && !isCyrillicKeyboardAdded
        let cyrillicRecommendedByEnv = userUsesCyrillicEnvironment && !isCyrillicKeyboardAdded
        return baseOk && !cyrillicRequiredOnPad && !cyrillicRecommendedByEnv
    }
}

/// Native UIKit `UISegmentedControl` wrapper that preserves per-segment accessibility identifiers
/// (`settings.lang.*`, `field.*`, `theme.*`) for UI automation while rendering the authentic iOS 27 segmented control.
private struct NativeSegmentedControl: UIViewRepresentable {
    struct Item: Equatable {
        let id: String
        let title: String
        let accessibilityIdentifier: String
    }

    let items: [Item]
    @Binding var selection: String
    var apportionsWidthsByContent: Bool = false
    var expandsToFillWidth: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> AccessibleUISegmentedControl {
        let control = AccessibleUISegmentedControl(items: items.map(\.title))
        control.apportionsSegmentWidthsByContent = apportionsWidthsByContent
        control.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        control.setContentHuggingPriority(expandsToFillWidth ? .defaultLow : .required, for: .horizontal)
        control.segmentIdentifiers = items.map(\.accessibilityIdentifier)
        if let idx = items.firstIndex(where: { $0.id == selection }) {
            control.selectedSegmentIndex = idx
        }
        control.addTarget(context.coordinator, action: #selector(Coordinator.valueChanged(_:)), for: .valueChanged)
        control.applySegmentAccessibilityIdentifiers()
        return control
    }

    func updateUIView(_ uiView: AccessibleUISegmentedControl, context: Context) {
        context.coordinator.parent = self
        uiView.apportionsSegmentWidthsByContent = apportionsWidthsByContent
        uiView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        uiView.setContentHuggingPriority(expandsToFillWidth ? .defaultLow : .required, for: .horizontal)
        if uiView.numberOfSegments != items.count {
            uiView.removeAllSegments()
            for (idx, item) in items.enumerated() {
                uiView.insertSegment(withTitle: item.title, at: idx, animated: false)
            }
        } else {
            for (idx, item) in items.enumerated() {
                if uiView.titleForSegment(at: idx) != item.title {
                    uiView.setTitle(item.title, forSegmentAt: idx)
                }
            }
        }
        uiView.segmentIdentifiers = items.map(\.accessibilityIdentifier)
        if let idx = items.firstIndex(where: { $0.id == selection }),
           uiView.selectedSegmentIndex != idx {
            uiView.selectedSegmentIndex = idx
        }
        uiView.applySegmentAccessibilityIdentifiers()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: AccessibleUISegmentedControl, context: Context) -> CGSize {
        let height = proposal.height ?? 32
        let intrinsicWidth = uiView.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).width
        if let proposedWidth = proposal.width, proposedWidth.isFinite {
            if expandsToFillWidth {
                return CGSize(width: max(proposedWidth, 120), height: height)
            }
            return CGSize(width: min(proposedWidth, max(intrinsicWidth, 160)), height: height)
        }
        return CGSize(width: max(intrinsicWidth, 160), height: height)
    }

    final class Coordinator: NSObject {
        var parent: NativeSegmentedControl

        init(_ parent: NativeSegmentedControl) {
            self.parent = parent
        }

        @objc func valueChanged(_ sender: UISegmentedControl) {
            let idx = sender.selectedSegmentIndex
            guard idx >= 0 && idx < parent.items.count else { return }
            let newID = parent.items[idx].id
            if parent.selection != newID {
                HapticFeedback.playSelection()
                parent.selection = newID
            }
        }
    }
}

private final class AccessibleUISegmentedControl: UISegmentedControl {
    var segmentIdentifiers: [String] = [] {
        didSet { applySegmentAccessibilityIdentifiers() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applySegmentAccessibilityIdentifiers()
    }

    func applySegmentAccessibilityIdentifiers() {
        for label in Self.collectLabels(in: self) {
            label.adjustsFontSizeToFitWidth = false
            label.lineBreakMode = .byTruncatingTail
        }
        let segments = Self.collectSegments(in: self)
            .sorted { $0.convert($0.bounds, to: self).minX < $1.convert($1.bounds, to: self).minX }
        guard segments.count == segmentIdentifiers.count else { return }
        for (segment, id) in zip(segments, segmentIdentifiers) {
            segment.accessibilityIdentifier = id
        }
    }

    private static func collectSegments(in root: UIView) -> [UIView] {
        var result: [UIView] = []
        for subview in root.subviews {
            if NSStringFromClass(type(of: subview)) == "UISegment" {
                result.append(subview)
            } else {
                result.append(contentsOf: collectSegments(in: subview))
            }
        }
        return result
    }

    private static func collectLabels(in root: UIView) -> [UILabel] {
        var result: [UILabel] = []
        for subview in root.subviews {
            if let label = subview as? UILabel {
                result.append(label)
            }
            result.append(contentsOf: collectLabels(in: subview))
        }
        return result
    }
}

/// Renders a localized text whose height is the tallest of all interface languages at the current width,
/// so switching the interface language never makes the surrounding layout jump.
struct StableLocalizedText: View {
    let key: String
    var table = "Interface"
    let font: Font
    let color: Color

    private static let languages = ["crh", "uk", "en"]

    private static func bundle(for language: String) -> Bundle {
        KeyboardPreferences.localizationBundle(for: language)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Self.languages, id: \.self) { language in
                Text(LocalizedStringKey(key), tableName: table, bundle: Self.bundle(for: language))
                    .font(font)
                    .fixedSize(horizontal: false, vertical: true)
                    .hidden()
                    .accessibilityHidden(true)
            }
            Text(LocalizedStringKey(key), tableName: table, bundle: KeyboardPreferences.interfaceBundle)
                .font(font)
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

/// Top-down symmetrical two-hemisphere walnut-style brain vector icon with cortical folds.
private struct WalnutBrainIcon: View {
    let color: Color
    var size: CGFloat = 16

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let strokeWidth = max(w * 0.095, 1.15)
            let style = StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)

            // Left hemisphere outer walnut lobe (scalloped top-down silhouette)
            var leftLobe = Path()
            leftLobe.move(to: CGPoint(x: w * 0.46, y: h * 0.14))
            leftLobe.addCurve(
                to: CGPoint(x: w * 0.12, y: h * 0.36),
                control1: CGPoint(x: w * 0.28, y: h * 0.05),
                control2: CGPoint(x: w * 0.12, y: h * 0.19)
            )
            leftLobe.addCurve(
                to: CGPoint(x: w * 0.11, y: h * 0.66),
                control1: CGPoint(x: w * 0.05, y: h * 0.44),
                control2: CGPoint(x: w * 0.05, y: h * 0.58)
            )
            leftLobe.addCurve(
                to: CGPoint(x: w * 0.46, y: h * 0.88),
                control1: CGPoint(x: w * 0.13, y: h * 0.84),
                control2: CGPoint(x: w * 0.30, y: h * 0.94)
            )
            leftLobe.closeSubpath()

            // Right hemisphere outer walnut lobe (mirrored top-down silhouette)
            var rightLobe = Path()
            rightLobe.move(to: CGPoint(x: w * 0.54, y: h * 0.14))
            rightLobe.addCurve(
                to: CGPoint(x: w * 0.88, y: h * 0.36),
                control1: CGPoint(x: w * 0.72, y: h * 0.05),
                control2: CGPoint(x: w * 0.88, y: h * 0.19)
            )
            rightLobe.addCurve(
                to: CGPoint(x: w * 0.89, y: h * 0.66),
                control1: CGPoint(x: w * 0.95, y: h * 0.44),
                control2: CGPoint(x: w * 0.95, y: h * 0.58)
            )
            rightLobe.addCurve(
                to: CGPoint(x: w * 0.54, y: h * 0.88),
                control1: CGPoint(x: w * 0.87, y: h * 0.84),
                control2: CGPoint(x: w * 0.70, y: h * 0.94)
            )
            rightLobe.closeSubpath()

            context.stroke(leftLobe, with: .color(color), style: style)
            context.stroke(rightLobe, with: .color(color), style: style)

            // Walnut gyri/sulci inner folds
            var folds = Path()
            // Left upper sulcus
            folds.move(to: CGPoint(x: w * 0.44, y: h * 0.33))
            folds.addQuadCurve(to: CGPoint(x: w * 0.21, y: h * 0.39), control: CGPoint(x: w * 0.30, y: h * 0.26))
            // Left middle sulcus
            folds.move(to: CGPoint(x: w * 0.16, y: h * 0.53))
            folds.addQuadCurve(to: CGPoint(x: w * 0.43, y: h * 0.54), control: CGPoint(x: w * 0.30, y: h * 0.46))
            // Left lower sulcus
            folds.move(to: CGPoint(x: w * 0.44, y: h * 0.71))
            folds.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.69), control: CGPoint(x: w * 0.31, y: h * 0.77))

            // Right upper sulcus
            folds.move(to: CGPoint(x: w * 0.56, y: h * 0.33))
            folds.addQuadCurve(to: CGPoint(x: w * 0.79, y: h * 0.39), control: CGPoint(x: w * 0.70, y: h * 0.26))
            // Right middle sulcus
            folds.move(to: CGPoint(x: w * 0.84, y: h * 0.53))
            folds.addQuadCurve(to: CGPoint(x: w * 0.57, y: h * 0.54), control: CGPoint(x: w * 0.70, y: h * 0.46))
            // Right lower sulcus
            folds.move(to: CGPoint(x: w * 0.56, y: h * 0.71))
            folds.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.69), control: CGPoint(x: w * 0.69, y: h * 0.77))

            let innerStyle = StrokeStyle(lineWidth: max(strokeWidth * 0.85, 1.0), lineCap: .round, lineJoin: .round)
            context.stroke(folds, with: .color(color), style: innerStyle)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()
    NavigationStack(path: $navigationPath) {
        HomeView(navigationPath: $navigationPath)
    }
}

/// A UIKit-backed UITextView that dynamically updates its keyboardType, returnKeyType,
/// textContentType, and keyboardAppearance, reloading the responder input traits immediately
/// when the user switches sandbox modes.
private struct SandboxTextView: UIViewRepresentable {
    @Binding var text: String
    let currentText: String
    @Binding var isFocused: Bool
    @Binding var canUndo: Bool
    @Binding var canRedo: Bool
    @Binding var liveWPM: Int
    @Binding var liveCPM: Int
    let autoFocusOnAppear: Bool
    let placeholder: String
    let fieldMode: KeyboardTestFieldMode
    let themeMode: KeyboardTestThemeMode
    let preferencesToken: String
    let fontSize: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        textView.accessibilityIdentifier = "sandbox.input"
        textView.backgroundColor = .clear
        textView.font = InterfaceFont.uiFont("GeneralSans-Regular", size: fontSize, text: currentText)
        textView.textColor = .label
        textView.text = currentText
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .no
        if UIDevice.current.userInterfaceIdiom != .pad {
            textView.inputAssistantItem.leadingBarButtonGroups = []
            textView.inputAssistantItem.trailingBarButtonGroups = []
        }

        applyTraits(to: textView, coordinator: context.coordinator)

        if autoFocusOnAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                if textView.window != nil && !textView.isFirstResponder {
                    textView.becomeFirstResponder()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                if textView.window != nil && !textView.isFirstResponder {
                    textView.becomeFirstResponder()
                }
            }
        }
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.textView = uiView
        uiView.textColor = .label
        if currentText != context.coordinator.lastSyncedText || uiView.text != currentText {
            let delta = currentText.count - uiView.text.count
            context.coordinator.lastSyncedText = currentText
            if uiView.text != currentText {
                uiView.text = currentText
            }
            if currentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                context.coordinator.resetSpeedState()
            } else if delta > 0 && delta <= 2 && !KeyboardUsageStats.wasRecentlyInjected() {
                context.coordinator.recordTypedCharacters(delta)
            }
            if uiView.isFirstResponder {
                uiView.scrollRangeToVisible(uiView.selectedRange)
            }
            context.coordinator.refreshUndoRedoState(for: uiView)
        }
        let targetFont = InterfaceFont.uiFont("GeneralSans-Regular", size: fontSize, text: currentText)
        if uiView.font?.fontName != targetFont.fontName || uiView.font?.pointSize != targetFont.pointSize {
            uiView.font = targetFont
        }
        context.coordinator.updateInlineMathPreview(for: uiView)

        let fieldOrThemeChanged = context.coordinator.lastFieldMode != fieldMode ||
                                  context.coordinator.lastThemeMode != themeMode
        let prefsChanged = context.coordinator.lastPreferencesToken != preferencesToken

        if fieldOrThemeChanged || prefsChanged {
            applyTraits(to: uiView, coordinator: context.coordinator)
            if uiView.isFirstResponder {
                UIView.performWithoutAnimation {
                    uiView.reloadInputViews()
                }
            } else if fieldOrThemeChanged && autoFocusOnAppear && uiView.window != nil && UIApplication.shared.applicationState == .active {
                DispatchQueue.main.async {
                    uiView.becomeFirstResponder()
                }
            }
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("crh.key.sandboxTraitsChanged" as CFString),
                nil,
                nil,
                true
            )
        }
    }

    private func applyTraits(to textView: UITextView, coordinator: Coordinator) {
        coordinator.lastFieldMode = fieldMode
        coordinator.lastThemeMode = themeMode
        coordinator.lastPreferencesToken = preferencesToken

        let isActiveSandbox = UIApplication.shared.applicationState == .active &&
            (textView.isFirstResponder || isFocused || autoFocusOnAppear)
        if isActiveSandbox {
            let defaults = KeyboardPreferences.defaults
            defaults.set(themeMode.isDark, forKey: "crh.key.test.isDark")
            defaults.set(fieldMode.rawValue, forKey: "crh.key.test.fieldMode")
            defaults.set(true, forKey: "crh.key.test.sandboxFocused")
            defaults.set(Date().timeIntervalSince1970, forKey: "crh.key.test.overrideTimestamp")
            defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        }

        let isStructuredField = (fieldMode == .email || fieldMode == .url || fieldMode == .numbers)
        textView.autocapitalizationType = isStructuredField ? .none : .sentences
        textView.autocorrectionType = isStructuredField ? .no : .yes
        textView.keyboardType = fieldMode.keyboardType
        textView.returnKeyType = fieldMode.returnKeyType
        textView.textContentType = fieldMode.textContentType
        textView.keyboardAppearance = themeMode.keyboardAppearance
        textView.enablesReturnKeyAutomatically = (fieldMode != .standard)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SandboxTextView
        weak var textView: UITextView?
        var lastFieldMode: KeyboardTestFieldMode?
        var lastThemeMode: KeyboardTestThemeMode?
        var lastPreferencesToken: String?
        var lastSyncedText: String
        var isReloadingTraits = false
        private var observers: [NSObjectProtocol] = []
        private var keystrokeTimestamps: [CFTimeInterval] = []
        private lazy var inlineMathPreviewLabel: UILabel = {
            let label = UILabel()
            label.accessibilityIdentifier = "sandbox.inlineMathPreview"
            label.textColor = .placeholderText
            label.backgroundColor = .clear
            label.isUserInteractionEnabled = false
            label.isHidden = true
            return label
        }()

        func updateInlineMathPreview(for textView: UITextView) {
            if inlineMathPreviewLabel.superview !== textView {
                textView.addSubview(inlineMathPreviewLabel)
            }
            guard SystemKeyboardSettings.isShowMathResultsEnabled,
                  KeyboardPreferences.suggestionsEnabled else {
                inlineMathPreviewLabel.isHidden = true
                return
            }
            if #available(iOS 18.0, *), textView.mathExpressionCompletionType == .no {
                inlineMathPreviewLabel.isHidden = true
                return
            }
            let fullText = (textView.text ?? "") as NSString
            let selRange = textView.selectedRange
            let cursorLocation = min(max(selRange.location, 0), fullText.length)
            let beforeCursor = fullText.substring(to: cursorLocation)
            let afterCursor = fullText.substring(from: cursorLocation)
            let trimmedAfter = afterCursor.trimmingCharacters(in: .whitespacesAndNewlines)
            guard selRange.length == 0,
                  trimmedAfter.isEmpty || afterCursor.hasPrefix("\n"),
                  let mathResult = MathExpressionEvaluator.evaluateTrailingExpression(in: beforeCursor),
                  let selectedTextRange = textView.selectedTextRange else {
                inlineMathPreviewLabel.isHidden = true
                return
            }
            let caretRect = textView.caretRect(for: selectedTextRange.end)
            guard caretRect.height > 0 && !caretRect.origin.x.isInfinite && !caretRect.origin.y.isInfinite else {
                inlineMathPreviewLabel.isHidden = true
                return
            }
            inlineMathPreviewLabel.font = textView.font ?? UIFont.systemFont(ofSize: parent.fontSize)
            inlineMathPreviewLabel.textColor = .placeholderText
            inlineMathPreviewLabel.text = mathResult
            inlineMathPreviewLabel.sizeToFit()
            let labelSize = inlineMathPreviewLabel.bounds.size
            inlineMathPreviewLabel.frame = CGRect(
                x: caretRect.maxX + 1.5,
                y: caretRect.midY - labelSize.height / 2.0,
                width: labelSize.width,
                height: labelSize.height
            )
            inlineMathPreviewLabel.isHidden = false
        }

        init(_ parent: SandboxTextView) {
            self.parent = parent
            self.lastSyncedText = parent.currentText
            super.init()
            let nc = NotificationCenter.default
            observers.append(nc.addObserver(
                forName: Notification.Name("crh.key.clearSandboxText"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, let tv = self.textView else { return }
                let oldText = tv.text ?? ""
                if !oldText.isEmpty {
                    tv.undoManager?.registerUndo(withTarget: tv) { target in
                        target.text = oldText
                        target.delegate?.textViewDidChange?(target)
                    }
                }
                self.lastSyncedText = ""
                tv.text = ""
                self.parent.text = ""
                self.resetSpeedState()
                self.refreshUndoRedoState(for: tv)
                self.updateInlineMathPreview(for: tv)
            })
            observers.append(nc.addObserver(
                forName: Notification.Name("crh.key.sandboxUndo"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, let tv = self.textView else { return }
                if tv.undoManager?.canUndo == true {
                    tv.undoManager?.undo()
                    self.lastSyncedText = tv.text
                    self.parent.text = tv.text
                    if (tv.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.resetSpeedState()
                    }
                    self.refreshUndoRedoState(for: tv)
                    self.updateInlineMathPreview(for: tv)
                }
            })
            observers.append(nc.addObserver(
                forName: Notification.Name("crh.key.sandboxRedo"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, let tv = self.textView else { return }
                if tv.undoManager?.canRedo == true {
                    tv.undoManager?.redo()
                    self.lastSyncedText = tv.text
                    self.parent.text = tv.text
                    if (tv.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.resetSpeedState()
                    }
                    self.refreshUndoRedoState(for: tv)
                    self.updateInlineMathPreview(for: tv)
                }
            })
            observers.append(nc.addObserver(
                forName: Notification.Name("crh.key.sandboxPaste"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, let tv = self.textView else { return }
                if let clip = UIPasteboard.general.string, !clip.isEmpty {
                    let oldText = tv.text ?? ""
                    tv.undoManager?.registerUndo(withTarget: tv) { target in
                        target.text = oldText
                        target.delegate?.textViewDidChange?(target)
                    }
                    KeyboardUsageStats.markInjectedText(clip)
                    tv.insertText(clip)
                    self.lastSyncedText = tv.text
                    self.parent.text = tv.text
                    self.refreshUndoRedoState(for: tv)
                    self.updateInlineMathPreview(for: tv)
                }
            })
        }

        deinit {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func resetSpeedState() {
            keystrokeTimestamps.removeAll()
            if parent.liveWPM != 0 { parent.liveWPM = 0 }
            if parent.liveCPM != 0 { parent.liveCPM = 0 }
        }

        func refreshUndoRedoState(for textView: UITextView) {
            let canU = textView.undoManager?.canUndo ?? false
            let canR = textView.undoManager?.canRedo ?? false
            if parent.canUndo != canU { parent.canUndo = canU }
            if parent.canRedo != canR { parent.canRedo = canR }
        }

        func recordTypedCharacters(_ count: Int) {
            guard KeyboardPreferences.statsEnabled, count > 0 else { return }
            let now = CACurrentMediaTime()
            // Record 1 physical keystroke timestamp per tap (even for 2-character Cyrillic digraphs like къ/гъ/нъ/дж)
            keystrokeTimestamps.append(now)
            keystrokeTimestamps.removeAll { now - $0 > 12.0 }
            guard keystrokeTimestamps.count >= 2, let first = keystrokeTimestamps.first else { return }
            let span = max(now - first, 1.2)
            let cpm = min(Int((Double(keystrokeTimestamps.count) / span * 60.0).rounded()), 750)
            let hasCompletedWord: Bool = {
                let s = lastSyncedText.drop(while: { $0.isWhitespace || $0.isPunctuation })
                return s.contains(where: { $0.isWhitespace || $0.isPunctuation })
            }()
            let wpm: Int
            if hasCompletedWord || (keystrokeTimestamps.count >= 8 && (now - first) >= 2.0) {
                wpm = max(1, Int((Double(cpm) / KeyboardUsageStats.crhCharsPerWord).rounded()))
            } else {
                wpm = 0
            }
            if parent.liveCPM != cpm { parent.liveCPM = cpm }
            if parent.liveWPM != wpm { parent.liveWPM = wpm }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !isReloadingTraits {
                if parent.isFocused {
                    if UIApplication.shared.applicationState == .active {
                        let defaults = KeyboardPreferences.defaults
                        defaults.set(parent.themeMode.isDark, forKey: "crh.key.test.isDark")
                        defaults.set(parent.fieldMode.rawValue, forKey: "crh.key.test.fieldMode")
                        defaults.set(true, forKey: "crh.key.test.sandboxFocused")
                        defaults.set(Date().timeIntervalSince1970, forKey: "crh.key.test.overrideTimestamp")
                        defaults.synchronize()
                        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                    }
                } else {
                    parent.isFocused = true
                }
            }
            refreshUndoRedoState(for: textView)
            updateInlineMathPreview(for: textView)
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard !isReloadingTraits else { return }
            let defaults = KeyboardPreferences.defaults
            defaults.removeObject(forKey: "crh.key.test.isDark")
            defaults.removeObject(forKey: "crh.key.test.fieldMode")
            defaults.removeObject(forKey: "crh.key.test.overrideTimestamp")
            defaults.set(false, forKey: "crh.key.test.sandboxFocused")
            defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("crh.key.sandboxTraitsChanged" as CFString),
                nil,
                nil,
                true
            )
            if parent.isFocused {
                parent.isFocused = false
            }
            refreshUndoRedoState(for: textView)
            inlineMathPreviewLabel.isHidden = true
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            updateInlineMathPreview(for: textView)
        }

        func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text ?? ""
            let oldText = lastSyncedText
            let delta = newText.count - oldText.count
            if !newText.isEmpty && oldText != newText && !(textView.undoManager?.isUndoing ?? false) && !(textView.undoManager?.isRedoing ?? false) {
                textView.undoManager?.registerUndo(withTarget: textView) { target in
                    target.text = oldText
                    target.delegate?.textViewDidChange?(target)
                }
            }
            lastSyncedText = newText
            parent.text = newText
            if newText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                resetSpeedState()
            } else if delta > 0 && delta <= 2 && !KeyboardUsageStats.wasRecentlyInjected() {
                recordTypedCharacters(delta)
            }
            textView.scrollRangeToVisible(textView.selectedRange)
            refreshUndoRedoState(for: textView)
            updateInlineMathPreview(for: textView)
        }
    }
}

