import Testing
@testable import SpeakEasy

/// Rejouables séquences d'hypothèses pour l'aligneur — aucune micro impliquée.
@Suite("ReadingFixtures")
struct ReadingFixtures {

    /// Un texte court multi-phrases, utilisé comme référence commune.
    static func shortText() -> ReadingText {
        ReadingText(
            id: 903, kind: .story, title: "cat", difficulty: 1,
            lines: [
                ReadingLine(id: 0, speaker: nil, text: "the cat sat on the mat"),
            ]
        )
    }

    static func aligner(_ sentence: String) -> ReadingAligner {
        let text = ReadingText(id: 904, kind: .story, title: "t", difficulty: 1,
                               lines: [ReadingLine(id: 0, speaker: nil, text: sentence)])
        return ReadingAligner(reference: ReadingTokenizer.tokenize(text))
    }

    /// Transforme une chaîne en hypothèses finalisées, un mot par seconde.
    static func heard(_ words: String, finalized: Bool = true,
                      startStep: Double = 0.4) -> [HypToken] {
        words.split(separator: " ").enumerated().map { index, word in
            HypToken(normalized: String(word).lowercased(),
                     start: startStep * Double(index + 1),
                     isFinalized: finalized)
        }
    }

    @Test("fixture helper exposes a usable reference")
    func referenceIsUsable() {
        let tokens = ReadingTokenizer.tokenize(Self.shortText())
        #expect(tokens.count == 6)
    }
}