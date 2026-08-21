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
