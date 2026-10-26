//
//  DemoActionHandler.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import UIKit
import os

/// Manages keyboard typing history for undo/redo actions
final class TextHistoryManager {
    static let shared = TextHistoryManager()
    
    enum HistoryAction {
        case insert(String)
        case delete(String)
        case replace(oldText: String, newText: String)
    }
    
    private var undoStack: [HistoryAction] = []
    private var redoStack: [HistoryAction] = []
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    func recordInsert(_ text: String) {
        guard !text.isEmpty else { return }
        undoStack.append(.insert(text))
        redoStack.removeAll()
    }
    
    func recordDelete(_ text: String) {
        guard !text.isEmpty else { return }
        undoStack.append(.delete(text))
        redoStack.removeAll()
    }
    
    func recordReplace(oldText: String, newText: String) {
        undoStack.append(.replace(oldText: oldText, newText: newText))
        redoStack.removeAll()
    }
    
    func undo(proxy: UITextDocumentProxy) {
        guard let action = undoStack.popLast() else { return }
        switch action {
        case .insert(let text):
            for _ in 0..<text.count {
                proxy.deleteBackward()
            }
            redoStack.append(.insert(text))
        case .delete(let text):
            proxy.insertText(text)
            redoStack.append(.delete(text))
        case .replace(let oldText, let newText):
            for _ in 0..<newText.count {
                proxy.deleteBackward()
            }
            proxy.insertText(oldText)
            redoStack.append(.replace(oldText: oldText, newText: newText))
        }
    }
    
    func redo(proxy: UITextDocumentProxy) {
        guard let action = redoStack.popLast() else { return }
        switch action {
        case .insert(let text):
            proxy.insertText(text)
            undoStack.append(.insert(text))
        case .delete(let text):
            for _ in 0..<text.count {
                proxy.deleteBackward()
            }
            undoStack.append(.delete(text))
        case .replace(let oldText, let newText):
            for _ in 0..<oldText.count {
                proxy.deleteBackward()
            }
            proxy.insertText(newText)
            undoStack.append(.replace(oldText: oldText, newText: newText))
        }
    }
    
    func reset() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}

/// Custom keyboard behavior that respects iOS `Settings → General → Keyboards` preferences
/// (`Enable Caps Lock` and `.` Shortcut).
final class DemoKeyboardBehavior: StandardKeyboardBehavior {

    override func shouldEndSentence(
        after gesture: Gesture,
        on action: KeyboardAction
    ) -> Bool {
        guard SystemKeyboardSettings.isPeriodShortcutEnabled else { return false }
        return super.shouldEndSentence(after: gesture, on: action)
    }

    override func shouldSwitchToCapsLock(
        after gesture: Gesture,
        on action: KeyboardAction
    ) -> Bool {
        guard SystemKeyboardSettings.isCapsLockEnabled else { return false }
        return super.shouldSwitchToCapsLock(after: gesture, on: action)
    }
}

/**
 Action handler that performs standard keyboard actions, undo/redo handling,
 autocomplete triggers, and inactive primary action suppression.
 */
class DemoActionHandler: StandardKeyboardActionHandler {
    private lazy var transliterator = CrimeanTatarTransliterator()
    private var didInstantiateTransliterator = false
    private var activeFlickSymbol: (action: KeyboardAction, symbol: String)?
    private var activeFlickTrackingAction: KeyboardAction?
    private var didConsumeBackspacePress = false

    func resetComposition() {
        lastCompletedTypedWord = nil
        guard didInstantiateTransliterator else { return }
        transliterator.reset()
    }

    override func canHandle(_ gesture: Gestures.KeyboardGesture, on action: KeyboardAction) -> Bool {
        if action == .capsLock {
            return gesture == .press
        }
        if case .custom(let name) = action {
            if name == "toggle_script" {
                return gesture == .press
            }
            if ["undo", "redo", "url_domain"].contains(name) {
                return gesture == .release
            }
        }
        return super.canHandle(gesture, on: action)
    }

    override func handleDrag(
        on action: KeyboardAction,
        from startLocation: CGPoint,
        to currentLocation: CGPoint
    ) {
        if let symbol = CrimeanTatarIPadKeyboardLayoutProvider.flickSymbol(
            for: action,
            context: keyboardContext
        ) {
            let dx = currentLocation.x - startLocation.x
            let dy = currentLocation.y - startLocation.y
            if activeFlickTrackingAction != action {
                if dy > 2.0 && dy > abs(dx) * 0.65 {
                    activeFlickTrackingAction = action
                }
            }
            if activeFlickTrackingAction == action && abs(dx) < 42.0 {
                let rawProgress = min(max((dy - 2.0) / 34.0, 0), 1.0)
                KeyFlickState.shared.update(action: action, progress: rawProgress)
                if rawProgress >= 0.48 {
                    activeFlickSymbol = (action, symbol)
                } else if rawProgress < 0.40 {
                    activeFlickSymbol = nil
                }
                if rawProgress > 0.05 {
                    return
                }
            } else {
                activeFlickTrackingAction = nil
                activeFlickSymbol = nil
                KeyFlickState.shared.update(action: action, progress: 0)
            }
        }
        super.handleDrag(on: action, from: startLocation, to: currentLocation)
    }

