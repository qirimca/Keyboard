//
//  HomeView.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI
import KeyboardKitPro
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
    case googleGray = "theme.classicLight"
    case dark = "theme.modernDark"
    case classicDark = "theme.classicDark"

    var id: String { rawValue }

    var isDark: Bool { self == .dark || self == .classicDark }
    var isClassic: Bool { self == .googleGray || self == .classicDark }

    static func mode(isDark: Bool, isClassic: Bool) -> Self {
        isDark ? (isClassic ? .classicDark : .dark) : (isClassic ? .googleGray : .ios26White)
    }

    var icon: String {
        switch self {
        case .ios26White: return "sun.max.fill"
        case .googleGray: return "square.grid.2x2.fill"
        case .dark, .classicDark: return "moon.fill"
        }
    }

    var swatchColor: Color {
        switch self {
        case .ios26White: return .white
        case .googleGray: return Color(red: 172/255, green: 177/255, blue: 185/255)
        case .dark, .classicDark: return Color(white: 0.18)
        }
    }

    var appGroupValue: String {
        switch self {
        case .ios26White: return "ios26_white"
        case .googleGray, .classicDark: return "google_gray"
        case .dark: return "ios26_white"
        }
    }

    var keyboardAppearance: UIKeyboardAppearance {
        switch self {
        case .dark, .classicDark: return .dark
        default: return .light
        }
    }
}

/**
 This is the main demo app screen.

 This screen has a text field, an interactive testing sandbox for keyboard modes & color themes,
 and list items that show various keyboard-specific states.
 */
struct HomeView: View {
    @Binding var navigationPath: NavigationPath

    @AppStorage("crh.key.text") private var text = ""
    @AppStorage(KeyboardPreferences.languageKey, store: KeyboardPreferences.defaults) private var language = "crh"
    @AppStorage(KeyboardPreferences.cyrillicKey, store: KeyboardPreferences.defaults) private var cyrillicEnabled = true
    @AppStorage(KeyboardPreferences.suggestionsKey, store: KeyboardPreferences.defaults) private var suggestionsEnabled = true
    @AppStorage(KeyboardPreferences.systemKeyStyleKey, store: KeyboardPreferences.defaults) private var systemKeyStyle = "auto"
    @AppStorage(KeyboardPreferences.hostDiagnosticsKey, store: KeyboardPreferences.defaults) private var hostDiagnostics = ""

    @State private var selectedFieldMode: KeyboardTestFieldMode = .standard
    @State private var selectedThemeMode: KeyboardTestThemeMode = .ios26White

    @StateObject private var dictationContext = DictationContext(config: .app)
    @StateObject private var keyboardState = KeyboardStateContext(bundleId: AppConfiguration.keyboardBundleIdPattern)

    @State private var showIndicatorSheet = false
    @State private var isTestingExpanded = false
    @State private var isKeyboardVisible = false
    @State private var cyrillicStatus = CyrillicStatus.unknown
    @State private var cachedIsFullAccessEnabled = false
    @State private var cachedIsRtl = false
    @State private var viewportSize = CGSize.zero
    @State private var isWritingFieldFocused = false
    /// Height of the window area covered by a docked keyboard (0 when hidden or floating).
    @State private var dockedKeyboardOverlap: CGFloat = 0
    @Environment(\.scenePhase) private var scenePhase

    private enum CyrillicStatus { case enabled, missing, unknown }

    /// Free height above a docked keyboard.
    private var availableHeight: CGFloat {
        guard viewportSize.height > 0 else { return .greatestFiniteMagnitude }
        return viewportSize.height - dockedKeyboardOverlap
    }

    /// While typing in a short window the input field has priority: status and settings fold away first,
    /// then the test controls. Everything unfolds again as soon as there is room.
    private var foldsSettings: Bool { isWritingFieldFocused && availableHeight < 600 }
    private var foldsTestControls: Bool { isWritingFieldFocused && availableHeight < 400 }

