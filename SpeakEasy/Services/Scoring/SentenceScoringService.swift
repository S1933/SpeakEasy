import Foundation

struct SentenceScoringService: Sendable {
    struct Weights: Sendable {
        var missing: Double
        var wrong: Double
        var extra: Double

        nonisolated static let `default` = Weights(missing: 1.0, wrong: 1.0, extra: 0.5)
    }

    private let weights: Weights

    nonisolated init(weights: Weights = .default) {
        self.weights = weights
    }

    func score(expected: String, transcript: String) -> AttemptResult {
        let normalizedExpected = SentenceNormalizer.normalize(expected)
        let normalizedTranscript = SentenceNormalizer.normalize(transcript)
        let expectedTokens = SentenceNormalizer.tokenize(normalizedExpected)
        let transcriptTokens = SentenceNormalizer.tokenize(normalizedTranscript)

        if expectedTokens.isEmpty {
            return AttemptResult(
                expected: expected,
                transcript: transcript,
                score: 0,
                tokens: transcriptTokens.map { TokenResult(text: $0, status: .extra) }
            )
        }

        let alignment = align(expected: expectedTokens, transcript: transcriptTokens)

        var weightedErrors: Double = 0
        for op in alignment {
            switch op {
            case .match: continue
            case .substitute: weightedErrors += weights.wrong
            case .insert: weightedErrors += weights.missing
            case .delete: weightedErrors += weights.extra
            }
        }

        let expectedCount = Double(expectedTokens.count)
        let raw = 1 - weightedErrors / expectedCount
        let clamped = max(0, min(1, raw))
        let score = Int((clamped * 100).rounded())

        let tokens = buildTokenResults(
            alignment: alignment,
            expectedText: tokenizePreservingCase(expected),
            transcript: transcriptTokens
        )

        return AttemptResult(
            expected: expected,
            transcript: transcript,
            score: score,
            tokens: tokens
        )
    }

    private func tokenizePreservingCase(_ text: String) -> [String] {
        let collapsed = text
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        guard !collapsed.isEmpty else { return [] }
        return collapsed.split(separator: " ").map(String.init)
    }

    enum AlignmentOp: Sendable {
        case match(expectedIdx: Int, transcriptIdx: Int)
        case substitute(expectedIdx: Int, transcriptIdx: Int)
        case insert(expectedIdx: Int)
        case delete(transcriptIdx: Int)
    }

    private func align(expected: [String], transcript: [String]) -> [AlignmentOp] {
        let m = expected.count
        let n = transcript.count

        var dp = Array(repeating: Array(repeating: Double.infinity, count: n + 1), count: m + 1)
        var back: [[Backtrace]] = Array(repeating: Array(repeating: .none, count: n + 1), count: m + 1)

        dp[0][0] = 0
        for i in 1..<m + 1 {
            dp[i][0] = dp[i - 1][0] + weights.missing
            back[i][0] = .insert
        }
        for j in 1..<n + 1 {
            dp[0][j] = dp[0][j - 1] + weights.extra
            back[0][j] = .delete
        }

        for i in 1..<m + 1 {
            for j in 1..<n + 1 {
                let substituteCost = dp[i - 1][j - 1] + (expected[i - 1] == transcript[j - 1] ? 0 : weights.wrong)
                let insertCost = dp[i - 1][j] + weights.missing
                let deleteCost = dp[i][j - 1] + weights.extra

                var best = substituteCost
                var bestOp: Backtrace = expected[i - 1] == transcript[j - 1] ? .match : .substitute

                if insertCost < best {
                    best = insertCost
                    bestOp = .insert
                }
                if deleteCost < best {
                    best = deleteCost
                    bestOp = .delete
                }

                dp[i][j] = best
                back[i][j] = bestOp
            }
        }

        var ops: [AlignmentOp] = []
        var i = m
        var j = n
        while i > 0 || j > 0 {
            switch back[i][j] {
            case .match:
                ops.append(.match(expectedIdx: i - 1, transcriptIdx: j - 1))
                i -= 1; j -= 1
            case .substitute:
                ops.append(.substitute(expectedIdx: i - 1, transcriptIdx: j - 1))
                i -= 1; j -= 1
            case .insert:
                ops.append(.insert(expectedIdx: i - 1))
                i -= 1
            case .delete:
                ops.append(.delete(transcriptIdx: j - 1))
                j -= 1
            case .none:
                return ops.reversed()
            }
        }
        return ops.reversed()
    }

    private enum Backtrace {
        case match, substitute, insert, delete, none
    }

    private func buildTokenResults(
        alignment: [AlignmentOp],
        expectedText: [String],
        transcript: [String]
    ) -> [TokenResult] {
        alignment.map { op in
            switch op {
            case .match(let e, _):
                return TokenResult(text: expectedText[e], status: .correct)
            case .substitute(let e, let t):
                return TokenResult(text: expectedText[e], status: .incorrect(actual: transcript[t]))
            case .insert(let e):
                return TokenResult(text: expectedText[e], status: .missing)
            case .delete(let t):
                return TokenResult(text: transcript[t], status: .extra)
            }
        }
    }
}
