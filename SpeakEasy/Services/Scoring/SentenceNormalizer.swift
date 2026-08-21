import Foundation

enum SentenceNormalizer {

    /// Toutes les variantes Unicode d'apostrophe → U+0027.
    private static let apostropheVariants: [Character] = [
        "\u{2019}", // ’ right single quote
        "\u{2018}", // ‘ left single quote
        "\u{02BC}", // ʼ modifier letter apostrophe
        "\u{FF07}", // ＇ fullwidth
        "\u{00B4}"  // ´ acute accent (fréquent en saisie FR)
    ]

    /// Ponctuation rognée aux extrémités de CHAQUE token.
    private static let punctuation = CharacterSet(
        charactersIn: ".?!,;:\"“”«»()[]{}—–-…"
    )

    /// Mots parasites que l'ASR remonte parfois et qu'on ne doit pas pénaliser.
    private static let fillers: Set<String> = [
        "um", "uh", "erm", "er", "ah", "hmm", "mm", "eh"
    ]

    // MARK: - API

    /// Forme canonique d'une phrase, pour comparaison ou affichage debug.
    static func normalize(_ text: String) -> String {
        tokenize(text).joined(separator: " ")
    }

    /// Tokens normalisés, prêts pour l'alignement.
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

    /// Tokens d'affichage : casse et ponctuation d'origine préservées,
    /// mais **même cardinalité et même ordre** que `tokenize(_:)`.
    /// Indispensable pour que `buildTokenResults` indexe correctement.
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