    private var shouldShowStartOverlay: Bool {
        !areAllIndicatorsEnabled && !isWritingFieldFocused && !isKeyboardVisible && !isTestingExpanded
    }

    var body: some View {
        let _ = language // Observe interface language changes immediately
        ZStack {
            Color("BackgroungColor")
                .ignoresSafeArea()
                .onTapGesture {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
            BackgroundGrid()
                .allowsHitTesting(false)
            GeometryReader { geometry in
                ScrollViewReader { scroll in
                    ScrollView(.vertical, showsIndicators: false) {
                        let twoColumns = Self.usesTwoColumns(viewportSize) && geometry.size.width >= 700
                        let layout = twoColumns
                            ? AnyLayout(HomeTwoColumnLayout(spacing: foldsSettings ? 8 : 16))
                            : AnyLayout(VStackLayout(spacing: foldsSettings ? 6 : (geometry.size.height < 360 ? 10 : 14)))
                        layout {
                            // Child 0: Left column top in 2-col (status + settings when testing expanded), top in 1-col (status + settings)
                            VStack(alignment: .leading, spacing: 14) {
                                statusIndicatorsSection
                                if !twoColumns || isTestingExpanded {
                                    keyboardSettingsSection
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                            .frame(height: foldsSettings ? 0 : nil, alignment: .top)
                            .clipped()
                            .opacity(foldsSettings ? 0 : 1)
                            .allowsHitTesting(!foldsSettings)
                            .accessibilityHidden(foldsSettings)

                            // Child 1: Left column bottom in 2-col, middle in 1-col (Expandable testing button + sandbox controls)
                            testingExpandableSection
                                .id("testingSection")

                            // Child 2: Right column in 2-col, bottom in 1-col (Writing area when testing expanded, settings in 2-col when collapsed)
                            Group {
                                if isTestingExpanded {
                                    writingAreaSection
                                        .id("writingArea")
                                        .transition(.opacity)
                                } else if twoColumns {
                                    keyboardSettingsSection
                                        .transition(.opacity)
                                }
                            }
                        }
                        .padding(.bottom, shouldShowStartOverlay ? 76 : 8)
                    }
                    .onChange(of: isWritingFieldFocused) { _, focused in
                        syncSandboxFocusToAppGroup(focused)
                        if focused {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                scroll.scrollTo("writingArea", anchor: .top)
                            }
                        }
                    }
                    .onChange(of: isTestingExpanded) { _, expanded in
                        if expanded {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    scroll.scrollTo("writingArea", anchor: .bottom)
                                }
                            }
                        } else {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                    .onChange(of: geometry.size.height) { _, _ in
                        if isWritingFieldFocused {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                scroll.scrollTo("writingArea", anchor: .top)
                            }
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
            .keyboardDictation(
                context: dictationContext,
                config: .app,
                speechRecognizer: StandardSpeechRecognizer()
            ) {
                Dictation.Screen(
                    dictationContext: dictationContext) {
                        EmptyView()
                    } indicator: {
                        Dictation.BarVisualizer(isAnimating: $0)
                    } doneButton: { action in
                        Button(Home.home_ok_key.localized, action: action)
                            .buttonStyle(.borderedProminent)
                    }
            }
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
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: foldsSettings)
        .animation(.spring(response: 0.32, dampingFraction: 0.88), value: foldsTestControls)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            dockedKeyboardOverlap = Self.dockedOverlap(from: note)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            dockedKeyboardOverlap = 0
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavToolbarItem(placement: .navigationBarLeading, symbol: "questionmark") {
                navigationPath.append(DemoRoute.onboarding)
            }
            NavToolbarItem(placement: .navigationBarTrailing, symbol: "info") {
                navigationPath.append(DemoRoute.about)
            }
            ToolbarItem(placement: .principal) {
                Text("QırımKey")
                    .titleText(size: 24)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .sheet(isPresented: $showIndicatorSheet) {
            OnboardingView()
                .presentationCornerRadius(20)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            applyLaunchArguments()
            if isTestingExpanded || isWritingFieldFocused {
                syncThemeToAppGroup(selectedThemeMode)
            } else {
                clearThemeOverride()
            }
            refreshCyrillicStatus()
            keyboardState.refresh()
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
            // AppleKeyboards explicitly lists the app's Latin keyboard and not the Cyrillic one.
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
            defaults?.set(selectedThemeMode.appGroupValue, forKey: "crh.key.test.systemKeyStyle")
            defaults?.set(selectedThemeMode.isDark, forKey: "crh.key.test.isDark")
            defaults?.set(selectedFieldMode.rawValue, forKey: "crh.key.test.fieldMode")
        }
        defaults?.synchronize()
        notifySandboxTraitsChanged()
    }

    private func syncThemeToAppGroup(_ theme: KeyboardTestThemeMode) {
        let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
        defaults?.set(theme.appGroupValue, forKey: "crh.key.test.systemKeyStyle")
        defaults?.set(theme.isDark, forKey: "crh.key.test.isDark")
        defaults?.set(selectedFieldMode.rawValue, forKey: "crh.key.test.fieldMode")
        defaults?.synchronize()
        notifySandboxTraitsChanged()
    }

    /// Test hook: `-qt_field email -qt_theme classicDark` preselects the sandbox state at launch (no-op otherwise).
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
            }
            if let value = defaults.string(forKey: "qt_theme"),
               let theme = KeyboardTestThemeMode(rawValue: "theme.\(value)") {
                selectedThemeMode = theme
                isTestingExpanded = true
            }
            if args.contains("-qt_reset_text") || args.contains("-qt_field") || args.contains("-qt_theme") {
                UIView.setAnimationsEnabled(false)
                isTestingExpanded = true
            }
            if args.contains("-qt_reset_text") {
                text = ""
                suggestionsEnabled = true
                cyrillicEnabled = true
                KeyboardPreferences.defaults.set(true, forKey: KeyboardPreferences.suggestionsKey)
                KeyboardPreferences.defaults.set(true, forKey: KeyboardPreferences.cyrillicKey)
                KeyboardPreferences.defaults.synchronize()
            }
        }
    }

    /// The sandbox override must only apply while this app is in the foreground; otherwise it leaks into every other app.
    private func clearThemeOverride() {
        let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
        defaults?.removeObject(forKey: "crh.key.test.systemKeyStyle")
        defaults?.removeObject(forKey: "crh.key.test.isDark")
        defaults?.removeObject(forKey: "crh.key.test.fieldMode")
        defaults?.set(false, forKey: "crh.key.test.sandboxFocused")
        defaults?.synchronize()
        notifySandboxTraitsChanged()
    }

    /// Use the full window's orientation, independently of the keyboard's height.
    static func usesTwoColumns(_ size: CGSize) -> Bool {
        Device.iPad && size.width >= 700 && size.width > size.height
    }

    /// Height covered by a *docked* keyboard in the key window; 0 for hidden or floating keyboards.
    static func dockedOverlap(from note: Notification) -> CGFloat {
        guard let end = (note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue,
              let window = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .flatMap(\.windows)
                .first(where: \.isKeyWindow)
        else { return 0 }
        let frame = window.convert(end, from: window.screen.coordinateSpace)
        guard frame.width >= window.bounds.width * 0.85 else { return 0 }
        return max(0, window.bounds.maxY - frame.minY)
    }
}

/// Left column: children 0 and 1 stacked (status/settings, testing expandable). Right column: child 2 (writing area or settings),
/// stretched to the height of the taller column. All three stay in one container, so the text field keeps focus
/// when the layout changes between one and two columns.
private struct HomeTwoColumnLayout: Layout {
    var spacing: CGFloat = 16
    var leftFraction: CGFloat = 0.48

    private func widths(_ total: CGFloat) -> (left: CGFloat, right: CGFloat) {
        let usable = max(total - spacing, 0)
        let left = (usable * leftFraction).rounded()
        return (left, usable - left)
    }

    private func leftHeight(_ subviews: Subviews, width: CGFloat) -> CGFloat {
        guard subviews.count >= 3 else { return 0 }
        let a = subviews[0].sizeThatFits(.init(width: width, height: nil)).height
        let b = subviews[1].sizeThatFits(.init(width: width, height: nil)).height
        return a + spacing + b
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count >= 3 else { return .zero }
        let total = proposal.width ?? 800
        let w = widths(total)
        let rightHeight = subviews[2].sizeThatFits(.init(width: w.right, height: nil)).height
        return CGSize(width: total, height: max(leftHeight(subviews, width: w.left), rightHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count >= 3 else { return }
        let w = widths(bounds.width)
        let aHeight = subviews[0].sizeThatFits(.init(width: w.left, height: nil)).height
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
                          proposal: .init(width: w.left, height: aHeight))
        let bY = bounds.minY + aHeight + spacing
        let bHeight = subviews[1].sizeThatFits(.init(width: w.left, height: nil)).height
        subviews[1].place(at: CGPoint(x: bounds.minX, y: bY), anchor: .topLeading,
                          proposal: .init(width: w.left, height: bHeight))
        let rightNaturalHeight = subviews[2].sizeThatFits(.init(width: w.right, height: nil)).height
        subviews[2].place(at: CGPoint(x: bounds.minX + w.left + spacing, y: bounds.minY), anchor: .topLeading,
                          proposal: .init(width: w.right, height: max(rightNaturalHeight, bounds.height)))
    }

}

private extension HomeView {

    func interfaceLabel(_ key: String) -> Text {
        Text(LocalizedStringKey(key), tableName: "Interface", bundle: KeyboardPreferences.interfaceBundle)
    }

    var statusIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Home.home_crimea_key.localized)
                .mediumText(size: Device.iPad ? 16 : 14)
                .lineLimit(2, reservesSpace: true)
                .minimumScaleFactor(0.85)

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
                Text.customFontText(
                    Home.home_getkeyboard_key.localized,
                    fontName: "GeneralSans-Regular",
                    size: 12
                )
            }
        }
    }

    /// Keyboard Settings displayed directly on the Home screen (not hidden behind a modal sheet).
    var keyboardSettingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.black)
                interfaceLabel("settings.title")
                    .font(InterfaceFont.font("GeneralSans-Medium", size: Device.iPad ? 16 : 15))
                    .foregroundStyle(.black)
                Spacer()
            }

            Divider()

            // Language selector row
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.75))
                    .frame(width: 20, alignment: .center)
                interfaceLabel("settings.language")
                    .font(InterfaceFont.font("GeneralSans-Medium", size: 14))
                    .foregroundStyle(.black)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    ForEach([
                        ("crh", "Qırımtatarca"),
                        ("uk", "Українська"),
                        ("en", "English")
                    ], id: \.0) { code, title in
                        let isSelected = language == code
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                                language = code
                            }
                        } label: {
                            Text(verbatim: title)
                                .font(InterfaceFont.font("GeneralSans-Medium", size: 12, text: title))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color.crayola : Color.white, in: Capsule())
                                .foregroundStyle(.black)
                                .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.lang.\(code)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }

            // Cyrillic toggle: only iPad has a key (АБВ) it can hide; iOS cannot remove the keyboard from its list.
            if Device.iPad {
                HStack(spacing: 10) {
                    Image(systemName: "character.textbox")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black.opacity(0.75))
                        .frame(width: 20, alignment: .center)
                    Toggle(isOn: $cyrillicEnabled.animation(.spring(response: 0.32, dampingFraction: 0.85))) {
                        interfaceLabel("settings.cyrillic")
                            .font(InterfaceFont.font("GeneralSans-Medium", size: 14))
                            .foregroundStyle(.black)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    .toggleStyle(OutlinedToggleStyle())
                    .accessibilityIdentifier("settings.cyrillic.toggle")
                }
            }

            if cyrillicEnabled || !Device.iPad {
                VStack(alignment: .leading, spacing: 6) {
                    if cyrillicStatus == .missing {
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.orange)
                            StableLocalizedText(
                                key: "settings.missingCyrillic",
                                font: InterfaceFont.font("GeneralSans-Regular", size: 12),
                                color: .black.opacity(0.8)
                            )
                        }
                        .accessibilityIdentifier("settings.cyrillicWarning")
                    }
                    HStack(alignment: .top, spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 12))
                            .foregroundStyle(.black.opacity(0.65))
                        StableLocalizedText(
                            key: "settings.enableBothKeyboards",
                            font: InterfaceFont.font("GeneralSans-Regular", size: 12),
                            color: .black.opacity(0.75)
                        )
                    }
                    .accessibilityIdentifier("settings.enableBothKeyboards")
                }
                .padding(.leading, Device.iPad ? 30 : 0)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Autocomplete suggestions toggle
            HStack(spacing: 10) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.75))
                    .frame(width: 20, alignment: .center)
                Toggle(isOn: $suggestionsEnabled.animation(.spring(response: 0.32, dampingFraction: 0.85))) {
                    interfaceLabel("settings.suggestions")
                        .font(InterfaceFont.font("GeneralSans-Medium", size: 14))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .toggleStyle(OutlinedToggleStyle())
                .accessibilityIdentifier("settings.suggestions.toggle")
            }

            // System keys look: iOS gives keyboards no way to detect classic (pre-iOS 26 SDK) hosts, so it is a choice.
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black.opacity(0.75))
                    .frame(width: 20, alignment: .center)
                interfaceLabel("settings.systemKeys")
                    .font(InterfaceFont.font("GeneralSans-Medium", size: 14))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    ForEach(["auto", "classic", "modern"], id: \.self) { style in
                        let isSelected = systemKeyStyle == style
                        Button {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) { systemKeyStyle = style }
                        } label: {
                            interfaceLabel("settings.systemKeys.\(style)")
                                .font(InterfaceFont.font("GeneralSans-Medium", size: 12))
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color.crayola : Color.white, in: Capsule())
                                .foregroundStyle(.black)
                                .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("settings.systemKeys.\(style)")
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }

            StableLocalizedText(
                key: Device.iPad ? "settings.keyboardHelp" : "settings.keyboardHelpPhone",
                font: InterfaceFont.font("GeneralSans-Regular", size: 12),
                color: .black.opacity(0.65)
            )
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color.backgroundLight)
        .overlay {
            RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 2)
        }
        .padding(1)
    }

    /// Expandable Testing section: collapsed behind an animated button by default,
    /// revealing the keyboard variant preview pills and sandbox text area when tapped.
    var testingExpandableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                    isTestingExpanded.toggle()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "keyboard.badge.eye")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.black)
                    Text(Onboarding.onb_check_key.localized)
                        .font(InterfaceFont.font("GeneralSans-Medium", size: Device.iPad ? 16 : 15))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .rotationEffect(.degrees(isTestingExpanded ? 180 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(isTestingExpanded ? Color.crayola : Color.backgroundLight)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("testing.toggle")
            .frame(height: foldsSettings ? 0 : nil, alignment: .top)
            .clipped()
            .opacity(foldsSettings ? 0 : 1)
            .allowsHitTesting(!foldsSettings)
            .accessibilityHidden(foldsSettings)

            if isTestingExpanded && !foldsTestControls {
                testingSandboxSection
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(foldsSettings ? 0 : 1)
    }

    var testingSandboxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Elastic Field Mode buttons (never clips '123 Raqamlar' on the right)
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "keyboard")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.75))
                    .frame(width: 20, alignment: .center)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        ForEach(KeyboardTestFieldMode.allCases) { mode in
                            fieldModePill(mode, expandEqually: false)
                        }
                    }
                    HStack(spacing: 4) {
                        ForEach(KeyboardTestFieldMode.allCases) { mode in
                            fieldModePill(mode, expandEqually: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Row 2: Theme (Light / Dark) with leading icon matching Row 1
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.75))
                    .frame(width: 20, alignment: .center)

                HStack(spacing: 8) {
                    themeButton(key: "theme.light", icon: "sun.max.fill", selected: !selectedThemeMode.isDark) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedThemeMode = .mode(isDark: false, isClassic: selectedThemeMode.isClassic)
                        }
                    }
                    themeButton(key: "theme.dark", icon: "moon.fill", selected: selectedThemeMode.isDark) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                            selectedThemeMode = .mode(isDark: true, isClassic: selectedThemeMode.isClassic)
                        }
                    }
                }
            }

            // Row 3: Classic system keys style with leading icon matching Rows 1 & 2
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.black.opacity(0.75))
                    .frame(width: 20, alignment: .center)

                themeButton(key: "theme.classic", icon: "square.grid.2x2.fill", selected: selectedThemeMode.isClassic) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selectedThemeMode = .mode(isDark: selectedThemeMode.isDark, isClassic: !selectedThemeMode.isClassic)
                    }
                }
            }

            if !hostDiagnostics.isEmpty {
                Text(verbatim: hostDiagnostics)
                    .font(.system(size: 10.5, design: .monospaced))
                    .foregroundStyle(.black.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("testing.hostDiagnostics")
            }
        }
        .padding(12)
        .background(Color.backgroundLight)
        .overlay {
            RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 2)
        }
        .padding(1)
    }

    func fieldModePill(_ mode: KeyboardTestFieldMode, expandEqually: Bool) -> some View {
        let isSelected = selectedFieldMode == mode
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                selectedFieldMode = mode
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: mode.icon)
                    .font(.system(size: 12, weight: .bold))
                Text(LocalizedStringKey(mode.rawValue), tableName: "Interface", bundle: KeyboardPreferences.interfaceBundle)
                    .font(InterfaceFont.font("GeneralSans-Medium", size: 12.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .padding(.horizontal, expandEqually ? 6 : 10)
            .padding(.vertical, 7)
            .frame(maxWidth: expandEqually ? .infinity : nil)
            .background(isSelected ? Color.black : Color.white)
            .foregroundColor(isSelected ? Color.white : Color.black)
            .clipShape(Capsule())
            .overlay(
                Capsule().stroke(Color.black, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(mode.rawValue)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    func themeButton(key: String, icon: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                Text(LocalizedStringKey(key), tableName: "Interface", bundle: KeyboardPreferences.interfaceBundle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if selected { Image(systemName: "checkmark") }
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(.black)
            .background(selected ? Color.crayola : Color.white, in: Capsule())
            .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(key)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    var writingAreaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Text(Home.home_writearea_key.localized).mediumText()
                Image(systemName: selectedFieldMode.icon)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "multiply.circle.fill")
                            .foregroundStyle(.black)
                    }
                    .accessibilityIdentifier("sandbox.clear")
                    .padding(.trailing, 4)
                }
            }
            .padding([.horizontal, .top])

            Divider().padding(.horizontal)

            SandboxTextView(
                text: $text,
                isFocused: $isWritingFieldFocused,
                placeholder: Home.home_typing_key.localized,
                fieldMode: selectedFieldMode,
                themeMode: selectedThemeMode,
                preferencesToken: "\(cyrillicEnabled)-\(suggestionsEnabled)-\(systemKeyStyle)",
                fontSize: Device.iPad ? 16 : 14
            )
            .frame(minHeight: Device.iPad ? 90 : 70)
            .padding([.horizontal, .bottom])
            .environment(\.layoutDirection, isRtl ? .rightToLeft : .leftToRight)
        }
        .background(Color.backgroundLight)
        .overlay {
            RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 2)
        }
        .padding(1)
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

