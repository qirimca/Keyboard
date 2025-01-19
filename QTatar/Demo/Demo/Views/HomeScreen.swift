//
//  HomeScreen.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI
import KeyboardKitPro

/**
 This is the main demo app screen.
 
 This screen has a text field, an appearance toggle and list
 items that show various keyboard-specific states.
 */

struct HomeScreen: View {
    @AppStorage("crh.key.text") private var text = ""
    
    @StateObject private var dictationContext = DictationContext(config: .app)
    @StateObject private var keyboardState = KeyboardStateContext(bundleId: "crh.key.*")
    
    @State private var showOnboardingView: Bool = false
    @State private var showAboutView: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color("BackgroungColor").ignoresSafeArea()
                BackgroundGrid()
                VStack {
                    statusIndicatorsSection
                    ScrollView(.vertical, showsIndicators: false) {
                        writingAreaSection
                    }
                }
                .padding(Device.iPhone ? 12 : 24)
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
                            Button("âhşı", action: action)
                                .buttonStyle(.borderedProminent)
                        }
                }
            }
            .overlay(alignment: .bottom, content: {
                PrimaryButton(text: "Get Started Now!", background: Color.crayola) {
                    showOnboardingView.toggle()
                }.padding(Device.iPhone ? 12 : 24)
            })
            .gesture(TapGesture().onEnded {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }, including: .gesture)
            .navigationDestination(isPresented: $showAboutView, destination: {
                AboutView()
            })
            .navigationDestination(isPresented: $showOnboardingView, destination: {
                OnboardingView()
            })
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    NavButton(symbol: "questionmark") {
                        showOnboardingView.toggle()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavButton(symbol: "info") {
                        showAboutView.toggle()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("QırımKey").titleText(size: 34)
                }
            }
        }
    }
}

private extension HomeScreen {
    
    var statusIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Qırımtatar klaviaturası — siz içün, siznen birge.").mediumText() // Crimean Tatar Keyboard — for you, with you.
            HStack {
                KeyboardStateItem(state: .active(keyboardState.isKeyboardActive)) {
                    // pop up menu
                }
                KeyboardStateItem(state: .enable(keyboardState.isKeyboardEnabled)) {
                    // pop up menu
                }
                KeyboardStateItem(state: .fullAccess(keyboardState.isFullAccessEnabled)) {
                    // pop up menu
                }
            }
            Text("İlk olaraq Sistem Sazlamalarda klaviaturanı qoşıp, soñra yazğanda 🌐 vastasınen onı saylanız.").regularText(color: .secondary)
        }
    }
    
    var writingAreaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Metin meydanı").mediumText()
                Spacer()
                if !text.isEmpty {
                    HStack {
                        Spacer()
                        Button {
                            text = ""
                        } label: {
                            Image(systemName: "multiply.circle.fill")
                                .foregroundStyle(.black)
                        }
                        .padding(.trailing, 4)
                    }
                }
            }
            .padding([.horizontal, .top])
            
            Divider().padding(.horizontal)
            
            TextField("Type something...", text: $text, axis: .vertical)
                .font(.custom("GeneralSans-Regular", size: Device.iPad ? 16 : 12))
                .padding([.horizontal, .bottom])
                .cornerRadius(20)
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
}

#Preview {
    HomeScreen()
}