    func handleSwipePath(
        _ keys: [String],
        trailPoints: [CGPoint] = [],
        timestamps: [TimeInterval] = [],
        keyFrames: [String: CGRect] = [:]
    ) {
        let controllerWidth = (keyboardController as? UIViewController)?.view.bounds.width ?? 0
        let isPadFloatingWidth = keyboardContext.deviceType == .pad && controllerWidth > 0 && controllerWidth < 420
        guard (keyboardContext.deviceType == .phone || keyboardContext.isKeyboardFloating || isPadFloatingWidth),
              !keyboardContext.isKeyboardSplit,
              SystemKeyboardSettings.isSlideToTypeEnabled,
              keys.count >= 2 else {
            return
        }
        let proxy = keyboardContext.textDocumentProxy
        let before = proxy.documentContextBeforeInput ?? ""
        let isCyrillic = keyboardContext.locale.identifier.contains("Cyrl")
        let isUpper = keyboardContext.keyboardType == .alphabetic(.uppercased)
            || keyboardContext.keyboardType == .alphabetic(.capsLocked)
        let isAllCaps = keyboardContext.keyboardType == .alphabetic(.capsLocked)
        let shouldCap = isUpper || (SystemKeyboardSettings.isAutoCapitalizationEnabled(for: keyboardContext.textDocumentProxy) && proxy.isCursorAtNewSentence)
        let currentClause = String(SuggestionsDataBaseManager.currentSentenceSlice(in: before))
        let delimiters = CharacterSet(charactersIn: String.wordDelimiters.filter { $0 != "-" }.joined())
        let contextWords = currentClause
            .components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
            .filter { !$0.isEmpty }
        let positionContext = SuggestionsDataBaseManager.resolveSentencePositionContext(
            beforeText: before,
            contextWords: contextWords
        )

        var suggestions = SuggestionsDataBaseManager.shared.matchSwipePath(
            keySequence: keys,
            isCyrillic: isCyrillic,
            shouldCapitalize: shouldCap,
            contextWords: contextWords,
            positionContext: positionContext,
            trailPoints: trailPoints,
            timestamps: timestamps,
            keyFrames: keyFrames,
            limit: 10
        )
        if isAllCaps {
            suggestions = suggestions.map {
                Autocomplete.Suggestion(
                    text: $0.text.uppercased(with: Self.casingLocale),
                    isAutocorrect: false
                )
            }
        }
        guard !suggestions.isEmpty else { return }

        let isSameRepeatSwipeAfterBackspace = isPostSwipeBackspaceState
            && keys.first?.lowercased() == lastSwipeKeySequence.first?.lowercased()
            && keys.last?.lowercased() == lastSwipeKeySequence.last?.lowercased()
            && abs(keys.count - lastSwipeKeySequence.count) <= 2
            && lastSwipeCandidateQueue.count >= 4

        let best: String
        let primaryAlternatives: [String]
        if isSameRepeatSwipeAfterBackspace {
            best = lastSwipeCandidateQueue[3]
            primaryAlternatives = Array(lastSwipeCandidateQueue.prefix(3))
            isPostSwipeBackspaceState = false
        } else {
            let candidateTexts = suggestions.map(\.text)
            lastSwipeCandidateQueue = candidateTexts
            lastSwipeKeySequence = keys
            isPostSwipeBackspaceState = false
            best = candidateTexts[0]
            primaryAlternatives = Array(candidateTexts.dropFirst().prefix(3))
        }
        guard !best.isEmpty else { return }

        GreetingBannerState.shared.dismissForTyping()
        SpaceBarState.shared.fadeToResting()
        SpaceBarState.shared.recordKeystroke()
        resetComposition()
        lastAutoCorrection = nil
        suppressedAutocorrectWord = nil

        let needsLeadingSpace: Bool = {
            guard let lastChar = before.last else { return false }
            return !lastChar.isWhitespace && lastChar != "\n" && lastChar != "(" && lastChar != "[" && lastChar != "\"" && lastChar != "«"
        }()
        postSwipeNeedsLeadingSpace = needsLeadingSpace
        let textToInsert = needsLeadingSpace ? (" " + best) : best
        proxy.insertText(textToInsert)
        TextHistoryManager.shared.recordInsert(textToInsert)
        KeyboardUsageStats.recordCharacterTyped(count: best.count, keystrokes: keys.count)
        KeyboardUsageStats.recordManualWordCompleted()
        lastCompletedTypedWord = best
        lastSwipedWordInsertion = textToInsert
        hasActivePostSwipeSuggestions = true
        typedWordBuffer = ""
        if keyboardContext.keyboardType == .alphabetic(.uppercased) {
            keyboardController?.setKeyboardType(.alphabetic(.lowercased))
        }

        // Do not repeat the already-inserted word in Slot 0; offer alternative swipe candidates + next-word continuations.
        var toolbarSuggestions: [Autocomplete.Suggestion] = primaryAlternatives.map {
            Autocomplete.Suggestion(
                text: $0,
                isAutocorrect: false,
                additionalInfo: ["replaceSwipedWord": true]
            )
        }
        if toolbarSuggestions.count < 3 {
            let updatedContext = contextWords + [best]
            let nextPosition = SuggestionsDataBaseManager.resolveSentencePositionContext(
                beforeText: before + textToInsert,
                contextWords: updatedContext
            )
            let continuations = SuggestionsDataBaseManager.shared.nextWordSuggestions(
                contextWords: updatedContext,
                shouldCapitalize: false,
                positionContext: nextPosition
            )
            for cont in continuations where toolbarSuggestions.count < 3 {
                if !toolbarSuggestions.contains(where: { $0.text.caseInsensitiveCompare(cont.text) == .orderedSame })
                    && cont.text.caseInsensitiveCompare(best) != .orderedSame {
                    let formattedCont = isAllCaps
                        ? Autocomplete.Suggestion(text: cont.text.uppercased(with: Self.casingLocale), isAutocorrect: false)
                        : cont
                    toolbarSuggestions.append(formattedCont)
                }
            }
        }

        autocompleteContext.suggestions = toolbarSuggestions
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
            guard let self, self.lastSwipedWordInsertion == textToInsert else { return }
            self.autocompleteContext.suggestions = toolbarSuggestions
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self, self.lastSwipedWordInsertion == textToInsert else { return }
            self.autocompleteContext.suggestions = toolbarSuggestions
        }
    }

    func handleBackspaceSlideLeft() {
        guard !didConsumeBackspacePress else {
            didConsumeBackspacePress = false
            return
        }
        let proxy = keyboardContext.textDocumentProxy
        let before = proxy.documentContextBeforeInput ?? ""
        guard !before.isEmpty else { return }

        var chars = Array(before)
        var deleteCount = 0
        while let last = chars.last, last.isWhitespace && last != "\n" {
            chars.removeLast()
            deleteCount += 1
        }
        while let last = chars.last, !last.isWhitespace {
            chars.removeLast()
            deleteCount += 1
        }
        guard deleteCount > 0 else { return }

        let deletedString = String(before.suffix(deleteCount))
        let remainingBefore = String(before.dropLast(deleteCount))
        resetComposition()
        lastAutoCorrection = nil
        lastSwipedWordInsertion = nil
        lastSwipeCandidateQueue = []
        lastSwipeKeySequence = []
        isPostSwipeBackspaceState = false
        hasActivePostSwipeSuggestions = false
        typedWordBuffer = ""

        if feedbackConfiguration.isHapticFeedbackEnabled {
            HapticFeedback.lightImpact.trigger()
        }
        for _ in 0..<deleteCount {
            proxy.deleteBackward()
        }
        TextHistoryManager.shared.recordDelete(deletedString)

        if remainingBefore.isEmpty && (proxy.documentContextAfterInput ?? "").isEmpty {
            if !DemoStyleProvider.isSearchField(for: keyboardContext) {
                autocompleteContext.suggestions = []
                GreetingBannerState.shared.prepareForAppearance(reshuffle: false)
            } else {
                GreetingBannerState.shared.dismissForTyping()
            }
        } else {
            GreetingBannerState.shared.dismissForTyping()
        }
        if SystemKeyboardSettings.isAutoCapitalizationEnabled(for: keyboardContext.textDocumentProxy),
           proxy.autocapitalizationType != UITextAutocapitalizationType.none,
           keyboardContext.keyboardType == .alphabetic(.lowercased),
           remainingBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || remainingBefore.hasSuffix(". ")
            || remainingBefore.hasSuffix("! ")
            || remainingBefore.hasSuffix("? ")
            || remainingBefore.hasSuffix("\n") {
            keyboardController?.setKeyboardType(.alphabetic(.uppercased))
        } else {
            tryChangeKeyboardType(after: .release, on: .backspace)
        }
        keyboardController?.performAutocomplete()
    }

    func handleSlideFrom123Character(_ character: String) {
        SwipeTypingState.shared.clearKeyFrames()
        guard !character.isEmpty else {
            keyboardController?.setKeyboardType(.alphabetic(.lowercased))
            return
        }
        let action = KeyboardAction.character(character)
        triggerFeedback(for: .press, on: action)
        handle(.release, on: action)
        keyboardController?.setKeyboardType(.alphabetic(.lowercased))
        SwipeTypingState.shared.clearKeyFrames()
        keyboardController?.performAutocomplete()
    }

    private func apply(_ edit: CrimeanTatarTransliterator.Edit) {
        let proxy = keyboardContext.textDocumentProxy
        let removed = String((proxy.documentContextBeforeInput ?? "").suffix(edit.deleteCount))
        for _ in 0..<edit.deleteCount { proxy.deleteBackward() }
        if !edit.insertion.isEmpty {
            proxy.insertText(edit.insertion)
        }
        if edit.deleteCount > 0 || !edit.insertion.isEmpty {
            TextHistoryManager.shared.recordReplace(oldText: removed, newText: edit.insertion)
        }
        keyboardController?.performAutocomplete()
    }

    private static func previousCompletedWord(in proxy: UITextDocumentProxy, excludingCurrentWord: Bool) -> String? {
        guard let before = proxy.documentContextBeforeInput else { return nil }
        let currentClause = String(SuggestionsDataBaseManager.currentSentenceSlice(in: before))
        let delimiters = CharacterSet(charactersIn: String.wordDelimiters.filter { $0 != "-" }.joined())
        let tokens = currentClause
            .components(separatedBy: delimiters)
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "-")) }
            .filter { !$0.isEmpty }
        if excludingCurrentWord {
            return tokens.count >= 2 ? tokens[tokens.count - 2] : nil
        } else {
            return tokens.last
        }
    }

    private static func currentWordBeforeCursor(in proxy: UITextDocumentProxy) -> String? {
        if let tokenBeforeCursor = previousCompletedWord(in: proxy, excludingCurrentWord: false),
           !tokenBeforeCursor.isEmpty {
            return tokenBeforeCursor
        }
        if let word = proxy.currentWord, !word.isEmpty {
            return word
        }
        return nil
    }

    private var didLearnWordDuringSpaceRelease = false
    private var typedWordBuffer: String = ""
    private var lastCompletedTypedWord: String?
    private var lastAutoCorrection: (original: String, corrected: String)?
    private var lastSwipedWordInsertion: String?
    private var lastSwipeCandidateQueue: [String] = []
    private var lastSwipeKeySequence: [String] = []
    private var isPostSwipeBackspaceState = false
    private var postSwipeNeedsLeadingSpace = false
    private(set) var hasActivePostSwipeSuggestions = false
    private var suppressAutocorrectForCurrentSpaceRelease = false
    private var suppressedAutocorrectWord: String?

    private func resolveCompletedWord(in proxy: UITextDocumentProxy) -> (word: String?, prevWord: String?) {
        let proxyWord = Self.currentWordBeforeCursor(in: proxy)
        let proxyPrev = Self.previousCompletedWord(in: proxy, excludingCurrentWord: true)
        let word: String? = {
            if let proxyWord, SuggestionsDataBaseManager.isValidLearnableWord(proxyWord) {
                return proxyWord
            }
            if !typedWordBuffer.isEmpty {
                return typedWordBuffer
            }
            return proxyWord
        }()
        let beforeTrimmed = (proxy.documentContextBeforeInput ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let prevWord = proxyPrev ?? (beforeTrimmed.isEmpty ? lastCompletedTypedWord : nil)
        return (word, prevWord)
    }

    private static let casingLocale = Locale(identifier: "tr")

    /// Space applies the autocorrection computed from the text as it is right now. The published suggestions
    /// arrive asynchronously and are cleared on every edit, so a quick Space would otherwise find none.
    override func tryApplyAutocorrectSuggestion(
        before gesture: Gestures.KeyboardGesture,
        on action: KeyboardAction
    ) {
        if gesture == .release, action == .space {
            if suppressAutocorrectForCurrentSpaceRelease {
                suppressAutocorrectForCurrentSpaceRelease = false
                return
            }
            guard KeyboardPreferences.suggestionsEnabled && SystemKeyboardSettings.isPredictiveTextEnabled(for: keyboardContext.textDocumentProxy) else {
                return
            }
            let proxy = keyboardContext.textDocumentProxy
            let isAutocorrectAllowed = proxy.autocorrectionType != .no && SystemKeyboardSettings.isAutoCorrectionEnabled(for: keyboardContext.textDocumentProxy)
            autocompleteContext.isAutocorrectEnabled = isAutocorrectAllowed
            guard isAutocorrectAllowed else { return }
            if spaceDragGestureHandler.currentDragTextPositionOffset == 0 {
                let mathAllowed: Bool = {
                    guard SystemKeyboardSettings.isShowMathResultsEnabled(for: keyboardContext.textDocumentProxy) else { return false }
                    if #available(iOS 18.0, *) {
                        return proxy.mathExpressionCompletionType != .no
                    }
                    return true
                }()
                if mathAllowed,
                   let mathResult = MathExpressionEvaluator.evaluateTrailingExpression(in: proxy.documentContextBeforeInput) {
                    proxy.insertText(mathResult)
                    TextHistoryManager.shared.recordInsert(mathResult)
                    didLearnWordDuringSpaceRelease = true
                    typedWordBuffer = ""
                    return
                }
            }
            if spaceDragGestureHandler.currentDragTextPositionOffset == 0,
                !proxy.isCursorAtNewWord,
               proxy.isCursorAtTheEndOfTheCurrentWord,
               let word = proxy.currentWord,
               !word.isEmpty,
               let provider = (keyboardController as? KeyboardViewController)?.services.autocompleteProvider as? CrimeanTatarAutocompleteProvider {
                if let suppressed = suppressedAutocorrectWord,
                   suppressed.caseInsensitiveCompare(word) == .orderedSame {
                    suppressedAutocorrectWord = nil
                    return
                }
                let prevWord = Self.previousCompletedWord(in: proxy, excludingCurrentWord: true) ?? lastCompletedTypedWord
                let existing = autocompleteContext.suggestions
                let suggestions: [Autocomplete.Suggestion]
                if let first = existing.first,
                   first.text.lowercased(with: Self.casingLocale) == word.lowercased(with: Self.casingLocale) {
                    suggestions = existing
                } else {
                    suggestions = provider.suggestionsNow(for: word)
                    autocompleteContext.suggestions = suggestions
                }
                if let suggestion = suggestions.first(where: { $0.isAutocorrect }),
                   suggestion.text != word {
                    let replaceCount = (suggestion.additionalInfo["replaceCharCount"] as? Int) ?? word.count
                    let beforeText = proxy.documentContextBeforeInput ?? ""
                    let deleteCount = min(replaceCount, max(beforeText.count, word.count))
                    let oldText = deleteCount <= beforeText.count
                        ? String(beforeText.suffix(deleteCount))
                        : word
                    for _ in 0..<deleteCount { proxy.deleteBackward() }
                    proxy.insertText(suggestion.text)
                    TextHistoryManager.shared.recordReplace(oldText: oldText, newText: suggestion.text)
                    lastAutoCorrection = (original: oldText, corrected: suggestion.text)
                    didLearnWordDuringSpaceRelease = true
                    lastCompletedTypedWord = suggestion.text
                    typedWordBuffer = ""
                    SuggestionsDataBaseManager.shared.learnWordIfPermitted(
                        suggestion.text,
                        previousWord: prevWord,
                        proxy: proxy,
                        explicitlyConfirmed: false
                    )
                    return
                }
            }
            return
        }
    }


    override func handle(_ suggestion: Autocomplete.Suggestion) {
        let previousSwipedInsertion = lastSwipedWordInsertion
        let wasPostSwipeNeedsSpace = postSwipeNeedsLeadingSpace
        resetComposition()
        lastAutoCorrection = nil
        lastSwipedWordInsertion = nil
        lastSwipeCandidateQueue = []
        lastSwipeKeySequence = []
        isPostSwipeBackspaceState = false
        hasActivePostSwipeSuggestions = false
        suppressedAutocorrectWord = nil
        GreetingBannerState.shared.dismissForTyping()
        SpaceBarState.shared.fadeToResting()
        let proxy = keyboardContext.textDocumentProxy
        if suggestion.additionalInfo["insertSwipedAlternative"] as? Bool == true {
            let leadingSpace = wasPostSwipeNeedsSpace ? " " : ""
            let replacement = suggestion.text
            let newInsertion = leadingSpace + replacement
            KeyboardUsageStats.markInjectedText(replacement)
            KeyboardUsageStats.recordSuggestedWordCompleted(savedCharacters: max(replacement.count, 2))
            proxy.insertText(newInsertion)
            proxy.tryInsertSpaceAfterAutocomplete()
            TextHistoryManager.shared.recordInsert(newInsertion + " ")
            lastCompletedTypedWord = replacement
            typedWordBuffer = ""
            let prevWord = Self.previousCompletedWord(in: proxy, excludingCurrentWord: true)
            SuggestionsDataBaseManager.shared.learnWordIfPermitted(
                replacement,
                previousWord: prevWord,
                proxy: proxy,
                explicitlyConfirmed: false
            )
            autocompleteContext.suggestions = []
            keyboardController?.performAutocomplete()
            return
        }
        if suggestion.additionalInfo["appendAfterCurrentWord"] as? Bool == true {
            let beforeText = proxy.documentContextBeforeInput ?? ""
            let leadingSpace = (beforeText.last?.isWhitespace == true) ? "" : " "
            let replacement = suggestion.text
            let insertion = leadingSpace + replacement
            KeyboardUsageStats.markInjectedText(replacement)
            KeyboardUsageStats.recordSuggestedWordCompleted(savedCharacters: max(replacement.count, 2))
            proxy.insertText(insertion)
            proxy.tryInsertSpaceAfterAutocomplete()
            TextHistoryManager.shared.recordInsert(insertion + " ")
            lastCompletedTypedWord = replacement
            typedWordBuffer = ""
            autocompleteContext.suggestions = []
            keyboardController?.performAutocomplete()
            return
        }
        if suggestion.additionalInfo["replaceSwipedWord"] as? Bool == true,
           let swipedInserted = previousSwipedInsertion {
            let beforeText = proxy.documentContextBeforeInput ?? ""
            let hasTrailingSpace = beforeText.hasSuffix(swipedInserted + " ")
            let deleteCount = hasTrailingSpace
                ? (swipedInserted.count + 1)
                : min(swipedInserted.count, beforeText.count)
            for _ in 0..<deleteCount {
                proxy.deleteBackward()
            }
            let leadingSpace = swipedInserted.hasPrefix(" ") ? " " : ""
            let replacement = suggestion.text
            let newInsertion = leadingSpace + replacement
            KeyboardUsageStats.markInjectedText(replacement)
            KeyboardUsageStats.recordSuggestedWordCompleted(savedCharacters: max(replacement.count, 2))
            proxy.insertText(newInsertion)
            proxy.tryInsertSpaceAfterAutocomplete()
            TextHistoryManager.shared.recordReplace(oldText: swipedInserted, newText: newInsertion + " ")
            lastCompletedTypedWord = replacement
            typedWordBuffer = ""
            let prevWord = Self.previousCompletedWord(in: proxy, excludingCurrentWord: true)
            SuggestionsDataBaseManager.shared.learnWordIfPermitted(
                replacement,
                previousWord: prevWord,
                proxy: proxy,
                explicitlyConfirmed: false
            )
            autocompleteContext.suggestions = []
            keyboardController?.performAutocomplete()
            return
        }
        let mathAllowed: Bool = {
            guard SystemKeyboardSettings.isShowMathResultsEnabled(for: keyboardContext.textDocumentProxy) else { return false }
            if #available(iOS 18.0, *) {
                return proxy.mathExpressionCompletionType != .no
            }
            return true
        }()
        if mathAllowed,
           let mathEval = MathExpressionEvaluator.evaluateTrailingExpressionWithLiteral(in: proxy.documentContextBeforeInput) {
            let mathAction = (suggestion.additionalInfo["mathAction"] as? String) ?? {
                if suggestion.isUnknown || suggestion.text == mathEval.expression {
                    return "literal"
                } else if suggestion.text == mathEval.result {
                    return "replace"
                } else {
                    return "append"
                }
            }()
            let expr = (suggestion.additionalInfo["mathExpr"] as? String) ?? mathEval.expression
            let result = (suggestion.additionalInfo["mathResult"] as? String) ?? mathEval.result
            switch mathAction {
            case "literal":
                // Slot 0 («2+2=»): keep the literal expression as-is and advance with a space
                proxy.tryInsertSpaceAfterAutocomplete()
            case "replace":
                // Slot 2 (4): replace the entire expression (e.g. "2+2=") with just the result ("4")
                let before = proxy.documentContextBeforeInput ?? ""
                let deleteCount = before.hasSuffix(expr) ? expr.count : mathEval.expression.count
                for _ in 0..<deleteCount {
                    proxy.deleteBackward()
                }
                KeyboardUsageStats.markInjectedText(result)
                KeyboardUsageStats.recordSuggestedWordCompleted(savedCharacters: max(result.count, 2))
                proxy.insertText(result)
                proxy.tryInsertSpaceAfterAutocomplete()
                TextHistoryManager.shared.recordReplace(oldText: expr, newText: result)
            default:
                // Slot 1 (2+2=4): append the result right after "="
                KeyboardUsageStats.markInjectedText(result)
                KeyboardUsageStats.recordSuggestedWordCompleted(savedCharacters: max(result.count, 2))
                proxy.insertText(result)
                proxy.tryInsertSpaceAfterAutocomplete()
                TextHistoryManager.shared.recordInsert(result)
            }
            typedWordBuffer = ""
            handle(.release, on: .character(""))
            return
        }
        if let replaceCount = suggestion.additionalInfo["replaceCharCount"] as? Int, replaceCount > 0 {
            let beforeText = proxy.documentContextBeforeInput ?? ""
            let deleteCount = min(replaceCount, beforeText.count)
            let oldText = String(beforeText.suffix(deleteCount))
            for _ in 0..<deleteCount {
                proxy.deleteBackward()
            }
            let replacement = suggestion.text
            KeyboardUsageStats.markInjectedText(replacement)
            KeyboardUsageStats.recordSuggestedWordCompleted(savedCharacters: max(replacement.count, 2))
            proxy.insertText(replacement)
            proxy.tryInsertSpaceAfterAutocomplete()
            TextHistoryManager.shared.recordReplace(oldText: oldText, newText: replacement)
            lastAutoCorrection = (original: oldText, corrected: replacement)
            lastCompletedTypedWord = replacement
            typedWordBuffer = ""
            autocompleteContext.suggestions = []
            keyboardController?.performAutocomplete()
            return
        }
        let currentWord = proxy.currentWord ?? typedWordBuffer
        let beforeTrimmed = (proxy.documentContextBeforeInput ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let prevWord = Self.previousCompletedWord(in: proxy, excludingCurrentWord: !currentWord.isEmpty)
            ?? (beforeTrimmed.isEmpty ? lastCompletedTypedWord : nil)
        let replacement = suggestion.text
        let savedChars = max(replacement.count - currentWord.count + 1, 2)
        KeyboardUsageStats.markInjectedText(replacement)
        KeyboardUsageStats.recordSuggestedWordCompleted(savedCharacters: savedChars)
        TextHistoryManager.shared.recordReplace(oldText: currentWord, newText: replacement)
        lastCompletedTypedWord = replacement
        typedWordBuffer = ""
        SuggestionsDataBaseManager.shared.learnWordIfPermitted(
            replacement,
            previousWord: prevWord,
            proxy: proxy,
            explicitlyConfirmed: suggestion.isUnknown
        )
        super.handle(suggestion)
    }

    override func handle(
        _ gesture: Gestures.KeyboardGesture,
        on action: KeyboardAction,
        replaced: Bool = false
    ) {
        #if DEBUG
        let started = CFAbsoluteTimeGetCurrent()
        defer {
            let ms = (CFAbsoluteTimeGetCurrent() - started) * 1000
            if gesture == .release || ms > 8 {
                Self.perfLog.info("handle \(String(describing: gesture), privacy: .public) \(String(describing: action), privacy: .public) \(ms, format: .fixed(precision: 1), privacy: .public)ms")
            }
        }
        #endif
        handleUntimed(gesture, on: action, replaced: replaced)
    }

    #if DEBUG
    private static let perfLog = Logger(subsystem: "crh.key.perf", category: "handler")
    #endif

    private static let wordEndingPunctuation: Set<String> = [".", ",", "!", "?", ";", ":"]

    private func handleUntimed(
        _ gesture: Gestures.KeyboardGesture,
        on action: KeyboardAction,
        replaced: Bool
    ) {
        if gesture == .press, !replaced {
            activeFlickSymbol = nil
            activeFlickTrackingAction = nil
            KeyFlickState.shared.reset()
            switch action {
            case .character, .characterMargin:
                SpaceBarState.shared.fadeToResting()
            default:
                break
            }
        }
        if gesture == .release, !replaced {
            activeFlickTrackingAction = nil
            KeyFlickState.shared.reset()
        }
        if gesture == .release, !replaced,
           let flick = activeFlickSymbol, flick.action == action {
            activeFlickSymbol = nil
            SpaceBarState.shared.fadeToResting()
            GreetingBannerState.shared.dismissForTyping()
            handleUntimed(.release, on: .character(flick.symbol), replaced: false)
            return
        }
        if !replaced, replacementAction(for: gesture, on: action) != nil {
            super.handle(gesture, on: action, replaced: false)
            return
        }
        if action == .custom(named: "toggle_script") {
            if gesture == .press {
                triggerFeedback(for: gesture, on: action)
                resetComposition()
                (keyboardController as? KeyboardViewController)?.toggleScript()
            }
            return
        }
        if action == .backspace, gesture == .press {
            didConsumeBackspacePress = false
            hasActivePostSwipeSuggestions = false
            isPostSwipeBackspaceState = false
        }
        if action == .backspace, gesture == .press,
           let swipedInsertion = lastSwipedWordInsertion {
            lastSwipedWordInsertion = nil
            let proxy = keyboardContext.textDocumentProxy
            let before = proxy.documentContextBeforeInput ?? ""
            if before.hasSuffix(swipedInsertion) {
                didConsumeBackspacePress = true
                triggerFeedback(for: gesture, on: action)
                resetComposition()
                let remainingBefore = String(before.dropLast(swipedInsertion.count))
                for _ in 0..<swipedInsertion.count {
                    proxy.deleteBackward()
                }
                TextHistoryManager.shared.recordDelete(swipedInsertion)
                typedWordBuffer = ""

                // Offer the next 3 swipe candidates [W_5, W_6, W_7] (after W_1 and [W_2, W_3, W_4]) right after Backspace
                let rotatedCandidates: [String] = {
                    guard lastSwipeCandidateQueue.count >= 2 else { return [] }
                    var nextBatch: [String]
                    if lastSwipeCandidateQueue.count >= 5 {
                        nextBatch = Array(lastSwipeCandidateQueue.dropFirst(4).prefix(3))
                    } else if lastSwipeCandidateQueue.count >= 4 {
                        nextBatch = Array(lastSwipeCandidateQueue.dropFirst(3).prefix(3))
                    } else {
                        nextBatch = Array(lastSwipeCandidateQueue.dropFirst().prefix(3))
                    }
                    if nextBatch.count < 3 {
                        for fallback in lastSwipeCandidateQueue.dropFirst() where nextBatch.count < 3 {
                            if !nextBatch.contains(fallback) {
                                nextBatch.append(fallback)
                            }
                        }
                    }
                    return nextBatch
                }()
                if !rotatedCandidates.isEmpty {
                    isPostSwipeBackspaceState = true
                    hasActivePostSwipeSuggestions = true
                    GreetingBannerState.shared.dismissForTyping()
                    let rotatedSuggestions = rotatedCandidates.map {
                        Autocomplete.Suggestion(
                            text: $0,
                            isAutocorrect: false,
                            additionalInfo: ["insertSwipedAlternative": true]
                        )
                    }
                    autocompleteContext.suggestions = rotatedSuggestions
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                        guard let self, self.isPostSwipeBackspaceState else { return }
                        self.autocompleteContext.suggestions = rotatedSuggestions
                    }
                } else {
                    if remainingBefore.isEmpty && (proxy.documentContextAfterInput ?? "").isEmpty {
                        if !DemoStyleProvider.isSearchField(for: keyboardContext) {
                            autocompleteContext.suggestions = []
                            GreetingBannerState.shared.prepareForAppearance(reshuffle: false)
                        } else {
                            GreetingBannerState.shared.dismissForTyping()
                        }
                    } else {
                        GreetingBannerState.shared.dismissForTyping()
                    }
                }

                if SystemKeyboardSettings.isAutoCapitalizationEnabled(for: keyboardContext.textDocumentProxy),
                   proxy.autocapitalizationType != UITextAutocapitalizationType.none,
                   keyboardContext.keyboardType == .alphabetic(.lowercased),
                   remainingBefore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || remainingBefore.hasSuffix(". ")
                    || remainingBefore.hasSuffix("! ")
                    || remainingBefore.hasSuffix("? ")
                    || remainingBefore.hasSuffix("\n") {
                    keyboardController?.setKeyboardType(.alphabetic(.uppercased))
                } else {
                    tryChangeKeyboardType(after: .release, on: action)
                }
                if rotatedCandidates.isEmpty {
                    keyboardController?.performAutocomplete()
                }
                return
            }
        }
        if action == .backspace, gesture == .press,
           let autoFix = lastAutoCorrection {
            let proxy = keyboardContext.textDocumentProxy
            let before = proxy.documentContextBeforeInput ?? ""
            if before.hasSuffix(autoFix.corrected + " ") {
                didConsumeBackspacePress = true
                lastAutoCorrection = nil
                suppressedAutocorrectWord = autoFix.original
                triggerFeedback(for: gesture, on: action)
                resetComposition()
                GreetingBannerState.shared.dismissForTyping()
                let deleteLen = autoFix.corrected.count + 1
                for _ in 0..<deleteLen {
                    proxy.deleteBackward()
                }
                proxy.insertText(autoFix.original)
                TextHistoryManager.shared.recordReplace(oldText: autoFix.corrected + " ", newText: autoFix.original)
                typedWordBuffer = autoFix.original
                tryChangeKeyboardType(after: .release, on: action)
                keyboardController?.performAutocomplete()
                return
            } else {
                lastAutoCorrection = nil
            }
        }
        if action == .backspace, gesture == .release, didConsumeBackspacePress {
            didConsumeBackspacePress = false
            tryChangeKeyboardType(after: gesture, on: action)
            SpaceBarState.shared.fadeToResting()
            return
        }
        if action == .space, gesture == .release, keyboardContext.isSpaceDragGestureActive {
            super.handle(gesture, on: action, replaced: replaced)
            return
        }
        var pendingSpaceWord: (word: String, prevWord: String?)?
        if gesture == .release {
            suppressAutocorrectForCurrentSpaceRelease = (action == .space && (lastSwipedWordInsertion != nil || hasActivePostSwipeSuggestions))
            hasActivePostSwipeSuggestions = false
            isPostSwipeBackspaceState = false
            SpaceBarState.shared.fadeToResting()
            let proxy = keyboardContext.textDocumentProxy
            switch action {
            case .character(let ch), .characterMargin(let ch):
                guard !ch.isEmpty else { break }
                lastAutoCorrection = nil
                lastSwipedWordInsertion = nil
                lastSwipeCandidateQueue = []
                lastSwipeKeySequence = []
                suppressedAutocorrectWord = nil
                GreetingBannerState.shared.dismissForTyping()
                SpaceBarState.shared.recordKeystroke()
                KeyboardUsageStats.recordCharacterTyped(count: ch.count, keystrokes: 1)
                if Self.wordEndingPunctuation.contains(ch) {
                    let before = proxy.documentContextBeforeInput ?? ""
                    let hasWordBefore = !typedWordBuffer.isEmpty
                        || (before.last.map { $0.isLetter || $0.isNumber } ?? false)
                    if hasWordBefore {
                        KeyboardUsageStats.recordManualWordCompleted()
                        let resolved = resolveCompletedWord(in: proxy)
                        let hasPendingAutocorrect = autocompleteContext.suggestions.contains(where: { $0.isAutocorrect })
                        if let word = resolved.word, !word.isEmpty, !hasPendingAutocorrect {
                            lastCompletedTypedWord = word
                            SuggestionsDataBaseManager.shared.learnWordIfPermitted(
                                word,
                                previousWord: resolved.prevWord,
                                proxy: proxy
                            )
                        }
                        typedWordBuffer = ""
                    }
                } else if ch.contains(where: { $0.isLetter || $0.isNumber }) {
                    typedWordBuffer.append(ch)
                } else if (ch == "'" || ch == "’" || ch == "\u{02BC}" || ch == "-") && !typedWordBuffer.isEmpty {
                    typedWordBuffer.append(ch)
                } else {
                    typedWordBuffer = ""
                }
            case .space:
                lastAutoCorrection = nil
                lastSwipedWordInsertion = nil
                didLearnWordDuringSpaceRelease = false
                GreetingBannerState.shared.dismissForTyping()
                KeyboardUsageStats.recordCharacterTyped(count: 1)
                let before = proxy.documentContextBeforeInput ?? ""
                let hasWordBefore = !typedWordBuffer.isEmpty
                    || (before.last.map { $0.isLetter || $0.isNumber } ?? false)
                if hasWordBefore {
                    KeyboardUsageStats.recordManualWordCompleted()
                    let resolved = resolveCompletedWord(in: proxy)
                    if let word = resolved.word, !word.isEmpty {
                        pendingSpaceWord = (word, resolved.prevWord)
                        lastCompletedTypedWord = word
                    }
                    typedWordBuffer = ""
                }
            case .primary:
                lastAutoCorrection = nil
                lastSwipedWordInsertion = nil
                suppressedAutocorrectWord = nil
                GreetingBannerState.shared.dismissForTyping()
                let before = proxy.documentContextBeforeInput ?? ""
                let hasWordBefore = !typedWordBuffer.isEmpty
                    || (before.last.map { $0.isLetter || $0.isNumber } ?? false)
                if hasWordBefore {
                    KeyboardUsageStats.recordManualWordCompleted()
                    let resolved = resolveCompletedWord(in: proxy)
                    let hasPendingAutocorrect = autocompleteContext.suggestions.contains(where: { $0.isAutocorrect })
                    if let word = resolved.word, !word.isEmpty, !hasPendingAutocorrect {
                        lastCompletedTypedWord = word
                        SuggestionsDataBaseManager.shared.learnWordIfPermitted(
                            word,
                            previousWord: resolved.prevWord,
                            proxy: proxy
                        )
                    }
                    typedWordBuffer = ""
                }
            case .backspace:
                if !typedWordBuffer.isEmpty {
                    typedWordBuffer.removeLast()
                }
                if (proxy.documentContextBeforeInput ?? "").isEmpty && (proxy.documentContextAfterInput ?? "").isEmpty {
                    if !DemoStyleProvider.isSearchField(for: keyboardContext) {
                        autocompleteContext.suggestions = []
                        GreetingBannerState.shared.prepareForAppearance(reshuffle: false)
                    } else {
                        GreetingBannerState.shared.dismissForTyping()
                    }
                } else {
                    GreetingBannerState.shared.dismissForTyping()
                }
            default:
                break
            }
        }
        if action == .capsLock {
            if gesture == .press {
                triggerFeedback(for: gesture, on: action)
                let nextCasing: Keyboard.Case = keyboardContext.keyboardType.isAlphabeticCapsLocked
                    ? .lowercased
                    : .capsLocked
                keyboardController?.setKeyboardType(.alphabetic(nextCasing))
                keyboardController?.performAutocomplete()
            }
            return
        }
        if (gesture == .press || gesture == .release), case .keyboardType(let type) = action, type.isAlphabetic {
            keyboardContext.hasChosenLettersInNumericField = true
        }
        if gesture == .release {
            let proxy = keyboardContext.textDocumentProxy
            let effectiveKeyboardType = DemoStyleProvider.effectiveProxyKeyboardType(for: keyboardContext)
            if proxy.smartDashesType != .no,
               effectiveKeyboardType != .URL,
               effectiveKeyboardType != .emailAddress {
                switch action {
                case .character(let ch), .characterMargin(let ch):
                    if ch == "-", (proxy.documentContextBeforeInput ?? "").hasSuffix("-") {
                        resetComposition()
                        proxy.deleteBackward()
                        proxy.insertText("—")
                        TextHistoryManager.shared.recordReplace(oldText: "-", newText: "—")
                        tryChangeKeyboardType(after: gesture, on: action)
                        keyboardController?.performAutocomplete()
                        return
                    }
                    if ch == ".", (proxy.documentContextBeforeInput ?? "").hasSuffix("..") {
                        resetComposition()
                        proxy.deleteBackward()
                        proxy.deleteBackward()
                        proxy.insertText("…")
                        TextHistoryManager.shared.recordReplace(oldText: "..", newText: "…")
                        tryChangeKeyboardType(after: gesture, on: action)
                        keyboardController?.performAutocomplete()
                        return
                    }
                default:
                    break
                }
            }
        }
        if keyboardContext.locale.identifier.contains("Cyrl") {
            let proxy = keyboardContext.textDocumentProxy
            let hasSelection = !(proxy.selectedText ?? "").isEmpty
            switch action {
            case .character(let character), .characterMargin(let character):
                let isUkrainianApostrophe = character == "\u{02BC}"
                    || ((character == "'" || character == "’") && KeyboardPreferences.ukrainianCyrillicLayoutEnabled && !transliterator.source.isEmpty)
                if !character.isEmpty,
                   character.unicodeScalars.contains(where: { (0x0400...0x04FF).contains($0.value) })
                    || character.allSatisfy({ $0.isNumber || $0 == "-" })
                    || isUkrainianApostrophe {
                    if gesture == .press {
                        triggerFeedback(for: gesture, on: action)
                        return
                    }
                    if gesture == .release {
                        didInstantiateTransliterator = true
                        transliterator.ukrainianLayout = KeyboardPreferences.ukrainianCyrillicLayoutEnabled
                        let context: String? = hasSelection ? nil : (proxy.documentContextBeforeInput ?? "")
                        apply(transliterator.append(character, context: context, documentID: proxy.safeDocumentIdentifier))
                        tryChangeKeyboardType(after: gesture, on: action)
                    }
                    return
                }
            default:
                break
            }
            if action == .backspace, gesture == .press || gesture == .repeatPress {
                didInstantiateTransliterator = true
                transliterator.ukrainianLayout = KeyboardPreferences.ukrainianCyrillicLayoutEnabled
                let context: String? = hasSelection ? nil : (proxy.documentContextBeforeInput ?? "")
                if let edit = transliterator.backspace(context: context,
                                                       documentID: proxy.safeDocumentIdentifier) {
                    apply(edit)
                    return
                }
            } else if gesture == .release && action != .backspace && !action.isShiftAction && action != .capsLock {
                // Changing pages does not change the document. Keep the original source
                // across 123/#+=/ABC so reference rules can see digits and hyphens.
                if case .keyboardType = action {
                    super.handle(gesture, on: action, replaced: replaced)
                    return
                }
                resetComposition()
            }
        }
        // Prevent tapping inactive primary actions only when enablesReturnKeyAutomatically is enabled
        if case .primary = action, gesture == .release {
            let proxy = keyboardContext.textDocumentProxy
            if DemoStyleProvider.effectiveEnablesReturnKeyAutomatically(for: keyboardContext) {
                let hasText = proxy.hasText || !(proxy.documentContextBeforeInput?.isEmpty ?? true)
                if !hasText {
                    return
                }
            }
        }
        
        // Custom iPad system keys: undo, redo, and URL domain (.com)
        if case .custom(let name) = action, gesture == .release {
            if name == "undo" {
                TextHistoryManager.shared.undo(proxy: keyboardContext.textDocumentProxy)
                keyboardController?.performAutocomplete()
                return
            } else if name == "redo" {
                TextHistoryManager.shared.redo(proxy: keyboardContext.textDocumentProxy)
                keyboardController?.performAutocomplete()
                return
            } else if name == "url_domain" {
                GreetingBannerState.shared.dismissForTyping()
                KeyboardUsageStats.recordCharacterTyped(count: 4)
                TextHistoryManager.shared.recordInsert(".com")
                keyboardContext.textDocumentProxy.insertText(".com")
                keyboardController?.performAutocomplete()
                return
            }
        }
        
        // Track history before executing action
        if gesture == .release {
            switch action {
            case .character(let char), .characterMargin(let char):
                TextHistoryManager.shared.recordInsert(char)
            case .space:
                TextHistoryManager.shared.recordInsert(" ")
            case .backspace:
                if let lastChar = keyboardContext.textDocumentProxy.documentContextBeforeInput?.last {
                    TextHistoryManager.shared.recordDelete(String(lastChar))
                }
            default:
                break
            }
        }
        
        super.handle(gesture, on: action, replaced: replaced)
        
        guard gesture == .release else { return }
        if let pending = pendingSpaceWord, !didLearnWordDuringSpaceRelease {
            SuggestionsDataBaseManager.shared.learnWordIfPermitted(
                pending.word,
                previousWord: pending.prevWord,
                proxy: keyboardContext.textDocumentProxy
            )
        }
        if action.isShiftAction || action == .capsLock {
            keyboardController?.performAutocomplete()
        }
    }

    override func tryEndSentence(after gesture: Gestures.KeyboardGesture, on action: KeyboardAction) {
        guard keyboardBehavior.shouldEndSentence(after: gesture, on: action) else { return }
        keyboardContext.textDocumentProxy.endSentence()
        TextHistoryManager.shared.recordReplace(oldText: "  ", newText: ". ")
    }
}
