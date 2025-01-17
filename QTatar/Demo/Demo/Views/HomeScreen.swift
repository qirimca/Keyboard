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
    @StateObject private var keyboardState = KeyboardStateContext(
        bundleId: "crh.key.*")
    
    
    
    @State private var isIndicatorAction: Bool = false
    
    var body: some View {
        ZStack {
            Color(.backgroung).ignoresSafeArea()
            backgroundGrid()
            VStack {
                navbarSection
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
            getStartedButton
        })
        .gesture(
            TapGesture()
                .onEnded {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }, including: .gesture)
    }
}

private extension HomeScreen {
    
    func backgroundGrid(gridSize: CGFloat = 20, dotSize: CGFloat = 2.0) -> some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ForEach(0..<Int(geometry.size.height / gridSize), id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<Int(geometry.size.width / gridSize), id: \.self) { column in
                            Circle()
                                .fill(Color.gray.opacity(0.3)) // Dot color and opacity
                                .frame(width: dotSize, height: dotSize) // Dot size
                                .frame(width: gridSize, height: gridSize) // Center the dot in its grid cell
                        }
                    }
                }
            }
        }.ignoresSafeArea()
    }
    
    var navbarSection: some View {
        HStack {
            Text("Qırımtatar\nklaviaturası").titleText(size: 34)
            Spacer()
            
            Image(systemName: "questionmark")
                .imageScale(.medium)
                .foregroundStyle(.black)
                .padding()
                .overlay {
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 36)
                }
            
            Image(systemName: "gear")
                .imageScale(.medium)
                .foregroundStyle(.black)
                .padding()
                .overlay {
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 36)
                }
                .onTapGesture {
                    withAnimation {
                        if let url = URL(string: UIApplication.openSettingsURLString),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        } else {
                            debugPrint("Не удалось открыть настройки.")
                        }
                    }
                }
            
            Image(systemName: "info")
                .imageScale(.medium)
                .foregroundStyle(.black)
                .padding()
                .overlay {
                    Circle()
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 36)
                }
        }
    }
    
    var statusIndicatorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Klaviatura").mediumText()
            HStack {
                KeyboardStateItem(state: .active(keyboardState.isKeyboardActive)) {
                    isIndicatorAction.toggle()
                }
                KeyboardStateItem(state: .enable(keyboardState.isKeyboardEnabled)) {
                    isIndicatorAction.toggle()
                }
                KeyboardStateItem(state: .fullAccess(keyboardState.isFullAccessEnabled)) {
                    isIndicatorAction.toggle()
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
            
            if #available(iOS 16.0, *) {
                TextField("Type something...", text: $text, axis: .vertical)
                    .font(.custom("GeneralSans-Regular", size: Device.iPad ? 16 : 12))
                    .padding([.horizontal, .bottom])
                    .cornerRadius(20)
                    .environment(\.layoutDirection, isRtl ? .rightToLeft : .leftToRight)
            } else {
                TextEditor(text: $text)
                    .frame(minHeight: 200)
                    .padding([.horizontal, .bottom])
                    .cornerRadius(20)
                    .environment(\.layoutDirection, isRtl ? .rightToLeft : .leftToRight)
            }
        }
        .background(Color("BackgroungColor"))
        .overlay {
            RoundedRectangle(cornerRadius: 20).stroke(Color.black, lineWidth: 2)
        }
        .padding(1)
    }
    
    var getStartedButton: some View {
        Button {
            
        } label: {
            Text("Get Started Now!")
                .mediumText()
                .padding(.vertical)
                .frame(maxWidth: .infinity)
                .background(Color("CrayolaColor"))
                .clipShape(Capsule())
                .overlay {
                    Capsule()
                        .stroke(Color.black, lineWidth: 2)
                }
        }.padding(Device.iPhone ? 12 : 24)
    }
    
    var isRtl: Bool {
        let keyboardId = keyboardState.activeKeyboardBundleIds.first
        return keyboardId?.hasSuffix("rtl") ?? false
    }
}

#Preview {
    HomeScreen()
}
