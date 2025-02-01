//
//  HomeView.swift
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

struct HomeView: View {
    @AppStorage("crh.key.text") private var text = ""
    
    @StateObject private var dictationContext = DictationContext(config: .app)
    @StateObject private var keyboardState = KeyboardStateContext(bundleId: "crh.key.*")
    
    @State private var showOnboardingView: Bool = false
    @State private var showIndicatorSheet: Bool = false
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
                            Button(Home.home_ok_key.localized, action: action)
                                .buttonStyle(.borderedProminent)
                        }
                }
            }
            .overlay(alignment: .bottom, content: {
                if !areAllIndicatorsEnabled {
                    PrimaryButton(text: Home.home_start_key.localized, background: Color.crayola) {
                        showOnboardingView.toggle()
                    }.padding(Device.iPhone ? 12 : 24)
                }
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
        }
    }
}

private extension HomeView {
    
    var statusIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Home.home_crimea_key.localized).mediumText()
            HStack {
                KeyboardStateItem(state: .active(keyboardState.isKeyboardActive)) {
                    showIndicatorSheet.toggle()
                }
                KeyboardStateItem(state: .enable(keyboardState.isKeyboardEnabled)) {
                    showIndicatorSheet.toggle()
                }
                KeyboardStateItem(state: .fullAccess(keyboardState.isFullAccessEnabled)) {
                    showIndicatorSheet.toggle()
                }
            }.frame(height: 60)
            
            if !keyboardState.isKeyboardActive {
                Text(Home.home_getkeyboard_key.localized).regularText()
            }
        }
    }
    
    var writingAreaSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(Home.home_writearea_key.localized).mediumText()
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
            
            TextField(text: $text, axis: .vertical) {
                Text(Home.home_typing_key.localized).regularText(size: 14)
            }
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
    
    var areAllIndicatorsEnabled: Bool {
        keyboardState.isKeyboardActive &&
        keyboardState.isKeyboardEnabled &&
        keyboardState.isFullAccessEnabled
    }
}

#Preview {
    HomeView()
}
