import Foundation

/// Adapted variant of SM-2 (SuperMemo): the "recall quality" is not entered
/// by the user but derived from the pronunciation score.
enum ReviewScheduler {

    /// Score 0–100 → quality 0–5 expected by SM-2.
    static func quality(from score: Int) -> Int {
        switch score {
        case 95...100: 5
        case 85..<95:  4
        case 70..<85:  3
        case 50..<70:  2
        case 25..<50:  1
        default:       0
        }
    }

    @MainActor
    static func apply(score: Int, to progress: SentenceProgress, on date: Date = .now) {
        let q = quality(from: score)

        if q < 3 {
            // Failure: reset the interval, the sentence comes back very soon.
            progress.repetitions = 0
            progress.intervalDays = 1
        } else {
            progress.repetitions += 1
            progress.intervalDays = switch progress.repetitions {
            case 1: 1
            case 2: 4
            default: Int((Double(progress.intervalDays) * progress.easeFactor).rounded())
            }
        }

        // Adjust the ease factor (original SM-2 formula).
        let delta = 0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02)
        progress.easeFactor = max(1.3, progress.easeFactor + delta)

        // Cap: beyond 6 months, the interval no longer adds value.
        progress.intervalDays = min(progress.intervalDays, 180)

        progress.dueDate = Calendar.current.date(
            byAdding: .day, value: progress.intervalDays, to: date) ?? date
    }
}
