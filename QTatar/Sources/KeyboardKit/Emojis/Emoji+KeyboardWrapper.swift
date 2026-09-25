//
//  Emoji+KeyboardWrapper.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2023-10-26.
//  Copyright © 2023-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI

public extension Emoji {
    
    /// A lightweight emoji keyboard used by the system keyboard.
    struct KeyboardWrapper: View {
        
        public init(
            actionHandler: KeyboardActionHandler,
            keyboardContext: KeyboardContext,
            calloutContext: CalloutContext?,
            styleProvider: KeyboardStyleProvider
        ) {
            self.actionHandler = actionHandler
            self.keyboardContext = keyboardContext
        }
        
        private let actionHandler: KeyboardActionHandler
        private let keyboardContext: KeyboardContext
        
        private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 8)
        
        public var body: some View {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(emojis, id: \.char) { emoji in
                            Button {
                                actionHandler.handle(.character(emoji.char))
                            } label: {
                                Text(emoji.char)
                                    .font(.system(size: 28))
                                    .frame(maxWidth: .infinity, minHeight: 36)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.top, 4)
                }
                
                HStack {
                    Button {
                        keyboardContext.keyboardType = .alphabetic(.auto)
                    } label: {
                        Text(KKL10n.switcherAlphabetic.text(for: keyboardContext))
                            .font(.system(size: 16, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
                .background(Color.keyboardDarkButtonBackground)
            }
            .background(Color.keyboardBackground(for: keyboardContext))
        }
        
        private var emojis: [Emoji] {
            EmojiCategory.all
                .filter { $0 != .frequent }
                .flatMap(\.emojis)
        }
        
        static let isPro = false
    }
}
