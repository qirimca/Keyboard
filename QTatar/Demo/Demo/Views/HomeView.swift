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
    @State private var selectedFieldMode: KeyboardTestFieldMode = .standard
    @State private var selectedThemeMode: KeyboardTestThemeMode = .ios26White
    
    @StateObject private var dictationContext = DictationContext(config: .app)
    @StateObject private var keyboardState = KeyboardStateContext(bundleId: AppConfiguration.keyboardBundleIdPattern)
    
    @State private var showIndicatorSheet = false
    @State private var showSettings = false
    @State private var isWritingFieldFocused = false
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
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
                        let twoColumns = Self.usesTwoColumns(geometry.size)
                        let layout = twoColumns
                            ? AnyLayout(HomeTwoColumnLayout(spacing: 16))
                            : AnyLayout(VStackLayout(spacing: geometry.size.height < 360 ? 8 : 12))
                        layout {
                            // Order matters: in two columns children 0 and 2 stack on the left, child 1 fills the right.
                            statusIndicatorsSection
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                            writingAreaSection
                                .id("writingArea")
                            testingSandboxSection
                        }
                    }
                    .onChange(of: isWritingFieldFocused) { _, focused in
                        if focused { scroll.scrollTo("writingArea", anchor: .top) }
                    }
                    .onChange(of: geometry.size.height) { _, _ in
                        if isWritingFieldFocused { scroll.scrollTo("writingArea", anchor: .top) }
                    }
                }
            }
            .padding(.horizontal, Device.iPhone ? 12 : 24)
            .padding(.top, Device.iPhone ? 12 : 16)
            .padding(.bottom, Device.iPhone ? 12 : 24)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scrollDismissesKeyboard(.interactively)
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
        .overlay(alignment: .bottom, content: {
            if !areAllIndicatorsEnabled && !isWritingFieldFocused {
                PrimaryButton(text: Home.home_start_key.localized, background: Color.crayola) {
                    navigationPath.append(DemoRoute.onboarding)
                }.padding(Device.iPhone ? 12 : 24)
            }
        })
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            NavToolbarItem(placement: .navigationBarLeading, symbol: "questionmark") {
                navigationPath.append(DemoRoute.onboarding)
            }
            NavToolbarItem(placement: .navigationBarTrailing, symbol: "info") {
                navigationPath.append(DemoRoute.about)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel(Text("settings.title", tableName: "Interface", bundle: KeyboardPreferences.interfaceBundle))
            }
            ToolbarItem(placement: .principal) {
                Text("QırımKey")
                    .titleText(size: 24)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .sheet(isPresented: $showSettings) { KeyboardSettingsView() }
        .sheet(isPresented: $showIndicatorSheet) {
            OnboardingView()
                .presentationCornerRadius(20)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            applyLaunchArguments()
            syncThemeToAppGroup(selectedThemeMode)
            keyboardState.refresh()
        }
        .onChange(of: selectedThemeMode) { _, newTheme in
            syncThemeToAppGroup(newTheme)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                syncThemeToAppGroup(selectedThemeMode)
                keyboardState.refresh()
            } else {
                clearThemeOverride()
            }
        }
        .onDisappear { clearThemeOverride() }
        .onChange(of: text) { _, _ in
            keyboardState.refresh()
        }
    }
    
    private func syncThemeToAppGroup(_ theme: KeyboardTestThemeMode) {
        let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
        defaults?.set(theme.appGroupValue, forKey: "crh.key.test.systemKeyStyle")
        defaults?.synchronize()
    }
    
    /// Test hook: `-qt_field email -qt_theme classicDark` preselects the sandbox state at launch (no-op otherwise).
    private func applyLaunchArguments() {
        let defaults = UserDefaults.standard
        if let value = defaults.string(forKey: "qt_field"),
           let mode = KeyboardTestFieldMode(rawValue: "field.\(value)") {
            selectedFieldMode = mode
        }
        if let value = defaults.string(forKey: "qt_theme"),
           let theme = KeyboardTestThemeMode(rawValue: "theme.\(value)") {
            selectedThemeMode = theme
        }
    }
    
    /// The sandbox override must only apply while this app is in the foreground; otherwise it leaks into every other app.
    private func clearThemeOverride() {
        let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
        defaults?.removeObject(forKey: "crh.key.test.systemKeyStyle")
        defaults?.synchronize()
    }
    
    /// Two columns are used on iPad whenever the area is wide (landscape, or any wide window with an open keyboard),
    /// so the input field is never covered by the keyboard and the screen is used well.
    static func usesTwoColumns(_ size: CGSize) -> Bool {
        Device.iPad && size.width >= 700 && (size.width > size.height || size.height < 520)
    }
}

/// Left column: children 0 and 2 stacked (status, sandbox). Right column: child 1 (writing area),
/// stretched to the height of the taller column. All three stay in one container, so the text field keeps focus
/// when the layout changes between one and two columns.
private struct HomeTwoColumnLayout: Layout {
    var spacing: CGFloat = 16
    var leftFraction: CGFloat = 0.46

    private func widths(_ total: CGFloat) -> (left: CGFloat, right: CGFloat) {
        let usable = max(total - spacing, 0)
        let left = (usable * leftFraction).rounded()
        return (left, usable - left)
    }

