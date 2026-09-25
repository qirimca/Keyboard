//
//  OnboardingView.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 19.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.openURL) var openURL
    @State private var selected = Page.onboard1.rawValue
    @State private var text = ""
    
    private enum Page: String, CaseIterable {
        case onboard1 = "Onboard1"
        case onboard2 = "Onboard2"
        case onboard3 = "Onboard3"
        case onboard4 = "Onboard4"
        
        var instruction: String {
            switch self {
            case .onboard1: Onboarding.onb_onb1_key.localized
            case .onboard2: Onboarding.onb_onb2_key.localized
            case .onboard3: Onboarding.onb_onb3_key.localized
            case .onboard4: Onboarding.onb_onb4_key.localized
            }
        }
        
        var index: Int {
            Self.allCases.firstIndex(of: self) ?? 0
        }
    }
    
    var body: some View {
        ZStack {
            Color("BackgroungColor").ignoresSafeArea()
            BackgroundGrid()
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
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            NavToolbarItem(placement: .navigationBarLeading, symbol: "chevron.backward") {
                dismiss()
            }
            ToolbarItem(placement: .principal) {
                Text(Onboarding.onb_settings_key.localized)
                    .titleText()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
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
                    openURL(URL(string: UIApplication.openSettingsURLString)!)
                }
                .padding(.horizontal, 20)
            }
            
            if page == .onboard3 {
                TextField(text: $text) {
                    Text(Onboarding.onb_check_key.localized).regularText()
                }
                .font(.custom("GeneralSans-Regular", size: Device.iPad ? 16 : 12))
                .padding()
                .cornerRadius(20)
                .lineLimit(1)
                .submitLabel(.done)
                .background(Color.backgroundLight)
                .overlay {
                    RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 2)
                }
            }
            
            Image(page.rawValue)
                .resizable()
                .scaledToFit()
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
                .background(Color.backgroundLight)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(LinearGradient(
                    colors: [gradient, Color.black],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing), lineWidth: 2))
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
                    .foregroundStyle(.black)
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
