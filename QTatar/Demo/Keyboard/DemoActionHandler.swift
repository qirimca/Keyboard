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

/**
 Action handler that performs standard keyboard actions, undo/redo handling,
 autocomplete triggers, and inactive primary action suppression.
 */
class DemoActionHandler: StandardKeyboardActionHandler {
    private lazy var transliterator = CrimeanTatarTransliterator()
    private var didInstantiateTransliterator = false

    func resetComposition() {
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

    /// Space applies the autocorrection computed from the text as it is right now. The published suggestions
    /// arrive asynchronously and are cleared on every edit, so a quick Space would otherwise find none.
    override func tryApplyAutocorrectSuggestion(
        before gesture: Gestures.KeyboardGesture,
        on action: KeyboardAction
    ) {
        if gesture == .release, action == .space, KeyboardPreferences.suggestionsEnabled {
            autocompleteContext.isAutocorrectEnabled = true
            let proxy = keyboardContext.textDocumentProxy
            if spaceDragGestureHandler.currentDragTextPositionOffset == 0,
               !proxy.isCursorAtNewWord,
               proxy.isCursorAtTheEndOfTheCurrentWord,
               let word = proxy.currentWord,
               !word.isEmpty,
               let provider = (keyboardController as? KeyboardViewController)?.services.autocompleteProvider as? CrimeanTatarAutocompleteProvider {
                let suggestions = provider.suggestionsNow(for: word)
                autocompleteContext.suggestions = suggestions
                if let suggestion = suggestions.first(where: { $0.isAutocorrect }),
                   suggestion.text != word {
                    for _ in 0..<word.count { proxy.deleteBackward() }
                    proxy.insertText(suggestion.text)
                    TextHistoryManager.shared.recordReplace(oldText: word, newText: suggestion.text)
                    return
                }
            }
        }
        super.tryApplyAutocorrectSuggestion(before: gesture, on: action)
    }


    override func handle(_ suggestion: Autocomplete.Suggestion) {
        resetComposition()
        let currentWord = keyboardContext.textDocumentProxy.currentWord ?? ""
        let replacement = suggestion.text
        TextHistoryManager.shared.recordReplace(oldText: currentWord, newText: replacement)
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

    private func handleUntimed(
        _ gesture: Gestures.KeyboardGesture,
        on action: KeyboardAction,
        replaced: Bool
    ) {
        if action == .custom(named: "toggle_script") {
            if gesture == .press {
                triggerFeedback(for: gesture, on: action)
                resetComposition()
                (keyboardController as? KeyboardViewController)?.toggleScript()
            }
            return
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
        if keyboardContext.locale.identifier.contains("Cyrl") {
            let proxy = keyboardContext.textDocumentProxy
            let hasSelection = !(proxy.selectedText ?? "").isEmpty
            switch action {
            case .character(let character), .characterMargin(let character):
                if !character.isEmpty,
                   character.unicodeScalars.contains(where: { (0x0400...0x04FF).contains($0.value) })
                    || character.allSatisfy({ $0.isNumber || $0 == "-" }) {
                    if gesture == .press {
                        triggerFeedback(for: gesture, on: action)
                        return
                    }
                    if gesture == .release {
                        didInstantiateTransliterator = true
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
            if proxy.enablesReturnKeyAutomatically == true {
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
        if action.isShiftAction || action == .capsLock {
            keyboardController?.performAutocomplete()
        }
    }
}