    private func leftHeight(_ subviews: Subviews, width: CGFloat) -> CGFloat {
        guard subviews.count >= 3 else { return 0 }
        let a = subviews[0].sizeThatFits(.init(width: width, height: nil)).height
        let c = subviews[2].sizeThatFits(.init(width: width, height: nil)).height
        return a + spacing + c
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count >= 3 else { return .zero }
        let total = proposal.width ?? 800
        let w = widths(total)
        let rightHeight = subviews[1].sizeThatFits(.init(width: w.right, height: nil)).height
        return CGSize(width: total, height: max(leftHeight(subviews, width: w.left), rightHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count >= 3 else { return }
        let w = widths(bounds.width)
        let aHeight = subviews[0].sizeThatFits(.init(width: w.left, height: nil)).height
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
                          proposal: .init(width: w.left, height: aHeight))
        let cY = bounds.minY + aHeight + spacing
        let cHeight = subviews[2].sizeThatFits(.init(width: w.left, height: nil)).height
        subviews[2].place(at: CGPoint(x: bounds.minX, y: cY), anchor: .topLeading,
                          proposal: .init(width: w.left, height: cHeight))
        subviews[1].place(at: CGPoint(x: bounds.minX + w.left + spacing, y: bounds.minY), anchor: .topLeading,
                          proposal: .init(width: w.right, height: bounds.height))
    }

}

private extension HomeView {
    
    var statusIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Home.home_crimea_key.localized)
                .mediumText(size: Device.iPad ? 16 : 14)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            
            KeyboardStateIndicatorsRow(
                states: [
                    .active(keyboardState.isKeyboardActive),
                    .enable(keyboardState.isKeyboardEnabled),
                    .fullAccess(keyboardState.isFullAccessEnabled)
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
    
    var testingSandboxSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Row 1: Field Mode (Visual icons + Crimean Tatar labels)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.75))
                        .padding(.trailing, 2)
                    
                    ForEach(KeyboardTestFieldMode.allCases) { mode in
                        let isSelected = selectedFieldMode == mode
                        Button {
                            selectedFieldMode = mode
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 13, weight: .bold))
                                Text(LocalizedStringKey(mode.rawValue), tableName: "Interface", bundle: KeyboardPreferences.interfaceBundle)
                                    .font(.custom("GeneralSans-Medium", size: 13))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isSelected ? Color.black : Color.white)
                            .foregroundColor(isSelected ? Color.white : Color.black)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.black, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
            
            // Row 2: Color Scheme / System Key Style (Visual color swatches + Crimean Tatar labels)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.75))
                        .padding(.trailing, 2)
                    
                    ForEach(KeyboardTestThemeMode.allCases) { theme in
                        let isSelected = selectedThemeMode == theme
                        Button {
                            selectedThemeMode = theme
                        } label: {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(theme.swatchColor)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Color.black, lineWidth: 1))
                                Image(systemName: theme.icon)
                                    .font(.system(size: 11, weight: .semibold))
                                Text(LocalizedStringKey(theme.rawValue), tableName: "Interface", bundle: KeyboardPreferences.interfaceBundle)
                                    .font(.custom("GeneralSans-Medium", size: 12))
                            }
                            .padding(.horizontal, 11)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.crayola : Color.white)
                            .foregroundColor(.black)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule().stroke(Color.black, lineWidth: 1.5)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(Color.backgroundLight)
        .overlay {
            RoundedRectangle(cornerRadius: 16).stroke(Color.black, lineWidth: 2)
        }
        .padding(1)
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
        let keyboardId = keyboardState.activeKeyboardBundleIds.first
        return keyboardId?.hasSuffix("rtl") ?? false
    }
    
    var areAllIndicatorsEnabled: Bool {
        keyboardState.isKeyboardActive &&
        keyboardState.isKeyboardEnabled &&
        keyboardState.isFullAccessEnabled
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
    let fontSize: CGFloat
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.font = UIFont(name: "GeneralSans-Regular", size: fontSize) ?? .systemFont(ofSize: fontSize)
        textView.textColor = .black
        textView.text = text
        textView.autocorrectionType = .yes
        textView.spellCheckingType = .no
        textView.inputAssistantItem.leadingBarButtonGroups = []
        textView.inputAssistantItem.trailingBarButtonGroups = []
        
        applyTraits(to: textView, coordinator: context.coordinator)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            if textView.window != nil && !textView.isFirstResponder {
                textView.becomeFirstResponder()
            }
        }
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }
        
        let traitsChanged = context.coordinator.lastFieldMode != fieldMode ||
                            context.coordinator.lastThemeMode != themeMode
        
        if traitsChanged {
            applyTraits(to: uiView, coordinator: context.coordinator)
            if uiView.isFirstResponder {
                uiView.reloadInputViews()
                uiView.resignFirstResponder()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    uiView.becomeFirstResponder()
                }
            } else {
                uiView.becomeFirstResponder()
            }
        }
    }
    
    private func applyTraits(to textView: UITextView, coordinator: Coordinator) {
        coordinator.lastFieldMode = fieldMode
        coordinator.lastThemeMode = themeMode
        
        let defaults = UserDefaults(suiteName: AppConfiguration.appGroupID)
        defaults?.set(themeMode.appGroupValue, forKey: "crh.key.test.systemKeyStyle")
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
        
        init(_ parent: SandboxTextView) {
            self.parent = parent
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }
    }
}
