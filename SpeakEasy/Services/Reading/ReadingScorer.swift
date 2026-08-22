import Foundation

struct ReadingScorer: Sendable {

    /// Pause au-delà de laquelle on parle d'hésitation.
    private let hesitationThreshold: TimeInterval = 1.2

    func score(snapshot: AlignmentSnapshot,
               tokenCount: Int,
               duration: TimeInterval) -> ReadingResult {

        var correct = 0, missed: [Int] = [], substituted: [Int] = []
        for (index, state) in snapshot.states.enumerated() {
            switch state {
            case .correct:     correct += 1
            case .missed:      missed.append(index)
            case .substituted: substituted.append(index)
            case .pending:     missed.append(index)   // non lu = non acquis
            }
        }

        let minutes = max(duration / 60, 0.01)
        return ReadingResult(
            accuracy: tokenCount == 0 ? 0 : Int(Double(correct) / Double(tokenCount) * 100),
            wcpm: Int(Double(correct) / minutes),
            missedIndices: missed,
            substitutedIndices: substituted,
            insertions: snapshot.insertions,
            hesitationIndices: hesitations(in: snapshot),
            duration: duration
        )
    }

    private func hesitations(in snapshot: AlignmentSnapshot) -> [Int] {
        let ordered = snapshot.timings.sorted { $0.key < $1.key }
        var out: [Int] = []
        for (previous, current) in zip(ordered, ordered.dropFirst())
        where current.value - previous.value > hesitationThreshold {
            out.append(current.key)
        }
        return out
    }
}