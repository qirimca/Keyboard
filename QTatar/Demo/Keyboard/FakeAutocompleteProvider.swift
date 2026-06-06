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
    private var latestQuery = ""
    
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
        let query = AutocompleteQueryResolver.queryText(
            for: keyboardContext.textDocumentProxy
        ) ?? text
        latestQuery = query
        
        let shouldCapitalize = Self.shouldCapitalize(
            typedText: query,
            proxy: keyboardContext.textDocumentProxy
        )
        
        let proxy = keyboardContext.textDocumentProxy
        let suggestions: [Autocomplete.Suggestion]
        
        if query.isEmpty {
            if Self.isDocumentEmpty(proxy) {
                suggestions = manager.starterSuggestions(shouldCapitalize: shouldCapitalize)
            } else if let previousWord = proxy.wordBeforeInput {
                suggestions = manager.nextWordSuggestions(
                    after: previousWord,
                    shouldCapitalize: shouldCapitalize
                )
            } else {
                suggestions = []
            }
        } else {
            suggestions = manager.suggestions(
                for: query,
                shouldCapitalize: shouldCapitalize
            )
        }
        
        guard query == latestQuery else { return [] }
        
        return suggestions.map { suggestion in
            var mapped = suggestion
            mapped.isAutocorrect = suggestion.isAutocorrect && context.isAutocorrectEnabled
            return mapped
        }
    }
}

/// Resolves the word that autocomplete should query in the dictionary.
enum AutocompleteQueryResolver {
    
    static func queryText(for proxy: UITextDocumentProxy) -> String? {
        if let word = proxy.currentWord, !word.isEmpty {
            return word
        }
        
        if let before = proxy.documentContextBeforeInput {
            let fragment = before.wordFragmentAtEnd
            if !fragment.isEmpty {
                return fragment
            }
            if proxy.isCursorAtNewWord {
                return ""
            }
        }
        
        if proxy.documentContextBeforeInput == nil,
           proxy.documentContextAfterInput == nil {
            return ""
        }
        
        return ""
    }
}

private extension FakeAutocompleteProvider {
    
    static func isDocumentEmpty(_ proxy: UITextDocumentProxy) -> Bool {
        let before = proxy.documentContextBeforeInput?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let after = proxy.documentContextAfterInput?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return before.isEmpty && after.isEmpty
    }
    
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
