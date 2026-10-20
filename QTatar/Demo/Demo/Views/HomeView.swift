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
    @AppStorage(KeyboardPreferences.suggestionsKey, store: KeyboardPreferences.defaults) private var suggestionsEnabled = true
    @AppStorage(KeyboardPreferences.wordLearningKey, store: KeyboardPreferences.defaults) private var wordLearningEnabled = true

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
        return .ios26White
    }()

    @StateObject private var keyboardState = KeyboardStateContext(bundleId: AppConfiguration.keyboardBundleIdPattern)

    @State private var showIndicatorSheet = false
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
                            // Child 0: Status indicators (Left column top in 2-col, top in 1-col)
                            statusIndicatorsSection

                            // Child 1: Keyboard settings (Left column bottom in 2-col, middle in 1-col)
                            keyboardSettingsSection

                            // Child 2: Try Keyboard + Writing Area (Right column in 2-col, bottom in 1-col)
                            testingAndWritingSection
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, shouldShowStartOverlay ? 76 : 12)
                    }
                    .onChange(of: isWritingFieldFocused) { _, focused in
                        syncSandboxFocusToAppGroup(focused)
                        if focused {
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
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
            }
            .padding(.horizontal, Device.iPhone ? 12 : 24)
            .padding(.top, Device.iPhone ? 12 : 16)
            .padding(.bottom, Device.iPhone ? 12 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollDismissesKeyboard(.interactively)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: language)
            .animation(.spring(response: 0.32, dampingFraction: 0.86), value: cyrillicEnabled)
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
                .padding(Device.iPhone ? 12 : 24)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        })
        .animation(.easeInOut(duration: 0.25), value: shouldShowStartOverlay)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavToolbarItem(placement: .navigationBarLeading, symbol: "questionmark") {
                navigationPath.append(DemoRoute.onboarding)
            }
            NavToolbarItem(placement: .navigationBarTrailing, symbol: "info") {
                navigationPath.append(DemoRoute.about)
            }
            ToolbarItem(placement: .principal) {
                HStack(spacing: 8) {
                    Image("logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.14), lineWidth: 0.75)
                        )
                        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
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
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            Self.registerFloatingRequestObserverIfNeeded()
            if !didInitializeThemeFromSystem {
                didInitializeThemeFromSystem = true
                selectedThemeMode = .mode(isDark: colorScheme == .dark)
            }
            applyLaunchArguments()
            if isTestingExpanded || isWritingFieldFocused {
                syncThemeToAppGroup(selectedThemeMode)
            } else {
                clearThemeOverride()
            }
            refreshCyrillicStatus()
            keyboardState.refresh()
        }
        .onChange(of: colorScheme) { _, newScheme in
            let args = ProcessInfo.processInfo.arguments
            if !args.contains("-qt_theme") {
                selectedThemeMode = .mode(isDark: newScheme == .dark)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                isKeyboardVisible = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UITextInputMode.currentInputModeDidChangeNotification)) { _ in
            refreshCyrillicStatus()
        }
        .onChange(of: selectedThemeMode) { _, newTheme in
            syncThemeToAppGroup(newTheme)
        }
        .onChange(of: selectedFieldMode) { _, _ in
            syncThemeToAppGroup(selectedThemeMode)
        }
        .onChange(of: cyrillicEnabled) { _, newValue in
            KeyboardPreferences.defaults.set(newValue, forKey: KeyboardPreferences.cyrillicKey)
            KeyboardPreferences.defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            notifySandboxTraitsChanged()
        }
        .onChange(of: suggestionsEnabled) { _, newValue in
            KeyboardPreferences.defaults.set(newValue, forKey: KeyboardPreferences.suggestionsKey)
            KeyboardPreferences.defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            notifySandboxTraitsChanged()
        }
        .onChange(of: wordLearningEnabled) { _, newValue in
            KeyboardPreferences.defaults.set(newValue, forKey: KeyboardPreferences.wordLearningKey)
            KeyboardPreferences.defaults.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            notifySandboxTraitsChanged()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                if isTestingExpanded || isWritingFieldFocused {
                    syncThemeToAppGroup(selectedThemeMode)
                } else {
                    clearThemeOverride()
                }
                refreshCyrillicStatus()
                keyboardState.refresh()
            } else {
                clearThemeOverride()
            }
        }
        .onDisappear { clearThemeOverride() }
    }

    private static var didRegisterFloatingObserver = false

    private static func registerFloatingRequestObserverIfNeeded() {
        guard !didRegisterFloatingObserver else { return }
        didRegisterFloatingObserver = true
        CFNotificationCenterAddObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
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
    }

    static func invokeHostSetFloating(_ floating: Bool) {
        if let implClass: AnyClass = NSClassFromString("UIKeyboardImpl") {
            let isFloatingSel = NSSelectorFromString("isFloating")
            if let checkMethod = class_getClassMethod(implClass, isFloatingSel) {
                typealias IsFloatingFn = @convention(c) (AnyObject, Selector) -> Bool
                let checkFn = unsafeBitCast(method_getImplementation(checkMethod), to: IsFloatingFn.self)
                if checkFn(implClass, isFloatingSel) == floating {
                    return
                }
            }
        }
        if let hostClass: AnyClass = NSClassFromString("UIPeripheralHost") {
            let hostSel = NSSelectorFromString("setFloating:onCompletion:")
            if let method = class_getClassMethod(hostClass, hostSel) {
                typealias SetHostFloatingFn = @convention(c) (AnyObject, Selector, Bool, AnyObject?) -> Void
                let fn = unsafeBitCast(method_getImplementation(method), to: SetHostFloatingFn.self)
                fn(hostClass, hostSel, floating, nil)
                return
            }
        }
        if let implClass: AnyClass = NSClassFromString("UIKeyboardImpl") {
            let implSel = NSSelectorFromString("setFloating:")
            if let method = class_getClassMethod(implClass, implSel) {
                typealias SetFloatingFn = @convention(c) (AnyObject, Selector, Bool) -> Void
                let fn = unsafeBitCast(method_getImplementation(method), to: SetFloatingFn.self)
                fn(implClass, implSel, floating)
            }
        }
    }

    private func refreshCyrillicStatus() {
        cachedIsFullAccessEnabled = keyboardState.isFullAccessEnabled
        cachedIsRtl = keyboardState.activeKeyboardBundleIds.first?.hasSuffix("rtl") ?? false
        let appleKeyboards = (UserDefaults.standard.object(forKey: "AppleKeyboards") as? [String]) ?? []
        let modes = UITextInputMode.activeInputModes
        let modeIdentifiers = modes.compactMap { $0.value(forKey: "identifier") as? String }
        let identifiers = appleKeyboards + modeIdentifiers
        let languages = modes.compactMap(\.primaryLanguage)
            .map { $0.replacingOccurrences(of: "_", with: "-").lowercased() }
        let cyrillicByIdentifier = identifiers.contains { $0.contains(AppConfiguration.cyrillicKeyboardBundleId) }
        let cyrillicSeenInAppGroup = KeyboardPreferences.defaults.bool(forKey: "crh.key.cyrillicExtensionSeen")
        if cyrillicByIdentifier || cyrillicSeenInAppGroup || languages.contains(where: { $0.hasPrefix("crh-cyrl") }) {
            cyrillicStatus = .enabled
        } else if appleKeyboards.contains(where: { $0.contains(AppConfiguration.keyboardBundleId) }) {
            cyrillicStatus = .missing
        } else if identifiers.contains(where: { $0.hasPrefix(AppConfiguration.keyboardBundleIdPattern.replacingOccurrences(of: "*", with: "")) }) ||
                  languages.contains("crh") || languages.isEmpty || modes.contains(where: { $0.primaryLanguage == nil }) {
            cyrillicStatus = .unknown
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
        let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
        defaults?.set(focused, forKey: "crh.key.test.sandboxFocused")
        if focused {
            defaults?.set(selectedThemeMode.isDark, forKey: "crh.key.test.isDark")
            defaults?.set(selectedFieldMode.rawValue, forKey: "crh.key.test.fieldMode")
        }
        defaults?.synchronize()
        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        notifySandboxTraitsChanged()
    }

    private func syncThemeToAppGroup(_ theme: KeyboardTestThemeMode) {
        let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
        defaults?.set(theme.isDark, forKey: "crh.key.test.isDark")
        defaults?.set(selectedFieldMode.rawValue, forKey: "crh.key.test.fieldMode")
        defaults?.synchronize()
        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        notifySandboxTraitsChanged()
    }

    /// Test hook: `-qt_field email -qt_theme modernDark` preselects the sandbox state at launch (no-op otherwise).
    private func applyLaunchArguments() {
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
            if args.contains("-qt_reset_text") || args.contains("-qt_field") || args.contains("-qt_theme") {
                UIView.setAnimationsEnabled(false)
                isTestingExpanded = true
                shouldAutoFocusSandbox = true
            }
            if args.contains("-qt_reset_text") {
                text = ""
                suggestionsEnabled = true
                wordLearningEnabled = true
                cyrillicEnabled = true
                KeyboardPreferences.defaults.set(true, forKey: KeyboardPreferences.suggestionsKey)
                KeyboardPreferences.defaults.set(true, forKey: KeyboardPreferences.wordLearningKey)
                KeyboardPreferences.defaults.set(true, forKey: KeyboardPreferences.cyrillicKey)
                KeyboardPreferences.defaults.synchronize()
                if let containerDir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConfiguration.appGroupID) {
                    try? FileManager.default.removeItem(at: containerDir.appendingPathComponent("user_lexicon.sqlite"))
                    try? FileManager.default.removeItem(at: containerDir.appendingPathComponent("user_lexicon.sqlite-wal"))
                    try? FileManager.default.removeItem(at: containerDir.appendingPathComponent("user_lexicon.sqlite-shm"))
                }
            }
            if shouldAutoFocusSandbox {
                syncThemeToAppGroup(selectedThemeMode)
            }
        }
    }

    /// The sandbox override must only apply while this app is in the foreground; otherwise it leaks into every other app.
    private func clearThemeOverride() {
        let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
        defaults?.removeObject(forKey: "crh.key.test.isDark")
        defaults?.removeObject(forKey: "crh.key.test.fieldMode")
        defaults?.set(false, forKey: "crh.key.test.sandboxFocused")
        defaults?.synchronize()
        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
        notifySandboxTraitsChanged()
    }

    /// Use the full window's orientation, independently of the keyboard's height.
    static func usesTwoColumns(_ size: CGSize, containerSize: CGSize = .zero) -> Bool {
        guard Device.iPad else { return false }
        let screenSize = UIScreen.main.bounds.size
        let isLandscape = (size.width > size.height && size.width >= 600)
            || (screenSize.width > screenSize.height)
            || (containerSize.width >= 900)
        let effectiveWidth = max(size.width, containerSize.width)
        return isLandscape && effectiveWidth >= 600
    }
}

