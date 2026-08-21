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

    // Champs de planification SM-2 (utilisés en S4.5)
    var dueDate: Date?
    var easeFactor: Double
    var interval: Double

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
        interval: Double = 1.0
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
        self.interval = interval
    }
}