//
//  HomeView.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import Combine
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
        case .search: return "Q"
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
    @AppStorage(KeyboardPreferences.oneHandedModeKey, store: KeyboardPreferences.defaults) private var oneHandedMode = "off"

    @AppStorage(KeyboardUsageStats.totalWordsKey, store: KeyboardPreferences.defaults) private var totalWords = 0
    @AppStorage(KeyboardUsageStats.manualWordsKey, store: KeyboardPreferences.defaults) private var manualWords = 0
    @AppStorage(KeyboardUsageStats.suggestedWordsKey, store: KeyboardPreferences.defaults) private var suggestedWords = 0
    @AppStorage(KeyboardUsageStats.suggestedCharsKey, store: KeyboardPreferences.defaults) private var suggestedCharacters = 0
    @AppStorage(KeyboardUsageStats.totalCharsKey, store: KeyboardPreferences.defaults) private var totalCharacters = 0
    @AppStorage(KeyboardUsageStats.learnedWordsKey, store: KeyboardPreferences.defaults) private var learnedWordsCount = 0
    @AppStorage(KeyboardUsageStats.uniqueWordsKey, store: KeyboardPreferences.defaults) private var uniqueWordsCount = 0
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
    @State private var showLearnedWordsSheet = false
    @State private var learnedWordsEntries: [(word: String, freq: Int, lastUsed: Int64)] = []
    @State private var latinBadgeTrigger = 0
    @State private var cyrillicBadgeTrigger = 0
    @State private var ukrainianBadgeTrigger = 0
    @State private var isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

    @State private var selectedFieldMode: KeyboardTestFieldMode = {
        if let value = UserDefaults.standard.string(forKey: "qt_field"),
           let mode = KeyboardTestFieldMode(rawValue: "field.\(value)") {
            return mode
        }
        return .standard
    }()
    @State private var selectedThemeMode: KeyboardTestThemeMode = {
        if ProcessInfo.processInfo.arguments.contains("-qt_theme"),
           let value = UserDefaults.standard.string(forKey: "qt_theme") {
            return value.lowercased().contains("dark") ? .dark : .ios26White
        }
        return UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .ios26White
    }()
    @State private var hasManualThemeOverride: Bool = (ProcessInfo.processInfo.arguments.contains("-qt_theme") && UserDefaults.standard.string(forKey: "qt_theme") != nil)

    private struct OnboardingSheetRequest: Identifiable, Equatable {
        let mode: OnboardingView.Mode
        let initialPage: String
        var id: String { "\(mode.rawValue)-\(initialPage)" }
    }

    @StateObject private var keyboardState = KeyboardStateContext(bundleId: AppConfiguration.keyboardBundleIdPattern)

    @AppStorage("crh.key.primaryExtensionSeen", store: KeyboardPreferences.defaults) private var primaryExtensionSeen = false
    @AppStorage("crh.key.cyrillicExtensionSeen", store: KeyboardPreferences.defaults) private var cyrillicExtensionSeen = false
    @AppStorage("crh.key.ukrainianExtensionSeen", store: KeyboardPreferences.defaults) private var ukrainianExtensionSeen = false
    @AppStorage("crh.key.lastRenderedPrimaryAdded", store: KeyboardPreferences.defaults) private var lastRenderedPrimaryAdded = false
    @AppStorage("crh.key.lastRenderedCyrillicAdded", store: KeyboardPreferences.defaults) private var lastRenderedCyrillicAdded = false
    @AppStorage("crh.key.lastRenderedUkrainianAdded", store: KeyboardPreferences.defaults) private var lastRenderedUkrainianAdded = false
    @State private var didCheckColdLaunchExtensionDiff = false
    @State private var activeOnboardingSheet: OnboardingSheetRequest?
    @State private var pendingCyrillicRemovalCheck = false
    @State private var didEnterBackgroundForCyrillicCheck = false
    @State private var showCyrillicGuideAlert = false
    @State private var isTestingExpanded: Bool = !ProcessInfo.processInfo.arguments.contains("-qt_expand_stats")
    @State private var shouldAutoFocusSandbox: Bool = {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-qt_no_autofocus") || args.contains("-qt_expand_stats") || args.contains("-qt_open_learned_words") || args.contains("-qt_open_about") {
            return false
        }
        if args.contains("-qt_demo_stats")
            && !args.contains("-qt_reset_text")
            && !args.contains("-qt_field")
            && !args.contains("-qt_focus_sandbox_live")
            && !args.contains("-qt_demo_dark") {
            return false
        }
        return args.contains("-qt_reset_text") || args.contains("-qt_field") || args.contains("-qt_theme") || args.contains("-qt_focus_sandbox_live") || args.contains("-qt_demo_dark")
    }()
    @State private var isKeyboardVisible = false
    @State private var cyrillicStatus = CyrillicStatus.unknown
    @State private var ukrainianStatus = CyrillicStatus.unknown
    @State private var didManuallyDisableCyrillicOnIPad = false
    @State private var didManuallyDisableUkrainianOnIPad = false
    @State private var didEnableBothCyrillicOnIPad = false
    @State private var didSelectAbvLayoutOnIPad = false
    @State private var cachedIsFullAccessEnabled = false
    @State private var cachedIsRtl = false
    @State private var viewportSize = CGSize.zero
    @State private var containerSize = CGSize.zero
    @State private var isWritingFieldFocused = false
    @State private var isSandboxCrimeanTatarKeyboardActive: Bool = !ProcessInfo.processInfo.arguments.contains("-qt_wrong_keyboard")
    @State private var didInitializeThemeFromSystem = false
    @State private var lastKnownSettingsSnapshot: [String: Bool] = [:]
    @State private var settingsSyncRevision: Int = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum CyrillicStatus { case enabled, missing, unknown }

    private var animationsAllowed: Bool {
        !reduceMotion && !isLowPowerMode && !Self.isUITestingEnvironment
    }

    private var shouldShowStartOverlay: Bool {
        false
    }

    var body: some View {
        let _ = language // Observe interface language changes immediately
        let _ = settingsSyncRevision // Observe external Settings.bundle / App Group preference updates
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            ScrollViewReader { scroll in
                let effectiveContainerSize = containerSize.width > 0 ? containerSize : viewportSize
                let isLandscapeCompactHeight = viewportSize.width > viewportSize.height &&
                    effectiveContainerSize.height > 0 &&
                    effectiveContainerSize.height < 420
                ScrollView(.vertical, showsIndicators: false) {
                    let twoColumns = Self.usesTwoColumns(viewportSize, containerSize: effectiveContainerSize)
                    let itemSpacing: CGFloat = Device.iPad ? 12 : 10
                    let layout = twoColumns
                        ? AnyLayout(HomeTwoColumnLayout(spacing: 16))
                        : AnyLayout(VStackLayout(spacing: itemSpacing))
                    layout {
                        // Child 0: Status indicators (only shown when Full Access is disabled)
                        if !areAllIndicatorsEnabled {
                            AnyView(statusIndicatorsSection)
                                .id("statusIndicators")
                        }

                        // Child 1: Try Keyboard + Writing Area at the very top
                        AnyView(testingAndWritingSection)

                        // Child 2: Basic Statistics (expandable) + 3 Settings Blocks (Main Settings, Standard Layout, Cyrillic Layouts)
                        VStack(alignment: .leading, spacing: itemSpacing) {
                            AnyView(statisticsAndAchievementsSection)
                                .id("statsSection")
                            AnyView(keyboardSettingsSection)
                            AnyView(standardLayoutSection)
                            AnyView(cyrillicLayoutsSection)
                        }
                    }
                    // iPad: single column (portrait / split view) stays at a readable width; very wide
                    // two-column windows (13" iPad, Stage Manager) are capped and centered.
                    .frame(maxWidth: Device.iPad ? (twoColumns ? 1180 : 680) : .infinity)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, (Device.iPhone || (viewportSize.width > 0 && viewportSize.width < 520)) ? 12 : 24)
                    .padding(.top, Device.iPhone ? 8 : 14)
                    .padding(.bottom, shouldShowStartOverlay ? 76 : (isKeyboardVisible ? 24 : (Device.iPhone ? 16 : 24)))
                }
                .background {
                    scrollPositionObserversView(scroll: scroll, isLandscapeCompactHeight: isLandscapeCompactHeight, effectiveContainerSize: effectiveContainerSize)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { containerSize = geometry.size }
                        .onChange(of: geometry.size) { _, size in containerSize = size }
                }
            }
            .animation(animationsAllowed ? .easeInOut(duration: 0.22) : nil, value: language)
            .animation(animationsAllowed ? .easeInOut(duration: 0.22) : nil, value: cyrillicEnabled)
            .animation(animationsAllowed ? .easeInOut(duration: 0.22) : nil, value: statsEnabled)
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
            homeLifecycleObserversView
            homePreferencesObserversView
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
        .animation(animationsAllowed ? .easeInOut(duration: 0.25) : nil, value: shouldShowStartOverlay)
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
                let effectiveDark = hasManualThemeOverride ? selectedThemeMode.isDark : (colorScheme == .dark)
                HStack(spacing: 8) {
                    TaraqTamgaLogoBadge(
                        size: 28,
                        cornerRadius: 7,
                        isDarkOverride: hasManualThemeOverride ? selectedThemeMode.isDark : nil
                    )
                    .shadow(color: .black.opacity(effectiveDark ? 0.28 : 0.06), radius: 3, x: 0, y: 1)
                    Text("QırımKey")
                        .font(InterfaceFont.brandFont("GeneralSans-Semibold", size: Device.iPad ? 22 : 19))
                        .foregroundStyle(effectiveDark ? Color.white : Color.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .animation(animationsAllowed ? .easeInOut(duration: 0.2) : nil, value: effectiveDark)
            }
        }
        .preferredColorScheme(hasManualThemeOverride ? (selectedThemeMode == .dark ? .dark : .light) : nil)
        .sheet(item: $activeOnboardingSheet, onDismiss: {
            refreshCyrillicStatus()
        }) { request in
            NavigationStack {
                OnboardingView(mode: request.mode, initialPage: request.initialPage)
            }
            .presentationCornerRadius(20)
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert(localizedInterfaceString("settings.cyrillicGuideTitle"), isPresented: $showCyrillicGuideAlert) {
            Button(localizedInterfaceString("settings.cyrillicAddAction")) {
                Self.openKeyboardSettings()
            }
            Button(Home.home_start_key.localized) {
                activeOnboardingSheet = OnboardingSheetRequest(mode: .add, initialPage: "Onboard1")
            }
            Button(localizedInterfaceString("stats.resetCancel"), role: .cancel) {}
        } message: {
            if #available(iOS 26.0, *) {
                Text(localizedInterfaceString("settings.enableBothKeyboards"))
            } else {
                Text(localizedInterfaceString("settings.missingCyrillic"))
            }
        }
    }

    @ViewBuilder
    private func scrollPositionObserversView(scroll: ScrollViewProxy, isLandscapeCompactHeight: Bool, effectiveContainerSize: CGSize) -> some View {
        Color.clear
            .onChange(of: isStatsExpanded) { _, expanded in
                if expanded {
                    refreshStatsFromAppGroup(syncSQLite: true)
                    withAnimation(animationsAllowed ? .easeInOut(duration: 0.25) : nil) {
                        scroll.scrollTo("statsSection", anchor: .top)
                    }
                }
            }
            .onChange(of: isLandscapeCompactHeight) { _, isCompactHeight in
                if isCompactHeight {
                    if isWritingFieldFocused {
                        scroll.scrollTo("testingSandbox", anchor: .top)
                    } else if !areAllIndicatorsEnabled && Self.usesTwoColumns(viewportSize, containerSize: effectiveContainerSize) {
                        scroll.scrollTo("statusIndicators", anchor: .top)
                    }
                }
            }
            .onChange(of: isWritingFieldFocused) { _, focused in
                syncSandboxFocusToAppGroup(focused)
                refreshCyrillicStatus()
                if focused && isLandscapeCompactHeight {
                    scroll.scrollTo("testingSandbox", anchor: .top)
                }
            }
            .onChange(of: isKeyboardVisible) { _, _ in
                refreshCyrillicStatus()
            }
            .onChange(of: isSandboxCrimeanTatarKeyboardActive) { _, _ in
                refreshCyrillicStatus()
            }
            .onChange(of: text) { _, _ in
                if statsEnabled {
                    refreshStatsFromAppGroup(syncSQLite: false, synchronizePreferences: false)
                }
                if isWritingFieldFocused && isLandscapeCompactHeight {
                    scroll.scrollTo("testingSandbox", anchor: .top)
                }
            }
            .onChange(of: isTestingExpanded) { _, expanded in
                if expanded {
                    shouldAutoFocusSandbox = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        withAnimation(animationsAllowed ? .easeInOut(duration: 0.25) : nil) {
                            scroll.scrollTo("testingSection", anchor: .top)
                        }
                    }
                } else {
                    shouldAutoFocusSandbox = false
                    clearThemeOverride()
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            }
    }

    @ViewBuilder
    private var homeLifecycleObserversView: some View {
        Color.clear
            .onAppear {
                Self.canAnimateUserChanges = false
                isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                Self.registerStatsSyncObserverIfNeeded()
                Self.enforceFullScreenWindowIfNeeded()
                if !didInitializeThemeFromSystem {
                    didInitializeThemeFromSystem = true
                    if !ProcessInfo.processInfo.arguments.contains("-qt_theme") {
                        selectedThemeMode = .mode(isDark: UIScreen.main.traitCollection.userInterfaceStyle == .dark)
                    }
                }
                applyLaunchArguments()
                syncPreferencesFromSettingsBundleAndAppGroup()
                if UIApplication.shared.applicationState == .active && (isWritingFieldFocused || shouldAutoFocusSandbox || hasManualThemeOverride) {
                    syncThemeToAppGroup(selectedThemeMode)
                } else {
                    clearThemeOverride()
                }
                refreshCyrillicStatus()
                keyboardState.refresh()
                refreshStatsFromAppGroup(syncSQLite: true, synchronizePreferences: true)
                AppStoreReviewManager.recordForegroundSession()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    Self.canAnimateUserChanges = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UITextInputMode.currentInputModeDidChangeNotification)) { _ in
                refreshCyrillicStatus()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
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
            .onReceive(NotificationCenter.default.publisher(for: Self.localOneHandedRefreshNotification)) { _ in
                CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                KeyboardPreferences.refreshCachedPreferences()
                let updated = KeyboardPreferences.oneHandedMode
                if oneHandedMode != updated {
                    oneHandedMode = updated
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                syncPreferencesFromSettingsBundleAndAppGroup()
                refreshCyrillicStatus()
                keyboardState.refresh()
                refreshStatsFromAppGroup(syncSQLite: true, synchronizePreferences: true)
                AppStoreReviewManager.recordForegroundSession()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                syncPreferencesFromSettingsBundleAndAppGroup()
                refreshCyrillicStatus()
                keyboardState.refresh()
                refreshStatsFromAppGroup(syncSQLite: true, synchronizePreferences: true)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                shouldAutoFocusSandbox = false
                clearThemeOverride()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                if pendingCyrillicRemovalCheck {
                    didEnterBackgroundForCyrillicCheck = true
                }
                didManuallyDisableCyrillicOnIPad = false
                didManuallyDisableUkrainianOnIPad = false
                shouldAutoFocusSandbox = false
                clearThemeOverride()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                withAnimation(animationsAllowed ? .easeInOut(duration: 0.25) : nil) {
                    isKeyboardVisible = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                withAnimation(animationsAllowed ? .easeInOut(duration: 0.25) : nil) {
                    isKeyboardVisible = false
                }
            }
            .onDisappear {
                shouldAutoFocusSandbox = false
                clearThemeOverride()
            }
    }

    @ViewBuilder
    private var homePreferencesObserversView: some View {
        Color.clear
            .onChange(of: colorScheme) { _, newScheme in
                let args = ProcessInfo.processInfo.arguments
                if !args.contains("-qt_theme") && !hasManualThemeOverride {
                    selectedThemeMode = .mode(isDark: newScheme == .dark)
                    if UIApplication.shared.applicationState == .active && (isWritingFieldFocused || shouldAutoFocusSandbox) {
                        syncThemeToAppGroup(selectedThemeMode)
                    } else {
                        clearThemeOverride()
                    }
                }
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
                lastKnownSettingsSnapshot[KeyboardPreferences.cyrillicKey] = newValue
                KeyboardPreferences.defaults.set(newValue, forKey: KeyboardPreferences.cyrillicKey)
                KeyboardPreferences.defaults.set(newValue, forKey: "crh.key.lastSynced.\(KeyboardPreferences.cyrillicKey)")
                UserDefaults.standard.set(newValue, forKey: KeyboardPreferences.cyrillicKey)
                KeyboardPreferences.defaults.synchronize()
                UserDefaults.standard.synchronize()
                CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                KeyboardPreferences.refreshCachedPreferences()
                notifySandboxTraitsChanged()
            }
            .onChange(of: ukrainianCyrillicLayout) { _, newValue in
                lastKnownSettingsSnapshot[KeyboardPreferences.ukrainianCyrillicLayoutKey] = newValue
                KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(newValue)
                KeyboardPreferences.defaults.set(newValue, forKey: "crh.key.lastSynced.\(KeyboardPreferences.ukrainianCyrillicLayoutKey)")
                UserDefaults.standard.set(newValue, forKey: KeyboardPreferences.ukrainianCyrillicLayoutKey)
                KeyboardPreferences.defaults.synchronize()
                UserDefaults.standard.synchronize()
                CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                KeyboardPreferences.refreshCachedPreferences()
                notifySandboxTraitsChanged()
            }
            .onChange(of: suggestionsEnabled) { _, newValue in
                lastKnownSettingsSnapshot[KeyboardPreferences.suggestionsKey] = newValue
                KeyboardPreferences.defaults.set(newValue, forKey: KeyboardPreferences.suggestionsKey)
                KeyboardPreferences.defaults.set(newValue, forKey: "crh.key.lastSynced.\(KeyboardPreferences.suggestionsKey)")
                UserDefaults.standard.set(newValue, forKey: KeyboardPreferences.suggestionsKey)
                KeyboardPreferences.defaults.synchronize()
                UserDefaults.standard.synchronize()
                CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                KeyboardPreferences.refreshCachedPreferences()
                notifySandboxTraitsChanged()
            }
            .onChange(of: wordLearningEnabled) { _, newValue in
                lastKnownSettingsSnapshot[KeyboardPreferences.wordLearningKey] = newValue
                KeyboardPreferences.setWordLearningEnabled(newValue)
                KeyboardPreferences.defaults.set(newValue, forKey: "crh.key.lastSynced.\(KeyboardPreferences.wordLearningKey)")
                UserDefaults.standard.set(newValue, forKey: KeyboardPreferences.wordLearningKey)
                KeyboardPreferences.defaults.synchronize()
                UserDefaults.standard.synchronize()
                CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                KeyboardPreferences.refreshCachedPreferences()
                notifySandboxTraitsChanged()
            }
            .onChange(of: statsEnabled) { _, newValue in
                lastKnownSettingsSnapshot[KeyboardPreferences.statsEnabledKey] = newValue
                KeyboardPreferences.setStatsEnabled(newValue)
                KeyboardPreferences.defaults.set(newValue, forKey: "crh.key.lastSynced.\(KeyboardPreferences.statsEnabledKey)")
                UserDefaults.standard.set(newValue, forKey: KeyboardPreferences.statsEnabledKey)
                KeyboardPreferences.defaults.synchronize()
                UserDefaults.standard.synchronize()
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
                    isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                    Self.enforceFullScreenWindowIfNeeded()
                    syncPreferencesFromSettingsBundleAndAppGroup()
                    if isWritingFieldFocused || shouldAutoFocusSandbox || hasManualThemeOverride {
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
                    if pendingCyrillicRemovalCheck {
                        didEnterBackgroundForCyrillicCheck = true
                    }
                    didManuallyDisableCyrillicOnIPad = false
                    didManuallyDisableUkrainianOnIPad = false
                    shouldAutoFocusSandbox = false
                    clearThemeOverride()
                }
            }
    }

    private static let localStatsRefreshNotification = Notification.Name("crh.key.localStatsRefresh")
    private static let localOneHandedRefreshNotification = Notification.Name("crh.key.localOneHandedRefresh")
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
        CFNotificationCenterAddObserver(
            center,
            nil,
            { _, _, _, _, _ in
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: HomeView.localOneHandedRefreshNotification, object: nil)
                }
            },
            KeyboardPreferences.oneHandedModeChangedNotification as CFString,
            nil,
            .deliverImmediately
        )
    }

    private func syncPreferencesFromSettingsBundleAndAppGroup() {
        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
        let groupDefaults = KeyboardPreferences.defaults
        let stdDefaults = UserDefaults.standard
        var didReconcileChange = false

        func reconcileBool(key: String, defaultValue: Bool) -> Bool {
            let lastSyncedKey = "crh.key.lastSynced.\(key)"
            let groupObj = groupDefaults.object(forKey: key) as? Bool
            let stdObj = stdDefaults.object(forKey: key) as? Bool
            let previousKnown = lastKnownSettingsSnapshot[key] ?? (groupDefaults.object(forKey: lastSyncedKey) as? Bool)
            let resolved: Bool
            if let g = groupObj, let s = stdObj, g != s {
                if let prev = previousKnown {
                    if s != prev && g == prev {
                        resolved = s
                    } else if g != prev && s == prev {
                        resolved = g
                    } else {
                        resolved = g
                    }
                } else {
                    resolved = g
                }
                didReconcileChange = true
            } else if let groupVal = groupObj {
                resolved = groupVal
            } else if let stdVal = stdObj {
                resolved = stdVal
            } else {
                resolved = defaultValue
            }
            if let prev = previousKnown, prev != resolved {
                didReconcileChange = true
            }
            if groupObj != resolved {
                groupDefaults.set(resolved, forKey: key)
                didReconcileChange = true
            }
            if stdObj != resolved {
                stdDefaults.set(resolved, forKey: key)
                didReconcileChange = true
            }
            if (groupDefaults.object(forKey: lastSyncedKey) as? Bool) != resolved {
                groupDefaults.set(resolved, forKey: lastSyncedKey)
            }
            lastKnownSettingsSnapshot[key] = resolved
            return resolved
        }

        let newCyrillic = (groupDefaults.object(forKey: KeyboardPreferences.cyrillicKey) as? Bool) ?? true
        let newUkrainian = (groupDefaults.object(forKey: KeyboardPreferences.ukrainianCyrillicLayoutKey) as? Bool) ?? false
        let newSuggestions = reconcileBool(key: KeyboardPreferences.suggestionsKey, defaultValue: true)
        let newWordLearning = reconcileBool(key: KeyboardPreferences.wordLearningKey, defaultValue: true)
        let newStats = (groupDefaults.object(forKey: KeyboardPreferences.statsEnabledKey) as? Bool) ?? true

        let oneHandedKey = KeyboardPreferences.oneHandedModeKey
        let lastSyncedOneHandedKey = "crh.key.lastSynced.\(oneHandedKey)"
        let groupOneHanded = groupDefaults.string(forKey: oneHandedKey)
        let stdOneHanded = stdDefaults.string(forKey: oneHandedKey)
        let prevOneHanded = groupDefaults.string(forKey: lastSyncedOneHandedKey)
        let resolvedOneHanded: String = {
            if let g = groupOneHanded, let s = stdOneHanded, g != s {
                if let prev = prevOneHanded, s != prev && g == prev {
                    return (s == "left" || s == "right") ? s : "off"
                }
                return (g == "left" || g == "right") ? g : "off"
            } else if let g = groupOneHanded {
                return (g == "left" || g == "right") ? g : "off"
            } else if let s = stdOneHanded {
                return (s == "left" || s == "right") ? s : "off"
            }
            return KeyboardPreferences.oneHandedMode
        }()
        if groupOneHanded != resolvedOneHanded {
            groupDefaults.set(resolvedOneHanded, forKey: oneHandedKey)
            didReconcileChange = true
        }
        if stdOneHanded != resolvedOneHanded {
            stdDefaults.set(resolvedOneHanded, forKey: oneHandedKey)
            didReconcileChange = true
        }
        if prevOneHanded != resolvedOneHanded {
            groupDefaults.set(resolvedOneHanded, forKey: lastSyncedOneHandedKey)
        }
        if oneHandedMode != resolvedOneHanded {
            oneHandedMode = resolvedOneHanded
        }

        if cyrillicEnabled != newCyrillic { cyrillicEnabled = newCyrillic }
        if ukrainianCyrillicLayout != newUkrainian {
            ukrainianCyrillicLayout = newUkrainian
        }
        if suggestionsEnabled != newSuggestions { suggestionsEnabled = newSuggestions }
        if wordLearningEnabled != newWordLearning { wordLearningEnabled = newWordLearning }
        if statsEnabled != newStats { statsEnabled = newStats }

        if didReconcileChange {
            if !newStats {
                isStatsExpanded = false
                liveWPM = 0
                liveCPM = 0
            }
            groupDefaults.synchronize()
            stdDefaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            settingsSyncRevision &+= 1
            notifySandboxTraitsChanged()
        }

        KeyboardPreferences.refreshCachedPreferences()
    }

    private func refreshStatsFromAppGroup(syncSQLite: Bool = false, synchronizePreferences: Bool = false) {
        if ProcessInfo.processInfo.arguments.contains("-qt_demo_stats") { return }
        if synchronizePreferences {
            Self.lastPreferencesSyncTime = CFAbsoluteTimeGetCurrent()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        }
        guard statsEnabled else { return }
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
        let newUniqueWords = d.integer(forKey: KeyboardUsageStats.uniqueWordsKey)
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
        if uniqueWordsCount != newUniqueWords { uniqueWordsCount = newUniqueWords }
        if abs(activeSeconds - newActiveSeconds) > 0.3 { activeSeconds = newActiveSeconds }
        if peakWPM != newPeakWPM { peakWPM = newPeakWPM }
        if peakCPM != newPeakCPM { peakCPM = newPeakCPM }
        if lastWPM != newLastWPM { lastWPM = newLastWPM }
        if lastCPM != newLastCPM { lastCPM = newLastCPM }
        if phrasesInserted != newPhrasesInserted { phrasesInserted = newPhrasesInserted }

        let bestWPM = max(newPeakWPM, max(newLastWPM, liveWPM))
        AppStoreReviewManager.evaluateAndRequestReviewIfAppropriate(
            totalWords: newTotalWords,
            learnedWords: newLearnedWords,
            bestWPM: bestWPM,
            isKeyboardReady: areAllIndicatorsEnabled,
            isTypingActive: isWritingFieldFocused || isKeyboardVisible
        )
    }

    static func openKeyboardSettings() {
        openAppSettings()
    }

    static func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    static func openSystemKeyboardSettings() {
        // The system keyboard pane has no documented direct URL. The row displays
        // the General → Keyboard path before opening the app's Settings page.
        openAppSettings()
    }

    private func refreshCyrillicStatus() {
        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        _ = SystemKeyboardSettings.enabledSystemKeyboardIdentifiers(forceRefresh: true)
        cachedIsFullAccessEnabled = keyboardState.isFullAccessEnabled
        cachedIsRtl = keyboardState.activeKeyboardBundleIds.first?.hasSuffix("rtl") ?? false
        let args = ProcessInfo.processInfo.arguments
        let languages = UITextInputMode.activeInputModes.compactMap(\.primaryLanguage)
            .map { $0.replacingOccurrences(of: "_", with: "-").lowercased() }
        let hasActiveLatinMode = languages.contains { $0 == "crh" || $0.hasPrefix("crh-latn") }
        let hasActiveStandardCyrillicMode = languages.contains { $0 == "crh-cyrl" || ($0.hasPrefix("crh-cyrl") && !$0.hasPrefix("crh-cyrl-ua")) }
        let hasActiveUkrainianMode = languages.contains { $0.hasPrefix("crh-cyrl-ua") }
        let hasAnyActiveCRHMode = hasActiveLatinMode || hasActiveStandardCyrillicMode || hasActiveUkrainianMode
        let isSimulatedUITest = Self.isUITestingEnvironment || args.contains("-qt_demo_stats")
        let hasAuthoritativeList = SystemKeyboardSettings.hasAuthoritativeSystemKeyboardsList()

        let prevPrimary = lastRenderedPrimaryAdded
        let prevCyrillic = lastRenderedCyrillicAdded
        let prevUkrainian = lastRenderedUkrainianAdded

        if hasActiveLatinMode && !args.contains("-qt_keyboard_missing") {
            primaryExtensionSeen = true
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.primaryExtensionSeen")
        } else if !isSimulatedUITest && !args.contains("-qt_keyboard_missing") && SystemKeyboardSettings.isPrimaryKeyboardExtensionEnabled {
            primaryExtensionSeen = true
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.primaryExtensionSeen")
        } else if !isSimulatedUITest && !args.contains("-qt_keyboard_added") && hasAuthoritativeList && !SystemKeyboardSettings.isPrimaryKeyboardExtensionEnabled && !hasActiveLatinMode {
            primaryExtensionSeen = false
            KeyboardPreferences.defaults.set(false, forKey: "crh.key.primaryExtensionSeen")
        } else if !hasAnyActiveCRHMode && isWritingFieldFocused && isKeyboardVisible && !isSandboxCrimeanTatarKeyboardActive && !args.contains("-qt_keyboard_added") && !args.contains("-qt_wrong_keyboard") {
            primaryExtensionSeen = false
            KeyboardPreferences.defaults.set(false, forKey: "crh.key.primaryExtensionSeen")
        }

        if pendingCyrillicRemovalCheck && didEnterBackgroundForCyrillicCheck {
            pendingCyrillicRemovalCheck = false
            didEnterBackgroundForCyrillicCheck = false
            if !hasActiveLatinMode && (!hasAuthoritativeList || !SystemKeyboardSettings.isPrimaryKeyboardExtensionEnabled) {
                primaryExtensionSeen = false
                KeyboardPreferences.defaults.set(false, forKey: "crh.key.primaryExtensionSeen")
            }
            if !hasActiveStandardCyrillicMode && (!hasAuthoritativeList || !SystemKeyboardSettings.isCyrillicKeyboardExtensionEnabled) {
                cyrillicExtensionSeen = false
                KeyboardPreferences.defaults.set(false, forKey: "crh.key.cyrillicExtensionSeen")
            }
            if !hasActiveUkrainianMode && (!hasAuthoritativeList || !SystemKeyboardSettings.isUkrainianKeyboardExtensionEnabled) {
                ukrainianExtensionSeen = false
                KeyboardPreferences.defaults.set(false, forKey: "crh.key.ukrainianExtensionSeen")
            }
        }

        let targetCyrillicStatus: CyrillicStatus
        if args.contains("-qt_cyrillic_missing") || (args.contains("-qt_keyboard_missing") && !args.contains("-qt_cyrillic_added")) {
            targetCyrillicStatus = .missing
        } else if args.contains("-qt_cyrillic_added") {
            targetCyrillicStatus = .enabled
        } else if isSimulatedUITest {
            let hasSeenCyrillic = cyrillicExtensionSeen
                || KeyboardPreferences.defaults.bool(forKey: "crh.key.cyrillicExtensionSeen")
                || (Self.isUITestingEnvironment && !args.contains("-qt_cyrillic_missing"))
            targetCyrillicStatus = hasSeenCyrillic ? .enabled : .missing
        } else if hasActiveStandardCyrillicMode || SystemKeyboardSettings.isCyrillicKeyboardExtensionEnabled {
            cyrillicExtensionSeen = true
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.cyrillicExtensionSeen")
            targetCyrillicStatus = .enabled
        } else if hasAuthoritativeList && !SystemKeyboardSettings.isCyrillicKeyboardExtensionEnabled {
            cyrillicExtensionSeen = false
            KeyboardPreferences.defaults.set(false, forKey: "crh.key.cyrillicExtensionSeen")
            targetCyrillicStatus = .missing
        } else {
            let hasSeenCyrillic = cyrillicExtensionSeen
                || KeyboardPreferences.defaults.bool(forKey: "crh.key.cyrillicExtensionSeen")
            targetCyrillicStatus = hasSeenCyrillic ? .enabled : .missing
        }

        let targetUkrainianStatus: CyrillicStatus
        if args.contains("-qt_ukrainian_missing") || args.contains("-qt_cyrillic_missing") || (args.contains("-qt_keyboard_missing") && !args.contains("-qt_ukrainian_added") && !args.contains("-qt_ukrainian_fiva")) {
            targetUkrainianStatus = .missing
        } else if args.contains("-qt_ukrainian_added") || args.contains("-qt_ukrainian_fiva") {
            targetUkrainianStatus = .enabled
        } else if isSimulatedUITest {
            let hasSeenUkrainian = ukrainianExtensionSeen
                || KeyboardPreferences.defaults.bool(forKey: "crh.key.ukrainianExtensionSeen")
            targetUkrainianStatus = hasSeenUkrainian ? .enabled : .missing
        } else if hasActiveUkrainianMode || SystemKeyboardSettings.isUkrainianKeyboardExtensionEnabled {
            ukrainianExtensionSeen = true
            KeyboardPreferences.defaults.set(true, forKey: "crh.key.ukrainianExtensionSeen")
            targetUkrainianStatus = .enabled
        } else if hasAuthoritativeList && !SystemKeyboardSettings.isUkrainianKeyboardExtensionEnabled {
            ukrainianExtensionSeen = false
            KeyboardPreferences.defaults.set(false, forKey: "crh.key.ukrainianExtensionSeen")
            targetUkrainianStatus = .missing
        } else {
            let hasSeenUkrainian = ukrainianExtensionSeen
                || KeyboardPreferences.defaults.bool(forKey: "crh.key.ukrainianExtensionSeen")
            targetUkrainianStatus = hasSeenUkrainian ? .enabled : .missing
        }

        let applyStatusUpdates = {
            cyrillicStatus = targetCyrillicStatus
            ukrainianStatus = targetUkrainianStatus
            syncCyrillicToggleWithExtensionState()
        }

        if animationsAllowed && Self.canAnimateUserChanges {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.82)) {
                applyStatusUpdates()
            }
        } else {
            applyStatusUpdates()
        }

        let currentPrimary = isPrimaryKeyboardAdded
        let currentCyrillic = (targetCyrillicStatus == .enabled)
        let currentUkrainian = (targetUkrainianStatus == .enabled)

        let primaryDiff = currentPrimary != prevPrimary
        let cyrillicDiff = currentCyrillic != prevCyrillic
        let ukrainianDiff = currentUkrainian != prevUkrainian

        if primaryDiff || cyrillicDiff || ukrainianDiff {
            lastRenderedPrimaryAdded = currentPrimary
            lastRenderedCyrillicAdded = currentCyrillic
            lastRenderedUkrainianAdded = currentUkrainian
            if activeOnboardingSheet != nil {
                withAnimation(animationsAllowed ? .spring(response: 0.35, dampingFraction: 0.84) : nil) {
                    activeOnboardingSheet = nil
                }
            }
            let delay = didCheckColdLaunchExtensionDiff ? 0.05 : 0.28
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                if primaryDiff { latinBadgeTrigger &+= 1 }
                if cyrillicDiff { cyrillicBadgeTrigger &+= 1 }
                if ukrainianDiff { ukrainianBadgeTrigger &+= 1 }
            }
        }
        didCheckColdLaunchExtensionDiff = true
    }

    private func syncCyrillicToggleWithExtensionState() {
        let hasStandardExtension = (cyrillicStatus == .enabled)
        let hasUkrainianExtension = (ukrainianStatus == .enabled)

        if !hasStandardExtension && !hasUkrainianExtension && !Self.isUITestingEnvironment {
            if cyrillicEnabled {
                cyrillicEnabled = false
            }
            if ukrainianCyrillicLayout {
                ukrainianCyrillicLayout = false
            }
            KeyboardPreferences.setCyrillicEnabled(false)
            KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(false)
            return
        }

        if hasStandardExtension && !hasUkrainianExtension {
            if !Device.iPad || !didManuallyDisableCyrillicOnIPad {
                if !cyrillicEnabled {
                    cyrillicEnabled = true
                }
                KeyboardPreferences.setCyrillicEnabled(true)
            }
            if ukrainianCyrillicLayout {
                ukrainianCyrillicLayout = false
            }
            KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(false)
            return
        }

        if hasUkrainianExtension && !hasStandardExtension {
            if !Device.iPad || !didManuallyDisableUkrainianOnIPad {
                if !ukrainianCyrillicLayout {
                    ukrainianCyrillicLayout = true
                }
                if !cyrillicEnabled {
                    cyrillicEnabled = true
                }
                KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(true)
                KeyboardPreferences.setCyrillicEnabled(true)
            }
            return
        }

        if hasStandardExtension && (!Device.iPad || !didManuallyDisableCyrillicOnIPad) {
            if !cyrillicEnabled {
                cyrillicEnabled = true
            }
            KeyboardPreferences.setCyrillicEnabled(true)
        }

        if hasUkrainianExtension && (!Device.iPad || !didManuallyDisableUkrainianOnIPad) {
            if !Device.iPad || !hasStandardExtension || !didSelectAbvLayoutOnIPad {
                if !ukrainianCyrillicLayout {
                    ukrainianCyrillicLayout = true
                }
                KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(true)
            }
            if !Device.iPad || !didManuallyDisableCyrillicOnIPad {
                if !cyrillicEnabled {
                    cyrillicEnabled = true
                }
                KeyboardPreferences.setCyrillicEnabled(true)
            }
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

    private func applyWindowUserInterfaceStyle(_ theme: KeyboardTestThemeMode) {
        guard hasManualThemeOverride else { return }
        let style: UIUserInterfaceStyle = theme.isDark ? .dark : .light
        let apply = {
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        if window.overrideUserInterfaceStyle != style {
                            window.overrideUserInterfaceStyle = style
                        }
                        if window.rootViewController?.overrideUserInterfaceStyle != style {
                            window.rootViewController?.overrideUserInterfaceStyle = style
                        }
                    }
                }
            }
        }
        apply()
        DispatchQueue.main.async(execute: apply)
    }

    private func syncThemeToAppGroup(_ theme: KeyboardTestThemeMode) {
        applyWindowUserInterfaceStyle(theme)
        guard UIApplication.shared.applicationState == .active else { return }
        let defaults = KeyboardPreferences.defaults
        if isWritingFieldFocused || shouldAutoFocusSandbox || hasManualThemeOverride {
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
                hasManualThemeOverride = true
                if value.lowercased().contains("dark") {
                    selectedThemeMode = .dark
                } else {
                    selectedThemeMode = .ios26White
                }
                isTestingExpanded = true
                shouldAutoFocusSandbox = true
            }
            if args.contains("-qt_demo_dark") {
                hasManualThemeOverride = true
                selectedThemeMode = .dark
            }
            applyWindowUserInterfaceStyle(selectedThemeMode)
            let isXCTestRun = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil || args.contains("-UITesting")
            let isUITestLaunch = args.contains(where: { $0.hasPrefix("-qt_") }) || isXCTestRun
            let allowSpaceBarBreathing = !isUITestLaunch || args.contains("-qt_enable_animations")
            KeyboardPreferences.defaults.set(isUITestLaunch, forKey: "crh.key.test.isUITesting")
            KeyboardPreferences.defaults.set(allowSpaceBarBreathing, forKey: "crh.key.test.allowSpaceBarBreathing")
            if isUITestLaunch {
                KeyboardPreferences.defaults.set(Date().timeIntervalSince1970, forKey: "crh.key.test.uiTestingTimestamp")
            } else {
                KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.uiTestingTimestamp")
                KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.holdCallout")
                KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.demoSwipeKeys")
                KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.useModernPillCallout")
            }
            KeyboardPreferences.defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            if isUITestLaunch {
                if isXCTestRun && !args.contains("-qt_enable_animations") {
                    UIView.setAnimationsEnabled(false)
                } else {
                    UIView.setAnimationsEnabled(true)
                }
                isTestingExpanded = true
                shouldAutoFocusSandbox = true
            }
            if args.contains("-qt_reset_text") {
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
                KeyboardPreferences.defaults.set(true, forKey: KeyboardPreferences.statsEnabledKey)
                cyrillicExtensionSeen = args.contains("-qt_cyrillic_added")
                ukrainianExtensionSeen = args.contains("-qt_ukrainian_added") || args.contains("-qt_ukrainian_fiva")
                KeyboardPreferences.defaults.set(args.contains("-qt_cyrillic_added"), forKey: "crh.key.cyrillicExtensionSeen")
                KeyboardPreferences.defaults.set(args.contains("-qt_ukrainian_added") || args.contains("-qt_ukrainian_fiva"), forKey: "crh.key.ukrainianExtensionSeen")
                KeyboardPreferences.defaults.synchronize()
                defaults.set(true, forKey: KeyboardPreferences.suggestionsKey)
                defaults.set(true, forKey: KeyboardPreferences.wordLearningKey)
                defaults.set(true, forKey: KeyboardPreferences.cyrillicKey)
                defaults.set(false, forKey: KeyboardPreferences.ukrainianCyrillicLayoutKey)
                defaults.set(true, forKey: KeyboardPreferences.statsEnabledKey)
                KeyboardPreferences.setOneHandedMode("off")
                KeyboardPreferences.refreshCachedPreferences()
                KeyboardUsageStats.resetAll()
                refreshStatsFromAppGroup(syncSQLite: false)
            }
            if args.contains("-qt_no_suggestions") {
                suggestionsEnabled = false
                KeyboardPreferences.setSuggestionsEnabled(false)
                KeyboardPreferences.defaults.set(false, forKey: KeyboardPreferences.suggestionsKey)
                defaults.set(false, forKey: KeyboardPreferences.suggestionsKey)
                KeyboardPreferences.defaults.synchronize()
                CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                KeyboardPreferences.refreshCachedPreferences()
            }
            if args.contains("-qt_one_handed_left") {
                KeyboardPreferences.setOneHandedMode("left")
            } else if args.contains("-qt_one_handed_right") {
                KeyboardPreferences.setOneHandedMode("right")
            } else if args.contains("-qt_one_handed_off") {
                KeyboardPreferences.setOneHandedMode("off")
            }
            KeyboardPreferences.defaults.set(args.contains("-qt_hold_callout"), forKey: "crh.key.test.holdCallout")
            if args.contains("-qt_no_autofocus") {
                shouldAutoFocusSandbox = false
            } else if args.contains("-qt_focus_sandbox_live") {
                isTestingExpanded = true
                shouldAutoFocusSandbox = true
            }
            if args.contains("-qt_open_app_settings") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    Self.openAppSettings()
                }
            }
            if let langIdx = args.firstIndex(of: "-qt_lang"), langIdx + 1 < args.count {
                let rawLang = args[langIdx + 1].lowercased()
                let requestedLang: String
                if rawLang.hasPrefix("en") {
                    requestedLang = "en"
                } else if rawLang.hasPrefix("uk") {
                    requestedLang = "uk"
                } else {
                    requestedLang = "crh"
                }
                language = requestedLang
                KeyboardPreferences.defaults.set(requestedLang, forKey: KeyboardPreferences.languageKey)
                KeyboardPreferences.defaults.synchronize()
            }
            if args.contains("-qt_cyrillic_missing") {
                cyrillicEnabled = false
                cyrillicExtensionSeen = false
                KeyboardPreferences.setCyrillicEnabled(false)
                KeyboardPreferences.defaults.set(false, forKey: "crh.key.cyrillicExtensionSeen")
                defaults.set(false, forKey: KeyboardPreferences.cyrillicKey)
            } else if args.contains("-qt_cyrillic_added") {
                cyrillicEnabled = true
                cyrillicExtensionSeen = true
                KeyboardPreferences.setCyrillicEnabled(true)
                KeyboardPreferences.defaults.set(true, forKey: "crh.key.cyrillicExtensionSeen")
                defaults.set(true, forKey: KeyboardPreferences.cyrillicKey)
            }
            if args.contains("-qt_ukrainian_missing") || args.contains("-qt_cyrillic_missing") {
                ukrainianCyrillicLayout = false
                ukrainianExtensionSeen = false
                KeyboardPreferences.defaults.set(false, forKey: "crh.key.ukrainianExtensionSeen")
                KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(false)
                defaults.set(false, forKey: KeyboardPreferences.ukrainianCyrillicLayoutKey)
            } else if args.contains("-qt_ukrainian_fiva") || args.contains("-qt_ukrainian_added") {
                cyrillicEnabled = true
                ukrainianCyrillicLayout = true
                ukrainianExtensionSeen = true
                KeyboardPreferences.setCyrillicEnabled(true)
                KeyboardPreferences.defaults.set(true, forKey: "crh.key.ukrainianExtensionSeen")
                KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(true)
                defaults.set(true, forKey: KeyboardPreferences.cyrillicKey)
                defaults.set(true, forKey: KeyboardPreferences.ukrainianCyrillicLayoutKey)
            } else if args.contains("-qt_cyrillic_added") {
                ukrainianCyrillicLayout = false
                ukrainianExtensionSeen = false
                KeyboardPreferences.defaults.set(false, forKey: "crh.key.ukrainianExtensionSeen")
                KeyboardPreferences.setUkrainianCyrillicLayoutEnabled(false)
                defaults.set(false, forKey: KeyboardPreferences.ukrainianCyrillicLayoutKey)
            }
            KeyboardPreferences.defaults.synchronize()
            if args.contains("-qt_stats_disabled") {
                statsEnabled = false
                isStatsExpanded = false
                KeyboardPreferences.setStatsEnabled(false)
            } else if args.contains("-qt_expand_stats") {
                statsEnabled = true
                KeyboardPreferences.setStatsEnabled(true)
                isTestingExpanded = false
                shouldAutoFocusSandbox = false
                isStatsExpanded = true
            }
            if args.contains("-qt_demo_stats") {
                let demoLang: String = {
                    if let idx = args.firstIndex(of: "-qt_lang"), idx + 1 < args.count {
                        let raw = args[idx + 1].lowercased()
                        if raw.hasPrefix("en") { return "en" }
                        if raw.hasPrefix("uk") { return "uk" }
                        return "crh"
                    }
                    return language
                }()
                if args.contains("-qt_demo_swipe") {
                    let swipeKeySeq: String
                    switch demoLang {
                    case "uk":
                        swipeKeySeq = "q,u,v,e,t"
                    case "en":
                        swipeKeySeq = "b,i,r,l,i,k"
                    default:
                        swipeKeySeq = "b,i,r,l,i,k"
                    }
                    KeyboardPreferences.defaults.set(swipeKeySeq, forKey: "crh.key.test.demoSwipeKeys")
                } else {
                    KeyboardPreferences.defaults.removeObject(forKey: "crh.key.test.demoSwipeKeys")
                }
                if args.contains("-qt_prefill_cyrillic_phrase") {
                    switch demoLang {
                    case "uk":
                        // Verified bannerCRH #68 (Çerkez-Ali): "Qırım — menim Vatanımdır!" (type final 2 letters "ир" via ФІВА)
                        text = "Qırım — menim Vatanımd"
                    case "en":
                        // Verified bannerCRH #36 (Vasfiye Qıpçaq): "Tiliñni bil, oqu, yaz!" (type final 2 letters "яз" via ФЫВА)
                        text = "Tiliñni bil, oqu, "
                    default:
                        // Verified bannerCRH #63 (İsmail Gasprinskiy): "Tilde, fikirde, işte — birlik!" (type final 2 letters "ик" via ФЫВА)
                        text = "Tilde, fikirde, işte — birl"
                    }
                } else if args.contains("-qt_prefill_phrase_prefix") {
                    switch demoLang {
                    case "uk":
                        // Verified bannerCRH #68 (Çerkez-Ali): "Qırım — menim Vatanımdır!" (type final 2 letters "ır")
                        text = "Qırım — menim Vatanımd"
                    case "en":
                        // Verified bannerCRH #7 (Qırımtatar atalar sözü): "Tilge ürmet — ilge ürmettir." (type final 2 letters "ir")
                        text = "Tilge ürmet — ilge ürmett"
                    default:
                        // Verified bannerCRH #26 (Seyran Üseinov): "Til — bizim temelimiz!" (type final letters)
                        text = "Til — bizim "
                    }
                } else if args.contains("-qt_prefill_greeting_prefix") {
                    switch demoLang {
                    case "uk":
                        // Verified bannerCRH #85 (Qırımtatar atalar sözü): "Birlikte — quvet!" (type final 2 letters "et")
                        text = "Birlikte — quv"
                    case "en":
                        // Verified bannerCRH #63 (İsmail Gasprinskiy): "Tilde, fikirde, işte — birlik!" (type final 2 letters "ik")
                        text = "Tilde, fikirde, işte — birl"
                    default:
                        // Verified bannerCRH #63 (İsmail Gasprinskiy): "Tilde, fikirde, işte — birlik!" (type final 2 letters "ik")
                        text = "Tilde, fikirde, işte — birl"
                    }
                } else if !args.contains("-qt_reset_text") && !args.contains("-qt_field") {
                    switch demoLang {
                    case "uk":
                        // Verified bannerCRH #68 + #85:
                        text = "Qırım — menim Vatanımdır! Birlikte — quvet!"
                    case "en":
                        // Verified bannerCRH #7 + #22:
                        text = "Tilge ürmet — ilge ürmettir. Tilni bilmek — dostluqnı qaviyleştirmektir."
                    default:
                        // Verified bannerCRH #28 (Seyran Üseinov):
                        text = "Dünyada eñ tatlı — qırımtatar tilimiz!"
                    }
                    let isDarkLaunch = args.contains("-qt_demo_dark") || (args.contains("-qt_theme") && args.contains("modernDark"))
                    if !args.contains("-qt_focus_sandbox_live") && !isDarkLaunch {
                        shouldAutoFocusSandbox = false
                    }
                }
                totalWords = 180
                manualWords = 120
                suggestedWords = 60
                totalCharacters = 1140
                suggestedCharacters = 390
                peakWPM = 38
                lastWPM = 38
                peakCPM = 228
                lastCPM = 228
                liveWPM = 38
                liveCPM = 228
                activeSeconds = 420
                learnedWordsCount = 18
                uniqueWordsCount = 64
                phrasesInserted = 7
                let d = KeyboardPreferences.defaults
                d.set(180, forKey: KeyboardUsageStats.totalWordsKey)
                d.set(120, forKey: KeyboardUsageStats.manualWordsKey)
                d.set(60, forKey: KeyboardUsageStats.suggestedWordsKey)
                d.set(1140, forKey: KeyboardUsageStats.totalCharsKey)
                d.set(390, forKey: KeyboardUsageStats.suggestedCharsKey)
                d.set(38, forKey: KeyboardUsageStats.peakWPMKey)
                d.set(38, forKey: KeyboardUsageStats.lastWPMKey)
                d.set(228, forKey: KeyboardUsageStats.peakCPMKey)
                d.set(228, forKey: KeyboardUsageStats.lastCPMKey)
                d.set(420.0, forKey: KeyboardUsageStats.activeSecondsKey)
                d.set(18, forKey: KeyboardUsageStats.learnedWordsKey)
                d.set(64, forKey: KeyboardUsageStats.uniqueWordsKey)
                d.set(7, forKey: KeyboardUsageStats.phrasesInsertedKey)
                d.synchronize()
                KeyboardUsageStats.seedDemoLearnedWordsIfNeeded()
            }
            if args.contains("-qt_open_about") {
                shouldAutoFocusSandbox = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    if navigationPath.isEmpty {
                        navigationPath.append(DemoRoute.about)
                    }
                }
            }
            if args.contains("-qt_open_learned_words") {
                shouldAutoFocusSandbox = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    openLearnedWordsDictionary()
                }
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
        let hasUITestArgs = CommandLine.arguments.contains(where: { $0.hasPrefix("-qt_") || $0 == "-UITesting" })
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil && !hasUITestArgs {
            defaults.removeObject(forKey: "crh.key.test.isUITesting")
            defaults.removeObject(forKey: "crh.key.test.uiTestingTimestamp")
        }
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
    var leftFraction: CGFloat = 0.44

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
        L10n.label(key)
    }

    func localizedInterfaceString(_ key: String, table: String? = nil, languageCode: String? = nil) -> String {
        let lang = languageCode ?? language
        let bundle = KeyboardPreferences.localizationBundle(for: lang)
        return bundle.localizedString(forKey: key, value: key, table: table ?? "Interface")
    }

    private static var appearedBadgeIDs: Set<String> = []
    static var canAnimateUserChanges: Bool = false

    static func shouldAnimateInitialAppear(for badgeID: String) -> Bool {
        false
    }

    static var isUITestingEnvironment: Bool {
        KeyboardPreferences.defaults.bool(forKey: "crh.key.test.isUITesting")
            || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
            || ProcessInfo.processInfo.arguments.contains("-qt_reset_text")
    }

    func settingsIconBadge(
        _ systemName: String,
        color: Color,
        isEnabled: Bool = true,
        triggerToken: String = "",
        badgeID: String = ""
    ) -> some View {
        InteractiveSettingsIconBadge(
            badgeID: badgeID.isEmpty ? "icon.\(systemName)" : badgeID,
            systemName: systemName,
            color: color,
            isEnabled: isEnabled,
            triggerToken: triggerToken
        )
    }

    func latinKeycapIconBadge(
        color: Color,
        isEnabled: Bool = true,
        badgeID: String = "settings.standardLayout.keycap"
    ) -> some View {
        TransliterationKeycapBadge(
            badgeID: badgeID,
            sourceLabel: "Q",
            targetLabel: "Q",
            isEnabled: isEnabled,
            isUkrainianStyle: false,
            isLatinOnlyStyle: true,
            accentColor: color,
            triggerCount: latinBadgeTrigger
        )
    }

    func cyrillicKeycapIconBadge(
        color: Color,
        isEnabled: Bool = true,
        isUkrainianStyle: Bool = false,
        badgeID: String = "settings.cyrillic.keycap"
    ) -> some View {
        TransliterationKeycapBadge(
            badgeID: badgeID,
            sourceLabel: isUkrainianStyle ? "К\u{02BC}" : "Къ",
            targetLabel: "Q",
            isEnabled: isEnabled,
            isUkrainianStyle: isUkrainianStyle,
            accentColor: color,
            triggerCount: isUkrainianStyle ? ukrainianBadgeTrigger : cyrillicBadgeTrigger
        )
    }

    func latinLettersMiniCapsules(isEnabled: Bool) -> some View {
        LatinCharactersMiniCapsulesView(
            badgeID: "settings.standardLayout.capsules",
            isEnabled: isEnabled,
            brandBlue: brandBlue,
            primaryInk: primaryInk,
            secondaryInk: secondaryInk,
            accessibilityLabelText: localizedInterfaceString("settings.standardLayout.desc")
        )
    }

    func cyrillicTransliterationMiniCapsules(isEnabled: Bool) -> some View {
        UkrainianTransliterationMiniCapsulesView(
            badgeID: "settings.cyrillic.capsules",
            isEnabled: isEnabled,
            brandBlue: Color(red: 0.35, green: 0.34, blue: 0.84),
            primaryInk: primaryInk,
            secondaryInk: secondaryInk,
            accessibilityLabelText: localizedInterfaceString("settings.cyrillic"),
            pairs: [
                ("гъ", "ğ"),
                ("къ", "q"),
                ("нъ", "ñ"),
                ("дж", "c")
            ]
        )
    }

    func ukrainianTransliterationMiniCapsules(isEnabled: Bool) -> some View {
        UkrainianTransliterationMiniCapsulesView(
            badgeID: "settings.ukrainianCyrillic.capsules",
            isEnabled: isEnabled,
            brandBlue: brandBlue,
            primaryInk: primaryInk,
            secondaryInk: secondaryInk,
            accessibilityLabelText: localizedInterfaceString("settings.ukrainianCyrillic.desc")
        )
    }

    func walnutBrainIconBadge(color: Color, isEnabled: Bool = true) -> some View {
        InteractiveWalnutIconBadge(
            badgeID: "settings.wordLearning.walnut",
            color: color,
            isEnabled: isEnabled
        )
    }

    var statusIndicatorsSection: some View {
        let warningAmber = Color(red: 0.96, green: 0.58, blue: 0.04)
        let fullAccessToggleBinding = Binding<Bool>(
            get: { isFullAccessGranted },
            set: { _ in
                HapticFeedback.playSelection()
                activeOnboardingSheet = OnboardingSheetRequest(mode: .add, initialPage: "Onboard2")
            }
        )

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    HapticFeedback.playSelection()
                    activeOnboardingSheet = OnboardingSheetRequest(mode: .add, initialPage: "Onboard2")
                } label: {
                    HStack(spacing: 12) {
                        settingsIconBadge(
                            isFullAccessGranted ? "lock.open.fill" : "exclamationmark.triangle.fill",
                            color: isFullAccessGranted ? appleGreen : warningAmber,
                            badgeID: isFullAccessGranted ? "status.fullAccess.ok" : "status.fullAccess.warning"
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            StableLocalizedText(
                                key: (isFullAccessGranted ? Home.home_full_on_key : Home.home_full_off_key).rawValue,
                                table: "Home",
                                fontName: "GeneralSans-Medium",
                                fontSize: 15,
                                color: primaryInk,
                                lineLimit: 1,
                                minimumScaleFactor: 0.85
                            )
                            StableLocalizedText(
                                key: isFullAccessGranted ? "settings.fullAccess.onHint" : "settings.fullAccess.addHint",
                                fontName: "GeneralSans-Regular",
                                fontSize: 12,
                                color: secondaryInk,
                                lineLimit: 3
                            )
                        }
                        Spacer(minLength: 8)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Toggle("", isOn: animationsAllowed ? fullAccessToggleBinding.animation(.spring(response: 0.32, dampingFraction: 0.85)) : fullAccessToggleBinding)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("status.fullAccess.toggle")
                    .padding(.trailing, 24)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("status.fullAccess.row")
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 3)
    }

    private var interfaceLanguageIconName: String {
        switch language {
        case "uk": return "lang.uk.tryzub"
        case "en": return "lang.en.unionjack"
        default: return "lang.crh.tamga"
        }
    }

    /// Block 1: Main 3 Keyboard Settings (`Мова інтерфейсу`, `Налаштування програми`, `Системні налаштування`).
    var keyboardSettingsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Language selector row (single horizontal row on both iPhone and iPad)
            HStack(spacing: 12) {
                settingsIconBadge(
                    interfaceLanguageIconName,
                    color: brandBlue,
                    triggerToken: language,
                    badgeID: "settings.language.globe"
                )
                StableLocalizedText(
                    key: "settings.language",
                    fontName: "GeneralSans-Medium",
                    fontSize: 15,
                    color: primaryInk,
                    lineLimit: 1,
                    minimumScaleFactor: 0.85
                )
                .layoutPriority(1)
                Spacer(minLength: 8)
                languageSegmentedControl(fullWidth: false, compact: !Device.iPad)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Divider().padding(.leading, 54)

            // Navigation link row to App Settings in iOS Settings (Settings → Apps → QırımKey)
            Button {
                HapticFeedback.playSelection()
                Self.openAppSettings()
            } label: {
                HStack(spacing: 12) {
                    settingsIconBadge("gearshape", color: brandBlue, badgeID: "settings.appSettings.gear")
                    VStack(alignment: .leading, spacing: 2) {
                        StableLocalizedText(
                            key: "settings.appSettings",
                            fontName: "GeneralSans-Medium",
                            fontSize: 15,
                            color: primaryInk,
                            lineLimit: 1,
                            minimumScaleFactor: 0.85
                        )
                        StableLocalizedText(
                            key: "settings.appSettings.desc",
                            fontName: "GeneralSans-Regular",
                            fontSize: 12,
                            color: secondaryInk,
                            lineLimit: 1,
                            minimumScaleFactor: 0.75
                        )
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .frame(width: 16, height: 22, alignment: .center)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.appSettings.button")

            Divider().padding(.leading, 54)

            // Navigation link row to System Keyboard Settings (Settings → General → Keyboard)
            Button {
                HapticFeedback.playSelection()
                Self.openSystemKeyboardSettings()
            } label: {
                HStack(spacing: 12) {
                    settingsIconBadge("slider.horizontal.3", color: Color(red: 0.16, green: 0.56, blue: 0.94), badgeID: "settings.systemKeyboard.slider")
                    VStack(alignment: .leading, spacing: 2) {
                        StableLocalizedText(
                            key: "settings.systemKeyboard",
                            fontName: "GeneralSans-Medium",
                            fontSize: 15,
                            color: primaryInk,
                            lineLimit: 1,
                            minimumScaleFactor: 0.85
                        )
                        StableLocalizedText(
                            key: "settings.systemKeyboard.ios26Desc",
                            fontName: "GeneralSans-Regular",
                            fontSize: 12,
                            color: secondaryInk,
                            lineLimit: 1,
                            minimumScaleFactor: 0.75
                        )
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(.tertiaryLabel))
                        .frame(width: 16, height: 22, alignment: .center)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settings.systemKeyboard.button")
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 3)
    }

    /// Block 2: Separate card for Standard (Latin) Layout (`Стандартна розкладка`) with linearly drawn `Q` 3D keycap badge and read-only system-synced toggle.
    var standardLayoutSection: some View {
        let primaryAdded = isPrimaryKeyboardAdded
        let primaryKeyboardToggleBinding = Binding<Bool>(
            get: { primaryAdded },
            set: { _ in
                HapticFeedback.playSelection()
                latinBadgeTrigger &+= 1
                pendingCyrillicRemovalCheck = true
                didEnterBackgroundForCyrillicCheck = false
                activeOnboardingSheet = OnboardingSheetRequest(
                    mode: primaryAdded ? .removeCyrillic : .add,
                    initialPage: "Onboard1"
                )
            }
        )

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    latinKeycapIconBadge(
                        color: brandBlue,
                        isEnabled: primaryAdded,
                        badgeID: "settings.standardLayout.keycap"
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Button {
                                HapticFeedback.playSelection()
                                latinBadgeTrigger &+= 1
                                pendingCyrillicRemovalCheck = true
                                didEnterBackgroundForCyrillicCheck = false
                                activeOnboardingSheet = OnboardingSheetRequest(
                                    mode: primaryAdded ? .removeCyrillic : .add,
                                    initialPage: "Onboard1"
                                )
                            } label: {
                                StableLocalizedText(
                                    key: "settings.standardLayout",
                                    fontName: "GeneralSans-Medium",
                                    fontSize: 15,
                                    color: primaryInk,
                                    lineLimit: 1,
                                    minimumScaleFactor: 0.85
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(height: 20, alignment: .leading)

                        latinLettersMiniCapsules(isEnabled: primaryAdded)
                            .frame(height: 18, alignment: .leading)
                    }
                    Spacer(minLength: 8)
                    Toggle("", isOn: animationsAllowed ? primaryKeyboardToggleBinding.animation(.spring(response: 0.32, dampingFraction: 0.85)) : primaryKeyboardToggleBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("status.primaryKeyboard.toggle")
                        .padding(.trailing, 24)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("status.primaryKeyboard.row")
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 3)
    }

    /// Block 3: Separate card for Additional Cyrillic Layouts (`Кирилична клавіатура` + `Українська розкладка` when `language == "uk"`).
    var cyrillicLayoutsSection: some View {
        let args = ProcessInfo.processInfo.arguments
        let allowAutomatedIPadInMemoryToggle = Self.isUITestingEnvironment
            && Device.iPad
            && !args.contains("-qt_cyrillic_added")
            && !args.contains("-qt_cyrillic_missing")
        let isCyrillicEffectiveOn = allowAutomatedIPadInMemoryToggle
            ? (cyrillicEnabled && !didManuallyDisableCyrillicOnIPad)
            : isCyrillicKeyboardAdded
        let isUkrainianEffectiveOn = isUkrainianKeyboardAdded
        let showIPadAbvSelector = Device.iPad && language == "uk" && isCyrillicEffectiveOn && isUkrainianEffectiveOn

        let cyrillicToggleBinding = Binding<Bool>(
            get: { isCyrillicEffectiveOn },
            set: { wantOn in
                HapticFeedback.playSelection()
                cyrillicBadgeTrigger &+= 1
                if allowAutomatedIPadInMemoryToggle {
                    didManuallyDisableCyrillicOnIPad = !wantOn
                    cyrillicEnabled = wantOn
                    return
                }
                pendingCyrillicRemovalCheck = true
                didEnterBackgroundForCyrillicCheck = false
                activeOnboardingSheet = OnboardingSheetRequest(
                    mode: isCyrillicEffectiveOn ? .removeCyrillic : .add,
                    initialPage: "Onboard1"
                )
            }
        )
        let ukrainianToggleBinding = Binding<Bool>(
            get: { isUkrainianEffectiveOn },
            set: { _ in
                HapticFeedback.playSelection()
                ukrainianBadgeTrigger &+= 1
                pendingCyrillicRemovalCheck = true
                didEnterBackgroundForCyrillicCheck = false
                activeOnboardingSheet = OnboardingSheetRequest(
                    mode: isUkrainianEffectiveOn ? .removeCyrillic : .add,
                    initialPage: "Onboard1"
                )
            }
        )

        return VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    cyrillicKeycapIconBadge(
                        color: Color(red: 0.35, green: 0.34, blue: 0.84),
                        isEnabled: isCyrillicEffectiveOn,
                        isUkrainianStyle: false,
                        badgeID: "settings.cyrillic.keycap"
                    )
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Button {
                                cyrillicToggleBinding.wrappedValue.toggle()
                            } label: {
                                StableLocalizedText(
                                    key: "settings.cyrillic",
                                    fontName: "GeneralSans-Medium",
                                    fontSize: 15,
                                    color: primaryInk,
                                    lineLimit: 1,
                                    minimumScaleFactor: 0.85
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(height: 20, alignment: .leading)

                        cyrillicTransliterationMiniCapsules(isEnabled: isCyrillicEffectiveOn)
                            .frame(height: 18, alignment: .leading)
                    }
                    Spacer(minLength: 6)
                    if showIPadAbvSelector {
                        iPadAbvSelectorButton(
                            isActive: !ukrainianCyrillicLayout,
                            accentColor: Color(red: 0.35, green: 0.34, blue: 0.84),
                            accessibilityID: "settings.cyrillic.abvSelector"
                        ) {
                            HapticFeedback.playSelection()
                            didSelectAbvLayoutOnIPad = true
                            didEnableBothCyrillicOnIPad = true
                            withAnimation(animationsAllowed ? .spring(response: 0.28, dampingFraction: 0.82) : nil) {
                                ukrainianCyrillicLayout = false
                            }
                            cyrillicBadgeTrigger &+= 1
                        }
                    }
                    Toggle("", isOn: animationsAllowed ? cyrillicToggleBinding.animation(.spring(response: 0.32, dampingFraction: 0.85)) : cyrillicToggleBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("settings.cyrillic.toggle")
                        .padding(.trailing, 24)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("settings.cyrillic.statusRow")

            if language == "uk" {
                Divider().padding(.leading, 54)

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 12) {
                        cyrillicKeycapIconBadge(
                            color: brandBlue,
                            isEnabled: isUkrainianEffectiveOn,
                            isUkrainianStyle: true,
                            badgeID: "settings.ukrainianCyrillic.keycap"
                        )

                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Button {
                                    ukrainianToggleBinding.wrappedValue.toggle()
                                } label: {
                                    StableLocalizedText(
                                        key: "settings.ukrainianCyrillic",
                                        fontName: "GeneralSans-Medium",
                                        fontSize: 15,
                                        color: primaryInk,
                                        lineLimit: 1,
                                        minimumScaleFactor: 0.85
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(height: 20, alignment: .leading)

                            ukrainianTransliterationMiniCapsules(isEnabled: isUkrainianEffectiveOn)
                                .frame(height: 18, alignment: .leading)
                        }
                        Spacer(minLength: 6)
                        if showIPadAbvSelector {
                            iPadAbvSelectorButton(
                                isActive: ukrainianCyrillicLayout,
                                accentColor: brandBlue,
                                accessibilityID: "settings.ukrainianCyrillic.abvSelector"
                            ) {
                                HapticFeedback.playSelection()
                                didSelectAbvLayoutOnIPad = true
                                didEnableBothCyrillicOnIPad = true
                                withAnimation(animationsAllowed ? .spring(response: 0.28, dampingFraction: 0.82) : nil) {
                                    ukrainianCyrillicLayout = true
                                }
                                ukrainianBadgeTrigger &+= 1
                            }
                        }
                        Toggle("", isOn: animationsAllowed ? ukrainianToggleBinding.animation(.spring(response: 0.32, dampingFraction: 0.85)) : ukrainianToggleBinding)
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .accessibilityIdentifier("settings.ukrainianCyrillic.toggle")
                            .padding(.trailing, 24)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings.ukrainianCyrillic.statusRow")
            }
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 3)
    }

    private func iPadAbvSelectorButton(
        isActive: Bool,
        accentColor: Color,
        accessibilityID: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack {
                // Physical 3D keycap shadow / lower lip
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isActive
                            ? accentColor.opacity(colorScheme == .dark ? 0.55 : 0.72)
                            : Color.black.opacity(colorScheme == .dark ? 0.45 : 0.16)
                    )
                    .offset(y: 1.5)

                // Raised 3D keycap top surface
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(
                        isActive
                            ? LinearGradient(
                                colors: [accentColor.opacity(0.96), accentColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            : LinearGradient(
                                colors: [
                                    colorScheme == .dark ? Color(white: 0.28) : Color.white,
                                    colorScheme == .dark ? Color(white: 0.22) : Color(white: 0.94)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                    )

                // Inner keycap rim highlight
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(
                        isActive ? Color.white.opacity(0.42) : Color.primary.opacity(0.14),
                        lineWidth: 1.0
                    )
                    .padding(1.2)

                Text("абв")
                    .font(InterfaceFont.font("GeneralSans-Semibold", size: 12.5))
                    .foregroundStyle(isActive ? Color.white : primaryInk.opacity(0.85))
                    .padding(.horizontal, 9)
            }
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: 27)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("абв")
        .accessibilityValue(isActive ? "1" : "0")
        .accessibilityIdentifier(accessibilityID)
    }

    func languageSegmentedControl(fullWidth: Bool, compact: Bool = false) -> some View {
        NativeSegmentedControl(
            items: [
                .init(id: "crh", title: compact ? "QT" : "Qırımtatarca", accessibilityIdentifier: "settings.lang.crh"),
                .init(id: "uk", title: compact ? "УК" : "Українська", accessibilityIdentifier: "settings.lang.uk"),
                .init(id: "en", title: compact ? "EN" : "English", accessibilityIdentifier: "settings.lang.en")
            ],
            selection: Binding(
                get: { language },
                set: { newValue in
                    withAnimation(animationsAllowed ? .easeInOut(duration: 0.2) : nil) {
                        language = newValue
                    }
                }
            ),
            apportionsWidthsByContent: false,
            expandsToFillWidth: compact ? false : fullWidth,
            fixedWidth: compact ? 148 : 292
        )
        .frame(height: 32)
    }

    /// Combines the expandable "Try Keyboard" controls and the writing area into a single unified Apple card.
    var testingAndWritingSection: some View {
        let keyboardAdded = isPrimaryKeyboardAdded || isCyrillicKeyboardAdded || isUkrainianKeyboardAdded
        let showWrongKeyboardWarning = (!ProcessInfo.processInfo.arguments.contains("-qt_suppress_wrong_keyboard_warning")
            && isWritingFieldFocused && isKeyboardVisible && !isSandboxCrimeanTatarKeyboardActive)
            || ProcessInfo.processInfo.arguments.contains("-qt_wrong_keyboard")
        let warningAmber = Color(red: 0.96, green: 0.58, blue: 0.04)

        return VStack(alignment: .leading, spacing: 0) {
            if showWrongKeyboardWarning {
                HStack(spacing: 8) {
                    Button {
                        HapticFeedback.playSelection()
                        activeOnboardingSheet = OnboardingSheetRequest(
                            mode: .add,
                            initialPage: keyboardAdded ? "Onboard3" : "Onboard1"
                        )
                    } label: {
                        HStack(spacing: 12) {
                            settingsIconBadge(
                                "exclamationmark.triangle.fill",
                                color: warningAmber,
                                badgeID: "testing.header.warningBadge"
                            )
                            if keyboardAdded {
                                StableLocalizedText(
                                    key: "sandbox.wrongKeyboardWarning",
                                    fontName: "GeneralSans-Semibold",
                                    fontSize: 15,
                                    color: primaryInk,
                                    lineLimit: 2
                                )
                            } else {
                                Text(Home.home_keyboard_off_key.localized + " — " + localizedInterfaceString("settings.cyrillic.addHint"))
                                    .font(InterfaceFont.font("GeneralSans-Semibold", size: 15))
                                    .foregroundStyle(primaryInk)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 4)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("testing.header.wrongKeyboardWarning")

                    Button {
                        withAnimation(animationsAllowed ? .spring(response: 0.36, dampingFraction: 0.84) : nil) {
                            isTestingExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .rotationEffect(.degrees(isTestingExpanded ? 90 : 0))
                            .frame(width: 16, height: 22, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("testing.toggle")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .id("testingSection")
            } else {
                Button {
                    withAnimation(animationsAllowed ? .spring(response: 0.36, dampingFraction: 0.84) : nil) {
                        isTestingExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 12) {
                        settingsIconBadge("keyboard.badge.eye", color: brandBlue, triggerToken: "\(isTestingExpanded)", badgeID: "testing.header.keyboard")
                        StableLocalizedText(
                            key: Onboarding.onb_check_key.rawValue,
                            table: "Onboarding",
                            fontName: "GeneralSans-Semibold",
                            fontSize: 15,
                            color: primaryInk,
                            lineLimit: 1,
                            fixedHorizontal: true
                        )
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(.tertiaryLabel))
                            .rotationEffect(.degrees(isTestingExpanded ? 90 : 0))
                            .frame(width: 16, height: 22, alignment: .center)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("testing.toggle")
                .id("testingSection")
            }

            if isTestingExpanded {
                Divider().padding(.horizontal, 14)

                VStack(alignment: .leading, spacing: 8) {
                    testingSandboxSection
                        .id("testingSandbox")
                    writingAreaSection
                        .id("writingArea")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
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
        VStack(alignment: .leading, spacing: 7) {
            // Row 1: Leading mode icon badge + Native iOS 27 Segmented Field Mode strip
            HStack(spacing: 10) {
                settingsIconBadge(
                    selectedFieldMode.icon,
                    color: brandBlue,
                    triggerToken: selectedFieldMode.rawValue,
                    badgeID: "testing.fieldMode.icon"
                )
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
                                withAnimation(animationsAllowed ? .easeInOut(duration: 0.2) : nil) {
                                    selectedFieldMode = mode
                                }
                            }
                        }
                    ),
                    apportionsWidthsByContent: false
                )
                .frame(height: 30)
            }

            // Row 2: Leading theme icon badge + Native iOS 27 Segmented Theme switcher (Light / Dark)
            HStack(spacing: 10) {
                settingsIconBadge(
                    selectedThemeMode.icon,
                    color: selectedThemeMode.isDark
                        ? Color(red: 0.35, green: 0.34, blue: 0.84)
                        : Color(red: 0.96, green: 0.58, blue: 0.04),
                    triggerToken: selectedThemeMode.rawValue,
                    badgeID: "testing.themeMode.icon"
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
                                hasManualThemeOverride = true
                                shouldAutoFocusSandbox = true
                                withAnimation(animationsAllowed ? .easeInOut(duration: 0.2) : nil) {
                                    selectedThemeMode = mode
                                }
                            }
                        }
                    ),
                    apportionsWidthsByContent: false
                )
                .frame(height: 30)
            }
        }
    }

    var writingAreaSection: some View {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let displayWPM = (statsEnabled && hasText) ? liveWPM : 0
        let displayCPM = (statsEnabled && hasText) ? liveCPM : 0
        let showsSpeedBadge = statsEnabled && (displayCPM > 0 || displayWPM > 0)

        return ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(Home.home_typing_key.localized)
                    .font(InterfaceFont.font("GeneralSans-Regular", size: Device.iPad ? 16 : 15))
                    .foregroundStyle(Color(.placeholderText))
                    .padding(.horizontal, 13)
                    .padding(.top, 11)
                    .allowsHitTesting(false)
            }
            SandboxTextView(
                text: $text,
                currentText: text,
                isFocused: $isWritingFieldFocused,
                isCrimeanTatarKeyboardActive: $isSandboxCrimeanTatarKeyboardActive,
                canUndo: $canSandboxUndo,
                canRedo: $canSandboxRedo,
                liveWPM: $liveWPM,
                liveCPM: $liveCPM,
                autoFocusOnAppear: shouldAutoFocusSandbox,
                onDidAutoFocus: {
                    if shouldAutoFocusSandbox {
                        shouldAutoFocusSandbox = false
                    }
                },
                placeholder: Home.home_typing_key.localized,
                fieldMode: selectedFieldMode,
                themeMode: selectedThemeMode,
                hasManualThemeOverride: hasManualThemeOverride,
                preferencesToken: "\(cyrillicEnabled)-\(ukrainianCyrillicLayout)-\(suggestionsEnabled)-\(wordLearningEnabled)-\(statsEnabled)",
                fontSize: Device.iPad ? 16 : 15,
                isFullAccessGranted: isFullAccessGranted
            )
            .frame(height: Device.iPad ? 92 : 70)
            .padding(.leading, 8)
            .padding(.trailing, text.isEmpty ? 8 : 34)
            .padding(.top, 4)
            .padding(.bottom, showsSpeedBadge ? 24 : 5)
            .environment(\.layoutDirection, isRtl ? .rightToLeft : .leftToRight)
        }
        .overlay(alignment: .topTrailing) {
            Button {
                text = ""
                NotificationCenter.default.post(name: Notification.Name("crh.key.clearSandboxText"), object: nil)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(secondaryInk.opacity(0.75))
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
            .padding(.trailing, 6)
            .opacity(text.isEmpty ? 0 : 1)
            .disabled(text.isEmpty)
            .accessibilityIdentifier("sandbox.clear")
        }
        .overlay(alignment: .bottomLeading) {
            if showsSpeedBadge {
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
                .padding(.vertical, 2.5)
                .background(brandBlue.opacity(0.12), in: Capsule())
                .padding(.leading, 10)
                .padding(.bottom, 6)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("sandbox.speedBadge")
            }
        }
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
    }

    private func localizedInterfaceString(_ key: String, for lang: String) -> String {
        let bundle = KeyboardPreferences.localizationBundle(for: lang)
        return bundle.localizedString(forKey: key, value: key, table: "Interface")
    }

    private func formattedActiveTime(for lang: String) -> String {
        let totalSecs = Int(max(activeSeconds, 0))
        let mins = totalSecs / 60
        let secs = totalSecs % 60
        if mins == 0 {
            return "\(secs) \(localizedInterfaceString("stats.secUnit", for: lang))"
        }
        return "\(mins) \(localizedInterfaceString("stats.minUnit", for: lang))"
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

    func compactStatPill(icon: String, color: Color, value: String, allLangValues: [String]) -> some View {
        let pillFont = Font.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit()
        return HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color)
            ZStack(alignment: .leading) {
                ForEach(allLangValues, id: \.self) { v in
                    Text(v)
                        .font(pillFont)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .hidden()
                        .accessibilityHidden(true)
                }
                Text(value)
                    .font(pillFont)
                    .foregroundStyle(primaryInk)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    func walnutBrainStatPill(color: Color, value: String, allLangValues: [String]) -> some View {
        let pillFont = Font.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit()
        return HStack(spacing: 3) {
            WalnutBrainIcon(color: color, size: 12.5)
            ZStack(alignment: .leading) {
                ForEach(allLangValues, id: \.self) { v in
                    Text(v)
                        .font(pillFont)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                        .hidden()
                        .accessibilityHidden(true)
                }
                Text(value)
                    .font(pillFont)
                    .foregroundStyle(primaryInk)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .contentTransition(.numericText())
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
        .fixedSize(horizontal: true, vertical: false)
    }

    private func openLearnedWordsDictionary() {
        HapticFeedback.playSelection()
        let fetched = KeyboardUsageStats.fetchLearnedWords()
        learnedWordsEntries = fetched
        if learnedWordsCount != fetched.count && (!CommandLine.arguments.contains("-qt_demo_stats") || !fetched.isEmpty) {
            learnedWordsCount = fetched.count
        }
        showLearnedWordsSheet = true
    }

    private func deleteLearnedWordFromSheet(_ word: String) {
        HapticFeedback.playSelection()
        let newCount = KeyboardUsageStats.deleteLearnedWord(word)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
            learnedWordsEntries.removeAll { $0.word == word }
            learnedWordsCount = newCount
        }
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
        let wordsUnit = localizedInterfaceString("stats.wordsUnit")
        let learnedWordsUnit = localizedInterfaceString("stats.learnedWordsUnit")
        let allLangs = ["crh", "uk", "en"]
        let wordsAllLangs = allLangs.map { "\(totalWords) \(localizedInterfaceString("stats.wordsUnit", for: $0))" }
        let wpmAllLangs = allLangs.map { "\(bestWPM) \(localizedInterfaceString("stats.wpmUnit", for: $0))" }
        let timeAllLangs = allLangs.map { formattedActiveTime(for: $0) }
        let learnedAllLangs = allLangs.map { "\(learnedWordsCount) \(localizedInterfaceString("stats.learnedWordsUnit", for: $0))" }

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

        let statsHeaderChevron = Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Color(.tertiaryLabel))
            .rotationEffect(.degrees(isStatsExpanded ? 90 : 0))
            .frame(width: 16, height: 22, alignment: .center)
            .opacity(statsEnabled ? 1.0 : 0.35)

        let singleRowHeader = HStack(spacing: 6) {
            settingsIconBadge(
                "chart.bar.xaxis",
                color: Color(red: 0.58, green: 0.29, blue: 0.92),
                isEnabled: statsEnabled,
                triggerToken: "\(statsEnabled)-\(isStatsExpanded)",
                badgeID: "stats.header.chart"
            )
            StableLocalizedText(
                key: "stats.title",
                fontName: "GeneralSans-Semibold",
                fontSize: 15,
                color: statsEnabled ? primaryInk : secondaryInk,
                lineLimit: 1,
                fixedHorizontal: true
            )

            Spacer(minLength: 6)

            if statsEnabled && !isStatsExpanded {
                HStack(spacing: 4.5) {
                    compactStatPill(icon: "text.word.spacing", color: brandBlue, value: "\(totalWords) \(wordsUnit)", allLangValues: wordsAllLangs)
                    compactStatPill(icon: "bolt.heart.fill", color: Color(red: 0.95, green: 0.32, blue: 0.38), value: "\(bestWPM) \(wpmUnit)", allLangValues: wpmAllLangs)
                    compactStatPill(icon: "clock.fill", color: appleGreen, value: formattedActiveTime, allLangValues: timeAllLangs)
                    walnutBrainStatPill(color: Color(red: 0.96, green: 0.58, blue: 0.04), value: "\(learnedWordsCount) \(learnedWordsUnit)", allLangValues: learnedAllLangs)
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            HStack(spacing: 8) {
                Color.clear
                    .frame(width: 58, height: 22)
                statsHeaderChevron
            }
        }

        return VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Button {
                    guard statsEnabled else { return }
                    HapticFeedback.playSelection()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        isStatsExpanded.toggle()
                    }
                } label: {
                    Group {
                        if Device.iPad {
                            singleRowHeader
                        } else {
                            ViewThatFits(in: .horizontal) {
                                singleRowHeader

                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(spacing: 8) {
                                        settingsIconBadge(
                                            "chart.bar.xaxis",
                                            color: Color(red: 0.58, green: 0.29, blue: 0.92),
                                            isEnabled: statsEnabled,
                                            triggerToken: "\(statsEnabled)-\(isStatsExpanded)",
                                            badgeID: "stats.header.chart"
                                        )
                                        StableLocalizedText(
                                            key: "stats.title",
                                            fontName: "GeneralSans-Semibold",
                                            fontSize: 15,
                                            color: statsEnabled ? primaryInk : secondaryInk,
                                            lineLimit: 1,
                                            fixedHorizontal: true
                                        )

                                        Spacer(minLength: 6)

                                        HStack(spacing: 8) {
                                            Color.clear
                                                .frame(width: 58, height: 22)
                                            statsHeaderChevron
                                        }
                                    }

                                    if statsEnabled && !isStatsExpanded {
                                        HStack(spacing: 0) {
                                            compactStatPill(icon: "text.word.spacing", color: brandBlue, value: "\(totalWords) \(wordsUnit)", allLangValues: wordsAllLangs)
                                            Spacer(minLength: 2)
                                            compactStatPill(icon: "bolt.heart.fill", color: Color(red: 0.95, green: 0.32, blue: 0.38), value: "\(bestWPM) \(wpmUnit)", allLangValues: wpmAllLangs)
                                            Spacer(minLength: 2)
                                            compactStatPill(icon: "clock.fill", color: appleGreen, value: formattedActiveTime, allLangValues: timeAllLangs)
                                            Spacer(minLength: 2)
                                            walnutBrainStatPill(color: Color(red: 0.96, green: 0.58, blue: 0.04), value: "\(learnedWordsCount) \(learnedWordsUnit)", allLangValues: learnedAllLangs)
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!statsEnabled)
                .accessibilityIdentifier("stats.expandToggle")

                Toggle("", isOn: animationsAllowed ? $statsEnabled.animation(.spring(response: 0.32, dampingFraction: 0.85)) : $statsEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.stats.toggle")
                    .padding(.trailing, 24)
            }

            if statsEnabled && isStatsExpanded {
                AnyView(
                    expandedStatisticsContentView(
                        bestWPM: bestWPM,
                        bestCPM: bestCPM,
                        wpmUnit: wpmUnit,
                        cpmUnit: cpmUnit,
                        typedChars: typedChars,
                        savedChars: savedChars,
                        effectiveManualWords: effectiveManualWords,
                        boostMultiplier: boostMultiplier,
                        speedTierLevel: speedTier.level,
                        volumeTierLevel: volumeTier.level,
                        speedSubtitle: speedSubtitle,
                        speedTierSubtitle: speedTierSubtitle,
                        volumeTierSubtitle: volumeTierSubtitle
                    )
                )
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.03), radius: 8, x: 0, y: 2)
        .onDisappear {
            Self.appearedBadgeIDs.remove("stats.header.chart")
        }
        .sheet(isPresented: $showLearnedWordsSheet) {
            AnyView(learnedWordsSheetView)
        }
        .alert(localizedInterfaceString("stats.resetConfirmTitle"), isPresented: $showResetStatsConfirmation) {
            Button(localizedInterfaceString("stats.resetConfirmAction"), role: .destructive) {
                KeyboardUsageStats.resetAll()
                liveWPM = 0
                liveCPM = 0
                learnedWordsCount = 0
                uniqueWordsCount = 0
                learnedWordsEntries = []
                refreshStatsFromAppGroup(syncSQLite: false)
            }
            Button(localizedInterfaceString("stats.cancel"), role: .cancel) {}
        } message: {
            Text(localizedInterfaceString("stats.resetConfirmMessage"))
        }
    }

    @ViewBuilder
    private func expandedStatisticsContentView(
        bestWPM: Int,
        bestCPM: Int,
        wpmUnit: String,
        cpmUnit: String,
        typedChars: Int,
        savedChars: Int,
        effectiveManualWords: Int,
        boostMultiplier: Double,
        speedTierLevel: Int,
        volumeTierLevel: Int,
        speedSubtitle: String,
        speedTierSubtitle: String,
        volumeTierSubtitle: String
    ) -> some View {
        Divider()

        let baseCharsSubtitle = String(format: localizedInterfaceString("stats.charsSubtitle"), typedChars)
        let wordsTileSubtitle = uniqueWordsCount > 0
            ? "\(baseCharsSubtitle) · \(uniqueWordsCount) \(localizedInterfaceString("stats.uniqueWordsUnit"))"
            : baseCharsSubtitle

        VStack(spacing: 10) {
            HStack(spacing: 10) {
                statTile(
                    icon: "text.word.spacing",
                    color: brandBlue,
                    title: localizedInterfaceString("stats.words"),
                    value: "\(totalWords)",
                    subtitle: wordsTileSubtitle
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
                    value: localizedInterfaceString("stats.speedTier\(speedTierLevel)"),
                    subtitle: speedTierSubtitle
                )
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("stats.speedTierTile")

                statTile(
                    icon: "flame.fill",
                    color: Color(red: 0.58, green: 0.29, blue: 0.92),
                    title: localizedInterfaceString("stats.volumeLevel"),
                    value: localizedInterfaceString("stats.volumeTier\(volumeTierLevel)"),
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

        AnyView(expandedAchievementsGridView(bestWPM: bestWPM))
    }

    @ViewBuilder
    private func expandedAchievementsGridView(bestWPM: Int) -> some View {
        if Device.iPhone {
            VStack(spacing: 8) {
                progressiveAchievementBadge(
                    icon: "flag.checkered",
                    title: localizedInterfaceString("stats.ach.firstStep"),
                    descFormat: localizedInterfaceString("stats.ach.firstStep.desc"),
                    currentValue: totalWords,
                    milestones: [10, 50, 250, 1000, 5000],
                    milestoneLabels: ["10", "50", "250", "1k", "5k"]
                )
                progressiveAchievementBadge(
                    icon: "bolt.heart.fill",
                    title: localizedInterfaceString("stats.ach.speed"),
                    descFormat: localizedInterfaceString("stats.ach.speed.desc"),
                    currentValue: bestWPM,
                    milestones: [15, 25, 40, 55, 75],
                    milestoneLabels: ["15", "25", "40", "55", "75"]
                )
                progressiveAchievementBadge(
                    icon: "book.closed.fill",
                    title: localizedInterfaceString("stats.ach.scholar"),
                    descFormat: localizedInterfaceString("stats.ach.scholar.desc"),
                    currentValue: max(learnedWordsCount, totalWords / 10),
                    milestones: [5, 25, 75, 200, 500],
                    milestoneLabels: ["5", "25", "75", "200", "500"]
                )
                progressiveAchievementBadge(
                    icon: "sparkles",
                    title: localizedInterfaceString("stats.ach.wisdom"),
                    descFormat: localizedInterfaceString("stats.ach.wisdom.desc"),
                    currentValue: phrasesInserted,
                    milestones: [1, 5, 15, 35, 75],
                    milestoneLabels: ["1", "5", "15", "35", "75"]
                )
            }
        } else {
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    progressiveAchievementBadge(
                        icon: "flag.checkered",
                        title: localizedInterfaceString("stats.ach.firstStep"),
                        descFormat: localizedInterfaceString("stats.ach.firstStep.desc"),
                        currentValue: totalWords,
                        milestones: [10, 50, 250, 1000, 5000],
                        milestoneLabels: ["10", "50", "250", "1k", "5k"]
                    )
                    progressiveAchievementBadge(
                        icon: "bolt.heart.fill",
                        title: localizedInterfaceString("stats.ach.speed"),
                        descFormat: localizedInterfaceString("stats.ach.speed.desc"),
                        currentValue: bestWPM,
                        milestones: [15, 25, 40, 55, 75],
                        milestoneLabels: ["15", "25", "40", "55", "75"]
                    )
                }
                HStack(spacing: 10) {
                    progressiveAchievementBadge(
                        icon: "book.closed.fill",
                        title: localizedInterfaceString("stats.ach.scholar"),
                        descFormat: localizedInterfaceString("stats.ach.scholar.desc"),
                        currentValue: max(learnedWordsCount, totalWords / 10),
                        milestones: [5, 25, 75, 200, 500],
                        milestoneLabels: ["5", "25", "75", "200", "500"]
                    )
                    progressiveAchievementBadge(
                        icon: "sparkles",
                        title: localizedInterfaceString("stats.ach.wisdom"),
                        descFormat: localizedInterfaceString("stats.ach.wisdom.desc"),
                        currentValue: phrasesInserted,
                        milestones: [1, 5, 15, 35, 75],
                        milestoneLabels: ["1", "5", "15", "35", "75"]
                    )
                }
            }
        }
    }

    func statTile(icon: String, color: Color, title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(color)
                Text(title)
                    .font(InterfaceFont.font("GeneralSans-Medium", size: Device.iPhone ? 11.5 : 12))
                    .foregroundStyle(secondaryInk)
                    .lineLimit(1)
            }
            Text(value)
                .font(.system(size: Device.iPhone ? 12.5 : 14.5, weight: .bold, design: .rounded))
                .foregroundStyle(primaryInk)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    func walnutBrainStatTile(color: Color, title: String, value: String, subtitle: String) -> some View {
        Button {
            openLearnedWordsDictionary()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    WalnutBrainIcon(color: color, size: 13)
                    Text(title)
                        .font(InterfaceFont.font("GeneralSans-Medium", size: Device.iPhone ? 11.5 : 12))
                        .foregroundStyle(secondaryInk)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(secondaryInk.opacity(0.75))
                        .accessibilityHidden(true)
                }
                Text(value)
                    .font(.system(size: Device.iPhone ? 12.5 : 14.5, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryInk)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var learnedWordsSheetView: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    walnutBrainIconBadge(
                        color: Color(red: 0.96, green: 0.58, blue: 0.04),
                        isEnabled: wordLearningEnabled
                    )
                    Text(localizedInterfaceString("settings.wordLearning"))
                        .font(InterfaceFont.font("GeneralSans-Medium", size: 15.5))
                        .foregroundStyle(primaryInk)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Toggle("", isOn: $wordLearningEnabled)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("stats.learnedWords.wordLearningToggle")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 11)
                .background(
                    Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 6)

                if learnedWordsEntries.isEmpty {
                    VStack(spacing: 12) {
                        WalnutBrainIcon(color: Color(red: 0.96, green: 0.58, blue: 0.04), size: 42)
                            .padding(.bottom, 4)
                        Text(localizedInterfaceString("stats.learnedWords.emptyTitle"))
                            .font(InterfaceFont.font("GeneralSans-Semibold", size: 17))
                            .foregroundStyle(primaryInk)
                            .multilineTextAlignment(.center)
                        Text(localizedInterfaceString("stats.learnedWords.emptyDesc"))
                            .font(InterfaceFont.font("GeneralSans-Regular", size: 14))
                            .foregroundStyle(secondaryInk)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 28)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("stats.learnedWords.emptyState")
                } else {
                    List {
                        ForEach(learnedWordsEntries, id: \.word) { item in
                            HStack(spacing: 10) {
                                WalnutBrainIcon(color: Color(red: 0.96, green: 0.58, blue: 0.04), size: 14)
                                Text(item.word)
                                    .font(InterfaceFont.font("GeneralSans-Medium", size: 16))
                                    .foregroundStyle(primaryInk)
                                    .accessibilityIdentifier("stats.learnedWords.row.\(item.word)")
                                Spacer(minLength: 8)
                                if item.freq > 1 {
                                    Text("×\(item.freq)")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                        .foregroundStyle(secondaryInk)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 2.5)
                                        .background(Color(.tertiarySystemFill), in: Capsule())
                                }
                                Button(role: .destructive) {
                                    deleteLearnedWordFromSheet(item.word)
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color.red)
                                        .frame(width: 30, height: 30)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel(localizedInterfaceString("stats.learnedWords.delete"))
                                .accessibilityIdentifier("stats.learnedWords.delete.\(item.word)")
                            }
                        }
                        .onDelete { offsets in
                            let wordsToDelete = offsets.map { learnedWordsEntries[$0].word }
                            for w in wordsToDelete {
                                deleteLearnedWordFromSheet(w)
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .accessibilityIdentifier("stats.learnedWords.list")
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(localizedInterfaceString("stats.learnedWordsSubtitle"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !learnedWordsEntries.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) {
                            HapticFeedback.playSelection()
                            KeyboardUsageStats.clearAllLearnedWords()
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                                learnedWordsEntries = []
                                learnedWordsCount = 0
                            }
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.red)
                        }
                        .accessibilityLabel(localizedInterfaceString("stats.learnedWords.clearAll"))
                        .accessibilityIdentifier("stats.learnedWords.clearAllButton")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showLearnedWordsSheet = false
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .accessibilityLabel(localizedInterfaceString("stats.learnedWords.done"))
                    .accessibilityIdentifier("stats.learnedWords.doneButton")
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    func progressiveAchievementBadge(
        icon: String,
        title: String,
        descFormat: String,
        currentValue: Int,
        milestones: [Int],
        milestoneLabels: [String]
    ) -> some View {
        let totalLevels = max(milestones.count, 1)
        let completedLevels = milestones.filter { currentValue >= $0 }.count
        let isMaxed = completedLevels >= totalLevels
        let activeIndex = min(completedLevels, totalLevels - 1)
        let displayLevel = min(completedLevels + 1, totalLevels)
        let currentTarget = milestones[activeIndex]
        let prevThreshold = activeIndex > 0 ? milestones[activeIndex - 1] : 0
        let stageSpan = max(currentTarget - prevThreshold, 1)
        let stageProgress: Double = isMaxed
            ? 1.0
            : min(max(Double(currentValue - prevThreshold) / Double(stageSpan), 0.0), 1.0)
        let hasUnlockedAny = completedLevels > 0
        let accentColor = hasUnlockedAny ? appleGreen : brandBlue
        let levelBadgeText = String(format: localizedInterfaceString("stats.ach.levelBadge"), displayLevel, totalLevels)
        let subtitleText = String(format: descFormat, currentValue, currentTarget)

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: isMaxed ? "checkmark.seal.fill" : icon)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text(title)
                    .font(InterfaceFont.font("GeneralSans-Semibold", size: 12.5))
                    .foregroundStyle(primaryInk)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(levelBadgeText)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(accentColor)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(accentColor.opacity(0.14), in: Capsule())
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text(subtitleText)
                .font(InterfaceFont.font("GeneralSans-Regular", size: 11))
                .foregroundStyle(secondaryInk)
                .lineLimit(1)
                .contentTransition(.numericText())

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(accentColor)
                        .frame(width: max(geo.size.width * CGFloat(min(max(stageProgress, currentValue > 0 ? 0.08 : 0.04), 1.0)), 4))
                }
            }
            .frame(height: 4)

            HStack(spacing: 4) {
                ForEach(Array(milestoneLabels.enumerated()), id: \.offset) { idx, label in
                    let isDone = idx < completedLevels
                    let isCurrent = idx == activeIndex && !isMaxed
                    Text(isDone ? "✓\(label)" : label)
                        .font(.system(size: 9.5, weight: (isDone || isCurrent) ? .bold : .medium, design: .rounded))
                        .foregroundStyle(isDone ? appleGreen : (isCurrent ? brandBlue : secondaryInk))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2.5)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(isDone ? appleGreen.opacity(0.14) : (isCurrent ? brandBlue.opacity(0.13) : Color.primary.opacity(0.05)))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(isCurrent ? brandBlue.opacity(0.45) : Color.clear, lineWidth: 0.8)
                        )
                }
            }
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
                .strokeBorder(hasUnlockedAny ? appleGreen.opacity(0.42) : Color.clear, lineWidth: 1)
        )
    }

    var isRtl: Bool {
        cachedIsRtl
    }

    var isCyrillicKeyboardAdded: Bool {
        cyrillicStatus == .enabled
    }

    var isUkrainianKeyboardAdded: Bool {
        ukrainianStatus == .enabled
    }

    var userUsesCyrillicEnvironment: Bool {
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

    var isPrimaryKeyboardAdded: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-qt_keyboard_missing") {
            return false
        }
        if args.contains("-qt_keyboard_added") {
            return true
        }
        let languages = UITextInputMode.activeInputModes.compactMap(\.primaryLanguage)
            .map { $0.replacingOccurrences(of: "_", with: "-").lowercased() }
        let hasActiveLatinMode = languages.contains { $0 == "crh" || $0.hasPrefix("crh-latn") }
        let hasAnyActiveCRHMode = languages.contains { $0 == "crh" || $0.hasPrefix("crh-") }
        if hasActiveLatinMode {
            return true
        }
        if !hasAnyActiveCRHMode && isWritingFieldFocused && isKeyboardVisible && !isSandboxCrimeanTatarKeyboardActive && !args.contains("-qt_wrong_keyboard") {
            return false
        }
        if Self.isUITestingEnvironment || args.contains("-qt_demo_stats") {
            return true
        }
        if SystemKeyboardSettings.isPrimaryKeyboardExtensionEnabled {
            return true
        }
        if primaryExtensionSeen || KeyboardPreferences.defaults.bool(forKey: "crh.key.primaryExtensionSeen") {
            return true
        }
        return false
    }

    var isFullAccessGranted: Bool {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-qt_full_access_missing") {
            return false
        }
        if args.contains("-qt_full_access_granted") {
            return true
        }
        if Self.isUITestingEnvironment || args.contains("-qt_demo_stats") {
            return true
        }
        if !isPrimaryKeyboardAdded && !isCyrillicKeyboardAdded && !isUkrainianKeyboardAdded {
            return false
        }
        return cachedIsFullAccessEnabled
    }

    var areAllIndicatorsEnabled: Bool {
        isFullAccessGranted
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
    var fixedWidth: CGFloat? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> AccessibleUISegmentedControl {
        let control = AccessibleUISegmentedControl(items: items.map(\.title))
        control.apportionsSegmentWidthsByContent = apportionsWidthsByContent
        control.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 13, weight: .medium)], for: .normal)
        control.setTitleTextAttributes([.font: UIFont.systemFont(ofSize: 13, weight: .semibold)], for: .selected)
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
        if let fixedWidth {
            return CGSize(width: fixedWidth, height: height)
        }
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
        configureSegmentLabels(in: self)
        applySegmentAccessibilityIdentifiers()
    }

    private func configureSegmentLabels(in view: UIView) {
        for subview in view.subviews {
            if let label = subview as? UILabel {
                label.adjustsFontSizeToFitWidth = true
                label.minimumScaleFactor = 0.82
                label.allowsDefaultTighteningForTruncation = true
            }
            configureSegmentLabels(in: subview)
        }
    }

    func applySegmentAccessibilityIdentifiers() {
        let count = accessibilityElementCount()
        if count == segmentIdentifiers.count {
            for index in segmentIdentifiers.indices {
                if let element = accessibilityElement(at: index) as? UIAccessibilityIdentification {
                    element.accessibilityIdentifier = segmentIdentifiers[index]
                }
            }
        }
        let segmentViews = subviews
            .filter { $0.frame.width > 10 }
            .sorted { $0.frame.minX < $1.frame.minX }
        guard segmentViews.count == segmentIdentifiers.count else { return }
        for (index, segView) in segmentViews.enumerated() {
            segView.accessibilityIdentifier = segmentIdentifiers[index]
        }
    }

}

/// Renders a localized text whose height is the tallest of all interface languages at the current width,
/// computing the language-specific font (`GeneralSans` for `crh`/`en`, `SF Pro` for `uk`) per language
/// so switching the interface language never makes the surrounding row or icon jump by even 1 pt.
struct StableLocalizedText: View {
    let key: String
    var table = "Interface"
    var fontName: String = "GeneralSans-Regular"
    var fontSize: CGFloat = 15
    var font: Font? = nil
    let color: Color
    var lineLimit: Int? = nil
    var minimumScaleFactor: CGFloat = 1.0
    var fixedHorizontal: Bool = false
    var customStrings: [String: String]? = nil

    @AppStorage(KeyboardPreferences.languageKey, store: KeyboardPreferences.defaults) private var language = "crh"

    private static let languages = ["crh", "uk", "en"]

    private func resolvedString(for language: String) -> String {
        if let custom = customStrings?[language] {
            return custom
        }
        let bundle = KeyboardPreferences.localizationBundle(for: language)
        return bundle.localizedString(forKey: key, value: key, table: table)
    }

    private var activeString: String {
        let currentLang = language
        if let customStrings {
            return customStrings[currentLang] ?? customStrings["crh"] ?? key
        }
        return KeyboardPreferences.localizationBundle(for: currentLang).localizedString(forKey: key, value: key, table: table)
    }

    private func renderText(_ raw: String) -> Text {
        let parts = raw.components(separatedBy: "{{globe}}")
        guard parts.count > 1 else {
            return Text(raw)
        }
        var result = Text(parts[0])
        for part in parts.dropFirst() {
            result = result + Text(Image(systemName: "globe")) + Text(part)
        }
        return result
    }

    var body: some View {
        let currentText = activeString
        ZStack(alignment: .leading) {
            ForEach(Self.languages, id: \.self) { lang in
                let sample = resolvedString(for: lang)
                renderText(sample)
                    .font(font ?? InterfaceFont.font(fontName, size: fontSize, text: sample))
                    .lineLimit(lineLimit)
                    .minimumScaleFactor(minimumScaleFactor)
                    .fixedSize(horizontal: fixedHorizontal, vertical: true)
                    .multilineTextAlignment(.leading)
                    .hidden()
                    .accessibilityHidden(true)
            }
            renderText(currentText)
                .font(font ?? InterfaceFont.font(fontName, size: fontSize, text: currentText))
                .foregroundStyle(color)
                .lineLimit(lineLimit)
                .minimumScaleFactor(minimumScaleFactor)
                .fixedSize(horizontal: fixedHorizontal, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: fixedHorizontal ? nil : .infinity, alignment: .leading)
    }
}

/// Top-down symmetrical two-hemisphere walnut-style brain vector shape with cortical folds.
private struct WalnutBrainShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        // Left hemisphere outer walnut lobe
        p.move(to: CGPoint(x: w * 0.46, y: h * 0.14))
        p.addCurve(
            to: CGPoint(x: w * 0.12, y: h * 0.36),
            control1: CGPoint(x: w * 0.28, y: h * 0.05),
            control2: CGPoint(x: w * 0.12, y: h * 0.19)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.11, y: h * 0.66),
            control1: CGPoint(x: w * 0.05, y: h * 0.44),
            control2: CGPoint(x: w * 0.05, y: h * 0.58)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.46, y: h * 0.88),
            control1: CGPoint(x: w * 0.13, y: h * 0.84),
            control2: CGPoint(x: w * 0.30, y: h * 0.94)
        )
        p.closeSubpath()

        // Right hemisphere outer walnut lobe
        p.move(to: CGPoint(x: w * 0.54, y: h * 0.14))
        p.addCurve(
            to: CGPoint(x: w * 0.88, y: h * 0.36),
            control1: CGPoint(x: w * 0.72, y: h * 0.05),
            control2: CGPoint(x: w * 0.88, y: h * 0.19)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.89, y: h * 0.66),
            control1: CGPoint(x: w * 0.95, y: h * 0.44),
            control2: CGPoint(x: w * 0.95, y: h * 0.58)
        )
        p.addCurve(
            to: CGPoint(x: w * 0.54, y: h * 0.88),
            control1: CGPoint(x: w * 0.87, y: h * 0.84),
            control2: CGPoint(x: w * 0.70, y: h * 0.94)
        )
        p.closeSubpath()

        // Walnut gyri/sulci inner folds
        p.move(to: CGPoint(x: w * 0.44, y: h * 0.33))
        p.addQuadCurve(to: CGPoint(x: w * 0.21, y: h * 0.39), control: CGPoint(x: w * 0.30, y: h * 0.26))
        p.move(to: CGPoint(x: w * 0.16, y: h * 0.53))
        p.addQuadCurve(to: CGPoint(x: w * 0.43, y: h * 0.54), control: CGPoint(x: w * 0.30, y: h * 0.46))
        p.move(to: CGPoint(x: w * 0.44, y: h * 0.71))
        p.addQuadCurve(to: CGPoint(x: w * 0.22, y: h * 0.69), control: CGPoint(x: w * 0.31, y: h * 0.77))

        p.move(to: CGPoint(x: w * 0.56, y: h * 0.33))
        p.addQuadCurve(to: CGPoint(x: w * 0.79, y: h * 0.39), control: CGPoint(x: w * 0.70, y: h * 0.26))
        p.move(to: CGPoint(x: w * 0.84, y: h * 0.53))
        p.addQuadCurve(to: CGPoint(x: w * 0.57, y: h * 0.54), control: CGPoint(x: w * 0.70, y: h * 0.46))
        p.move(to: CGPoint(x: w * 0.56, y: h * 0.71))
        p.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.69), control: CGPoint(x: w * 0.69, y: h * 0.77))

        return p
    }
}

/// Top-down symmetrical two-hemisphere walnut-style brain vector icon with cortical folds.
private struct WalnutBrainIcon: View {
    let color: Color
    var size: CGFloat = 16
    var drawProgress: CGFloat = 1.0

    var body: some View {
        WalnutBrainShape()
            .trim(from: 0, to: drawProgress)
            .stroke(
                color,
                style: StrokeStyle(
                    lineWidth: max(size * 0.092, 1.15),
                    lineCap: .round,
                    lineJoin: .round
                )
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Vector line-art shapes for settings & sandbox icons so each icon draws cleanly from strokes inside a stationary badge.
private struct SettingsLineArtIconShape: Shape {
    let systemName: String

    static func iconFrameSize(for systemName: String) -> CGFloat {
        switch systemName {
        case "lang.crh.tamga", "lang.uk.tryzub", "lang.en.unionjack":
            return 17.5
        default:
            return 16.5
        }
    }

    static func strokeStyle(for systemName: String, frameSize: CGFloat) -> StrokeStyle {
        switch systemName {
        case "lang.crh.tamga":
            return StrokeStyle(lineWidth: 1.65, lineCap: .round, lineJoin: .round)
        case "lang.uk.tryzub", "lang.en.unionjack":
            return StrokeStyle(lineWidth: 1.55, lineCap: .round, lineJoin: .round)
        default:
            return StrokeStyle(lineWidth: 1.55, lineCap: .round, lineJoin: .round)
        }
    }

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        switch systemName {
        case "lang.crh.tamga":
            // Friendly rounded-corner Crimean Tatar Taraq Tamğa line-drawing (9:5 proportions with soft rounded corners)
            let scale = min(w / 9.0, h / 5.6)
            let drawW = scale * 9.0
            let drawH = scale * 5.0
            let ox = rect.minX + (w - drawW) * 0.5
            let oy = rect.minY + (h - drawH) * 0.5
            func pt(_ gx: CGFloat, _ gy: CGFloat) -> CGPoint {
                CGPoint(x: ox + gx * scale, y: oy + gy * scale)
            }
            let cornerR = scale * 0.55
            // 1. Outer arch with soft rounded bends and feet
            p.move(to: pt(0.4, 3.55))
            p.addArc(tangent1End: pt(1.55, 3.55), tangent2End: pt(1.55, 0.55), radius: cornerR * 0.65)
            p.addArc(tangent1End: pt(1.55, 0.55), tangent2End: pt(7.45, 0.55), radius: cornerR)
            p.addArc(tangent1End: pt(7.45, 0.55), tangent2End: pt(7.45, 3.55), radius: cornerR)
            p.addArc(tangent1End: pt(7.45, 3.55), tangent2End: pt(8.6, 3.55), radius: cornerR * 0.65)
            p.addLine(to: pt(8.6, 3.55))
            // 2. Central vertical stem
            p.move(to: pt(4.5, 0.55))
            p.addLine(to: pt(4.5, 4.55))
            // 3. Central bottom crossbar
            p.move(to: pt(3.35, 4.55))
            p.addLine(to: pt(5.65, 4.55))

        case "lang.uk.tryzub":
            // Friendly rounded-stroke Ukrainian Tryzub centerline drawing (single-line progressive sketch)
            let cx = w * 0.50
            func pt(_ dx: CGFloat, _ ny: CGFloat, sign: CGFloat = 1.0) -> CGPoint {
                CGPoint(x: cx + sign * dx * w, y: ny * h)
            }
            // 1. Left & right outer wings with soft rounded curves down to the base
            for sign: CGFloat in [-1.0, 1.0] {
                p.move(to: pt(0.0, 0.77, sign: sign))
                p.addQuadCurve(to: pt(0.37, 0.72, sign: sign), control: pt(0.32, 0.77, sign: sign))
                p.addLine(to: pt(0.37, 0.20, sign: sign))
                p.addCurve(
                    to: pt(0.16, 0.55, sign: sign),
                    control1: pt(0.21, 0.27, sign: sign),
                    control2: pt(0.18, 0.42, sign: sign)
                )
                p.addCurve(
                    to: pt(0.0, 0.72, sign: sign),
                    control1: pt(0.28, 0.53, sign: sign),
                    control2: pt(0.24, 0.70, sign: sign)
                )
                // Side crossbar tie
                p.move(to: pt(0.19, 0.58, sign: sign))
                p.addLine(to: pt(0.37, 0.58, sign: sign))
            }
            // 2. Central spear with soft rounded loop and bottom finial
            p.move(to: pt(0.0, 0.10))
            p.addCurve(
                to: pt(0.0, 0.54, sign: -1.0),
                control1: pt(0.12, 0.24, sign: -1.0),
                control2: pt(0.10, 0.44, sign: -1.0)
            )
            p.addCurve(
                to: pt(0.0, 0.10, sign: 1.0),
                control1: pt(0.10, 0.44, sign: 1.0),
                control2: pt(0.12, 0.24, sign: 1.0)
            )
            p.move(to: pt(0.0, 0.54))
            p.addLine(to: pt(0.0, 0.90))

        case "lang.en.unionjack":
            // Friendly rounded-corner UK badge sketch matching the unified line-art icon family
            let x0 = w * 0.08, x1 = w * 0.92
            let y0 = h * 0.17, y1 = h * 0.83
            let cx = w * 0.50, cy = h * 0.50
            let r = min(w, h) * 0.18

            // 1. Soft rounded squircle frame
            p.addRoundedRect(
                in: CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0),
                cornerSize: CGSize(width: r, height: r)
            )
            // 2. Central St George's Cross (clean single rounded strokes)
            p.move(to: CGPoint(x: cx, y: y0 + h * 0.02))
            p.addLine(to: CGPoint(x: cx, y: y1 - h * 0.02))
            p.move(to: CGPoint(x: x0 + w * 0.02, y: cy))
            p.addLine(to: CGPoint(x: x1 - w * 0.02, y: cy))
            // 3. Diagonal quadrant saltire rays with breathing gap around the center intersection
            let gx = w * 0.14
            let gy = h * 0.12
            let ix = w * 0.09
            let iy = h * 0.08
            p.move(to: CGPoint(x: x0 + ix, y: y0 + iy))
            p.addLine(to: CGPoint(x: cx - gx, y: cy - gy))
            p.move(to: CGPoint(x: cx + gx, y: cy + gy))
            p.addLine(to: CGPoint(x: x1 - ix, y: y1 - iy))
            p.move(to: CGPoint(x: x1 - ix, y: y0 + iy))
            p.addLine(to: CGPoint(x: cx + gx, y: cy - gy))
            p.move(to: CGPoint(x: cx - gx, y: cy + gy))
            p.addLine(to: CGPoint(x: x0 + ix, y: y1 - iy))

        case "globe":
            let r = min(w, h) * 0.42
            let c = CGPoint(x: w * 0.5, y: h * 0.5)
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            p.addEllipse(in: CGRect(x: c.x - r * 0.48, y: c.y - r, width: r * 0.96, height: r * 2))
            p.move(to: CGPoint(x: c.x - r, y: c.y))
            p.addLine(to: CGPoint(x: c.x + r, y: c.y))
            p.move(to: CGPoint(x: c.x - r * 0.84, y: c.y - r * 0.45))
            p.addQuadCurve(to: CGPoint(x: c.x + r * 0.84, y: c.y - r * 0.45), control: CGPoint(x: c.x, y: c.y - r * 0.30))
            p.move(to: CGPoint(x: c.x - r * 0.84, y: c.y + r * 0.45))
            p.addQuadCurve(to: CGPoint(x: c.x + r * 0.84, y: c.y + r * 0.45), control: CGPoint(x: c.x, y: c.y + r * 0.30))

        case "sparkles":
            func addStar(cx: CGFloat, cy: CGFloat, r: CGFloat) {
                p.move(to: CGPoint(x: cx, y: cy - r))
                p.addQuadCurve(to: CGPoint(x: cx + r, y: cy), control: CGPoint(x: cx, y: cy))
                p.addQuadCurve(to: CGPoint(x: cx, y: cy + r), control: CGPoint(x: cx, y: cy))
                p.addQuadCurve(to: CGPoint(x: cx - r, y: cy), control: CGPoint(x: cx, y: cy))
                p.addQuadCurve(to: CGPoint(x: cx, y: cy - r), control: CGPoint(x: cx, y: cy))
            }
            addStar(cx: w * 0.42, cy: h * 0.46, r: min(w, h) * 0.34)
            addStar(cx: w * 0.77, cy: h * 0.24, r: min(w, h) * 0.16)
            addStar(cx: w * 0.75, cy: h * 0.76, r: min(w, h) * 0.14)

        case "chart.bar.xaxis":
            p.move(to: CGPoint(x: w * 0.12, y: h * 0.84))
            p.addLine(to: CGPoint(x: w * 0.88, y: h * 0.84))
            p.addRoundedRect(in: CGRect(x: w * 0.18, y: h * 0.52, width: w * 0.14, height: h * 0.32), cornerSize: CGSize(width: 1.5, height: 1.5))
            p.addRoundedRect(in: CGRect(x: w * 0.43, y: h * 0.32, width: w * 0.14, height: h * 0.52), cornerSize: CGSize(width: 1.5, height: 1.5))
            p.addRoundedRect(in: CGRect(x: w * 0.68, y: h * 0.16, width: w * 0.14, height: h * 0.68), cornerSize: CGSize(width: 1.5, height: 1.5))

        case "keyboard.badge.eye":
            p.addRoundedRect(in: CGRect(x: w * 0.08, y: h * 0.22, width: w * 0.84, height: h * 0.56), cornerSize: CGSize(width: 3, height: 3))
            for col in 0..<4 {
                let x = w * (0.21 + CGFloat(col) * 0.19)
                p.move(to: CGPoint(x: x - w * 0.04, y: h * 0.38))
                p.addLine(to: CGPoint(x: x + w * 0.04, y: h * 0.38))
                p.move(to: CGPoint(x: x - w * 0.04, y: h * 0.51))
                p.addLine(to: CGPoint(x: x + w * 0.04, y: h * 0.51))
            }
            p.move(to: CGPoint(x: w * 0.28, y: h * 0.64))
            p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.64))

        case "gearshape":
            let c = CGPoint(x: w * 0.5, y: h * 0.5)
            let innerR = min(w, h) * 0.165
            let rootR = min(w, h) * 0.295
            let tipR = min(w, h) * 0.415
            p.addEllipse(in: CGRect(x: c.x - innerR, y: c.y - innerR, width: innerR * 2, height: innerR * 2))
            let teeth = 8
            for i in 0..<teeth {
                let baseAngle = Double(i) * (2.0 * .pi / Double(teeth))
                let a0 = baseAngle - 0.17
                let a1 = baseAngle - 0.10
                let a2 = baseAngle + 0.10
                let a3 = baseAngle + 0.17
                let nextBase = Double(i + 1) * (2.0 * .pi / Double(teeth)) - 0.17
                let pt0 = CGPoint(x: c.x + CGFloat(cos(a0)) * rootR, y: c.y + CGFloat(sin(a0)) * rootR)
                let pt1 = CGPoint(x: c.x + CGFloat(cos(a1)) * tipR, y: c.y + CGFloat(sin(a1)) * tipR)
                let pt2 = CGPoint(x: c.x + CGFloat(cos(a2)) * tipR, y: c.y + CGFloat(sin(a2)) * tipR)
                let pt3 = CGPoint(x: c.x + CGFloat(cos(a3)) * rootR, y: c.y + CGFloat(sin(a3)) * rootR)
                let ptNext = CGPoint(x: c.x + CGFloat(cos(nextBase)) * rootR, y: c.y + CGFloat(sin(nextBase)) * rootR)
                if i == 0 {
                    p.move(to: pt0)
                }
                p.addLine(to: pt1)
                p.addLine(to: pt2)
                p.addLine(to: pt3)
                p.addLine(to: ptNext)
            }
            p.closeSubpath()

        case "slider.horizontal.3":
            let rows: [(y: CGFloat, knobX: CGFloat)] = [
                (h * 0.24, w * 0.34),
                (h * 0.50, w * 0.66),
                (h * 0.76, w * 0.42)
            ]
            let r = min(w, h) * 0.095
            for row in rows {
                p.move(to: CGPoint(x: w * 0.12, y: row.y))
                p.addLine(to: CGPoint(x: max(w * 0.12, row.knobX - r), y: row.y))
                p.addEllipse(in: CGRect(x: row.knobX - r, y: row.y - r, width: r * 2, height: r * 2))
                p.move(to: CGPoint(x: min(w * 0.88, row.knobX + r), y: row.y))
                p.addLine(to: CGPoint(x: w * 0.88, y: row.y))
            }

        case "character.cursor.ibeam":
            p.move(to: CGPoint(x: w * 0.14, y: h * 0.74))
            p.addLine(to: CGPoint(x: w * 0.34, y: h * 0.24))
            p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.74))
            p.move(to: CGPoint(x: w * 0.20, y: h * 0.57))
            p.addLine(to: CGPoint(x: w * 0.48, y: h * 0.57))
            p.move(to: CGPoint(x: w * 0.76, y: h * 0.18))
            p.addLine(to: CGPoint(x: w * 0.76, y: h * 0.82))
            p.move(to: CGPoint(x: w * 0.66, y: h * 0.18))
            p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.18))
            p.move(to: CGPoint(x: w * 0.66, y: h * 0.82))
            p.addLine(to: CGPoint(x: w * 0.86, y: h * 0.82))

        case "magnifyingglass":
            let r = min(w, h) * 0.28
            let c = CGPoint(x: w * 0.42, y: h * 0.42)
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            p.move(to: CGPoint(x: c.x + r * 0.72, y: c.y + r * 0.72))
            p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.85))

        case "at":
            let c = CGPoint(x: w * 0.5, y: h * 0.5)
            let innerR = min(w, h) * 0.16
            let outerR = min(w, h) * 0.40
            p.addEllipse(in: CGRect(x: c.x - innerR, y: c.y - innerR, width: innerR * 2, height: innerR * 2))
            p.move(to: CGPoint(x: c.x + innerR, y: c.y - innerR))
            p.addLine(to: CGPoint(x: c.x + innerR, y: c.y + innerR * 0.85))
            p.addQuadCurve(
                to: CGPoint(x: c.x + outerR * 0.95, y: c.y),
                control: CGPoint(x: c.x + outerR * 0.85, y: c.y + innerR * 1.45)
            )
            p.addArc(center: c, radius: outerR, startAngle: .degrees(0), endAngle: .degrees(45), clockwise: true)

        case "globe.americas.fill", "link":
            let r = min(w, h) * 0.42
            let c = CGPoint(x: w * 0.5, y: h * 0.5)
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            p.move(to: CGPoint(x: c.x - r * 0.35, y: c.y - r * 0.82))
            p.addQuadCurve(to: CGPoint(x: c.x - r * 0.10, y: c.y - r * 0.10), control: CGPoint(x: c.x + r * 0.15, y: c.y - r * 0.45))
            p.addQuadCurve(to: CGPoint(x: c.x + r * 0.28, y: c.y + r * 0.78), control: CGPoint(x: c.x + r * 0.42, y: c.y + r * 0.25))

        case "textformat.123":
            // "1"
            p.move(to: CGPoint(x: w * 0.14, y: h * 0.36))
            p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.28))
            p.addLine(to: CGPoint(x: w * 0.22, y: h * 0.72))
            // "2"
            p.move(to: CGPoint(x: w * 0.38, y: h * 0.37))
            p.addQuadCurve(to: CGPoint(x: w * 0.58, y: h * 0.38), control: CGPoint(x: w * 0.48, y: h * 0.22))
            p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.72))
            p.addLine(to: CGPoint(x: w * 0.58, y: h * 0.72))
            // "3"
            p.move(to: CGPoint(x: w * 0.70, y: h * 0.32))
            p.addQuadCurve(to: CGPoint(x: w * 0.78, y: h * 0.50), control: CGPoint(x: w * 0.92, y: h * 0.34))
            p.addQuadCurve(to: CGPoint(x: w * 0.70, y: h * 0.68), control: CGPoint(x: w * 0.92, y: h * 0.66))

        case "sun.max.fill":
            let c = CGPoint(x: w * 0.5, y: h * 0.5)
            let r = min(w, h) * 0.21
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            for i in 0..<8 {
                let angle = Double(i) * (.pi / 4.0)
                let r1 = min(w, h) * 0.31
                let r2 = min(w, h) * 0.43
                p.move(to: CGPoint(x: c.x + CGFloat(cos(angle)) * r1, y: c.y + CGFloat(sin(angle)) * r1))
                p.addLine(to: CGPoint(x: c.x + CGFloat(cos(angle)) * r2, y: c.y + CGFloat(sin(angle)) * r2))
            }

        case "exclamationmark.triangle.fill", "exclamationmark.triangle":
            let top = CGPoint(x: w * 0.50, y: h * 0.12)
            let right = CGPoint(x: w * 0.90, y: h * 0.84)
            let left = CGPoint(x: w * 0.10, y: h * 0.84)
            let bottomMid = CGPoint(x: w * 0.50, y: h * 0.84)
            let cornerR = min(w, h) * 0.08
            p.move(to: bottomMid)
            p.addArc(tangent1End: left, tangent2End: top, radius: cornerR)
            p.addArc(tangent1End: top, tangent2End: right, radius: cornerR)
            p.addArc(tangent1End: right, tangent2End: left, radius: cornerR)
            p.closeSubpath()
            // Exclamation mark stem & dot
            p.move(to: CGPoint(x: w * 0.50, y: h * 0.38))
            p.addLine(to: CGPoint(x: w * 0.50, y: h * 0.58))
            let dotR = min(w, h) * 0.032
            p.addEllipse(in: CGRect(x: w * 0.50 - dotR, y: h * 0.71 - dotR, width: dotR * 2, height: dotR * 2))

        case "checkmark.circle.fill", "checkmark.circle":
            let c = CGPoint(x: w * 0.50, y: h * 0.50)
            let r = min(w, h) * 0.40
            p.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
            p.move(to: CGPoint(x: w * 0.32, y: h * 0.52))
            p.addLine(to: CGPoint(x: w * 0.45, y: h * 0.65))
            p.addLine(to: CGPoint(x: w * 0.69, y: h * 0.37))

        case "lock.open.fill", "lock.open":
            p.addRoundedRect(
                in: CGRect(x: w * 0.22, y: h * 0.46, width: w * 0.56, height: h * 0.40),
                cornerSize: CGSize(width: 2.5, height: 2.5)
            )
            p.move(to: CGPoint(x: w * 0.36, y: h * 0.46))
            p.addLine(to: CGPoint(x: w * 0.36, y: h * 0.28))
            p.addArc(
                center: CGPoint(x: w * 0.50, y: h * 0.28),
                radius: w * 0.14,
                startAngle: .degrees(180),
                endAngle: .degrees(350),
                clockwise: false
            )

        default: // "moon.stars.fill", "moon.fill"
            let c = CGPoint(x: w * 0.48, y: h * 0.50)
            let r = min(w, h) * 0.34
            p.addArc(center: c, radius: r, startAngle: .degrees(35), endAngle: .degrees(305), clockwise: false)
            p.addQuadCurve(
                to: CGPoint(x: c.x + r * CGFloat(cos(35.0 * .pi / 180.0)), y: c.y + r * CGFloat(sin(35.0 * .pi / 180.0))),
                control: CGPoint(x: c.x - r * 0.15, y: c.y)
            )
        }

        return p
    }
}

