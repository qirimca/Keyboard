import Foundation
import Testing
@testable import Transliteration

/// Expected values are produced by the reference engine (qirimca/ctcorpus_translit `mod_translit.js` with
/// `ModTranslitData`) — never by hand. Regenerate with `scratch/gen.js` (see handoff).
private let parityCases: [(String, String)] = {
    guard let url = Bundle.module.url(forResource: "parity", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let raw = try? JSONDecoder().decode([[String]].self, from: data) else { return [] }
    return raw.compactMap { $0.count == 2 ? ($0[0], $0[1]) : nil }
}()

@Test func matchesReferenceEngine() {
    #expect(parityCases.count > 5000)
    let mismatches = parityCases.filter { CrimeanTatarTransliterator.transliterate($0.0) != $0.1 }
    #expect(mismatches.isEmpty, "first mismatches: \(mismatches.prefix(10).map { "\($0.0)→\(CrimeanTatarTransliterator.transliterate($0.0)) (want \($0.1))" })")
}

@Test func typingCharacterByCharacterEqualsWholeWord() {
    var failures: [String] = []
    for (word, expected) in parityCases.prefix(2500) where !word.contains(" ") {
        var engine = CrimeanTatarTransliterator()
        let id = UUID()
        var document = "x "
        for character in word {
            let edit = engine.append(String(character), context: document, documentID: id)
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
        }
        if document != "x " + expected { failures.append("\(word)→\(document) (want \(expected))") }
    }
    #expect(failures.isEmpty, "\(failures.prefix(10))")
}

@Test func backspaceRestoresPreviousLiveState() {
    for word in ["къырым", "ЁЛКА", "юз", "джан", "щука", "ель"] {
        var engine = CrimeanTatarTransliterator()
        let id = UUID()
        var document = ""
        var states = [""]
        for character in word {
            let edit = engine.append(String(character), context: document, documentID: id)
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            states.append(document)
        }
        for expected in states.dropLast().reversed() {
            guard let edit = engine.backspace(context: document, documentID: id) else { Issue.record("no edit for \(word)"); return }
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            #expect(document == expected)
        }
    }
}

@Test func digraphAndBackspace() {
    var engine = CrimeanTatarTransliterator()
    let id = UUID()
    #expect(engine.append("г", context: "hello ", documentID: id) == .init(deleteCount: 0, insertion: "g"))
    #expect(engine.append("ъ", context: "hello g", documentID: id) == .init(deleteCount: 1, insertion: "ğ"))
    #expect(engine.backspace(context: "hello ğ", documentID: id) == .init(deleteCount: 1, insertion: "g"))
    #expect(engine.backspace(context: "hello g", documentID: id) == .init(deleteCount: 1, insertion: ""))
    #expect(engine.backspace(context: "hello ", documentID: id) == nil)
}

@Test func changedContextNeverDeletesUnownedText() {
    var engine = CrimeanTatarTransliterator()
    let id = UUID()
    _ = engine.append("г", context: "", documentID: id)
    #expect(engine.append("ъ", context: "other", documentID: id).deleteCount == 0)
    #expect(engine.backspace(context: "other moved", documentID: id) == nil)
}

@Test func changingDocumentResetsComposition() {
    var engine = CrimeanTatarTransliterator()
    _ = engine.append("г", context: "", documentID: UUID())
    #expect(engine.append("ъ", context: "g", documentID: UUID()).deleteCount == 0)
}

@Test func missingContextNeverDeletesText() {
    var engine = CrimeanTatarTransliterator()
    let id = UUID()
    _ = engine.append("г", context: nil, documentID: id)
    #expect(engine.append("ъ", context: nil, documentID: id).deleteCount == 0)
    #expect(engine.backspace(context: nil, documentID: id) == nil)
}

@Test func exceptionRewritesOnlyOwnedWord() {
    var engine = CrimeanTatarTransliterator()
    let id = UUID()
    var document = "prefix "
    for character in "алейкум" {
        let edit = engine.append(String(character), context: document, documentID: id)
        document = String(document.dropLast(edit.deleteCount)) + edit.insertion
    }
    #expect(document == "prefix aleyküm")
}
