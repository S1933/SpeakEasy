import Foundation

struct ReadingToken: Sendable, Identifiable, Equatable {
    let id: Int              // index absolu dans le texte
    let raw: String          // "don't," — tel qu'affiché, ponctuation comprise
    let normalized: String   // "dont" — via SentenceNormalizer
    let lineIndex: Int
    /// Position du token dans la ligne, pour reconstruire l'AttributedString.
    let rangeInLine: Range<String.Index>
}

enum ReadingTokenizer {
    /// `spokenSpeaker` : en mode dialogue alterné, seules les répliques de ce
    /// rôle entrent dans la référence. nil = tout le texte est lu.
    static func tokenize(_ text: ReadingText, spokenSpeaker: String? = nil) -> [ReadingToken] {
        var out: [ReadingToken] = []
        var id = 0
        for (lineIndex, line) in text.lines.enumerated() {
            if let role = spokenSpeaker, line.speaker != role { continue }
            var cursor = line.text.startIndex
            while cursor < line.text.endIndex {
                // Un « mot » = suite de caractères non blancs.
                guard let wordStart = line.text[cursor...]
                        .firstIndex(where: { !$0.isWhitespace }) else { break }
                let wordEnd = line.text[wordStart...]
                    .firstIndex(where: { $0.isWhitespace }) ?? line.text.endIndex
                let raw = String(line.text[wordStart..<wordEnd])

                // SentenceNormalizer gère déjà casse, accents et contractions :
                // on réutilise pour rester cohérent avec le scoring du mode Repeat.
                if let normalized = SentenceNormalizer.tokenize(raw).first,
                   !normalized.isEmpty {
                    out.append(ReadingToken(id: id, raw: raw, normalized: normalized,
                                            lineIndex: lineIndex,
                                            rangeInLine: wordStart..<wordEnd))
                    id += 1
                }
                cursor = wordEnd
            }
        }
        return out
    }
}