/// Vector stroke path for the `Къ`, `Кʼ`, or `Q` glyph inside `TransliterationKeycapBadge` so the inner symbol draws from lines while the 3D keycap rim stays stationary.
private struct KeycapGlyphStrokeShape: Shape {
    let isUkrainianStyle: Bool
    var showsTargetQ: Bool = false

    func path(in rect: CGRect) -> Path {
        let w = rect.width
        let h = rect.height
        var p = Path()

        if showsTargetQ {
            // Latin "Q" vector contour: smooth oval ring drawn clockwise from 12 o'clock + crisp diagonal tail
            let cx = w * 0.49
            let cy = h * 0.47
            let rx = w * 0.25
            let ry = h * 0.29
            var oval = Path()
            oval.addArc(
                center: .zero,
                radius: 1.0,
                startAngle: .degrees(-90),
                endAngle: .degrees(270),
                clockwise: false
            )
            let transform = CGAffineTransform(translationX: cx, y: cy).scaledBy(x: rx, y: ry)
            p.addPath(oval, transform: transform)
            p.move(to: CGPoint(x: cx + rx * 0.15, y: cy + ry * 0.32))
            p.addLine(to: CGPoint(x: cx + rx * 1.10, y: cy + ry * 1.12))
            return p
        }

        // Cyrillic "К" strokes
        let kLeftX = isUkrainianStyle ? w * 0.24 : w * 0.16
        let kRightX = isUkrainianStyle ? w * 0.58 : w * 0.46
        p.move(to: CGPoint(x: kLeftX, y: h * 0.20))
        p.addLine(to: CGPoint(x: kLeftX, y: h * 0.80))
        p.move(to: CGPoint(x: kRightX, y: h * 0.22))
        p.addLine(to: CGPoint(x: kLeftX + w * 0.04, y: h * 0.50))
        p.addLine(to: CGPoint(x: kRightX + w * 0.02, y: h * 0.80))

        if isUkrainianStyle {
            // Modifier letter apostrophe "ʼ" stroke
            p.move(to: CGPoint(x: w * 0.74, y: h * 0.20))
            p.addQuadCurve(
                to: CGPoint(x: w * 0.68, y: h * 0.44),
                control: CGPoint(x: w * 0.80, y: h * 0.33)
            )
        } else {
            // Cyrillic hard sign "ъ" stroke
            p.move(to: CGPoint(x: w * 0.54, y: h * 0.42))
            p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.42))
            p.addLine(to: CGPoint(x: w * 0.66, y: h * 0.80))
            p.addQuadCurve(
                to: CGPoint(x: w * 0.86, y: h * 0.69),
                control: CGPoint(x: w * 0.84, y: h * 0.82)
            )
            p.addQuadCurve(
                to: CGPoint(x: w * 0.66, y: h * 0.57),
                control: CGPoint(x: w * 0.84, y: h * 0.56)
            )
        }

        return p
    }
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()
    NavigationStack(path: $navigationPath) {
        HomeView(navigationPath: $navigationPath)
    }
}

