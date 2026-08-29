import XCTest
@testable import SpeakEasy

@MainActor
final class FeedbackServiceTests: XCTestCase {
    let service = FeedbackService()

    func testPerfectMatchHeading() {
        let r = AttemptResult(
            expected: "I need to check the logs",
            transcript: "I need to check the logs",
            score: 100,
            tokens: (1...6).map { _ in TokenResult(text: "x", status: .correct) }
        )
        let f = service.feedback(for: r)
        XCTAssertEqual(f.headline, "Perfect.")
        XCTAssertNil(f.detail)
        XCTAssertNil(f.drillWord)
    }

    func testRevealedPerfectIsNoted() {
        let r = AttemptResult(
            expected: "I need to check the logs",
            transcript: "I need to check the logs",
            score: 100,
            tokens: (1...6).map { _ in TokenResult(text: "x", status: .correct) },
            wasRevealed: true
        )
        XCTAssertEqual(service.feedback(for: r).detail,
                       "Try it without revealing next time.")
    }

    func testMissingWordFeedback() {
        let r = AttemptResult(
            expected: "I need to check",
            transcript: "I need check",
            score: 93,
            tokens: [
                TokenResult(text: "I", status: .correct),
                TokenResult(text: "need", status: .correct),
                TokenResult(text: "to", status: .missing),
                TokenResult(text: "check", status: .correct)
            ]
        )
        let f = service.feedback(for: r)
        XCTAssertEqual(f.headline, "Almost there.")
        XCTAssertEqual(f.drillWord, "to")
    }

    func testSubstitutionFeedback() {
        let r = AttemptResult(
            expected: "I need to check",
            transcript: "I need to look",
            score: 86,
            tokens: [
                TokenResult(text: "I", status: .correct),
                TokenResult(text: "need", status: .correct),
                TokenResult(text: "to", status: .correct),
                TokenResult(text: "check", status: .incorrect(actual: "look"))
            ]
        )
        let f = service.feedback(for: r)
        XCTAssertEqual(f.headline, "One word off.")
        XCTAssertEqual(f.drillWord, "check")
    }

    func testMultipleErrorsFocusesOne() {
        let r = AttemptResult(
            expected: "I need to check the logs",
            transcript: "I need check logs",
            score: 86,
            tokens: [
                TokenResult(text: "I", status: .correct),
                TokenResult(text: "need", status: .correct),
                TokenResult(text: "to", status: .missing),
                TokenResult(text: "check", status: .correct),
                TokenResult(text: "the", status: .missing),
                TokenResult(text: "logs", status: .correct)
            ]
        )
        let f = service.feedback(for: r)
        XCTAssertEqual(f.headline, "Keep going.")
        XCTAssertEqual(f.drillWord, "to")
    }
}
