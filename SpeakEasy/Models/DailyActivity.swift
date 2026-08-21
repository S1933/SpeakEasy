import Foundation
import SwiftData

@Model
final class DailyActivity {
    @Attribute(.unique) var day: Date      // startOfDay
    var attemptCount: Int
    var sentenceCount: Int
    var totalScore: Int

    init(day: Date, attemptCount: Int = 0, sentenceCount: Int = 0, totalScore: Int = 0) {
        self.day = day
        self.attemptCount = attemptCount
        self.sentenceCount = sentenceCount
        self.totalScore = totalScore
    }

    var averageScore: Int { attemptCount == 0 ? 0 : totalScore / attemptCount }
}
