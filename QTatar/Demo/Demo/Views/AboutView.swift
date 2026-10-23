//
//  AboutView.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 17.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI
import StoreKit

struct AboutView: View {
    @Binding var navigationPath: NavigationPath
    @AppStorage(KeyboardPreferences.languageKey, store: KeyboardPreferences.defaults) private var language = "crh"
    
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    
    private var socialMediaLinks: [(String, String)] {
        [
            (About.about_website_key.localized, Configurations.website),
            ("Instagram", Configurations.instagram),
            ("Facebook", Configurations.facebook),
            ("GitHub", Configurations.github),
            ("Telegram", Configurations.telegram)
        ]
    }
    
    var body: some View {
        let _ = language
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()
            ScrollViewReader { scroll in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 18) {
                        headerSection
                        projectSection
                        contactSection
                            .id("contactSection")
                        feedbackSection
                        FooterView()
                    }
                    .padding(.horizontal, Device.iPhone ? 12 : 24)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    if ProcessInfo.processInfo.arguments.contains("-qt_open_about") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            scroll.scrollTo("contactSection", anchor: .center)
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            NavToolbarItem(placement: .navigationBarLeading, symbol: "chevron.backward") {
                dismiss()
            }
            NavToolbarItem(placement: .navigationBarTrailing, symbol: "questionmark") {
                navigationPath.append(DemoRoute.onboarding)
            }
            ToolbarItem(placement: .principal) {
                Text(About.about_title_key.localized)
                    .titleText(size: 24)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
    }
}

private extension AboutView {
    
    var headerSection: some View {
        VStack(spacing: 12) {
            TaraqTamgaLogoBadge(size: 84, cornerRadius: 20)
            Text(About.about_first_key.localized)
                .titleText()
                .multilineTextAlignment(.center)
            Text(About.about_description_key.localized)
                .regularText(size: 14, color: Color(.secondaryLabel))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
    }
    
    var projectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            containerTitle(title: About.about_init_key.localized, icon: "atom")
            HStack(alignment: .top, spacing: 12) {
                projectContainer(illustration: "quizlet", projectName: About.about_spell_title_key.localized, description: About.about_spell_description_key.localized, link: Configurations.quizlet)
                projectContainer(illustration: "languagetool", projectName: About.about_language_title_key.localized, description: About.about_language_description_key.localized, link: Configurations.languagetool)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 3)
    }
    
    var contactSection: some View {
        let links = socialMediaLinks
        return VStack(alignment: .leading, spacing: 8) {
            containerTitle(title: About.about_join_key.localized, icon: "hand.thumbsup")

            if Device.iPhone {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(Array(links.prefix(3)), id: \.0) { social, link in
                            linkButton(name: social, link: link)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(Array(links.dropFirst(3)), id: \.0) { social, link in
                            linkButton(name: social, link: link)
                        }
                    }
                }
            } else {
                HStack(alignment: .center, spacing: 10) {
                    ForEach(links, id: \.0) { social, link in
                        linkButton(name: social, link: link)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 3)
    }
    
    var feedbackSection: some View {
        VStack(spacing: 8) {
            containerTitle(title: About.about_feedback_key.localized, icon: "ellipsis.message")
            
            feedbackButton(title: About.about_rate_key.localized, icon: "star") {
                AppStoreReviewManager.openWriteReviewPage(using: openURL)
            }
            .accessibilityIdentifier("about.rateButton")
            
            ShareLink(
                item: AppStoreReviewManager.appStoreURL,
                subject: Text("QırımKey"),
                message: Text(About.about_first_key.localized)
            ) {
                cellItem(title: About.about_share_key.localized, icon: "arrowshape.turn.up.forward")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("about.shareButton")
            
            feedbackButton(title: About.about_send_key.localized, icon: "heart") {
                openURL(URL(string: Configurations.donatello)!)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 3)
    }
    
    // MARK: Additional components
    func containerTitle(title: String, icon: String) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Text(title)
                .mediumText(size: Device.iPhone ? 16 : 18)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            Image(systemName: icon)
                .imageScale(.large)
                .foregroundStyle(Color(.label))
        }
        .padding(.bottom, 6)
    }
    
    func linkButton(name: String, link: String) -> some View {
        Button {
            withAnimation {
                HapticFeedback.playSelection()
                openURL(URL(string: link)!)
            }
        } label: {
            HStack(spacing: 4) {
                Text(name)
                    .regularText(size: 13.5, color: Color(.systemBackground))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Image(systemName: "arrow.up.forward.app")
                    .imageScale(.small)
                    .foregroundStyle(Color(.systemBackground))
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(Color(.label))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    func feedbackButton(
        title: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticFeedback.playSelection()
            action()
        } label: {
            cellItem(title: title, icon: icon)
        }
        .buttonStyle(.plain)
    }
    
    func cellItem(title: String, icon: String) -> some View {
        HStack {
            Text(title).regularText(size: 14)
            Spacer(minLength: 8)
            Image(systemName: icon)
                .imageScale(.medium)
                .foregroundStyle(Color(.label))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
        .contentShape(Capsule())
        .overlay {
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [Color.french, Color.primary.opacity(0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        }
    }
    
    func projectContainer(illustration: String, projectName: String, description: String, link: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(illustration)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.18), lineWidth: 1.5))
            
            Text(projectName)
                .mediumText()
                .fixedSize(horizontal: false, vertical: true)
            
            Button {
                withAnimation {
                    HapticFeedback.playSelection()
                    openURL(URL(string: link)!)
                }
            } label: {
                HStack {
                    Text(About.about_more_key.localized).regularText(size: 14, color: Color(.systemBackground))
                    Image(systemName: "arrow.up.forward.app")
                        .imageScale(.small)
                        .foregroundStyle(Color(.systemBackground))
                }
                .padding(7)
                .frame(maxWidth: .infinity)
                .background(Color(.label))
                .clipShape(Capsule())
            }
            
            Text(description)
                .regularText(color: Color(.secondaryLabel))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 1)
        }
        .padding(14)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    @Previewable @State var navigationPath = NavigationPath()
    NavigationStack(path: $navigationPath) {
        AboutView(navigationPath: $navigationPath)
    }
}
