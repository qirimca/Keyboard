//
//  DemoActionHandler.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import UIKit

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
    private var transliterator = CrimeanTatarTransliterator()

    func resetComposition() { transliterator.reset() }

    override func canHandle(_ gesture: Gestures.KeyboardGesture, on action: KeyboardAction) -> Bool {
        if case .custom(let name) = action,
           ["toggle_script", "undo", "redo", "url_domain"].contains(name) {
            return gesture == .release
        }
        return super.canHandle(gesture, on: action)
    }

    private func apply(_ edit: CrimeanTatarTransliterator.Edit) {
        let proxy = keyboardContext.textDocumentProxy
        let removed = String((proxy.documentContextBeforeInput ?? "").suffix(edit.deleteCount))
        for _ in 0..<edit.deleteCount { proxy.deleteBackward() }
        proxy.insertText(edit.insertion)
        TextHistoryManager.shared.recordReplace(oldText: removed, newText: edit.insertion)
        keyboardController?.performAutocomplete()
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
        if action == .custom(named: "toggle_script"), gesture == .release {
            resetComposition()
            (keyboardController as? KeyboardViewController)?.toggleScript()
            return
        }
        if gesture == .release, case .keyboardType(let type) = action, type.isAlphabetic {
            keyboardContext.hasChosenLettersInNumericField = true
        }
        if keyboardContext.locale.identifier.contains("Cyrl") {
            let proxy = keyboardContext.textDocumentProxy
            if case .character(let character) = action,
               !character.isEmpty,
               character.unicodeScalars.allSatisfy({ (0x0400...0x04ff).contains($0.value) }) {
                if gesture == .release {
                    let context = proxy.selectedText == nil ? proxy.documentContextBeforeInput : nil
                    triggerFeedback(for: gesture, on: action)
                    apply(transliterator.append(character, context: context, documentID: proxy.documentIdentifier))
                    tryChangeKeyboardType(after: gesture, on: action)
                }
                return
            }
            if action == .backspace, gesture == .press || gesture == .repeatPress {
                if let edit = transliterator.backspace(context: proxy.documentContextBeforeInput,
                                                      documentID: proxy.documentIdentifier) {
                    apply(edit)
                    return
                }
            } else if gesture == .release && action != .backspace && !action.isShiftAction {
                resetComposition()
            }
        }
        // Prevent tapping inactive primary actions (e.g. Search when input is empty)
        if case .primary = action, gesture == .release {
            let proxy = keyboardContext.textDocumentProxy
            let enablesAuto = proxy.enablesReturnKeyAutomatically ?? false
            let returnType = proxy.returnKeyType
            let isSpecial = returnType == .search || returnType == .go || returnType == .send || returnType == .next || returnType == .done || returnType == .join || returnType == .route || returnType == .yahoo || returnType == .google
            if enablesAuto || isSpecial {
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

                return
            } else if name == "redo" {
                TextHistoryManager.shared.redo(proxy: keyboardContext.textDocumentProxy)

                return
            } else if name == "url_domain" {
                TextHistoryManager.shared.recordInsert(".com")
                keyboardContext.textDocumentProxy.insertText(".com")
                return
            }
        }
        
        // Track history before executing action
        if gesture == .release {
            switch action {
            case .character(let char):
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
        if action.isInputAction || action.isShiftAction || action == .capsLock {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                self?.keyboardController?.performAutocomplete()
            }
        }
    }
}
