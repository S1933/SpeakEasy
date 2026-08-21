import Testing
@testable import SpeakEasy

@Suite("Advanced scoring (S4.2/S4.3)")
struct SentenceScoringExtendedTests {
    private let service = SentenceScoringService()

    @Test("An accepted variant scores 100")
    func acceptedVariant() {
        let s = sentence("It looks fine to me.", variants: ["It seems fine to me."])
        #expect(service.score(sentence: s, transcript: "it seems fine to me",
                              mode: .translate).score == 100)
    }

    @Test("Dropping an article costs less than dropping a keyword")
    func weightedTokens() {
        let s = sentence("I think it's the best solution.", keywords: ["best", "solution"])
        let article = service.score(sentence: s,
                                    transcript: "i think it's best solution",
                                    mode: .repeatAfter)
        let keyword = service.score(sentence: s,
                                    transcript: "i think it's the best",
                                    mode: .repeatAfter)
        #expect(article.score > keyword.score)
    }

    @Test("Contractions are equivalent to their expanded form",
          arguments: [("it's fine", "it is fine"), ("i'm not sure", "i am not sure")])
    func contractions(pair: (String, String)) {
        #expect(service.score(expected: pair.0, transcript: pair.1).score == 100)
        #expect(service.score(expected: pair.1, transcript: pair.0).score == 100)
    }

    @Test("Near-miss: reference cases",
          arguments: [
            ("think", "sink", true), ("think", "fink", true),
            ("sheep", "ship", true), ("house", "ouse", true),
            ("think", "elephant", false), ("cat", "dog", false),
            ("cat", "cut", false)
          ])
    func nearMissCases(expected: String, actual: String, isNear: Bool) {
        #expect(PhoneticMatcher.isNearMiss(expected, actual) == isNear)
    }

    private func sentence(_ english: String, keywords: [String] = [],
                          variants: [String] = []) -> LearningSentence {
        LearningSentence(id: 1, category: .opinions, french: "x", english: english,
                         difficulty: 1, keywords: keywords, acceptedVariants: variants)
    }
}
