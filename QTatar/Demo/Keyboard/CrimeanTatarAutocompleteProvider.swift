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
    private weak var controller: UIInputViewController?
    private var latestQuery = ""

    init(
        context: AutocompleteContext,
        keyboardContext: KeyboardContext,
        controller: UIInputViewController? = nil
    ) {
        self.context = context
        self.keyboardContext = keyboardContext
        self.controller = controller
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
        let snapshot: QuerySnapshot? = await MainActor.run {
            if let controller = self.controller {
                guard controller.isViewLoaded, controller.view.window != nil else { return nil }
            }
            guard DemoStyleProvider.shouldShowTopToolbar(for: self.keyboardContext) else { return nil }
            return captureQuerySnapshot(fallbackText: text)
        }
        guard let snapshot else { return [] }
        let results = computeSuggestions(for: snapshot)
        let isCurrent = await MainActor.run {
            if let controller = self.controller {
                guard controller.isViewLoaded, controller.view.window != nil else { return false }
            }
            return snapshot.query == latestQuery
        }
        return isCurrent ? results : []
    }

    /// Synchronous suggestions for the current document state; used on the async path and directly on Space.
    func suggestionsNow(for text: String) -> [Autocomplete.Suggestion] {
        guard DemoStyleProvider.shouldShowTopToolbar(for: keyboardContext) else { return [] }
        let snapshot = captureQuerySnapshot(fallbackText: text)
        return computeSuggestions(for: snapshot)
    }

    private struct QuerySnapshot {
        let query: String
        let mathEvaluation: (expression: String, result: String)?
        let shouldCapitalize: Bool
        let isDocumentEmpty: Bool
        let completedContextWords: [String]
        let isAutocorrectEnabled: Bool
    }

    private func captureQuerySnapshot(fallbackText: String) -> QuerySnapshot {
        let proxy = keyboardContext.textDocumentProxy
        let query = AutocompleteQueryResolver.queryText(for: proxy) ?? fallbackText
        latestQuery = query
        let mathAllowed: Bool = {
            guard SystemKeyboardSettings.isShowMathResultsEnabled else { return false }
            if #available(iOS 18.0, *) {
                return proxy.mathExpressionCompletionType != .no
            }
            return true
        }()
        let mathEvaluation = mathAllowed
            ? MathExpressionEvaluator.evaluateTrailingExpressionWithLiteral(in: proxy.documentContextBeforeInput ?? fallbackText)
            : nil
        let shouldCapitalize = Self.shouldCapitalize(
            typedText: query,
            proxy: proxy,
            keyboardContext: keyboardContext
        )
        let isEmpty = query.isEmpty ? Self.isDocumentEmpty(proxy) : false
        if isEmpty && GreetingBannerState.shared.isDismissedForCurrentSession {
            GreetingBannerState.shared.prepareForAppearance()
        }
        let rawContextWords = !isEmpty ? Self.completedContextWords(before: proxy) : []
        let contextWords = query.isEmpty ? rawContextWords : Array(rawContextWords.dropLast())
        let autocorrectAllowed = context.isAutocorrectEnabled
            && proxy.autocorrectionType != .no
            && SystemKeyboardSettings.isAutoCorrectionEnabled
        return QuerySnapshot(
            query: query,
            mathEvaluation: mathEvaluation,
            shouldCapitalize: shouldCapitalize,
            isDocumentEmpty: isEmpty,
            completedContextWords: contextWords,
            isAutocorrectEnabled: autocorrectAllowed
        )
    }

    private func computeSuggestions(for snapshot: QuerySnapshot) -> [Autocomplete.Suggestion] {
        if let mathEval = snapshot.mathEvaluation {
            let expr = mathEval.expression
            let result = mathEval.result
            return [
                Autocomplete.Suggestion(
                    text: expr,
                    title: expr,
                    isUnknown: true,
                    additionalInfo: [
                        "mathAction": "literal",
                        "mathExpr": expr,
                        "mathResult": result
                    ]
                ),
                Autocomplete.Suggestion(
                    text: "\(expr)\(result)",
                    title: "\(expr)\(result)",
                    isAutocorrect: snapshot.isAutocorrectEnabled,
                    additionalInfo: [
                        "mathAction": "append",
                        "mathExpr": expr,
                        "mathResult": result
                    ]
                ),
                Autocomplete.Suggestion(
                    text: result,
                    title: result,
                    isAutocorrect: false,
                    additionalInfo: [
                        "mathAction": "replace",
                        "mathExpr": expr,
                        "mathResult": result
                    ]
                )
            ]
        }
        var suggestions: [Autocomplete.Suggestion]
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
                shouldCapitalize: snapshot.shouldCapitalize,
                contextWords: snapshot.completedContextWords
            )
            if let shortcutText = manager.shortcutReplacement(for: snapshot.query) {
                var updated = suggestions.filter { $0.text != shortcutText }.map { item -> Autocomplete.Suggestion in
                    var copy = item
                    copy.isAutocorrect = false
                    return copy
                }
                let shortcutSuggestion = Autocomplete.Suggestion(
                    text: shortcutText,
                    title: shortcutText,
                    isAutocorrect: true
                )
                updated.insert(shortcutSuggestion, at: 0)
                if updated.count > 3 {
                    updated = Array(updated.prefix(3))
                }
                suggestions = updated
            }
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
        if let mathQuery = MathExpressionEvaluator.trailingMathQuery(in: proxy.documentContextBeforeInput) {
            return mathQuery
        }

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
        let delimiters = CharacterSet(charactersIn: String.wordDelimiters.filter { $0 != "-" }.joined())
        return before
            .components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
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
        if SystemKeyboardSettings.isAutoCapitalizationEnabled && proxy.isCursorAtNewSentence {
            return true
        }
        return false
    }
}
