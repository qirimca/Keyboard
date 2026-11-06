//
//  AboutView.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 17.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

struct AboutView: View {
    var onNavigate: (DemoRoute) -> Void = { _ in }
    @AppStorage(KeyboardPreferences.languageKey, store: KeyboardPreferences.defaults) private var language = "crh"
    
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    private static let imageCacheLock = NSLock()
    private static var cachedImages: [String: UIImage] = [:]
    private static var didStartPrewarm = false

    static func prewarmImagesIfNeeded() {
        imageCacheLock.lock()
        guard !didStartPrewarm else {
            imageCacheLock.unlock()
            return
        }
        didStartPrewarm = true
        imageCacheLock.unlock()
        DispatchQueue.global(qos: .utility).async {
            for name in ["logo", "quizlet", "languagetool"] {
                guard let raw = UIImage(named: name) else { continue }
                let prepared = raw.preparingForDisplay() ?? raw
                imageCacheLock.lock()
                cachedImages[name] = prepared
                imageCacheLock.unlock()
            }
        }
    }

    private static func preparedImage(named name: String) -> UIImage? {
        imageCacheLock.lock()
        if let img = cachedImages[name] {
            imageCacheLock.unlock()
            return img
        }
        imageCacheLock.unlock()
        return UIImage(named: name)
    }

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
            GeometryReader { geo in
                let effectiveWidth = geo.size.width > 0 ? geo.size.width : (Device.iPhone ? 393 : 720)
                let isCompactWidth = Device.iPhone || effectiveWidth < 560
                ScrollViewReader { scroll in
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 14) {
                            headerSection
                                .id("headerSection")
                            projectSection(isCompactWidth: isCompactWidth)
                            contactSection(containerWidth: min(effectiveWidth, 720))
                                .id("contactSection")
                            feedbackSection
                                .id("feedbackSection")
                            FooterView()
                                .id("footerSection")
                        }
                        .padding(.horizontal, isCompactWidth ? 12 : 24)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                        // iPad: keep a readable column instead of stretching cards/illustrations edge-to-edge.
                        .frame(maxWidth: Device.iPad ? min(effectiveWidth, 720) : .infinity)
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        Self.prewarmImagesIfNeeded()
                        if ProcessInfo.processInfo.arguments.contains("-qt_open_about") || ProcessInfo.processInfo.arguments.contains("-qt_dump_all_proofs") {
                            for delay in [0.08, 0.20, 0.35] {
                                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                                    withAnimation(.linear(duration: 0.05)) {
                                        if isCompactWidth {
                                            scroll.scrollTo("feedbackSection", anchor: .bottom)
                                        } else {
                                            scroll.scrollTo("footerSection", anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .enableInteractivePopAndLeftEdgeSwipe { dismiss() }
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            NavToolbarItem(placement: .navigationBarLeading, symbol: "chevron.backward") {
                dismiss()
            }
            NavToolbarItem(placement: .navigationBarTrailing, symbol: "questionmark") {
                onNavigate(.onboarding)
            }
            ToolbarItem(placement: .principal) {
                Text(About.about_title_key.localized)
                    .titleText(size: 24)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
    }
}

private extension AboutView {
    
    var headerSection: some View {
        VStack(spacing: 8) {
            TaraqTamgaLogoBadge(size: 72, cornerRadius: 18)
                .accessibilityHidden(true)
            Text(About.about_first_key.localized)
                .titleText()
                .multilineTextAlignment(.center)
            Text(About.about_description_key.localized)
                .regularText(size: 14, color: Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal)
        .frame(maxWidth: .infinity)
    }
    
    func projectSection(isCompactWidth: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            containerTitle(title: About.about_init_key.localized, icon: "atom")
            if isCompactWidth {
                VStack(alignment: .leading, spacing: 12) {
                    projectContainer(illustration: "quizlet", projectName: About.about_spell_title_key.localized, description: About.about_spell_description_key.localized, link: Configurations.quizlet)
                    projectContainer(illustration: "languagetool", projectName: About.about_language_title_key.localized, description: About.about_language_description_key.localized, link: Configurations.languagetool)
                }
            } else {
                HStack(alignment: .top, spacing: 12) {
                    projectContainer(illustration: "quizlet", projectName: About.about_spell_title_key.localized, description: About.about_spell_description_key.localized, link: Configurations.quizlet)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    projectContainer(illustration: "languagetool", projectName: About.about_language_title_key.localized, description: About.about_language_description_key.localized, link: Configurations.languagetool)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 3)
    }
    
    func contactSection(containerWidth: CGFloat) -> some View {
        let links = socialMediaLinks
        return VStack(alignment: .leading, spacing: 8) {
            containerTitle(title: About.about_join_key.localized, icon: "hand.thumbsup")

            if containerWidth < 460 {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(Array(links.prefix(2)), id: \.0) { social, link in
                            linkButton(name: social, link: link, fixedHorizontal: true)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(Array(links.dropFirst(2).prefix(2)), id: \.0) { social, link in
                            linkButton(name: social, link: link, fixedHorizontal: true)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(Array(links.dropFirst(4)), id: \.0) { social, link in
                            linkButton(name: social, link: link, fixedHorizontal: true)
                        }
                    }
                }
            } else if containerWidth < 640 {
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        ForEach(Array(links.prefix(3)), id: \.0) { social, link in
                            linkButton(name: social, link: link, fixedHorizontal: true)
                        }
                    }
                    HStack(spacing: 8) {
                        ForEach(Array(links.dropFirst(3)), id: \.0) { social, link in
                            linkButton(name: social, link: link, fixedHorizontal: true)
                        }
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 10) {
                        ForEach(links, id: \.0) { social, link in
                            linkButton(name: social, link: link, fixedHorizontal: true)
                        }
                    }
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            ForEach(Array(links.prefix(3)), id: \.0) { social, link in
                                linkButton(name: social, link: link, fixedHorizontal: true)
                            }
                        }
                        HStack(spacing: 8) {
                            ForEach(Array(links.dropFirst(3)), id: \.0) { social, link in
                                linkButton(name: social, link: link, fixedHorizontal: true)
                            }
                        }
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
            
            feedbackButton(title: About.about_share_key.localized, icon: "arrowshape.turn.up.forward") {
                presentShareSheet()
            }
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

    private func presentShareSheet() {
        let shareText = "\(About.about_first_key.localized)\n\(AppStoreReviewManager.appStoreURL.absoluteString)"
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first(where: { $0 is UIWindowScene }) as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else { return }
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = rootVC.view
            popover.sourceRect = CGRect(x: rootVC.view.bounds.midX, y: rootVC.view.bounds.midY, width: 1, height: 1)
            popover.permittedArrowDirections = []
        }
        rootVC.present(activityVC, animated: true)
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
                .accessibilityHidden(true)
        }
        .padding(.bottom, 6)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
    
    func linkButton(name: String, link: String, fixedHorizontal: Bool = false) -> some View {
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
                    .fixedSize(horizontal: fixedHorizontal, vertical: false)
                Image(systemName: "arrow.up.forward.app")
                    .imageScale(.small)
                    .foregroundStyle(Color(.systemBackground))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity)
            .background(Color(.label))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(.isLink)
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
        let isHighContrast = colorSchemeContrast == .increased
        return HStack {
            Text(title).regularText(size: 14)
            Spacer(minLength: 8)
            Image(systemName: icon)
                .imageScale(.medium)
                .foregroundStyle(Color(.label))
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(Color(.tertiarySystemGroupedBackground), in: Capsule())
        .contentShape(Capsule())
        .overlay {
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [Color.french, Color.primary.opacity(isHighContrast ? 0.65 : 0.35)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isHighContrast ? 2.0 : 1.5
                )
        }
        .accessibilityElement(children: .combine)
    }
    
    func projectContainer(illustration: String, projectName: String, description: String, link: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Group {
                if let uiImg = Self.preparedImage(named: illustration) {
                    Image(uiImage: uiImg)
                        .resizable()
                } else {
                    Image(illustration)
                        .resizable()
                }
            }
            .scaledToFit()
            .frame(maxWidth: .infinity, maxHeight: Device.iPad ? 132 : 140)
            .accessibilityHidden(true)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.primary.opacity(0.18), lineWidth: 1.5))
            
            Text(projectName)
                .mediumText()
                .lineLimit(1)
                .minimumScaleFactor(0.90)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            Button {
                withAnimation {
                    HapticFeedback.playSelection()
                    openURL(URL(string: link)!)
                }
            } label: {
                HStack(spacing: 4) {
                    Text(About.about_more_key.localized)
                        .regularText(size: 14, color: Color(.systemBackground))
                        .lineLimit(1)
                    Image(systemName: "arrow.up.forward.app")
                        .imageScale(.small)
                        .foregroundStyle(Color(.systemBackground))
                        .accessibilityHidden(true)
                }
                .padding(7)
                .frame(maxWidth: .infinity)
                .background(Color(.label))
                .clipShape(Capsule())
            }
            .accessibilityLabel("\(About.about_more_key.localized), \(projectName)")
            .accessibilityAddTraits(.isLink)
            
            Text(description)
                .regularText(color: Color(.secondaryLabel))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.035), radius: 10, x: 0, y: 3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
