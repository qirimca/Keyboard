//
//  CrimeanTatarAutocompleteProvider.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2022-02-07.
//  Copyright © 2022-2024 Daniel Saidi. All rights reserved.
//

import Foundation
import KeyboardKit
import UIKit

/// Crimean Tatar autocomplete backed by the local SQLite dictionary.
class CrimeanTatarAutocompleteProvider: AutocompleteProvider {

    private let manager = SuggestionsDataBaseManager.shared
    private let keyboardContext: KeyboardContext
    private var latestQuery = ""

    init(
        context: AutocompleteContext,
        keyboardContext: KeyboardContext
    ) {
        self.context = context
        self.keyboardContext = keyboardContext
        manager.prepareAsync()
    }

    private var context: AutocompleteContext

    var locale: Locale = .current

    var canIgnoreWords: Bool { false }
    var canLearnWords: Bool { KeyboardPreferences.wordLearningEnabled }
    var ignoredWords: [String] = []
    var learnedWords: [String] = []

    func hasIgnoredWord(_ word: String) -> Bool { false }
    func hasLearnedWord(_ word: String) -> Bool { manager.hasLearnedWord(word) }
    func ignoreWord(_ word: String) {}
    func learnWord(_ word: String) {
        let proxy = keyboardContext.textDocumentProxy
        let completed = Self.completedContextWords(before: proxy)
        let prev = proxy.isCursorAtNewWord ? completed.last : completed.dropLast().last
        manager.learnWordIfPermitted(word, previousWord: prev, proxy: proxy)
    }
    func removeIgnoredWord(_ word: String) {}
    func unlearnWord(_ word: String) { manager.unlearnWord(word) }

    func autocompleteSuggestions(
        for text: String
    ) async throws -> [Autocomplete.Suggestion] {
        let snapshot = await MainActor.run {
            captureQuerySnapshot(fallbackText: text)
        }
        let results = computeSuggestions(for: snapshot)
        let isCurrent = await MainActor.run {
            snapshot.query == latestQuery
        }
        return isCurrent ? results : []
    }

    /// Synchronous suggestions for the current document state; used on the async path and directly on Space.
    func suggestionsNow(for text: String) -> [Autocomplete.Suggestion] {
        let snapshot = captureQuerySnapshot(fallbackText: text)
        return computeSuggestions(for: snapshot)
    }

    private struct QuerySnapshot {
        let query: String
        let shouldCapitalize: Bool
        let isDocumentEmpty: Bool
        let completedContextWords: [String]
        let isAutocorrectEnabled: Bool
    }

    private func captureQuerySnapshot(fallbackText: String) -> QuerySnapshot {
        let proxy = keyboardContext.textDocumentProxy
        let query = AutocompleteQueryResolver.queryText(for: proxy) ?? fallbackText
        latestQuery = query
        let shouldCapitalize = Self.shouldCapitalize(
            typedText: query,
            proxy: proxy,
            keyboardContext: keyboardContext
        )
        let isEmpty = query.isEmpty ? Self.isDocumentEmpty(proxy) : false
        let contextWords = (query.isEmpty && !isEmpty) ? Self.completedContextWords(before: proxy) : []
        return QuerySnapshot(
            query: query,
            shouldCapitalize: shouldCapitalize,
            isDocumentEmpty: isEmpty,
            completedContextWords: contextWords,
            isAutocorrectEnabled: context.isAutocorrectEnabled
        )
    }

    private func computeSuggestions(for snapshot: QuerySnapshot) -> [Autocomplete.Suggestion] {
        let suggestions: [Autocomplete.Suggestion]
        if snapshot.query.isEmpty {
            if snapshot.isDocumentEmpty {
                suggestions = []
            } else if !snapshot.completedContextWords.isEmpty {
                suggestions = manager.nextWordSuggestions(
                    contextWords: snapshot.completedContextWords,
                    shouldCapitalize: snapshot.shouldCapitalize
                )
            } else {
                suggestions = []
            }
        } else {
            suggestions = manager.suggestions(
                for: snapshot.query,
                shouldCapitalize: snapshot.shouldCapitalize
            )
        }
        return suggestions.map { suggestion in
            var mapped = suggestion
            mapped.isAutocorrect = suggestion.isAutocorrect && snapshot.isAutocorrectEnabled
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

private extension CrimeanTatarAutocompleteProvider {

    static func completedContextWords(before proxy: UITextDocumentProxy) -> [String] {
        guard let before = proxy.documentContextBeforeInput else { return [] }
        let delimiters = CharacterSet(charactersIn: String.wordDelimiters.joined())
        return before
            .components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    static func isDocumentEmpty(_ proxy: UITextDocumentProxy) -> Bool {
        let before = proxy.documentContextBeforeInput?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let after = proxy.documentContextAfterInput?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return before.isEmpty && after.isEmpty
    }

    static func shouldCapitalize(
        typedText: String,
        proxy: UITextDocumentProxy,
        keyboardContext: KeyboardContext
    ) -> Bool {
        // 1. If user already typed an uppercase letter (e.g. "Q"), keep subsequent completions capitalized
        if let first = typedText.first, first.isUppercase {
            return true
        }

        // 2. If keyboard is alphabetic, shift state directly governs suggestion capitalization:
        // When Shift is on (uppercased/capsLocked), suggestions start with a capital letter.
        // When Shift is off (lowercased), suggestions start with a lowercase letter.
        if case .alphabetic(let casing) = keyboardContext.keyboardType {
            return casing.isUppercased
        }

        // 3. Fallback for non-alphabetic or auto modes:
        if proxy.isCursorAtNewSentence {
            return true
        }
        return false
    }
}
