//
//  OnboardingView.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 19.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

struct OnboardingView: View {
    enum Mode: String, Equatable, Hashable {
        case add
        case removeCyrillic
    }

    var mode: Mode = .add
    var initialPage: String = "Onboard1"

    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @AppStorage(KeyboardPreferences.languageKey, store: KeyboardPreferences.defaults) private var language = "crh"
    @State private var selected: String
    @State private var text = ""

    init(mode: Mode = .add, initialPage: String = "Onboard1") {
        self.mode = mode
        self.initialPage = initialPage
        let validPage = Page(rawValue: initialPage)?.rawValue ?? Page.onboard1.rawValue
        self._selected = State(initialValue: validPage)
    }
    
    private enum Page: String, CaseIterable {
        case onboard1 = "Onboard1"
        case onboard2 = "Onboard2"
        case onboard3 = "Onboard3"
        case onboard4 = "Onboard4"
        
        var instruction: String {
            switch self {
            case .onboard1:
                return Onboarding.onb_onb1_key.localized
            case .onboard2:
                if #available(iOS 26.0, *) {
                    let v26 = L10n.tr("onb_onb2_ios26_key", table: "Onboarding")
                    return v26 != "onb_onb2_ios26_key" ? v26 : Onboarding.onb_onb2_key.localized
                }
                return Onboarding.onb_onb2_key.localized
            case .onboard3:
                return Onboarding.onb_onb3_key.localized
            case .onboard4:
                return Onboarding.onb_onb4_key.localized
            }
        }
        
        var index: Int {
            Self.allCases.firstIndex(of: self) ?? 0
        }
    }
    
    var body: some View {
        let _ = language
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            if mode == .removeCyrillic {
                removeCyrillicGuideView
                    .padding(16)
            } else {
                TabView(selection: $selected) {
                    ForEach(Page.allCases, id: \.rawValue) { page in
                        onboardingPage(page)
                            .tag(page.rawValue)
                            .padding(12)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: selected)
            }
        }
        .onAppear {
            let validPage = Page(rawValue: initialPage)?.rawValue ?? Page.onboard1.rawValue
            if selected != validPage {
                selected = validPage
            }
        }
        .onChange(of: initialPage) { _, newValue in
            let validPage = Page(rawValue: newValue)?.rawValue ?? Page.onboard1.rawValue
            if selected != validPage {
                selected = validPage
            }
        }
        .onChange(of: mode) { _, _ in
            let validPage = Page(rawValue: initialPage)?.rawValue ?? Page.onboard1.rawValue
            if selected != validPage {
                selected = validPage
            }
        }
        .accessibilityIdentifier(mode == .removeCyrillic ? "onboarding.removeCyrillic.view" : "onboarding.add.view")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            NavToolbarItem(placement: .navigationBarLeading, symbol: "chevron.backward") {
                dismiss()
            }
            ToolbarItem(placement: .principal) {
                Text(mode == .removeCyrillic ? L10n.tr("onb_remove_cyrillic_title", table: "Onboarding") : Onboarding.onb_settings_key.localized)
                    .titleText()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }

    private var removeCyrillicGuideView: some View {
        VStack(spacing: 16) {
            formattedInstructionText(for: L10n.tr("onb_remove_cyrillic_desc", table: "Onboarding"))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            navButton(text: Onboarding.onb_open_key.localized, gradient: Color.crayola) {
                HomeView.openKeyboardSettings()
            }
            .padding(.horizontal, 20)
            .accessibilityIdentifier("onboarding.openSettings.button")

            Image("Onboard2")
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
                .padding(.bottom, 8)

            navButton(text: Onboarding.onb_finish_key.localized, gradient: Color.crayola) {
                dismiss()
            }
            .padding(.horizontal, 20)
            .accessibilityIdentifier("onboarding.finish.button")
        }
        .frame(maxWidth: Device.iPad ? 620 : .infinity)
        .frame(maxWidth: .infinity)
    }
}

private extension OnboardingView {
    
    private func onboardingPage(_ page: Page) -> some View {
        VStack {
            formattedInstructionText(for: page.instruction)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            if page == .onboard1 || page == .onboard2 {
                navButton(text: Onboarding.onb_open_key.localized, gradient: Color.crayola) {
                    HomeView.openKeyboardSettings()
                }
                .padding(.horizontal, 20)
            }
            
            if page == .onboard3 {
                TextField(text: $text) {
                    Text(Onboarding.onb_check_key.localized).regularText(color: Color(.placeholderText))
                }
                .font(.custom("GeneralSans-Regular", size: Device.iPad ? 16 : 12))
                .foregroundStyle(Color(.label))
                .padding()
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .lineLimit(1)
                .submitLabel(.done)
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.primary.opacity(0.25), lineWidth: 1.5)
                }
            }
            
            Image(page.rawValue)
                .resizable()
                .scaledToFit()
                .accessibilityHidden(true)
                .padding(.bottom, 10)
            
            HStack {
                navButton(text: Onboarding.onb_back_key.localized, gradient: Color.coral) {
                    let pages = Page.allCases
                    let index = page.index
                    guard index > 0 else { return }
                    selected = pages[index - 1].rawValue
                }
                .opacity(page == .onboard1 ? 0 : 1)
                .disabled(page == .onboard1)
                
                Spacer()
                
                Text("\(page.index + 1)/\(Page.allCases.count)")
                    .mediumText()
                
                Spacer()
                
                navButton(
                    text: page == .onboard4
                        ? Onboarding.onb_finish_key.localized
                        : Onboarding.onb_next_key.localized,
                    gradient: page == .onboard4 ? Color.crayola : Color.french
                ) {
                    let pages = Page.allCases
                    let nextIndex = page.index + 1
                    if nextIndex < pages.count {
                        selected = pages[nextIndex].rawValue
                    } else {
                        dismiss()
                    }
                }
            }
        }
        .frame(maxWidth: Device.iPad ? 620 : .infinity)
        .frame(maxWidth: .infinity)
    }
    
    private func navButton(text: String, gradient: Color, action: @escaping () -> Void) -> some View {
        Button {
            HapticFeedback.playSelection()
            action()
        } label: {
            Text(text)
                .mediumText()
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(LinearGradient(
                    colors: [gradient, Color.primary.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
    
    private func formattedInstructionText(for text: String) -> Text {
        let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        let title = parts.first.map { String($0) } ?? ""
        let description = parts.count > 1
            ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            : ""
        let size: CGFloat = Device.iPad ? 20 : 16
        
        var result = Text.customFontText(
            title,
            fontName: "GeneralSans-Semibold",
            size: size
        )
        
        if !description.isEmpty {
            result = result
                + Text(": ")
                    .font(.custom("GeneralSans-Medium", size: Device.iPad ? size + 4 : size))
                    .foregroundStyle(Color(.label))
                + Text.customFontText(
                    description,
                    fontName: "GeneralSans-Medium",
                    size: size
                )
        }
        
        return result
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
    }
}
