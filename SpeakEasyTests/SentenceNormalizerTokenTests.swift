import Testing
@testable import SpeakEasy

@Suite("SentenceNormalizer")
struct SentenceNormalizerTokenTests {

    @Test("Internal punctuation is removed from each token")
    func internalPunctuation() {
        #expect(SentenceNormalizer.tokenize("I'm not sure, but I think it should work.")
                == ["i'm", "not", "sure", "but", "i", "think", "it", "should", "work"])
    }

    @Test("Typographic apostrophes are normalized")
    func curlyApostrophes() {
        #expect(SentenceNormalizer.tokenize("It\u{2019}s fine")
                == SentenceNormalizer.tokenize("It's fine"))
    }

    @Test("Fillers are ignored")
    func fillers() {
        #expect(SentenceNormalizer.tokenize("um I think uh so") == ["i", "think", "so"])
    }

    /// Structural contract: without it, buildTokenResults can crash.
    @Test("displayTokens and tokenize always have the same cardinality",
          arguments: SentenceRepository.shared.all)
    func cardinalityInvariant(sentence: LearningSentence) {
        #expect(SentenceNormalizer.displayTokens(sentence.english).count
                == SentenceNormalizer.tokenize(sentence.english).count)
    }

    /// ASR transcripts never carry commas. Before S1.1, the internal
    /// comma survived normalize() and caused an unfair substitution.
    @Test("Comma-bearing sentences score 100% on a punctuation-less transcript")
    func commaSentencesScorePerfect() {
        let service = SentenceScoringService()
        for sentence in SentenceRepository.shared.all where sentence.english.contains(",") {
            let transcript = sentence.english.replacingOccurrences(of: ",", with: "")
            let r = service.score(expected: sentence.english, transcript: transcript)
            #expect(r.score == 100, "Expected 100 for '\(sentence.english)'")
        }
    }
}
