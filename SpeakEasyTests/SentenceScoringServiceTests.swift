import XCTest
@testable import SpeakEasy

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

    func testMissingOneWordScores83() {
        let r = service.score(expected: "I need to check the logs",
                              transcript: "I need check the logs")
        XCTAssertEqual(r.score, 83)
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
        // weightedErrors = 0.5 (one extra word), expectedCount = 4
        // score = round((1 - 0.5/4) * 100) = round(87.5) = 88
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
        // missing "to" (1.0) + missing "the" (1.0) + extra nothing? actually "logs" matches
        // weightedErrors = 2, expectedCount = 6, score = round((1 - 2/6) * 100) = 67
        XCTAssertEqual(r.score, 67)
    }

    func testCompletelyWrongTranscriptScoresVeryLow() {
        let r = service.score(expected: "I need to check the logs",
                              transcript: "the quick brown fox jumps over")
        // Each expected word substituted (6 * 1.0) + 1 extra word (0.5) = 6.5
        // accuracy = 1 - 6.5/6 = negative, clamped to 0
        XCTAssertEqual(r.score, 0)
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
