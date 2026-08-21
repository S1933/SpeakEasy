import Foundation

struct FeedbackService: Sendable {
    nonisolated init() {}
    func feedback(for result: AttemptResult) -> String {
        var missing: [String] = []
        var incorrect: [(expected: String, actual: String)] = []
        var extras: [String] = []

        for token in result.tokens {
            switch token.status {
            case .correct:
                continue
            case .missing:
                missing.append(token.text)
            case .incorrect(let actual):
                incorrect.append((token.text, actual))
            case .extra:
                extras.append(token.text)
            }
        }

        let totalErrors = missing.count + incorrect.count + extras.count

        if totalErrors == 0 {
            return "Excellent. Perfect match."
        }

        if totalErrors == 1 {
            if let m = missing.first {
                return "Good attempt. You missed \"\(m)\"."
            }
            if let i = incorrect.first {
                return "Almost. You said \"\(i.actual)\" instead of \"\(i.expected)\"."
            }
            if let e = extras.first {
                return "Good attempt. You added an extra \"\(e)\"."
            }
        }

        return "Good attempt. Check the highlighted words and try again."
    }
}
