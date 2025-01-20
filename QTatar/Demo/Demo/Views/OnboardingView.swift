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
    @State private var selected = "Onboard1"
    @State private var text = ""
    
    var components = [
        "Onboard1": "Allow Full Access: Go to Settings > Apps > QırımKey > Keyboards > Allow Full Access and enable the option.",
        "Onboard2": "Add the Keyboard: Navigate to Settings > General > Keyboards > Add New Keyboard and select Crimean Tatar Keyboard (QırımKey).",
        "Onboard3": "Choose the Keyboard While Typing: While typing, tap the 🌐 icon (or long-press it) and select QırımKey from the list.",
        "Onboard4": "Start Using It: Enjoy using QırımKey with features like haptic feedback and advanced input support."
    ]
    
    private func sortedKeys() -> [String] {
        return components.keys.sorted()
    }
    
    var body: some View {
        
        ZStack {
            Color("BackgroungColor").ignoresSafeArea()
            BackgroundGrid()
            TabView(selection: $selected) {
                ForEach(sortedKeys(), id: \.self) { key in
                    VStack {
                        Text(formattedText(for: components[key] ?? ""))
                            .mediumText()
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        if selected == sortedKeys().first || selected == sortedKeys()[1] {
                            navButton(text: "Open Settings", gradient: Color.crayola) {
                                openURL(URL(string: UIApplication.openSettingsURLString)!)
                            }.padding(.horizontal, 20)
                        }
                        
                        if selected == sortedKeys()[2] {
                            TextField(text: $text) {
                                Text("Check the Keyboard").regularText()
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
                        
                        Image(key)
                            .resizable()
                            .scaledToFit()
                            .padding(.bottom, 10)
                        
                        HStack {
                            navButton(text: "Go Back", gradient: Color.coral, action: {
                                if selected != sortedKeys().first {
                                    if let currentIndex = sortedKeys().firstIndex(of: key) {
                                        selected = sortedKeys()[(currentIndex - 1 + sortedKeys().count) % sortedKeys().count]
                                    }
                                }
                            }).opacity(selected != sortedKeys().first ? 1.0 : 0.0)
                            
                            Spacer()
                            
                            Text("\(sortedKeys().firstIndex(of: key)! + 1)/\(components.count)")
                                .mediumText()
                            
                            Spacer()
                            
                            navButton(text: selected != sortedKeys().last ? "Go Next" : "Finish", gradient: selected != sortedKeys().last ? Color.french : Color.crayola) {
                                if selected != sortedKeys().last {
                                    if let currentIndex = sortedKeys().firstIndex(of: key) {
                                        selected = sortedKeys()[(currentIndex + 1) % sortedKeys().count]
                                    }
                                } else {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .tag(key)
                    .padding(12)
                }
            }.tabViewStyle(.page(indexDisplayMode: .never))
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                NavButton(symbol: "chevron.backward") {
                    dismiss()
                }
            }
            ToolbarItem(placement: .principal) {
                Text("Setting Up the Keyboard").titleText()
            }
        }
    }
}

private extension OnboardingView {
    
    func navButton(text: String, gradient: Color, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation {
                HapticFeedback.playSelection()
                action()
            }
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
    }
    
    func formattedText(for text: String) -> AttributedString {
        let parts = text.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true)
        let title = parts.first.map { String($0) } ?? ""
        let description = parts.count > 1 ? String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines) : ""
        
        var attributedString = AttributedString("")
        
        // Форматирование заголовка
        if !title.isEmpty {
            var titleAttributes = AttributeContainer()
            titleAttributes.font = .boldSystemFont(ofSize: Device.iPad ? 20 : 16)
            attributedString.append(AttributedString(title, attributes: titleAttributes))
        }
        
        // Добавление разделителя и описания
        if !description.isEmpty {
            attributedString.append(AttributedString(": "))
            attributedString.append(AttributedString(description))
        }
        
        return attributedString
    }
}

#Preview {
    OnboardingView()
}
