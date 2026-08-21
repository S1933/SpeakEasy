import Foundation

struct SentenceScoringService: Sendable {

    init() {}

    // MARK: - Public API

    /// Simple scoring (test forms / pipelines without a mode).
    func score(expected: String, transcript: String) -> AttemptResult {
        scoreAgainst(expected: expected, transcript: transcript,
                     keywords: [], profile: .strict, mode: .repeatAfter)
    }

    /// Full scoring: best variant accepted, keyword weighting,
    /// mode profile, contractions.
    func score(sentence: LearningSentence, transcript: String,
               mode: PracticeMode, wasRevealed: Bool = false) -> AttemptResult {
        let profile = mode.scoringProfile
        let keywordSet = Set(sentence.keywords.map { SentenceNormalizer.tokenize($0).joined() })
        let best = sentence.allTargets
            .map { target in
                scoreAgainst(expected: target, transcript: transcript,
                             keywords: keywordSet, profile: profile, mode: mode)
            }
            .max { $0.score < $1.score }

        return (best ?? .empty(expected: sentence.english, transcript: transcript, mode: mode))
            .withRevealed(wasRevealed)
    }

    // MARK: - Helpers

    private func cost(for token: String, base: Double,
                      keywords: Set<String>, profile: ScoringProfile) -> Double {
        if keywords.contains(token) { return base * profile.keywordMultiplier }
        if FunctionWords.set.contains(token) { return base * profile.functionWordMultiplier }
        return base
    }

    /// Normalization that mitigates variance on short sentences (S4.6).
    /// The effective denominator is bounded toward a reference length: a
    /// floor of 4 and a ceiling of 12 keep the mastery threshold (85)
    /// comparable regardless of length — one error on a short sentence
    /// costs more than on a long one.
    private func normalizedScore(errors: Double, expectedCount: Int) -> Int {
        let n = Double(expectedCount)
        let effective = min(max(n, 4.0), 12.0)
        let raw = 1 - errors / effective
        return Int((max(0, min(1, raw)) * 100).rounded())
    }

    private func scoreAgainst(expected: String, transcript: String,
                              keywords: Set<String>, profile: ScoringProfile,
                              mode: PracticeMode) -> AttemptResult {
        let expectedTokens = SentenceNormalizer.tokenize(expected)
        let transcriptTokens = SentenceNormalizer.tokenize(transcript)

        if expectedTokens.isEmpty {
            return .empty(expected: expected, transcript: transcript, mode: mode)
        }

        // Empty transcript → 0, without going through alignment (avoids the
        // degenerate path and supplies "missing" chips for each expected token).
        if transcriptTokens.isEmpty {
            return AttemptResult(expected: expected, transcript: transcript, score: 0,
                                 tokens: SentenceNormalizer.displayTokens(expected).map {
                                     TokenResult(text: $0, status: .missing)
                                 },
                                 mode: mode)
        }

        let alignment = align(expected: expectedTokens, transcript: transcriptTokens,
                              keywords: keywords, profile: profile)

        var weightedErrors: Double = 0
        for op in alignment {
            switch op {
            case .match:
                continue
            case .nearMiss(let e, _):
                weightedErrors += cost(for: expectedTokens[e],
                                       base: profile.wrong * profile.nearMissRatio,
                                       keywords: keywords, profile: profile)
            case .substitute(let e, _):
                weightedErrors += cost(for: expectedTokens[e], base: profile.wrong,
                                       keywords: keywords, profile: profile)
            case .insert(let e):
                weightedErrors += cost(for: expectedTokens[e], base: profile.missing,
                                       keywords: keywords, profile: profile)
            case .delete:
                weightedErrors += profile.extra
            case .mergeExpected, .mergeTranscript:
                continue
            }
        }

        let score = normalizedScore(errors: weightedErrors, expectedCount: expectedTokens.count)

        let tokens = buildTokenResults(alignment: alignment,
                                       expectedText: SentenceNormalizer.displayTokens(expected),
                                       expectedTokens: expectedTokens,
                                       transcript: transcriptTokens)
        return AttemptResult(expected: expected, transcript: transcript,
                             score: score, tokens: tokens, mode: mode)
    }

    // MARK: - Alignment (DP with contractions and near-miss)

    enum Backtrace: Sendable {
        case match, nearMiss, substitute, insert, delete
        case mergeExpected, mergeTranscript, none
    }

    enum AlignmentOp: Sendable {
        case match(expectedIdx: Int, transcriptIdx: Int)
        case nearMiss(expectedIdx: Int, transcriptIdx: Int)
        case substitute(expectedIdx: Int, transcriptIdx: Int)
        case insert(expectedIdx: Int)
        case delete(transcriptIdx: Int)
        case mergeExpected(expectedIdx: Int, transcriptIdx: Int)     // expected contracted (1) ↔ transcript expanded (2)
        case mergeTranscript(expectedIdx: Int, transcriptIdx: Int)   // expected expanded (2) ↔ transcript contracted (1)
    }

