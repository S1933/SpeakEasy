import Foundation
import SwiftData

@Model
final class SentenceProgress {
    @Attribute(.unique)
    var sentenceID: Int

    var attempts: Int
    var bestScore: Int
    var latestScore: Int
    var lastPracticedAt: Date?
    var isCompleted: Bool
    var isFavorite: Bool

    init(
        sentenceID: Int,
        attempts: Int = 0,
        bestScore: Int = 0,
        latestScore: Int = 0,
        lastPracticedAt: Date? = nil,
        isCompleted: Bool = false,
        isFavorite: Bool = false
    ) {
        self.sentenceID = sentenceID
        self.attempts = attempts
        self.bestScore = bestScore
        self.latestScore = latestScore
        self.lastPracticedAt = lastPracticedAt
        self.isCompleted = isCompleted
        self.isFavorite = isFavorite
    }
}