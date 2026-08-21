import Foundation

struct FeedbackService: Sendable {
    nonisolated init() {}

    struct Feedback: Sendable, Equatable {
        let headline: String
        let detail: String?
        let tip: String?
        /// The word to replay in a loop (S5.3).
        let drillWord: String?
    }

    /// Layered feedback that points to a single thing to work on (S4.4).
    func feedback(for result: AttemptResult) -> Feedback {
        var missing: [String] = [], extras: [String] = []
        var wrong: [(String, String)] = []
        var nearMisses: [(String, String, PhonemeIssue?)] = []

        for token in result.tokens {
            switch token.status {
            case .correct: continue
            case .missing: missing.append(token.text)
            case .extra: extras.append(token.text)
            case .incorrect(let actual): wrong.append((token.text, actual))
            case .nearMiss(let actual, let issue): nearMisses.append((token.text, actual, issue))
            }
        }

        if missing.isEmpty && wrong.isEmpty && extras.isEmpty && nearMisses.isEmpty {
            return Feedback(headline: "Perfect.",
                            detail: result.wasRevealed ? "Try it without revealing next time." : nil,
                            tip: nil, drillWord: nil)
        }

        // Priority 1: an identified pronunciation problem — the most actionable.
        if let (expected, actual, issue) = nearMisses.first, let issue {
            return Feedback(headline: "Close — watch \(issue.label).",
                            detail: "You said “\(actual)” where the sentence has “\(expected)”.",
                            tip: issue.tip, drillWord: expected)
        }

        // Priority 2: a single missing keyword changes the meaning.
        if let word = missing.first, missing.count == 1, wrong.isEmpty {
            return Feedback(headline: "Almost there.",
                            detail: "“\(word)” didn't come through.",
                            tip: "Slow down slightly on that word.", drillWord: word)
        }

        // Priority 3: isolated lexical substitution.
        if let (expected, actual) = wrong.first, wrong.count == 1 {
            return Feedback(headline: "One word off.",
                            detail: "You said “\(actual)” instead of “\(expected)”.",
                            tip: nil, drillWord: expected)
        }

        // Priority 4: many errors → call out just one of them.
        let focus = missing.first ?? wrong.first?.0 ?? nearMisses.first?.0
        return Feedback(headline: "Keep going.",
                        detail: focus.map { "Start with “\($0)” — get that one right, then run the whole sentence." },
                        tip: "Listen once more before your next try.",
                        drillWord: focus)
    }
}
