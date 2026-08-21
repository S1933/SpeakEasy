import Foundation

enum PracticeState: Sendable {
    case ready
    case recording
    case processing
    case result(AttemptResult)
}

struct AttemptResult: Sendable, Equatable {
    let expected: String
    let transcript: String
    let score: Int
    let tokens: [TokenResult]
    let mode: PracticeMode
    let wasRevealed: Bool

    init(expected: String, transcript: String, score: Int, tokens: [TokenResult],
         mode: PracticeMode = .repeatAfter, wasRevealed: Bool = false) {
        self.expected = expected
        self.transcript = transcript
        self.score = score
        self.tokens = tokens
        self.mode = mode
        self.wasRevealed = wasRevealed
    }

    /// Score qui compte pour la progression. Une réponse révélée plafonne.
    var effectiveScore: Int { wasRevealed ? min(score, 70) : score }

    func withRevealed(_ revealed: Bool) -> AttemptResult {
        AttemptResult(expected: expected, transcript: transcript, score: score,
                      tokens: tokens, mode: mode, wasRevealed: revealed)
    }
}

enum TokenStatus: Sendable, Equatable {
    case correct
    case nearMiss(actual: String, issue: PhonemeIssue?)
    case missing
    case incorrect(actual: String)
    case extra
}

struct TokenResult: Sendable, Equatable {
    let text: String
    let status: TokenStatus
}
