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

    // Depuis S4.2/S4.6, la pondération (mots fonctionnels) et la normalisation
    // de longueur changent les scores absolus. Valeurs recomputées.
    func testMissingOneFunctionWordScores93() {
        let r = service.score(expected: "I need to check the logs",
                              transcript: "I need check the logs")   // "to" omis (mot fonctionnel)
        XCTAssertEqual(r.score, 93)
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
        XCTAssertEqual(r.score, 86)
        if case .incorrect(let actual) = r.tokens[3].status {
            XCTAssertEqual(actual, "look")
        } else {
            XCTFail("Expected 'look' to be marked as incorrect substitution for 'check'")
        }
    }

    func testExtraWordHasLowerPenalty() {
        let r = service.score(expected: "I need to check",
                              transcript: "I really need to check")
        // weightedErrors = 0.5 (un mot en trop), score lissé sur la longueur
        XCTAssertEqual(r.score, 91)
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
        XCTAssertEqual(r.score, 86)
    }

    func testCompletelyWrongTranscriptScoresVeryLow() {
        let r = service.score(expected: "I need to check the logs",
                              transcript: "the quick brown fox jumps over")
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
