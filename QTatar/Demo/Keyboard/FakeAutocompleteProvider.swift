//
//  FakeAutocompleteProvider.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2022-02-07.
//  Copyright © 2022-2024 Daniel Saidi. All rights reserved.
//

import Foundation
import KeyboardKit
import UIKit

/// Crimean Tatar autocomplete backed by the local SQLite dictionary.
class FakeAutocompleteProvider: AutocompleteProvider {

    private let manager = SuggestionsDataBaseManager()
    private let keyboardContext: KeyboardContext
    
    init(
        context: AutocompleteContext,
        keyboardContext: KeyboardContext
    ) {
        self.context = context
        self.keyboardContext = keyboardContext
        manager.prepare()
    }

    private var context: AutocompleteContext
    
    var locale: Locale = .current
    
    var canIgnoreWords: Bool { false }
    var canLearnWords: Bool { false }
    var ignoredWords: [String] = []
    var learnedWords: [String] = []
    
    func hasIgnoredWord(_ word: String) -> Bool { false }
    func hasLearnedWord(_ word: String) -> Bool { false }
    func ignoreWord(_ word: String) {}
    func learnWord(_ word: String) {}
    func removeIgnoredWord(_ word: String) {}
    func unlearnWord(_ word: String) {}
    
    func autocompleteSuggestions(
        for text: String
    ) async throws -> [Autocomplete.Suggestion] {
        let shouldCapitalize = Self.shouldCapitalize(
            typedText: text,
            proxy: keyboardContext.textDocumentProxy
        )
        
        return manager.suggestions(
            for: text,
            shouldCapitalize: shouldCapitalize
        ).map { suggestion in
            var mapped = suggestion
            mapped.isAutocorrect = suggestion.isAutocorrect && context.isAutocorrectEnabled
            return mapped
        }
    }
}

private extension FakeAutocompleteProvider {
    
    static func shouldCapitalize(
        typedText: String,
        proxy: UITextDocumentProxy
    ) -> Bool {
        if typedText.first?.isUppercase == true { return true }
        if proxy.isCursorAtNewSentence { return true }
        if proxy.isCursorAtNewWord,
           let before = proxy.documentContextBeforeInput,
           before.trimmingCharacters(in: .whitespaces).isEmpty {
            return true
        }
        return false
    }
}
