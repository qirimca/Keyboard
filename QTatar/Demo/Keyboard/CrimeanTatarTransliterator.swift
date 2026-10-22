import Foundation

/// Faithful port of the qirimca/ctcorpus_translit `mod_translit` engine (translit/TranslitProcessor.php,
/// assets/mod_translit.js) for the Cyrillic → Latin direction. Rule data is exported from the same
/// `ModTranslitData` the website uses (see `TransliterationRules.json`).
///
/// Algorithm (mirrors `TranslitProcessor::translate`):
///  1. whole-word exceptions as literal, ordered substring replacements;
///  2. split into Cyrillic letter runs and the gaps between them (only runs are converted);
///  3. join runs with "\n", apply the ordered regex rules in multiline mode (`^`/`$` = word edges),
///     then the per-character `all_other_letters` map;
///  4. re-interleave gaps and converted runs.
///
/// The source word is retained while typing: Latin output alone cannot disambiguate е/э or ь/ъ, and the
/// website also re-translates the full Cyrillic text on every input event.
///
/// Four upstream rules (`Ё|Ю|Ц|Щ` before a capital letter) are corrected in the data:
/// `$1` preserves the following letter instead of the invalid `$2` dropping it.
/// The reference fixture records these intentional corrections (e.g. `ЁЛКА → YOLKA`).
struct CrimeanTatarTransliterator {
    private struct Dataset: Decodable {
        let lettersCyrl: String
        let exceptions: [[String]]
        let rules: [[String?]]
        let fallback: [[String]]
    }

    private enum Step {
        case regex(NSRegularExpression, String)
        case fallback
    }

    private struct Engine {
        let runRegex: NSRegularExpression
        let exceptions: [(search: String, replacement: String)]
        let steps: [Step]
        let fallback: [Unicode.Scalar: String]
    }

