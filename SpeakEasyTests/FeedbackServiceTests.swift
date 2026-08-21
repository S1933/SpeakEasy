import XCTest
@testable import SpeakEasy

final class FeedbackServiceTests: XCTestCase {
    let service = FeedbackService()

    func testPerfectMatchFeedback() {
        let r = AttemptResult(
            expected: "I need to check the logs",
            transcript: "I need to check the logs",
            score: 100,
            tokens: (1...6).map { _ in TokenResult(text: "x", status: .correct) }
        )
        XCTAssertEqual(service.feedback(for: r), "Excellent. Perfect match.")
    }

    func testMissingWordFeedback() {
        let r = AttemptResult(
            expected: "I need to check",
            transcript: "I need check",
            score: 75,
            tokens: [
                TokenResult(text: "I", status: .correct),
                TokenResult(text: "need", status: .correct),
                TokenResult(text: "to", status: .missing),
                TokenResult(text: "check", status: .correct)
            ]
        )
        XCTAssertEqual(service.feedback(for: r), "Good attempt. You missed \"to\".")
    }

    func testSubstitutionFeedback() {
        let r = AttemptResult(
            expected: "I need to check",
            transcript: "I need to look",
            score: 75,
            tokens: [
                TokenResult(text: "I", status: .correct),
                TokenResult(text: "need", status: .correct),
                TokenResult(text: "to", status: .correct),
                TokenResult(text: "check", status: .incorrect(actual: "look"))
            ]
        )
        XCTAssertEqual(service.feedback(for: r), "Almost. You said \"look\" instead of \"check\".")
    }

    func testMultipleErrorsFeedback() {
        let r = AttemptResult(
            expected: "I need to check the logs",
            transcript: "I need check logs",
            score: 67,
            tokens: [
                TokenResult(text: "I", status: .correct),
                TokenResult(text: "need", status: .correct),
                TokenResult(text: "to", status: .missing),
                TokenResult(text: "check", status: .correct),
                TokenResult(text: "the", status: .missing),
                TokenResult(text: "logs", status: .correct)
            ]
        )
        XCTAssertEqual(service.feedback(for: r), "Good attempt. Check the highlighted words and try again.")
    }
}
