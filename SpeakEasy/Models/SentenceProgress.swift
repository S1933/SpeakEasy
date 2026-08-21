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

    // Champs de planification SM-2 (S4.5)
    var dueDate: Date?
    var easeFactor: Double
    var repetitions: Int
    var intervalDays: Int

    /// Compact history of the last N scores, for the sparkline (S5.6).
    var recentScores: [Int]

    init(
        sentenceID: Int,
        attempts: Int = 0,
        bestScore: Int = 0,
        latestScore: Int = 0,
        lastPracticedAt: Date? = nil,
        isCompleted: Bool = false,
        isFavorite: Bool = false,
        dueDate: Date? = nil,
        easeFactor: Double = 2.5,
        repetitions: Int = 0,
        intervalDays: Int = 0,
        recentScores: [Int] = []
    ) {
        self.sentenceID = sentenceID
        self.attempts = attempts
        self.bestScore = bestScore
        self.latestScore = latestScore
        self.lastPracticedAt = lastPracticedAt
        self.isCompleted = isCompleted
        self.isFavorite = isFavorite
        self.dueDate = dueDate
        self.easeFactor = easeFactor
        self.repetitions = repetitions
        self.intervalDays = intervalDays
        self.recentScores = recentScores
    }
}
