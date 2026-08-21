import Foundation

extension AttemptResult {
    static func empty(expected: String, transcript: String, mode: PracticeMode) -> AttemptResult {
        AttemptResult(expected: expected, transcript: transcript, score: 0,
                      tokens: SentenceNormalizer.tokenize(transcript).map { TokenResult(text: $0, status: .extra) },
                      mode: mode)
    }
}
