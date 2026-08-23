import XCTest
@testable import SpeakEasy

@MainActor
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

    // MARK: - Digit normalization (Phase 0 spike finding: ASR writes "5" for "five")

    func testDigitTokensMapToWordForm() {
        XCTAssertEqual(
            SentenceNormalizer.tokenize("I have 5 dozen reasons"),
            ["i", "have", "five", "dozen", "reasons"]
        )
    }

    func testTeenAndTensDigitsMapToWordForm() {
        XCTAssertEqual(SentenceNormalizer.tokenize("She said 12 and he said 30"),
                       ["she", "said", "twelve", "and", "he", "said", "thirty"])
    }

    func testNumbersWithoutSingleWordFormPassThrough() {
        XCTAssertEqual(SentenceNormalizer.tokenize("about 100 times"),
                       ["about", "100", "times"])
    }

    func testDigitMappingPreservesCardinalityWithDisplayTokens() {
        let raw = "The 5 boxing wizards"
        XCTAssertEqual(SentenceNormalizer.displayTokens(raw).count,
                       SentenceNormalizer.tokenize(raw).count)
    }

    func testPunctuatedDigitIsMappedAfterTrim() {
        XCTAssertEqual(SentenceNormalizer.tokenize("I'll be 10 minutes late."),
                       ["i'll", "be", "ten", "minutes", "late"])
    }
}
