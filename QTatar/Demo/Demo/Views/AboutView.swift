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
    @Environment(\.requestReview) var requestReview
    @Environment(\.openURL) var openURL
    @Environment(\.dismiss) var dismiss
    
    @State private var showOnboardingView: Bool = false
    
    let socialMediaLinks = [
        ("Website", Configurations.website),
        ("Instagram", Configurations.instagram),
        ("Facebook", Configurations.facebook),
        ("GitHub", Configurations.github),
        ("Telegram", Configurations.telegram)
    ]
    
    var body: some View {
        ZStack {
            Color("BackgroungColor").ignoresSafeArea()
            BackgroundGrid()
            VStack {
                headerSection
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        projectSection
                        contactSection
                        feedbackSection
                        FooterView()
                    }.padding(1)
                }.refreshable {}
            }.padding(12)
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $showOnboardingView, destination: {
            OnboardingView()
        })
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavButton(symbol: "chevron.backward") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                NavButton(symbol: "questionmark") {
                    showOnboardingView.toggle()
                }
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
            Image("logo")
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .frame(height: 84)
            Text(About.about_first_key.localized)
                .titleText()
                .multilineTextAlignment(.center)
            Text(About.about_description_key.localized)
                .regularText(size: 14)
                .multilineTextAlignment(.center)
            
        }.padding(.horizontal)
    }
    
    var projectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            containerTitle(title: About.about_init_key.localized, icon: "atom")
            HStack {
                projectContainer(illustration: "quizlet", projectName: About.about_spell_title_key.localized, description: About.about_spell_description_key.localized, link: Configurations.quizlet)
                projectContainer(illustration: "languagetool", projectName: About.about_language_title_key.localized, description: About.about_language_description_key.localized, link: Configurations.languagetool)
            }
        }
        .padding(12)
        .background(Color.backgroundLight)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 2))
    }
    
    var contactSection: some View {
        VStack(spacing: 6) {
            containerTitle(title: About.about_join_key.localized, icon: "hand.thumbsup")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .center, spacing: 15) {
                    ForEach(socialMediaLinks, id: \.0) { social, link in
                        linkButton(name: social, link: link)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.backgroundLight)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 2))
    }
    
    var feedbackSection: some View {
        VStack(spacing: 6) {
            containerTitle(title: About.about_feedback_key.localized, icon: "ellipsis.message")
            
            cellItem(title: About.about_rate_key.localized, icon: "star")
                .onTapGesture {
                    withAnimation {
                        HapticFeedback.playSelection()
                        requestReview()
                    }
                }
            
            ShareLink(item: URL(string: "https://apps.apple.com/app/id\(Configurations.appID)?action=write-review")!) {
                cellItem(title: About.about_share_key.localized, icon: "arrowshape.turn.up.forward")
            }
            
            cellItem(title: About.about_send_key.localized, icon: "heart")
                .onTapGesture {
                    withAnimation {
                        HapticFeedback.playSelection()
                        openURL(URL(string: Configurations.donatello)!)
                    }
                }
        }
        .padding(12)
        .background(Color.backgroundLight)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 2))
    }
    
    // MARK: Additional components
    func containerTitle(title: String, icon: String) -> some View {
        HStack {
            Text(title).mediumText()
            Spacer()
            Image(systemName: icon)
                .imageScale(.large)
        }.padding(.bottom, 6)
    }
    
    func linkButton(name: String, link: String) -> some View {
        Button {
            withAnimation {
                HapticFeedback.playSelection()
                openURL(URL(string: link)!)
            }
        } label: {
            HStack {
                Text(name).regularText(size: 14, color: .white)
                Image(systemName: "arrow.up.forward.app")
                    .imageScale(.small)
                    .foregroundStyle(.white)
            }
            .padding(7)
            .padding(.horizontal, 12)
            .background(.black)
            .clipShape(Capsule())
        }
    }
    
    func cellItem(title: String, icon: String) -> some View {
        HStack {
            Text(title).regularText(size: 14)
            Spacer()
            Image(systemName: icon).imageScale(.medium)
        }
        .padding()
        .overlay(Capsule().stroke(LinearGradient(
            colors: [Color.french, Color.black],
            startPoint: .topLeading,
            endPoint: .bottomTrailing), lineWidth: 2))
    }
    
    func projectContainer(illustration: String, projectName: String, description: String, link: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(illustration)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 2))
            
            Text(projectName).mediumText()
            
            Button {
                withAnimation {
                    HapticFeedback.playSelection()
                    openURL(URL(string: link)!)
                }
            } label: {
                HStack {
                    Text(About.about_more_key.localized).regularText(size: 14, color: .white)
                    Image(systemName: "arrow.up.forward.app")
                        .imageScale(.small)
                        .foregroundStyle(.white)
                }
                .padding(7)
                .frame(maxWidth: .infinity)
                .background(.black)
                .clipShape(Capsule())
            }
            
            Text(description).regularText()
            Spacer(minLength: 1)
        }
        .padding(12)
        .background(Color.backgroundLight)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 2))
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    AboutView()
}
