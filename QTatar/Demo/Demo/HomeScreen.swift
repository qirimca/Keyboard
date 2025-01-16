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

    @State private var appearance = ColorScheme.light

    @State private var isAppearanceDark = false

    @AppStorage("crh.key.text") private var text = ""

    @StateObject private var dictationContext = DictationContext(config: .app)

    @StateObject private var keyboardState = KeyboardStateContext(
        bundleId: "crh.key.*")

    @Environment(\.colorScheme)
    private var colorScheme
    
    var body: some View {
        NavigationView {
            List {
                stateSectionHorizontal
                textFieldSection
                instagramLinkSection
            }
            .onChange(of: isAppearanceDark) { newValue in
                appearance = newValue ? .dark : .light
            }
            .background(
                Color(isAppearanceDark ? .black.withAlphaComponent(0.9) : .white)
            )
            .environment(\.colorScheme, appearance)
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
                        Button("Ок", action: action)
                            .buttonStyle(.borderedProminent)
                    }
            }
            .navigationTitle("Qırımtatar klaviaturası (β)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Toggle(isOn: $isAppearanceDark) {
                        TextConst.darkTheme.asText
                    }
                }
            }
        }
        .gesture(
            TapGesture()
                .onEnded {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                },
            including: .gesture
        )
    }
}

extension TextEditor {
    func keyboard(appearance: ColorScheme) -> some View {
        self.modifier(
            Styling.KeyboardAppearanceViewModifier(appearance: appearance)
        )
    }
}

extension HomeScreen {

    var instagramLinkSection: some View {
        Section(header: Text("İşleticiniñ Instagram esabı:")) {
            Button(action: {
                if let url = URL(string: "https://www.instagram.com/crimeantatar_corpora/") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Text("@crimeantatar_corpora").font(.subheadline)
                    Image(systemName: "link")
                        .imageScale(.medium)
                }.foregroundColor(.blue)
                
            }
            .accessibilityLabel("Instagram link")
        }
        .buttonStyle(.plain) // Указываем стиль кнопки
        .tint(.white) // Задаём синий цвет
    }
    
    var stateSectionHorizontal: some View {
        Section(
            header: TextConst.keyboard.asText.padding(.bottom, 0), // Уменьшаем отступы в header
            footer: footerText.padding(.top, 0) // Уменьшаем отступы в footer
        ) {
            VStack(spacing: 0) { // Вся секция обёрнута в VStack без промежутков
                HStack(spacing: 0) {
                    KeyboardStateItem(
                        state: .active(keyboardState.isKeyboardActive)
                    )
                    KeyboardStateItem(
                        state: .enable(keyboardState.isKeyboardEnabled)
                    )
                    KeyboardStateItem(
                        state: .fullAccess(keyboardState.isFullAccessEnabled)
                    )
                }
                .padding(0)

                HStack {
                    Text("Klaviatura sazlimaları: ").font(.subheadline)
                    Spacer()
                    Button("Aç ⚙️", action: {
                        if let url = URL(string: UIApplication.openSettingsURLString),
                           UIApplication.shared.canOpenURL(url) {
                            UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        } else {
                            debugPrint("Не удалось открыть настройки.")
                        }
                    })
                    .buttonStyle(.borderedProminent)
                    .tint(.blue.opacity(0.9))
                    .frame(minWidth: 80)
                    .font(.headline)
                }.offset(.init(width: 0, height: -4))
            }
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
        .listRowSeparator(.hidden) // Убираем разделители строк
    }

    var textFieldSection: some View {
        Section(header: TextConst.textPlace.asText) {
            TextEditor(text: $text)
                .keyboard(appearance: appearance)
                .frame(height: 100)
                .environment(\.layoutDirection, isRtl ? .rightToLeft : .leftToRight)
        }
    }

    var editorLinkSection: some View {
        Section(header: TextConst.editor.asText) {
            NavigationLink {
                TextEditor(text: $text)
                    .padding(.horizontal)
                    .navigationTitle(TextConst.editor.rawValue)
            } label: {
                Label {
                    TextConst.fullEditor.asText
                } icon: {
                    Image(systemName: "doc.text")
                }
            }
        }
    }
    
    var footerText: some View {
        TextConst.systemSettingsForKeyboard.asText
    }

    var isRtl: Bool {
        let keyboardId = keyboardState.activeKeyboardBundleIds.first
        return keyboardId?.hasSuffix("rtl") ?? false
    }
}

enum KeyboardState {
    case active(Bool)
    case enable(Bool)
    case fullAccess(Bool)
    
    var title: String {
        switch self {
        case .active(let value):
            return (value ? TextConst.keyboardVisible : .keyboardHidden).rawValue
        case .enable(let value):
            return (value ? TextConst.keyboardOn : .keyboardOff).rawValue
        case .fullAccess(let value):
            return (value ? TextConst.fullAccessOn : .fullAccessOff).rawValue
        }
    }
    
    var state: Bool {
        switch self {
        case .active(let value):
            return value
        case .enable(let value):
            return value
        case .fullAccess(let value):
            return value
        }
    }
    
    var stateColor: Color {
        state ? .cyan : .gray
    }
}

struct KeyboardStateItem: View {
    let state: KeyboardState

    var body: some View {
        VStack(spacing: 0) {
            Circle()
                .frame(width: 16, height: 16)
                .foregroundColor(state.stateColor)
            Text(state.title)
                .multilineTextAlignment(.center)
                .font(.system(size: 11))
        }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(height: 50)
    }
}

#Preview {
    HomeScreen()
}
