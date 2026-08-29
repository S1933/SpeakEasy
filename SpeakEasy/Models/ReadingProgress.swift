import Foundation
import SwiftData

/// Per-text reading progress. Independent of `SentenceProgress` — different
/// granularity, different scoring (accuracy + WCPM rather than SM-2).
@Model
final class ReadingProgress {
    @Attribute(.unique)
    var textId: Int

    var attempts: Int
    var bestAccuracy: Int
    var bestWCPM: Int
    var lastReadAt: Date

    init(textId: Int,
         attempts: Int = 0,
         bestAccuracy: Int = 0,
         bestWCPM: Int = 0,
         lastReadAt: Date = .distantPast) {
        self.textId = textId
        self.attempts = attempts
        self.bestAccuracy = bestAccuracy
        self.bestWCPM = bestWCPM
        self.lastReadAt = lastReadAt
    }
}