/// Left column: children 0 and 1 stacked (status, settings). Right column: child 2 (Try Keyboard + Writing Area)
/// at its natural height at the top of the column.
private struct HomeTwoColumnLayout: Layout {
    var spacing: CGFloat = 16
    var leftFraction: CGFloat = 0.48

    private func widths(_ total: CGFloat) -> (left: CGFloat, right: CGFloat) {
        let usable = max(total - spacing, 0)
        let left = (usable * leftFraction).rounded()
        return (left, usable - left)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count >= 3 else { return .zero }
        let totalWidth = proposal.width ?? 800
        let w = widths(totalWidth)
        let h0 = subviews[0].sizeThatFits(.init(width: w.left, height: nil)).height
        let h1 = subviews[1].sizeThatFits(.init(width: w.left, height: nil)).height
        let leftHeight = h0 + spacing + h1
        let rightHeight = subviews[2].sizeThatFits(.init(width: w.right, height: nil)).height
        return CGSize(width: totalWidth, height: max(leftHeight, rightHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count >= 3 else { return }
        let w = widths(bounds.width)
        let h0 = subviews[0].sizeThatFits(.init(width: w.left, height: nil)).height
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY),
            anchor: .topLeading,
            proposal: .init(width: w.left, height: h0)
        )
        let h1 = subviews[1].sizeThatFits(.init(width: w.left, height: nil)).height
        subviews[1].place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + h0 + spacing),
            anchor: .topLeading,
            proposal: .init(width: w.left, height: h1)
        )
        let h2 = subviews[2].sizeThatFits(.init(width: w.right, height: nil)).height
        subviews[2].place(
            at: CGPoint(x: bounds.minX + w.left + spacing, y: bounds.minY),
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

    func settingsIconBadge(_ systemName: String, color: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(color.gradient)
                .frame(width: 28, height: 28)
            Image(systemName: systemName)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    var statusIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            KeyboardStateIndicatorsRow(
                states: [
                    .active(keyboardState.isKeyboardActive),
                    .enable(keyboardState.isKeyboardEnabled),
                    .fullAccess(cachedIsFullAccessEnabled)
                ]
            ) {
                showIndicatorSheet = true
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
                        .minimumScaleFactor(0.75)
                    Spacer(minLength: 8)
                    languageSegmentedControl
                        .frame(maxWidth: 320)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        settingsIconBadge("globe", color: brandBlue)
                        interfaceLabel("settings.language")
                            .font(InterfaceFont.font("GeneralSans-Medium", size: 15))
                            .foregroundStyle(primaryInk)
                            .lineLimit(1)
                        Spacer()
                    }
                    languageSegmentedControl
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            // Cyrillic toggle: only iPad has an in-place script key (абв/abc) it can hide.
            if Device.iPad {
                Divider().padding(.leading, 54)

                HStack(spacing: 12) {
                    settingsIconBadge("character.textbox", color: Color(red: 0.35, green: 0.34, blue: 0.84))
                    interfaceLabel("settings.cyrillic")
                        .font(InterfaceFont.font("GeneralSans-Medium", size: 15))
                        .foregroundStyle(primaryInk)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 8)
                    Toggle("", isOn: $cyrillicEnabled.animation(.spring(response: 0.32, dampingFraction: 0.85)))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("settings.cyrillic.toggle")
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }

            if (cyrillicEnabled || !Device.iPad) && cyrillicStatus == .missing {
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
                .accessibilityIdentifier("settings.cyrillicWarning")
            }

            Divider().padding(.leading, 54)

            // Autocomplete suggestions toggle
            HStack(spacing: 12) {
                settingsIconBadge("text.bubble.fill", color: appleGreen)
                interfaceLabel("settings.suggestions")
                    .font(InterfaceFont.font("GeneralSans-Medium", size: 15))
                    .foregroundStyle(primaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
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
                settingsIconBadge("sparkles", color: Color(red: 0.96, green: 0.58, blue: 0.04))
                interfaceLabel("settings.wordLearning")
                    .font(InterfaceFont.font("GeneralSans-Medium", size: 15))
                    .foregroundStyle(primaryInk)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                Toggle("", isOn: $wordLearningEnabled.animation(.spring(response: 0.32, dampingFraction: 0.85)))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityIdentifier("settings.wordLearning.toggle")
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

    var languageSegmentedControl: some View {
        NativeSegmentedControl(
            items: [
                .init(id: "crh", title: "Qırımtatarca", accessibilityIdentifier: "settings.lang.crh"),
                .init(id: "uk", title: "Українська", accessibilityIdentifier: "settings.lang.uk"),
                .init(id: "en", title: "English", accessibilityIdentifier: "settings.lang.en")
            ],
            selection: $language,
            apportionsWidthsByContent: true
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
                        .minimumScaleFactor(0.8)
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
            // Row 1: Native iOS 27 Segmented Field Mode strip
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

            // Row 2: Native iOS 27 Segmented Theme switcher (Light / Dark)
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

    var writingAreaSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: selectedFieldMode.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(brandBlue)
                Text(Home.home_writearea_key.localized)
                    .font(InterfaceFont.font("GeneralSans-Medium", size: 13))
                    .foregroundStyle(secondaryInk)
                Spacer()
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
                    autoFocusOnAppear: shouldAutoFocusSandbox,
                    placeholder: Home.home_typing_key.localized,
                    fieldMode: selectedFieldMode,
                    themeMode: selectedThemeMode,
                    preferencesToken: "\(cyrillicEnabled)-\(suggestionsEnabled)-\(wordLearningEnabled)",
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

    var isRtl: Bool {
        cachedIsRtl
    }

    var areAllIndicatorsEnabled: Bool {
        keyboardState.isKeyboardActive &&
        keyboardState.isKeyboardEnabled &&
        cachedIsFullAccessEnabled
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

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> AccessibleUISegmentedControl {
        let control = AccessibleUISegmentedControl(items: items.map(\.title))
        control.apportionsSegmentWidthsByContent = apportionsWidthsByContent
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
        guard let path = Bundle.main.path(forResource: language, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
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
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []

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
            context.coordinator.lastSyncedText = currentText
            if uiView.text != currentText {
                uiView.text = currentText
            }
        }
        let targetFont = InterfaceFont.uiFont("GeneralSans-Regular", size: fontSize, text: currentText)
        if uiView.font?.fontName != targetFont.fontName || uiView.font?.pointSize != targetFont.pointSize {
            uiView.font = targetFont
        }

        let fieldOrThemeChanged = context.coordinator.lastFieldMode != fieldMode ||
                                  context.coordinator.lastThemeMode != themeMode
        let prefsChanged = context.coordinator.lastPreferencesToken != preferencesToken

        if fieldOrThemeChanged || prefsChanged {
            applyTraits(to: uiView, coordinator: context.coordinator)
            if uiView.isFirstResponder {
                UIView.performWithoutAnimation {
                    uiView.reloadInputViews()
                }
            } else if fieldOrThemeChanged && autoFocusOnAppear && uiView.window != nil {
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

        let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
        defaults?.set(themeMode.isDark, forKey: "crh.key.test.isDark")
        defaults?.set(fieldMode.rawValue, forKey: "crh.key.test.fieldMode")
        defaults?.set(true, forKey: "crh.key.test.sandboxFocused")
        defaults?.synchronize()
        CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)

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
        private var clearObserver: NSObjectProtocol?

        init(_ parent: SandboxTextView) {
            self.parent = parent
            self.lastSyncedText = parent.currentText
            super.init()
            self.clearObserver = NotificationCenter.default.addObserver(
                forName: Notification.Name("crh.key.clearSandboxText"),
                object: nil,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                self.lastSyncedText = ""
                self.textView?.text = ""
                self.parent.text = ""
            }
        }

        deinit {
            if let clearObserver {
                NotificationCenter.default.removeObserver(clearObserver)
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
            defaults?.set(parent.themeMode.isDark, forKey: "crh.key.test.isDark")
            defaults?.set(parent.fieldMode.rawValue, forKey: "crh.key.test.fieldMode")
            defaults?.set(true, forKey: "crh.key.test.sandboxFocused")
            defaults?.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("crh.key.sandboxTraitsChanged" as CFString),
                nil,
                nil,
                true
            )
            if !isReloadingTraits {
                parent.isFocused = true
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            guard !isReloadingTraits else { return }
            parent.isFocused = false
            let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
            defaults?.removeObject(forKey: "crh.key.test.isDark")
            defaults?.removeObject(forKey: "crh.key.test.fieldMode")
            defaults?.set(false, forKey: "crh.key.test.sandboxFocused")
            defaults?.synchronize()
            CFPreferencesAppSynchronize(AppConfiguration.appGroupID as CFString)
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("crh.key.sandboxTraitsChanged" as CFString),
                nil,
                nil,
                true
            )
        }

        func textViewDidChange(_ textView: UITextView) {
            lastSyncedText = textView.text
            parent.text = textView.text
        }
    }
}
