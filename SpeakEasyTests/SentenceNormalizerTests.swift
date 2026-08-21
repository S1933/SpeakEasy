import XCTest
@testable import SpeakEasy

final class SentenceNormalizerTests: XCTestCase {
    func testLowercases() {
        XCTAssertEqual(SentenceNormalizer.normalize("I THINK"), "i think")
    }

    func testNormalizesRightSingleQuote() {
        XCTAssertEqual(
            SentenceNormalizer.normalize("I don\u{2019}t think"),
            "i don't think"
        )
    }

    func testNormalizesLeftSingleQuote() {
        XCTAssertEqual(
            SentenceNormalizer.normalize("I don\u{2018}t think"),
            "i don't think"
        )
    }

    func testStripsTerminalPunctuation() {
        XCTAssertEqual(
            SentenceNormalizer.normalize("I need to check the logs."),
            "i need to check the logs"
        )
    }

    func testStripsMultipleTerminalPunctuation() {
        XCTAssertEqual(
            SentenceNormalizer.normalize("Really?!"),
            "really"
        )
    }

    func testCollapsesWhitespace() {
        XCTAssertEqual(
            SentenceNormalizer.normalize("  I   need    to  check.  "),
            "i need to check"
        )
    }

    func testDoesNotRemoveApostrophesInContractions() {
        XCTAssertEqual(
            SentenceNormalizer.normalize("I don't think it's a problem."),
            "i don't think it's a problem"
        )
    }

    func testTokenizeSplitsOnSpaces() {
        XCTAssertEqual(
            SentenceNormalizer.tokenize("i need to check"),
            ["i", "need", "to", "check"]
        )
    }

    func testTokenizeEmptyReturnsEmpty() {
        XCTAssertEqual(SentenceNormalizer.tokenize(""), [])
    }
}