    private static let engine: Engine = {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        let empty = Engine(runRegex: try! NSRegularExpression(pattern: "(?!)"), exceptions: [], steps: [], fallback: [:])
        guard let url = bundle.url(forResource: "TransliterationRules", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let dataset = try? JSONDecoder().decode(Dataset.self, from: data),
              let runRegex = try? NSRegularExpression(pattern: "[" + dataset.lettersCyrl + "]+") else {
            assertionFailure("Missing bundled transliteration rules")
            return empty
        }
        var steps: [Step] = []
        for rule in dataset.rules {
            guard let pattern = rule.first ?? nil else { continue }
            if pattern == "all_other_letters" {
                steps.append(.fallback)
                continue
            }
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.anchorsMatchLines]) else {
                assertionFailure("Invalid transliteration rule: \(pattern)")
                continue
            }
            let replacement = rule.count > 1 ? (rule[1] ?? "") : ""
            steps.append(.regex(regex, normalize(replacement, groups: regex.numberOfCaptureGroups)))
        }
        var fallback: [Unicode.Scalar: String] = [:]
        for pair in dataset.fallback where pair.count == 2 {
            if let scalar = pair[0].unicodeScalars.first { fallback[scalar] = pair[1] }
        }
        return Engine(
            runRegex: runRegex,
            exceptions: dataset.exceptions.compactMap { $0.count == 2 ? ($0[0], $0[1]) : nil },
            steps: steps,
            fallback: fallback
        )
    }()

    private static let groupRefRegex: NSRegularExpression? = try? NSRegularExpression(pattern: "\\$(\\d+)|\\$\\{(\\d+)\\}")

    /// PCRE drops `$N` for groups the pattern does not define; ICU would not, so strip them up front.
    private static func normalize(_ replacement: String, groups: Int) -> String {
        guard let regex = groupRefRegex else { return replacement }
        let ns = replacement as NSString
        var result = ""
        var last = 0
        for match in regex.matches(in: replacement, range: NSRange(location: 0, length: ns.length)) {
            result += ns.substring(with: NSRange(location: last, length: match.range.location - last))
            let group = match.range(at: 1).location != NSNotFound ? match.range(at: 1) : match.range(at: 2)
            if let number = Int(ns.substring(with: group)), number <= groups {
                result += ns.substring(with: match.range)
            }
            last = match.range.location + match.range.length
        }
        return result + ns.substring(from: last)
    }

    private static let cyrillicConsonants: Set<UnicodeScalar> = [
        "б", "в", "г", "ґ", "д", "ж", "з", "й", "к", "л", "м", "н", "п", "р", "с", "т", "ф", "х", "ц", "ч", "ш", "щ",
        "Б", "В", "Г", "Ґ", "Д", "Ж", "З", "Й", "К", "Л", "М", "Н", "П", "Р", "С", "Т", "Ф", "Х", "Ц", "Ч", "Ш", "Щ"
    ]

    static func normalizeUkrainianCyrillic(_ source: String, ukrainianLayout: Bool) -> String {
        let scalars = Array(source.unicodeScalars)
        let n = scalars.count
        var out = String.UnicodeScalarView()
        out.reserveCapacity(n + 4)

        func isApostrophe(_ s: UnicodeScalar) -> Bool {
            s == "\u{02BC}" || s == "'" || s == "’"
        }
        func isHardSign(_ s: UnicodeScalar) -> Bool {
            s == "ъ" || s == "Ъ"
        }
        func isCyrillicLetter(_ s: UnicodeScalar) -> Bool {
            (0x0400...0x04FF).contains(s.value)
        }
        func isUpperCyrillic(_ s: UnicodeScalar) -> Bool {
            isCyrillicLetter(s) && Character(s).isUppercase
        }
        func isAllCapsAt(_ idx: Int) -> Bool {
            if idx + 1 < n {
                let next = scalars[idx + 1]
                if isApostrophe(next) || isHardSign(next) {
                    if isHardSign(next) && Character(next).isUppercase { return true }
                    if idx + 2 < n && isCyrillicLetter(scalars[idx + 2]) {
                        return isUpperCyrillic(scalars[idx + 2])
                    }
                } else if isCyrillicLetter(next) {
                    return isUpperCyrillic(next)
                }
            }
            if idx > 0 {
                let prev = scalars[idx - 1]
                if isCyrillicLetter(prev) {
                    return isUpperCyrillic(prev)
                }
                if (isApostrophe(prev) || isHardSign(prev)) && idx >= 2 && isCyrillicLetter(scalars[idx - 2]) {
                    return isUpperCyrillic(scalars[idx - 2])
                }
            }
            return false
        }

        var i = 0
        while i < n {
            let scalar = scalars[i]
            if !ukrainianLayout {
                switch scalar {
                case "і":
                    out.append("и")
                case "І":
                    out.append("И")
                case "є":
                    out.append("э")
                case "Є":
                    out.append("Э")
                case "ґ":
                    out.append("г")
                case "Ґ":
                    out.append("Г")
                case "ї":
                    out.append(contentsOf: "йи".unicodeScalars)
                case "Ї":
                    out.append(contentsOf: (isAllCapsAt(i) ? "ЙИ" : "Йи").unicodeScalars)
                default:
                    out.append(scalar)
                }
                i += 1
                continue
            }

            switch scalar {
            case "і":
                out.append("и")
            case "І":
                out.append("И")
            case "и":
                out.append("ы")
            case "И":
                out.append("Ы")
            case "е":
                let prev2: UnicodeScalar? = i >= 2 ? scalars[i - 2] : nil
                let isDigraph = prev2 == "к" || prev2 == "К" || prev2 == "н" || prev2 == "Н" || prev2 == "г" || prev2 == "Г"
                let afterConsonantApostrophe = i >= 2
                    && isApostrophe(scalars[i - 1])
                    && Self.cyrillicConsonants.contains(scalars[i - 2])
                    && !isDigraph
                out.append(afterConsonantApostrophe ? "е" : "э")
            case "Е":
                let prev2: UnicodeScalar? = i >= 2 ? scalars[i - 2] : nil
                let isDigraph = prev2 == "к" || prev2 == "К" || prev2 == "н" || prev2 == "Н" || prev2 == "г" || prev2 == "Г"
                let afterConsonantApostrophe = i >= 2
                    && isApostrophe(scalars[i - 1])
                    && Self.cyrillicConsonants.contains(scalars[i - 2])
                    && !isDigraph
                if afterConsonantApostrophe {
                    let hasNextCyr = (i + 1 < n) && isCyrillicLetter(scalars[i + 1])
                    if hasNextCyr {
                        out.append("Е")
                    } else {
                        out.append(contentsOf: (isAllCapsAt(i) ? "ЙЭ" : "Йэ").unicodeScalars)
                    }
                } else {
                    out.append("Э")
                }
            case "є":
                let prevScalar: UnicodeScalar? = i > 0 ? scalars[i - 1] : nil
                if let prev = prevScalar, Self.cyrillicConsonants.contains(prev) {
                    let isAfterGe = prev == "ґ" || prev == "Ґ"
                    out.append(contentsOf: (isAfterGe ? "ье" : "ъе").unicodeScalars)
                } else {
                    out.append("е")
                }
            case "Є":
                let prevScalar: UnicodeScalar? = i > 0 ? scalars[i - 1] : nil
                let allCaps = isAllCapsAt(i)
                let hasNextCyr = (i + 1 < n) && isCyrillicLetter(scalars[i + 1])
                if !hasNextCyr {
                    out.append(contentsOf: (allCaps ? "ЙЭ" : "Йэ").unicodeScalars)
                } else if let prev = prevScalar, Self.cyrillicConsonants.contains(prev) {
                    let isAfterGe = prev == "ґ" || prev == "Ґ"
                    let sign: UnicodeScalar = isAfterGe ? (allCaps ? "Ь" : "ь") : (allCaps ? "Ъ" : "ъ")
                    out.append(sign)
                    out.append("Е")
                } else {
                    out.append("Е")
                }
            case "ї":
                out.append(contentsOf: "йи".unicodeScalars)
            case "Ї":
                out.append(contentsOf: (isAllCapsAt(i) ? "ЙИ" : "Йи").unicodeScalars)
            case "г":
                if i + 1 < n && (isApostrophe(scalars[i + 1]) || isHardSign(scalars[i + 1])) {
                    i += 1
                }
                out.append(contentsOf: "гъ".unicodeScalars)
            case "Г":
                let allCaps = isAllCapsAt(i)
                if i + 1 < n && (isApostrophe(scalars[i + 1]) || isHardSign(scalars[i + 1])) {
                    i += 1
                }
                out.append(contentsOf: (allCaps ? "ГЪ" : "Гъ").unicodeScalars)
            case "ґ":
                out.append("г")
            case "Ґ":
                out.append("Г")
            case "к":
                if i + 1 < n && isApostrophe(scalars[i + 1]) {
                    i += 1
                    out.append(contentsOf: "къ".unicodeScalars)
                } else {
                    out.append("к")
                }
            case "К":
                if i + 1 < n && isApostrophe(scalars[i + 1]) {
                    let allCaps = isAllCapsAt(i)
                    i += 1
                    out.append(contentsOf: (allCaps ? "КЪ" : "Къ").unicodeScalars)
                } else {
                    out.append("К")
                }
            case "н":
                if i + 1 < n && isApostrophe(scalars[i + 1]) {
                    i += 1
                    out.append(contentsOf: "нъ".unicodeScalars)
                } else {
                    out.append("н")
                }
            case "Н":
                if i + 1 < n && isApostrophe(scalars[i + 1]) {
                    let allCaps = isAllCapsAt(i)
                    i += 1
                    out.append(contentsOf: (allCaps ? "НЪ" : "Нъ").unicodeScalars)
                } else {
                    out.append("Н")
                }
            default:
                if isApostrophe(scalar) {
                    let prevScalar: UnicodeScalar? = i > 0 ? scalars[i - 1] : nil
                    let prevIsConsonant = prevScalar.map { Self.cyrillicConsonants.contains($0) } ?? false
                    if !prevIsConsonant {
                        // Immediately output apostrophe when not after a consonant (e.g. after vowel, at word start, or second press 'ʼʼ')
                        out.append(scalar)
                    } else if i + 1 < n && isApostrophe(scalars[i + 1]) {
                        // Double apostrophe after consonant ('пʼʼ') outputs a visible apostrophe
                        i += 1
                        out.append(scalars[i])
                    } else {
                        // After a consonant ('пʼєр', 'пʼер', 'ґʼе', 'ґʼє', 'обʼєкт'), act as hard-sign / soft-sign separator
                        let isAfterGe = prevScalar == "ґ" || prevScalar == "Ґ"
                        let allCaps = isAllCapsAt(i)
                        if isAfterGe {
                            out.append(allCaps ? "Ь" : "ь")
                        } else {
                            out.append(allCaps ? "Ъ" : "ъ")
                        }
                    }
                } else {
                    out.append(scalar)
                }
            }
            i += 1
        }
        return String(out)
    }

    static func transliterate(_ source: String, ukrainianLayout: Bool = false) -> String {
        var text = normalizeUkrainianCyrillic(source, ukrainianLayout: ukrainianLayout)
        for exception in engine.exceptions where !exception.search.isEmpty {
            text = text.replacingOccurrences(of: exception.search, with: exception.replacement, options: .literal)
        }

        let ns = text as NSString
        var gaps: [String] = []
        var runs: [String] = []
        var last = 0
        for match in engine.runRegex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
            gaps.append(ns.substring(with: NSRange(location: last, length: match.range.location - last)))
            runs.append(ns.substring(with: match.range))
            last = match.range.location + match.range.length
        }
        gaps.append(ns.substring(from: last))

        if !runs.isEmpty {
            var joined = runs.joined(separator: "\n")
            for step in engine.steps {
                switch step {
                case .regex(let regex, let template):
                    joined = regex.stringByReplacingMatches(
                        in: joined,
                        range: NSRange(location: 0, length: (joined as NSString).length),
                        withTemplate: template
                    )
                case .fallback:
                    var mapped = String.UnicodeScalarView()
                    for scalar in joined.unicodeScalars {
                        if let value = engine.fallback[scalar] { mapped.append(contentsOf: value.unicodeScalars) } else { mapped.append(scalar) }
                    }
                    joined = String(mapped)
                }
            }
            let converted = joined.components(separatedBy: "\n")
            if converted.count == runs.count { runs = converted }
        }

        var output = ""
        for index in gaps.indices {
            output += gaps[index]
            if index < runs.count { output += runs[index] }
        }
        return output
    }


    struct Edit: Equatable {
        let deleteCount: Int
        let insertion: String
    }

    var ukrainianLayout: Bool = false
    private(set) var source = ""
    private var output = ""
    private var expectedContext: String?
    private var documentID: UUID?

    mutating func reset() {
        source = ""
        output = ""
        expectedContext = nil
        documentID = nil
    }

    mutating func append(_ input: String, context: String?, documentID: UUID) -> Edit {
        let currentContext = context ?? ""
        let suffixMatches = !output.isEmpty && currentContext.hasSuffix(output)
        if self.documentID != documentID || context == nil || (expectedContext != currentContext && !suffixMatches) {
            reset()
        }
        self.documentID = documentID
        source += input
        return replacement(context: currentContext)
    }

    mutating func backspace(context: String?, documentID: UUID) -> Edit? {
        let currentContext = context ?? ""
        let suffixMatches = !output.isEmpty && currentContext.hasSuffix(output)
        guard self.documentID == documentID, context != nil, (expectedContext == currentContext || suffixMatches), !source.isEmpty else {
            reset()
            return nil
        }
        source.removeLast()
        return replacement(context: currentContext)
    }

    private mutating func replacement(context: String) -> Edit {
        let newOutput = Self.transliterate(source, ukrainianLayout: ukrainianLayout)
        let common = zip(output, newOutput).prefix(while: { $0 == $1 }).count
        let edit = Edit(deleteCount: output.count - common, insertion: String(newOutput.dropFirst(common)))
        expectedContext = String(context.dropLast(edit.deleteCount)) + edit.insertion
        output = newOutput
        return edit
    }
}