    private func align(expected: [String], transcript: [String],
                       keywords: Set<String>, profile: ScoringProfile) -> [AlignmentOp] {
        let m = expected.count
        let n = transcript.count

        var dp = Array(repeating: Array(repeating: Double.infinity, count: n + 1), count: m + 1)
        var back: [[Backtrace]] = Array(repeating: Array(repeating: .none, count: n + 1), count: m + 1)

        dp[0][0] = 0
        for i in 1...m {
            dp[i][0] = dp[i - 1][0] + cost(for: expected[i - 1], base: profile.missing,
                                           keywords: keywords, profile: profile)
            back[i][0] = .insert
        }
        for j in 1...n {
            dp[0][j] = dp[0][j - 1] + profile.extra
            back[0][j] = .delete
        }

        for i in 1...m {
            for j in 1...n {
                let identical = expected[i - 1] == transcript[j - 1]
                let near = !identical && PhoneticMatcher.isNearMiss(expected[i - 1], transcript[j - 1])

                let subBase = near ? profile.wrong * profile.nearMissRatio : profile.wrong
                let substituteCost = dp[i - 1][j - 1]
                    + (identical ? 0 : cost(for: expected[i - 1], base: subBase,
                                            keywords: keywords, profile: profile))
                let insertCost = dp[i - 1][j] + cost(for: expected[i - 1], base: profile.missing,
                                                     keywords: keywords, profile: profile)
                let deleteCost = dp[i][j - 1] + profile.extra

                var best = substituteCost
                var bestOp: Backtrace = identical ? .match : (near ? .nearMiss : .substitute)

                if insertCost < best { best = insertCost; bestOp = .insert }
                if deleteCost < best { best = deleteCost; bestOp = .delete }

                // Case A: expected expanded ("it is"), transcript contracted ("it's")
                if i >= 2, Contractions.matches(single: transcript[j - 1],
                                                pair: [expected[i - 2], expected[i - 1]]),
                   dp[i - 2][j - 1] < best {
                    best = dp[i - 2][j - 1]
                    bestOp = .mergeTranscript
                }
                // Case B: expected contracted ("it's"), transcript expanded ("it is")
                if j >= 2, Contractions.matches(single: expected[i - 1],
                                                pair: [transcript[j - 2], transcript[j - 1]]),
                   dp[i - 1][j - 2] < best {
                    best = dp[i - 1][j - 2]
                    bestOp = .mergeExpected
                }

                dp[i][j] = best
                back[i][j] = bestOp
            }
        }

        var ops: [AlignmentOp] = []
        var i = m, j = n
        while i > 0 || j > 0 {
            switch back[i][j] {
            case .match:
                ops.append(.match(expectedIdx: i - 1, transcriptIdx: j - 1)); i -= 1; j -= 1
            case .nearMiss:
                ops.append(.nearMiss(expectedIdx: i - 1, transcriptIdx: j - 1)); i -= 1; j -= 1
            case .substitute:
                ops.append(.substitute(expectedIdx: i - 1, transcriptIdx: j - 1)); i -= 1; j -= 1
            case .insert:
                ops.append(.insert(expectedIdx: i - 1)); i -= 1
            case .delete:
                ops.append(.delete(transcriptIdx: j - 1)); j -= 1
            case .mergeExpected:
                ops.append(.mergeExpected(expectedIdx: i - 1, transcriptIdx: j - 1)); i -= 1; j -= 2
            case .mergeTranscript:
                ops.append(.mergeTranscript(expectedIdx: i - 1, transcriptIdx: j - 1)); i -= 2; j -= 1
            case .none:
                return ops.reversed()
            }
        }
        return ops.reversed()
    }

    private func buildTokenResults(alignment: [AlignmentOp], expectedText: [String],
                                   expectedTokens: [String], transcript: [String]) -> [TokenResult] {
        var out: [TokenResult] = []
        for op in alignment {
            switch op {
            case .match(let e, _):
                out.append(TokenResult(text: expectedText[e], status: .correct))
            case .nearMiss(let e, let t):
                let issue = PhoneticMatcher.diagnose(expected: expectedTokens[e], actual: transcript[t])
                out.append(TokenResult(text: expectedText[e],
                                       status: .nearMiss(actual: transcript[t], issue: issue)))
            case .substitute(let e, let t):
                out.append(TokenResult(text: expectedText[e],
                                       status: .incorrect(actual: transcript[t])))
            case .insert(let e):
                out.append(TokenResult(text: expectedText[e], status: .missing))
            case .delete(let t):
                out.append(TokenResult(text: transcript[t], status: .extra))
            case .mergeExpected(let e, _):
                // expected contracted (1 token) → a single correct chip
                out.append(TokenResult(text: expectedText[e], status: .correct))
            case .mergeTranscript(let e, _):
                // expected expanded (2 tokens) → two correct chips
                out.append(TokenResult(text: expectedText[e - 1], status: .correct))
                out.append(TokenResult(text: expectedText[e], status: .correct))
            }
        }
        return out
    }
}