/// Switch in the app's outlined visual language: black 1.5pt outline, crayola when on.
struct OutlinedToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                configuration.label
                Spacer(minLength: 8)
                ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(configuration.isOn ? Color.crayola : Color.white)
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                        .padding(2.5)
                }
                .frame(width: 46, height: 28)
                .overlay(Capsule().stroke(Color.black, lineWidth: 1.5))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "1" : "0")
    }
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()
    NavigationStack(path: $navigationPath) {
        HomeView(navigationPath: $navigationPath)
    }
}

/// A UIKit-backed UITextView that dynamically updates its keyboardType, returnKeyType,
/// textContentType, and keyboardAppearance, calling `reloadInputViews()` immediately
/// when the user switches sandbox modes.
private struct SandboxTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
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
        textView.accessibilityIdentifier = "sandbox.input"
        textView.backgroundColor = .clear
        textView.font = InterfaceFont.uiFont("GeneralSans-Regular", size: fontSize, text: text)
        textView.textColor = .black
        textView.text = text
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .no
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []

        applyTraits(to: textView, coordinator: context.coordinator)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            if textView.window != nil && !textView.isFirstResponder {
                textView.becomeFirstResponder()
            }
        }
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if text != context.coordinator.lastSyncedText {
            context.coordinator.lastSyncedText = text
            if uiView.text != text {
                uiView.text = text
            }
        }
        let targetFont = InterfaceFont.uiFont("GeneralSans-Regular", size: fontSize, text: text)
        if uiView.font?.fontName != targetFont.fontName || uiView.font?.pointSize != targetFont.pointSize {
            uiView.font = targetFont
        }

        let traitsChanged = context.coordinator.lastFieldMode != fieldMode ||
                            context.coordinator.lastThemeMode != themeMode ||
                            context.coordinator.lastPreferencesToken != preferencesToken

        if traitsChanged {
            applyTraits(to: uiView, coordinator: context.coordinator)
            if uiView.isFirstResponder {
                UIView.performWithoutAnimation {
                    uiView.reloadInputViews()
                }
            } else {
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
        defaults?.set(themeMode.appGroupValue, forKey: "crh.key.test.systemKeyStyle")
        defaults?.set(themeMode.isDark, forKey: "crh.key.test.isDark")
        defaults?.set(fieldMode.rawValue, forKey: "crh.key.test.fieldMode")
        defaults?.synchronize()

        textView.keyboardType = fieldMode.keyboardType
        textView.returnKeyType = fieldMode.returnKeyType
        textView.textContentType = fieldMode.textContentType
        textView.keyboardAppearance = themeMode.keyboardAppearance
        textView.enablesReturnKeyAutomatically = (fieldMode != .standard)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SandboxTextView
        var lastFieldMode: KeyboardTestFieldMode?
        var lastThemeMode: KeyboardTestThemeMode?
        var lastPreferencesToken: String?
        var lastSyncedText: String

        init(_ parent: SandboxTextView) {
            self.parent = parent
            self.lastSyncedText = parent.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
            defaults?.set(parent.themeMode.appGroupValue, forKey: "crh.key.test.systemKeyStyle")
            defaults?.set(parent.themeMode.isDark, forKey: "crh.key.test.isDark")
            defaults?.set(parent.fieldMode.rawValue, forKey: "crh.key.test.fieldMode")
            defaults?.set(true, forKey: "crh.key.test.sandboxFocused")
            defaults?.synchronize()
            CFNotificationCenterPostNotification(
                CFNotificationCenterGetDarwinNotifyCenter(),
                CFNotificationName("crh.key.sandboxTraitsChanged" as CFString),
                nil,
                nil,
                true
            )
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
            let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
            defaults?.removeObject(forKey: "crh.key.test.systemKeyStyle")
            defaults?.removeObject(forKey: "crh.key.test.isDark")
            defaults?.removeObject(forKey: "crh.key.test.fieldMode")
            defaults?.set(false, forKey: "crh.key.test.sandboxFocused")
            defaults?.synchronize()
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
