//
//  Emoji+KeyboardWrapper.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2023-10-26.
//  Copyright © 2023-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI

public extension Emoji {
    
    /// A native-styled emoji keyboard used by the system keyboard when `.keyboardType(.emojis)` is selected.
    struct KeyboardWrapper: View {
        
        public init(
            actionHandler: KeyboardActionHandler,
            keyboardContext: KeyboardContext,
            calloutContext: CalloutContext?,
            styleProvider: KeyboardStyleProvider
        ) {
            self.actionHandler = actionHandler
            self.keyboardContext = keyboardContext
            self.styleProvider = styleProvider
        }
        
        private let actionHandler: KeyboardActionHandler
        @ObservedObject private var keyboardContext: KeyboardContext
        private let styleProvider: KeyboardStyleProvider
        
        @State private var selectedCategory: EmojiCategory = .smileysAndPeople
        
        private var categories: [EmojiCategory] {
            EmojiCategory.all
        }
        
        private var rows: [GridItem] {
            Array(repeating: GridItem(.flexible(), spacing: 2), count: 5)
        }
        
        private var totalHeight: CGFloat {
            let config = (styleProvider as? StandardKeyboardStyleProvider)?
                .keyboardLayoutConfiguration
                ?? .standard(for: keyboardContext)
            return config.rowHeight * 4
        }
        
        private var activeEmojis: [Emoji] {
            if selectedCategory == .frequent {
                let recents = Emoji.frequentEmojiProvider.emojis
                if !recents.isEmpty { return recents }
                return Array(EmojiCategory.smileysAndPeople.emojis.prefix(30))
            }
            return selectedCategory.emojis
        }
        
        private func categorySystemIcon(for category: EmojiCategory) -> String {
            switch category {
            case .frequent: return "clock"
            case .smileysAndPeople: return "face.smiling"
            case .animalsAndNature: return "pawprint"
            case .foodAndDrink: return "fork.knife"
            case .activity: return "soccerball"
            case .travelAndPlaces: return "car"
            case .objects: return "lightbulb"
            case .symbols: return "number"
            case .flags: return "flag"
            case .custom: return "star"
            }
        }

        private var activeInterfaceLanguage: String {
            if let saved = UserDefaults(suiteName: "group.crh.key.keyboardplus")?.string(forKey: "crh.key.interfaceLanguage"),
               !saved.isEmpty {
                return saved
            }
            let pref = Locale.preferredLanguages.first?.lowercased() ?? "crh"
            if pref.hasPrefix("uk") { return "uk" }
            if pref.hasPrefix("en") { return "en" }
            return "crh"
        }

        private func categoryHeaderTitle(for category: EmojiCategory) -> String {
            let lang = activeInterfaceLanguage
            switch category {
            case .frequent:
                return lang == "uk" ? "ЧАСТІ" : (lang == "en" ? "FREQUENTLY USED" : "SIQ QULLANILĞAN")
            case .smileysAndPeople:
                return lang == "uk" ? "СМАЙЛИ ТА ЛЮДИ" : (lang == "en" ? "SMILEYS & PEOPLE" : "TEBESSÜMLER VE İNSANLAR")
            case .animalsAndNature:
                return lang == "uk" ? "ТВАРИНИ ТА ПРИРОДА" : (lang == "en" ? "ANIMALS & NATURE" : "AYVANLAR VE TABİAT")
            case .foodAndDrink:
                return lang == "uk" ? "ЇЖА ТА НАПОЇ" : (lang == "en" ? "FOOD & DRINK" : "AŞ VE İÇKİLER")
            case .activity:
                return lang == "uk" ? "АКТИВНІСТЬ" : (lang == "en" ? "ACTIVITY" : "FAALİYET")
            case .travelAndPlaces:
                return lang == "uk" ? "ПОДОРОЖІ ТА МІСЦЯ" : (lang == "en" ? "TRAVEL & PLACES" : "SEYAAT VE YERLER")
            case .objects:
                return lang == "uk" ? "ПРЕДМЕТИ" : (lang == "en" ? "OBJECTS" : "NEZNE VE EŞYALAR")
            case .symbols:
                return lang == "uk" ? "СИМВОЛИ" : (lang == "en" ? "SYMBOLS" : "İŞARETLER")
            case .flags:
                return lang == "uk" ? "ПРАПОРИ" : (lang == "en" ? "FLAGS" : "BAYRAQLAR")
            case .custom:
                return lang == "uk" ? "ВЛАСНІ" : (lang == "en" ? "CUSTOM" : "MAHSUS")
            }
        }
        
        public var body: some View {
            let isCyrillic = keyboardContext.locale.identifier.contains("Cyrl")
            let isDark = keyboardContext.hasDarkColorScheme
            let fgColor: Color = isDark ? .white : .black
            VStack(spacing: 0) {
                Text(categoryHeaderTitle(for: selectedCategory))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(fgColor.opacity(0.52))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: 18)
                    .accessibilityIdentifier("emoji.categoryHeader")

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHGrid(rows: rows, spacing: 8) {
                        ForEach(activeEmojis, id: \.char) { emoji in
                            Button {
                                Emoji.frequentEmojiProvider.registerEmoji(emoji)
                                actionHandler.handle(.press, on: .character(emoji.char))
                                actionHandler.handle(.release, on: .character(emoji.char))
                            } label: {
                                Text(emoji.char)
                                    .font(.system(size: keyboardContext.isKeyboardFloating ? 24 : 29))
                                    .frame(width: 38, height: 34)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                HStack(spacing: 2) {
                    Button {
                        actionHandler.handle(.press, on: .keyboardType(.alphabetic(.lowercased)))
                        actionHandler.handle(.release, on: .keyboardType(.alphabetic(.lowercased)))
                    } label: {
                        Text(isCyrillic ? "АБВ" : "ABC")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(fgColor)
                            .frame(width: 44, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("key.alphabetic")
                    
                    HStack(spacing: 0) {
                        ForEach(categories, id: \.id) { category in
                            let isSelected = category == selectedCategory
                            Button {
                                selectedCategory = category
                            } label: {
                                Image(systemName: categorySystemIcon(for: category))
                                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                                    .foregroundColor(isSelected ? fgColor : fgColor.opacity(0.48))
                                    .frame(maxWidth: .infinity, minHeight: 30)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? fgColor.opacity(0.14) : Color.clear)
                                            .padding(.horizontal, 2)
                                            .padding(.vertical, 3)
                                    )
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    Button {
                        actionHandler.handle(.press, on: .backspace)
                        actionHandler.handle(.release, on: .backspace)
                    } label: {
                        Image(systemName: "delete.backward")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(fgColor)
                            .frame(width: 44, height: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("key.backspace")
                }
                .padding(.horizontal, 6)
                .frame(height: 38)
            }
            .frame(height: totalHeight)
        }
        
        static let isPro = false
    }
}
