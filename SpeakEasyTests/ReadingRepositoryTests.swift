import Testing
@testable import SpeakEasy

@Suite("ReadingRepository & ReadingTokenizer")
struct ReadingRepositoryTests {

    private func fixture() -> ReadingText {
        ReadingText(
            id: 900, kind: .story, title: "fixture", difficulty: 1,
            lines: [
                ReadingLine(id: 0, speaker: nil, text: "The cat sat on the old mat."),
                ReadingLine(id: 1, speaker: nil, text: "Don't forget the water,"),
                ReadingLine(id: 2, speaker: nil, text: "and the letter from Sam."),
            ]
        )
    }

    @Test("ReadingText computes its word count")
    func wordCount() {
        let text = fixture()
        // 7 + 4 + 5 = 16 whitespace words (apostrophe/capitalisation don't split)
        #expect(text.wordCount == 16)
    }

    @Test("dialogue exposes speakers in order of appearance")
    func speakers() {
        let text = ReadingText(
            id: 901, kind: .conversation, title: "d", difficulty: 1,
            lines: [
                ReadingLine(id: 0, speaker: "Sam", text: "Hey."),
                ReadingLine(id: 1, speaker: "Alex", text: "Hi."),
                ReadingLine(id: 2, speaker: "Sam", text: "How are you?"),
            ]
        )
        #expect(text.speakers == ["Sam", "Alex"])
    }

    @Test("tokenize preserves punctuation in raw and strips it from normalized")
    func tokenization() {
        let text = fixture()
        let tokens = ReadingTokenizer.tokenize(text)
        #expect(tokens.count == 16)

        // "water," keeps its comma in raw, strips it in normalized; "Don't" keeps its
        // internal apostrophe (SentenceNormalizer's punctuation set has no apostrophe).
        let water = tokens.first { $0.raw == "water," }
        #expect(water != nil)
        #expect(water?.normalized == "water")

        let dont = tokens.first { $0.raw == "Don't" }
        #expect(dont != nil)
        #expect(dont?.normalized == "don't")
    }

    @Test("each token carries its absolute id and lineIndex")
    func idsAndLineIndex() {
        let text = fixture()
        let tokens = ReadingTokenizer.tokenize(text)
        // ids are unique and sequential
        #expect(tokens.map(\.id) == Array(0..<tokens.count))
        // every token of line 1 has lineIndex == 1
        let line1 = tokens.filter { $0.lineIndex == 1 }
        #expect(!line1.isEmpty)
        #expect(line1.allSatisfy { $0.lineIndex == 1 })
    }

    @Test("spokenSpeaker filters lines to one role")
    func speakerFiltering() {
        let text = ReadingText(
            id: 902, kind: .conversation, title: "d", difficulty: 1,
            lines: [
                ReadingLine(id: 0, speaker: "Sam", text: "Are you coming along today?"),
                ReadingLine(id: 1, speaker: "Alex", text: "Yes, I will be there soon."),
                ReadingLine(id: 2, speaker: "Sam", text: "Great, see you then, bye."),
            ]
        )
        let sam = ReadingTokenizer.tokenize(text, spokenSpeaker: "Sam")
        #expect(sam.allSatisfy { $0.lineIndex == 0 || $0.lineIndex == 2 })
        #expect(sam.count == 10)  // 5 + 5 words from Sam's two lines
    }

    @Test("repository loads bundled texts by id")
    func repository() {
        // The bundled catalog must decode (>= 5 texts) and re-expose ids.
        #expect(ReadingRepository.shared.count >= 5)
        let first = ReadingRepository.shared.all.first
        #expect(first != nil)
        #expect(ReadingRepository.shared.text(id: first?.id ?? -1) == first)
    }
}