/// Stationary settings icon badge whose inner vector icon draws from lines using `.trim(from: 0, to: drawProgress)`.
/// The colored rounded-rectangle badge never jumps, scales, or rotates, and switching interface language never re-triggers animations.
private struct InteractiveSettingsIconBadge: View {
    let badgeID: String
    let systemName: String
    let color: Color
    var isEnabled: Bool = true
    var triggerToken: String = ""

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var drawProgress: CGFloat = 1.0
    @State private var drawGeneration: Int = 0

    private var animationsAllowed: Bool {
        !HomeView.isUITestingEnvironment && !reduceMotion && !isLowPowerMode
    }

    private func triggerLineDraw(delay: Double = 0.0) {
        guard animationsAllowed else {
            drawProgress = 1.0
            return
        }
        drawGeneration &+= 1
        let currentGen = drawGeneration
        var resetTx = Transaction()
        resetTx.disablesAnimations = true
        withTransaction(resetTx) {
            drawProgress = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + max(delay, 0.025)) {
            guard currentGen == drawGeneration else { return }
            guard animationsAllowed else {
                drawProgress = 1.0
                return
            }
            withAnimation(.easeInOut(duration: 0.48)) {
                drawProgress = 1.0
            }
        }
    }

    var body: some View {
        let effectiveColor = isEnabled ? color : Color(.systemGray2)
        let badgeFillStyle: AnyShapeStyle = {
            guard isEnabled else { return AnyShapeStyle(Color(.systemGray2).gradient) }
            switch systemName {
            case "lang.crh.tamga":
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [Color(red: 0.07, green: 0.58, blue: 0.85), Color(red: 0.04, green: 0.45, blue: 0.71)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case "lang.uk.tryzub":
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [Color(red: 0.02, green: 0.40, blue: 0.88), Color(red: 0.92, green: 0.70, blue: 0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            case "lang.en.unionjack":
                return AnyShapeStyle(
                    LinearGradient(
                        colors: [Color(red: 0.08, green: 0.26, blue: 0.74), Color(red: 0.82, green: 0.15, blue: 0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            default:
                return AnyShapeStyle(effectiveColor.gradient)
            }
        }()
        let glyphStrokeColor: Color = {
            if isEnabled && systemName == "lang.crh.tamga" {
                return Color(red: 0.99, green: 0.82, blue: 0.16)
            }
            return Color.white
        }()
        let iconFrame = SettingsLineArtIconShape.iconFrameSize(for: systemName)
        let strokeStyle = SettingsLineArtIconShape.strokeStyle(for: systemName, frameSize: iconFrame)

        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(badgeFillStyle)
                .frame(width: 28, height: 28)

            SettingsLineArtIconShape(systemName: systemName)
                .trim(from: 0, to: drawProgress)
                .stroke(
                    glyphStrokeColor,
                    style: strokeStyle
                )
                .frame(width: iconFrame, height: iconFrame)
        }
        .frame(width: 28, height: 28)
        .animation(animationsAllowed ? .easeInOut(duration: 0.2) : nil, value: isEnabled)
        .contentShape(Rectangle())
        .onTapGesture {
            triggerLineDraw()
        }
        .onChange(of: isEnabled) { _, newValue in
            guard HomeView.canAnimateUserChanges else { return }
            if newValue {
                triggerLineDraw()
            } else {
                drawGeneration &+= 1
                drawProgress = 1.0
            }
        }
        .onChange(of: triggerToken) { _, _ in
            guard HomeView.canAnimateUserChanges else { return }
            if isEnabled && !triggerToken.isEmpty {
                triggerLineDraw()
            }
        }
        .onChange(of: systemName) { _, _ in
            guard HomeView.canAnimateUserChanges else { return }
            if isEnabled && triggerToken.isEmpty {
                triggerLineDraw()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

/// Stationary walnut-brain icon badge that draws its cortical folds via vector stroke `.trim(from: 0, to: drawProgress)`.
private struct InteractiveWalnutIconBadge: View {
    let badgeID: String
    let color: Color
    var isEnabled: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var drawProgress: CGFloat = 1.0
    @State private var drawGeneration: Int = 0

    private var animationsAllowed: Bool {
        !HomeView.isUITestingEnvironment && !reduceMotion && !isLowPowerMode
    }

    private func triggerLineDraw(delay: Double = 0.0) {
        guard animationsAllowed else {
            drawProgress = 1.0
            return
        }
        drawGeneration &+= 1
        let currentGen = drawGeneration
        var resetTx = Transaction()
        resetTx.disablesAnimations = true
        withTransaction(resetTx) {
            drawProgress = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + max(delay, 0.025)) {
            guard currentGen == drawGeneration else { return }
            guard animationsAllowed else {
                drawProgress = 1.0
                return
            }
            withAnimation(.easeInOut(duration: 0.54)) {
                drawProgress = 1.0
            }
        }
    }

    var body: some View {
        let effectiveColor = isEnabled ? color : Color(.systemGray2)

        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(effectiveColor.gradient)
                .frame(width: 28, height: 28)
            WalnutBrainIcon(color: .white, size: 16.5, drawProgress: drawProgress)
        }
        .frame(width: 28, height: 28)
        .animation(animationsAllowed ? .easeInOut(duration: 0.2) : nil, value: isEnabled)
        .contentShape(Rectangle())
        .onTapGesture {
            triggerLineDraw()
        }
        .onChange(of: isEnabled) { _, newValue in
            guard HomeView.canAnimateUserChanges else { return }
            if newValue {
                triggerLineDraw()
            } else {
                drawGeneration &+= 1
                drawProgress = 1.0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

/// Stationary 3D keycap badge for Standard (`Q`) and Cyrillic -> Latin (`Къ → Q → Къ` or `Кʼ → Q → Кʼ`) layout rows with physical keycap rim and inner glyph `.trim` line-drawing animation.
private struct TransliterationKeycapBadge: View {
    let badgeID: String
    let sourceLabel: String
    let targetLabel: String
    let isEnabled: Bool
    let isUkrainianStyle: Bool
    var isLatinOnlyStyle: Bool = false
    let accentColor: Color
    var triggerCount: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var drawProgress: CGFloat = 1.0
    @State private var activeGlyphIsTargetQ: Bool = false
    @State private var drawGeneration: Int = 0

    private var animationsAllowed: Bool {
        !HomeView.isUITestingEnvironment && !reduceMotion && !isLowPowerMode
    }

    private func triggerLineDraw(delay: Double = 0.0, forceAllowWhenDisabled: Bool = false) {
        if ProcessInfo.processInfo.arguments.contains("-qt_hold_q_phase") {
            activeGlyphIsTargetQ = true
            drawProgress = 1.0
            return
        }
        guard animationsAllowed, (isEnabled || forceAllowWhenDisabled) else {
            activeGlyphIsTargetQ = isLatinOnlyStyle
            drawProgress = 1.0
            return
        }
        drawGeneration &+= 1
        let currentGen = drawGeneration
        var resetTx = Transaction()
        resetTx.disablesAnimations = true
        withTransaction(resetTx) {
            activeGlyphIsTargetQ = isLatinOnlyStyle
            drawProgress = 0.0
        }
        let startDelay = max(delay, 0.025)
        if isLatinOnlyStyle {
            DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
                guard currentGen == drawGeneration else { return }
                guard animationsAllowed else {
                    activeGlyphIsTargetQ = true
                    drawProgress = 1.0
                    return
                }
                withAnimation(.easeInOut(duration: 0.48)) {
                    drawProgress = 1.0
                }
            }
            return
        }
        // Phase 1: Draw source glyph (Къ / Кʼ)
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay) {
            guard currentGen == drawGeneration else { return }
            guard animationsAllowed else {
                activeGlyphIsTargetQ = false
                drawProgress = 1.0
                return
            }
            withAnimation(.easeInOut(duration: 0.36)) {
                drawProgress = 1.0
            }
        }
        // Phase 2: Morph to target Latin glyph "Q" and draw its contour
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + 0.46) {
            guard currentGen == drawGeneration else { return }
            guard animationsAllowed else {
                activeGlyphIsTargetQ = false
                drawProgress = 1.0
                return
            }
            var qResetTx = Transaction()
            qResetTx.disablesAnimations = true
            withTransaction(qResetTx) {
                activeGlyphIsTargetQ = true
                drawProgress = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
                guard currentGen == drawGeneration else { return }
                withAnimation(.easeInOut(duration: 0.34)) {
                    drawProgress = 1.0
                }
            }
        }
        // Phase 3: Return smoothly to source glyph (Къ / Кʼ) and draw its contour (Start State == End State)
        DispatchQueue.main.asyncAfter(deadline: .now() + startDelay + 0.98) {
            guard currentGen == drawGeneration else { return }
            guard animationsAllowed else {
                activeGlyphIsTargetQ = false
                drawProgress = 1.0
                return
            }
            var srcResetTx = Transaction()
            srcResetTx.disablesAnimations = true
            withTransaction(srcResetTx) {
                activeGlyphIsTargetQ = false
                drawProgress = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.025) {
                guard currentGen == drawGeneration else { return }
                withAnimation(.easeInOut(duration: 0.36)) {
                    drawProgress = 1.0
                }
            }
        }
    }

    var body: some View {
        ZStack {
            if isEnabled {
                if isUkrainianStyle {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.34, blue: 0.72),
                                    Color(red: 1.0, green: 0.84, blue: 0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                } else if isLatinOnlyStyle {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.07, green: 0.58, blue: 0.85),
                                    Color(red: 0.04, green: 0.45, blue: 0.71)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                } else {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(accentColor.gradient)
                }
            } else {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color(.systemGray3).gradient)
            }

            // Physical 3D keycap lower bevel/lip (stationary)
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .fill(Color.black.opacity(isEnabled ? 0.16 : 0.10))
                .frame(width: 22, height: 21)
                .offset(y: 1.0)

            // Physical 3D keycap top surface fill (stationary)
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .fill(Color.white.opacity(isEnabled ? (isUkrainianStyle ? 0.10 : 0.14) : 0.08))
                .frame(width: 22, height: 20.5)
                .offset(y: -0.25)

            // Permanent 3D keycap rim border (обідок) — always solid and stationary
            RoundedRectangle(cornerRadius: 4.5, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(isEnabled ? 0.72 : 0.45),
                    lineWidth: 1.15
                )
                .frame(width: 22, height: 20.5)
                .offset(y: -0.25)

            // Permanent inner vector line-drawing glyph for Q / Къ / Кʼ (Start State == End State)
            KeycapGlyphStrokeShape(isUkrainianStyle: isUkrainianStyle, showsTargetQ: isLatinOnlyStyle || activeGlyphIsTargetQ)
                .trim(from: 0, to: drawProgress)
                .stroke(
                    Color.white,
                    style: StrokeStyle(lineWidth: 1.55, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: .black.opacity(isUkrainianStyle && isEnabled ? 0.35 : 0.14), radius: 0.6, x: 0, y: 0.4)
                .frame(width: 15, height: 13.5)
                .offset(y: -0.25)
        }
        .frame(width: 28, height: 28)
        .animation(animationsAllowed ? .easeInOut(duration: 0.2) : nil, value: isEnabled)
        .animation(animationsAllowed ? .easeInOut(duration: 0.22) : nil, value: isUkrainianStyle)
        .contentShape(Rectangle())
        .onTapGesture {
            triggerLineDraw(forceAllowWhenDisabled: true)
        }
        .onAppear {
            if isLatinOnlyStyle || ProcessInfo.processInfo.arguments.contains("-qt_hold_q_phase") {
                activeGlyphIsTargetQ = true
                drawProgress = 1.0
            }
        }
        .onChange(of: isEnabled) { _, newValue in
            guard HomeView.canAnimateUserChanges else { return }
            if newValue {
                triggerLineDraw()
            } else {
                drawGeneration &+= 1
                activeGlyphIsTargetQ = isLatinOnlyStyle
                drawProgress = 1.0
            }
        }
        .onChange(of: triggerCount) { _, _ in
            guard HomeView.canAnimateUserChanges else { return }
            triggerLineDraw(forceAllowWhenDisabled: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }
}

/// Stationary mini-capsules (`q · ğ · ñ · ş · ç · ü · ö · ı`) for the Standard (Latin) layout row.
private struct LatinCharactersMiniCapsulesView: View {
    let badgeID: String
    let isEnabled: Bool
    let brandBlue: Color
    let primaryInk: Color
    let secondaryInk: Color
    let accessibilityLabelText: String
    var letters: [String] = ["q", "ğ", "ñ", "ş", "ç", "ü", "ö", "ı"]

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var drawProgress: CGFloat = 1.0
    @State private var drawGeneration: Int = 0

    private var animationsAllowed: Bool {
        !HomeView.isUITestingEnvironment && !reduceMotion && !isLowPowerMode
    }

    private func triggerLineDraw(delay: Double = 0.0, forceAllowWhenDisabled: Bool = false) {
        guard animationsAllowed, (isEnabled || forceAllowWhenDisabled) else {
            drawProgress = 1.0
            return
        }
        drawGeneration &+= 1
        let currentGen = drawGeneration
        var resetTx = Transaction()
        resetTx.disablesAnimations = true
        withTransaction(resetTx) {
            drawProgress = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + max(delay, 0.025)) {
            guard currentGen == drawGeneration else { return }
            guard animationsAllowed else {
                drawProgress = 1.0
                return
            }
            withAnimation(.easeInOut(duration: 0.45)) {
                drawProgress = 1.0
            }
        }
    }

    @ViewBuilder
    private func letterPill(_ letter: String) -> some View {
        Text(letter)
            .font(.system(size: Device.iPad ? 11 : 10.5, weight: .bold, design: .rounded))
            .foregroundStyle(isEnabled ? brandBlue : secondaryInk)
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, Device.iPad ? 5.5 : 4.5)
            .padding(.vertical, 2)
            .background(
                isEnabled ? brandBlue.opacity(0.10) : Color(.tertiarySystemFill),
                in: Capsule()
            )
            .overlay(
                Capsule()
                    .trim(from: 0, to: drawProgress)
                    .stroke(
                        isEnabled ? brandBlue.opacity(0.28) : Color.primary.opacity(0.08),
                        style: StrokeStyle(lineWidth: 0.85, lineCap: .round)
                    )
            )
    }

    var body: some View {
        HStack(spacing: Device.iPad ? 4 : 3) {
            ForEach(letters, id: \.self) { letter in
                letterPill(letter)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .lineLimit(1)
        .animation(animationsAllowed ? .easeInOut(duration: 0.2) : nil, value: isEnabled)
        .contentShape(Rectangle())
        .onTapGesture {
            triggerLineDraw(forceAllowWhenDisabled: true)
        }
        .onChange(of: isEnabled) { _, newValue in
            guard HomeView.canAnimateUserChanges else { return }
            if newValue {
                triggerLineDraw()
            } else {
                drawGeneration &+= 1
                drawProgress = 1.0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }
}

/// Stationary mini-capsules (`гъ → ğ · къ → q · нъ → ñ · дж → c` or `ґ → g · г → ğ · кʼ → q · нʼ → ñ`) for the Cyrillic layout rows.
private struct UkrainianTransliterationMiniCapsulesView: View {
    let badgeID: String
    let isEnabled: Bool
    let brandBlue: Color
    let primaryInk: Color
    let secondaryInk: Color
    let accessibilityLabelText: String
    var pairs: [(src: String, dst: String)] = Self.defaultPairs

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isLowPowerMode: Bool = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var drawProgress: CGFloat = 1.0
    @State private var drawGeneration: Int = 0

    private var animationsAllowed: Bool {
        !HomeView.isUITestingEnvironment && !reduceMotion && !isLowPowerMode
    }

    private static let defaultPairs: [(src: String, dst: String)] = [
        ("ґ", "g"),
        ("г", "ğ"),
        ("к\u{02BC}", "q"),
        ("н\u{02BC}", "ñ")
    ]

    private func triggerLineDraw(delay: Double = 0.0, forceAllowWhenDisabled: Bool = false) {
        guard animationsAllowed, (isEnabled || forceAllowWhenDisabled) else {
            drawProgress = 1.0
            return
        }
        drawGeneration &+= 1
        let currentGen = drawGeneration
        var resetTx = Transaction()
        resetTx.disablesAnimations = true
        withTransaction(resetTx) {
            drawProgress = 0.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + max(delay, 0.025)) {
            guard currentGen == drawGeneration else { return }
            guard animationsAllowed else {
                drawProgress = 1.0
                return
            }
            withAnimation(.easeInOut(duration: 0.45)) {
                drawProgress = 1.0
            }
        }
    }

    @ViewBuilder
    private func capsulePill(for pair: (src: String, dst: String)) -> some View {
        HStack(spacing: Device.iPad ? 2 : 1.5) {
            Text(pair.src)
                .font(.system(size: Device.iPad ? 11 : 10.5, weight: .semibold, design: .rounded))
                .foregroundStyle(isEnabled ? primaryInk : secondaryInk)
                .fixedSize(horizontal: true, vertical: false)
            Text("→")
                .font(.system(size: Device.iPad ? 9.5 : 9.0, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryInk.opacity(0.8))
                .fixedSize(horizontal: true, vertical: false)
            Text(pair.dst)
                .font(.system(size: Device.iPad ? 11 : 10.5, weight: .bold, design: .rounded))
                .foregroundStyle(isEnabled ? brandBlue : secondaryInk)
                .fixedSize(horizontal: true, vertical: false)
        }
        .fixedSize(horizontal: true, vertical: false)
        .lineLimit(1)
        .padding(.horizontal, Device.iPad ? 5 : 4)
        .padding(.vertical, 2)
        .background(
            isEnabled ? brandBlue.opacity(0.10) : Color(.tertiarySystemFill),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .trim(from: 0, to: drawProgress)
                .stroke(
                    isEnabled ? brandBlue.opacity(0.28) : Color.primary.opacity(0.08),
                    style: StrokeStyle(lineWidth: 0.85, lineCap: .round)
                )
        )
    }

    var body: some View {
        HStack(spacing: Device.iPad ? 4 : 3) {
            ForEach(pairs, id: \.src) { pair in
                capsulePill(for: pair)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .lineLimit(1)
        .animation(animationsAllowed ? .easeInOut(duration: 0.2) : nil, value: isEnabled)
        .contentShape(Rectangle())
        .onTapGesture {
            triggerLineDraw(forceAllowWhenDisabled: true)
        }
        .onChange(of: isEnabled) { _, newValue in
            guard HomeView.canAnimateUserChanges else { return }
            if newValue {
                triggerLineDraw()
            } else {
                drawGeneration &+= 1
                drawProgress = 1.0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabelText)
    }
}

/// A UIKit-backed UITextView that dynamically updates its keyboardType, returnKeyType,
/// textContentType, and keyboardAppearance, reloading the responder input traits immediately
/// when the user switches sandbox modes.
private struct SandboxTextView: UIViewRepresentable {
    @Binding var text: String
    let currentText: String
    @Binding var isFocused: Bool
    @Binding var isCrimeanTatarKeyboardActive: Bool
    @Binding var canUndo: Bool
    @Binding var canRedo: Bool
    @Binding var liveWPM: Int
    @Binding var liveCPM: Int
    let autoFocusOnAppear: Bool
    var onDidAutoFocus: () -> Void = {}
    let placeholder: String
    let fieldMode: KeyboardTestFieldMode
    let themeMode: KeyboardTestThemeMode
    let hasManualThemeOverride: Bool
    let preferencesToken: String
    let fontSize: CGFloat
    var isFullAccessGranted: Bool = true

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        context.coordinator.textView = textView
        textView.accessibilityIdentifier = "sandbox.input"
        textView.backgroundColor = .clear
        textView.font = InterfaceFont.uiFont("GeneralSans-Regular", size: fontSize, text: currentText.isEmpty ? "QırımKey" : currentText)
        textView.textColor = .label
        textView.text = currentText
        textView.autocorrectionType = .default
        textView.spellCheckingType = .default
        if UIDevice.current.userInterfaceIdiom != .pad {
            textView.inputAssistantItem.leadingBarButtonGroups = []
            textView.inputAssistantItem.trailingBarButtonGroups = []
        }

        applyTraits(to: textView, coordinator: context.coordinator)

        if autoFocusOnAppear {
            let coordinator = context.coordinator
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                guard coordinator.parent.autoFocusOnAppear, !coordinator.didPerformInitialAutoFocus else { return }
                Self.forceSoftwareKeyboardShownIfUITesting()
                if textView.window != nil && !textView.isFirstResponder {
                    textView.becomeFirstResponder()
                    let endPos = (textView.text as NSString).length
                    if endPos > 0 { textView.selectedRange = NSRange(location: endPos, length: 0) }
                }
                Self.forceSoftwareKeyboardShownIfUITesting()
                if textView.isFirstResponder {
                    let endPos = (textView.text as NSString).length
                    if endPos > 0 { textView.selectedRange = NSRange(location: endPos, length: 0) }
                    coordinator.didPerformInitialAutoFocus = true
                    coordinator.parent.onDidAutoFocus()
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                guard coordinator.parent.autoFocusOnAppear, !coordinator.didPerformInitialAutoFocus else { return }
                Self.forceSoftwareKeyboardShownIfUITesting()
                if textView.window != nil && !textView.isFirstResponder {
                    textView.becomeFirstResponder()
                    let endPos = (textView.text as NSString).length
                    if endPos > 0 { textView.selectedRange = NSRange(location: endPos, length: 0) }
                }
                Self.forceSoftwareKeyboardShownIfUITesting()
                coordinator.didPerformInitialAutoFocus = true
                coordinator.parent.onDidAutoFocus()
            }
        }
        return textView
    }

    static func forceSoftwareKeyboardShownIfUITesting() {
        // Software keyboard presentation is handled via standard UIKit responder chain.
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.textView = uiView
        uiView.textColor = .label
        context.coordinator.refreshActiveInputMode(for: uiView)
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
        let targetFont = InterfaceFont.uiFont("GeneralSans-Regular", size: fontSize, text: currentText.isEmpty ? "QırımKey" : currentText)
        if uiView.font?.fontName != targetFont.fontName || uiView.font?.pointSize != targetFont.pointSize {
            uiView.font = targetFont
        }
        context.coordinator.updateInlineMathPreview(for: uiView)

        let fieldChanged = context.coordinator.lastFieldMode != nil && context.coordinator.lastFieldMode != fieldMode
        let themeChanged = context.coordinator.lastThemeMode != nil && context.coordinator.lastThemeMode != themeMode
        let manualOverrideChanged = context.coordinator.lastManualThemeOverride != nil && context.coordinator.lastManualThemeOverride != hasManualThemeOverride
        let fieldOrThemeChanged = fieldChanged || themeChanged || manualOverrideChanged
        let focusChanged = context.coordinator.lastIsFocused != isFocused
        let prefsChanged = context.coordinator.lastPreferencesToken != preferencesToken
        let needsAutoFocus = autoFocusOnAppear && uiView.window != nil && UIApplication.shared.applicationState == .active && !uiView.isFirstResponder

        if fieldOrThemeChanged || (focusChanged && isFocused) || needsAutoFocus {
            applyTraits(to: uiView, coordinator: context.coordinator)
            if fieldOrThemeChanged && uiView.isFirstResponder && !isFullAccessGranted {
                let coordinator = context.coordinator
                DispatchQueue.main.async {
                    coordinator.isReloadingTraits = true
                    uiView.reloadInputViews()
                    coordinator.isReloadingTraits = false
                }
            }
            if needsAutoFocus {
                let coordinator = context.coordinator
                DispatchQueue.main.async {
                    if uiView.window != nil && !uiView.isFirstResponder {
                        uiView.becomeFirstResponder()
                    }
                    coordinator.didPerformInitialAutoFocus = true
                    coordinator.parent.onDidAutoFocus()
                }
            }
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("crh.key.sandboxTraitsChanged" as CFString),
                nil,
                nil,
                true
            )
            if fieldOrThemeChanged {
                DispatchQueue.main.async {
                    CFNotificationCenterPostNotification(
                        CFNotificationCenterGetDarwinNotifyCenter(),
                        CFNotificationName("crh.key.sandboxTraitsChanged" as CFString),
                        nil,
                        nil,
                        true
                    )
                }
            }
        } else {
            if focusChanged {
                context.coordinator.lastIsFocused = isFocused
            }
            if prefsChanged {
                context.coordinator.lastPreferencesToken = preferencesToken
            }
        }
    }

    private func applyTraits(to textView: UITextView, coordinator: Coordinator) {
        coordinator.lastFieldMode = fieldMode
        coordinator.lastThemeMode = themeMode
        coordinator.lastManualThemeOverride = hasManualThemeOverride
        coordinator.lastIsFocused = isFocused
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
        textView.autocorrectionType = isStructuredField ? .no : .default
        textView.spellCheckingType = isStructuredField ? .no : .default
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
        var lastManualThemeOverride: Bool?
        var lastIsFocused: Bool?
        var lastPreferencesToken: String?
        var lastSyncedText: String
        var isReloadingTraits = false
        var didPerformInitialAutoFocus = false
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
                forName: UITextInputMode.currentInputModeDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self, let tv = self.textView else { return }
                self.refreshActiveInputMode(for: tv)
            })
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

        func refreshActiveInputMode(for textView: UITextView) {
            let isCRH: Bool
            if ProcessInfo.processInfo.arguments.contains("-qt_wrong_keyboard") {
                isCRH = false
            } else if let lang = textView.textInputMode?.primaryLanguage?.replacingOccurrences(of: "_", with: "-").lowercased() {
                isCRH = lang.hasPrefix("crh")
                let args = ProcessInfo.processInfo.arguments
                if !HomeView.isUITestingEnvironment && !args.contains("-qt_demo_stats") {
                    if lang.hasPrefix("crh-cyrl-ua") {
                        KeyboardPreferences.defaults.set(true, forKey: "crh.key.ukrainianExtensionSeen")
                    } else if lang == "crh-cyrl" || lang.hasPrefix("crh-cyrl-") {
                        KeyboardPreferences.defaults.set(true, forKey: "crh.key.cyrillicExtensionSeen")
                    } else if lang == "crh" || lang.hasPrefix("crh-latn") {
                        KeyboardPreferences.defaults.set(true, forKey: "crh.key.primaryExtensionSeen")
                    }
                }
            } else {
                isCRH = true
            }
            if parent.isCrimeanTatarKeyboardActive != isCRH {
                parent.isCrimeanTatarKeyboardActive = isCRH
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
            if CommandLine.arguments.contains("-qt_demo_stats") {
                if parent.liveWPM != 38 { parent.liveWPM = 38 }
                if parent.liveCPM != 228 { parent.liveCPM = 228 }
                return
            }
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
            SandboxTextView.forceSoftwareKeyboardShownIfUITesting()
            if !isReloadingTraits {
                textView.keyboardAppearance = parent.themeMode.keyboardAppearance
                if UIApplication.shared.applicationState == .active {
                    let defaults = KeyboardPreferences.defaults
                    defaults.set(parent.themeMode.isDark, forKey: "crh.key.test.isDark")
                    defaults.set(parent.fieldMode.rawValue, forKey: "crh.key.test.fieldMode")
                    defaults.set(true, forKey: "crh.key.test.sandboxFocused")
                    defaults.set(Date().timeIntervalSince1970, forKey: "crh.key.test.overrideTimestamp")
                    defaults.synchronize()
                    CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
                    CFNotificationCenterPostNotification(
                        CFNotificationCenterGetDarwinNotifyCenter(),
                        CFNotificationName("crh.key.sandboxTraitsChanged" as CFString),
                        nil,
                        nil,
                        true
                    )
                }
                if !parent.isFocused {
                    parent.isFocused = true
                }
            }
            refreshActiveInputMode(for: textView)
            refreshUndoRedoState(for: textView)
            updateInlineMathPreview(for: textView)
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-qt_prefill_phrase_prefix") || args.contains("-qt_prefill_greeting_prefix") || args.contains("-qt_prefill_cyrillic_phrase") {
                let endPos = (textView.text as NSString).length
                textView.selectedRange = NSRange(location: endPos, length: 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak textView] in
                    guard let textView else { return }
                    let len = (textView.text as NSString).length
                    if textView.selectedRange.location != len {
                        textView.selectedRange = NSRange(location: len, length: 0)
                    }
                }
            }
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
                KeyboardUsageStats.recordSandboxCommittedWordIfNeeded(
                    oldText: oldText,
                    newText: newText,
                    isFullAccessGranted: parent.isFullAccessGranted
                )
            }
            textView.scrollRangeToVisible(textView.selectedRange)
            refreshUndoRedoState(for: textView)
            updateInlineMathPreview(for: textView)
        }
    }
}

