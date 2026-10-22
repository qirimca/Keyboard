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

    static func normalizeUkrainianCyrillic(_ source: String, ukrainianLayout: Bool) -> String {
        var out = String.UnicodeScalarView()
        out.reserveCapacity(source.unicodeScalars.count)
        for scalar in source.unicodeScalars {
            switch scalar {
            case "і":
                out.append("и")
            case "І":
                out.append("И")
            case "и" where ukrainianLayout:
                out.append("ы")
            case "И" where ukrainianLayout:
                out.append("Ы")
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
                out.append(contentsOf: "Йи".unicodeScalars)
            default:
                out.append(scalar)
            }
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
