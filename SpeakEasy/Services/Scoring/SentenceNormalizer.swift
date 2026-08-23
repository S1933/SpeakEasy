import Foundation

enum SentenceNormalizer {

    /// All Unicode apostrophe variants → U+0027.
    private static let apostropheVariants: [Character] = [
        "\u{2019}", // ’ right single quote
        "\u{2018}", // ‘ left single quote
        "\u{02BC}", // ʼ modifier letter apostrophe
        "\u{FF07}", // ＇ fullwidth
        "\u{00B4}"  // ´ acute accent (common in FR input)
    ]

    /// Punctuation trimmed at the ends of EACH token.
    private static let punctuation = CharacterSet(
        charactersIn: ".?!,;:\"“”«»()[]{}—–-…"
    )

    /// Filler words that ASR sometimes surfaces and that we must not penalize.
    private static let fillers: Set<String> = [
        "um", "uh", "erm", "er", "ah", "hmm", "mm", "eh"
    ]

    /// The ASR writes spoken numbers as digits ("5" for "five" — observed on
    /// device during the Phase 0 spike). Reference texts spell numbers out,
    /// so transcripts are mapped to their single-word form to keep the
    /// alignment fair. Numbers without a single-word form ("23", "100") are
    /// left as-is: the curated texts avoid them. One token in, one token out
    /// — the displayTokens/tokenize cardinality contract is preserved.
    private static let numberWords: [String: String] = [
        "0": "zero", "1": "one", "2": "two", "3": "three", "4": "four",
        "5": "five", "6": "six", "7": "seven", "8": "eight", "9": "nine",
        "10": "ten", "11": "eleven", "12": "twelve", "13": "thirteen",
        "14": "fourteen", "15": "fifteen", "16": "sixteen", "17": "seventeen",
        "18": "eighteen", "19": "nineteen",
        "20": "twenty", "30": "thirty", "40": "forty", "50": "fifty",
        "60": "sixty", "70": "seventy", "80": "eighty", "90": "ninety"
    ]

    // MARK: - API

    /// Canonical form of a sentence, for comparison or debug display.
    static func normalize(_ text: String) -> String {
        tokenize(text).joined(separator: " ")
    }

    /// Normalized tokens, ready for alignment.
    static func tokenize(_ text: String, dropFillers: Bool = true) -> [String] {
        var s = text.lowercased()
        for variant in apostropheVariants {
            s = s.replacingOccurrences(of: String(variant), with: "'")
        }

        let tokens = s
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).trimmingCharacters(in: punctuation) }
            .filter { !$0.isEmpty }
            .map { numberWords[$0] ?? $0 }

        return dropFillers ? tokens.filter { !fillers.contains($0) } : tokens
    }

    /// Display tokens: original case and punctuation preserved,
    /// but **same cardinality and same order** as `tokenize(_:)`.
    /// Essential so `buildTokenResults` indexes correctly.
    static func displayTokens(_ text: String) -> [String] {
        var kept: [String] = []
        for raw in text.split(whereSeparator: \.isWhitespace) {
            var probe = String(raw).lowercased()
            for variant in apostropheVariants {
                probe = probe.replacingOccurrences(of: String(variant), with: "'")
            }
            probe = probe.trimmingCharacters(in: punctuation)
            guard !probe.isEmpty, !fillers.contains(probe) else { continue }
            kept.append(String(raw))
        }
        return kept
    }
}
