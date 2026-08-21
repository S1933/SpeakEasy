import Testing
@testable import SpeakEasy

@Suite("SentenceNormalizer")
struct SentenceNormalizerTokenTests {

    @Test("La ponctuation interne est retirée de chaque token")
    func internalPunctuation() {
        #expect(SentenceNormalizer.tokenize("I'm not sure, but I think it should work.")
                == ["i'm", "not", "sure", "but", "i", "think", "it", "should", "work"])
    }

    @Test("Les apostrophes typographiques sont normalisées")
    func curlyApostrophes() {
        #expect(SentenceNormalizer.tokenize("It\u{2019}s fine")
                == SentenceNormalizer.tokenize("It's fine"))
    }

    @Test("Les fillers sont ignorés")
    func fillers() {
        #expect(SentenceNormalizer.tokenize("um I think uh so") == ["i", "think", "so"])
    }

    /// Contrat structurel : sans lui, buildTokenResults peut crasher.
    @Test("displayTokens et tokenize ont toujours la même cardinalité",
          arguments: SentenceRepository.shared.all)
    func cardinalityInvariant(sentence: LearningSentence) {
        #expect(SentenceNormalizer.displayTokens(sentence.english).count
                == SentenceNormalizer.tokenize(sentence.english).count)
    }

    /// Le transcript ASR ne porte jamais de virgule. Avant S1.1, la virgule
    /// interne survit à normalize() et provoque une substitution injuste.
    @Test("Les phrases à virgule scorent 100 % sur un transcript sans ponctuation")
    func commaSentencesScorePerfect() {
        let service = SentenceScoringService()
        for sentence in SentenceRepository.shared.all where sentence.english.contains(",") {
            let transcript = sentence.english.replacingOccurrences(of: ",", with: "")
            let r = service.score(expected: sentence.english, transcript: transcript)
            #expect(r.score == 100, "Attendu 100 pour '\(sentence.english)'")
        }
    }
}
