import XCTest
@testable import SpeakEasy

@MainActor
final class SentenceScoringServiceTests: XCTestCase {
    let service = SentenceScoringService()

    func testExactMatchScores100() {
        let r = service.score(expected: "I need to check the logs",
                              transcript: "I need to check the logs")
        XCTAssertEqual(r.score, 100)
        XCTAssertTrue(r.tokens.allSatisfy { if case .correct = $0.status { true } else { false } })
    }

    func testNormalizationIsCaseInsensitive() {
        let r = service.score(expected: "I need to check the logs",
                              transcript: "i need to check the logs")
        XCTAssertEqual(r.score, 100)
    }

    func testNormalizationIgnoresPunctuation() {
        let r = service.score(expected: "I need to check the logs",
                              transcript: "I need to check the logs!")
        XCTAssertEqual(r.score, 100)
    }

    // Since S4.2/S4.6, weighting (function words) and length
    // normalization change the absolute scores. Values recomputed.
    func testMissingOneFunctionWordScores92() {
        let r = service.score(expected: "I need to check the logs",
                              transcript: "I need check the logs")   // "to" omitted (function word)
        XCTAssertEqual(r.score, 92)
        XCTAssertEqual(r.tokens.count, 6)
        if case .missing = r.tokens[2].status {
            XCTAssertEqual(r.tokens[2].text, "to")
        } else {
            XCTFail("Expected 'to' to be marked missing")
        }
    }

    func testSubstitutionMarksIncorrect() {
        let r = service.score(expected: "I need to check the logs",
                              transcript: "I need to look the logs")
        XCTAssertEqual(r.score, 83)
        if case .incorrect(let actual) = r.tokens[3].status {
            XCTAssertEqual(actual, "look")
        } else {
            XCTFail("Expected 'look' to be marked as incorrect substitution for 'check'")
        }
    }

    func testExtraWordHasLowerPenalty() {
        let r = service.score(expected: "I need to check",
                              transcript: "I really need to check")
        // weightedErrors = 0.5 (one extra word), length-normalized score
        XCTAssertEqual(r.score, 88)
    }

    func testEmptyTranscriptScoresZero() {
        let r = service.score(expected: "I need to check the logs",
                              transcript: "")
        XCTAssertEqual(r.score, 0)
    }

    func testMultipleErrorsAccumulate() {
        let r = service.score(expected: "I need to check the logs",
                              transcript: "I need check logs")
        // "to" et "the" omis (mots fonctionnels)
        XCTAssertEqual(r.score, 83)
    }

    func testCompletelyWrongTranscriptScoresVeryLow() {
        let r = service.score(expected: "I need to check the logs",
                              transcript: "the quick brown fox jumps over")
        // Phrases sans rapport → score faible (< 30), jamais 0 sauf transcript vide.
        XCTAssertLessThan(r.score, 30)
        XCTAssertGreaterThan(r.score, 0)
    }

    func testTokensMaintainOrderForUI() {
        let r = service.score(expected: "I need to check",
                              transcript: "I need check")
        XCTAssertEqual(r.tokens.map(\.text), ["I", "need", "to", "check"])
        XCTAssertEqual(r.tokens.map { token in
            if case .correct = token.status { return "correct" }
            if case .missing = token.status { return "missing" }
            return "other"
        }, ["correct", "correct", "missing", "correct"])
    }

    func testEmptyExpectedScoresZero() {
        let r = service.score(expected: "", transcript: "hello")
        XCTAssertEqual(r.score, 0)
    }
}
