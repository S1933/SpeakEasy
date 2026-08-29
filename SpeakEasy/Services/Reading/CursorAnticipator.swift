import Foundation

/// Pure cursor-anticipation math for the reading session.
///
/// The on-device transcriber emits volatile results in bursts, typically
/// 0.5–1.5 s behind the voice. Between two emissions the aligned cursor is
/// frozen, so at fluent pace it visibly trails the reader by several words.
/// The underline is therefore driven by an ESTIMATED position: last aligned
/// position plus a lead computed from the measured reading rate and the time
/// since the last emission. Alignment stays the source of truth for colors;
/// only the underline (and line scroll) anticipate.
nonisolated struct CursorAnticipator: Sendable {

    /// The recognizer never reports a word the instant it is spoken — this
    /// floor keeps a constant ~1-word lead that absorbs intrinsic latency.
    var latencyFloor: TimeInterval = 0.5
    /// Hard cap on how far the underline may run ahead of alignment.
    var maxLead = 5
    /// Past this silence the reader is considered paused: stop growing and
    /// decay back toward the aligned cursor.
    var growthWindow: TimeInterval = 1.6
    var defaultRate = 2.2      // words/s ≈ 130 wpm
    var minRate = 0.8
    var maxRate = 4.0

    /// Estimated display cursor from the current state.
    /// - `alignedCursor`: position confirmed by the aligner (monotonic).
    /// - `previousDisplay`: previous returned value — output never goes
    ///   backward while reading.
    /// - `elapsed`: time since the last transcriber emission.
    func displayCursor(alignedCursor: Int,
                       previousDisplay: Int,
                       elapsed: TimeInterval,
                       rate: Double,
                       hasHypothesis: Bool,
                       tokenCount: Int) -> Int {
        guard tokenCount > 0 else { return 0 }
        let top = tokenCount - 1
        // No word heard yet: never invent a position ahead of the voice.
        guard hasHypothesis else { return min(alignedCursor, top) }

        if elapsed >= growthWindow {
            // Paused reader: decay one word per tick toward alignment so the
            // underline does not sit stranded ahead of the voice.
            return min(max(alignedCursor, previousDisplay - 1), top)
        }

        let lead = min(Int(rate * (elapsed + latencyFloor)), maxLead)
        let target = min(alignedCursor + lead, top)
        return max(previousDisplay, target)
    }

    /// Words-per-second measured from the audio timestamps of consumed
    /// tokens; falls back to `defaultRate` without enough points.
    static func rate(from timings: [TimeInterval],
                     defaultRate: Double = 2.2,
                     minRate: Double = 0.8,
                     maxRate: Double = 4.0) -> Double {
        guard timings.count >= 3,
              let lo = timings.min(), let hi = timings.max(), hi > lo else {
            return defaultRate
        }
        return min(max(Double(timings.count - 1) / (hi - lo), minRate), maxRate)
    }
}
