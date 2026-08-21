import Foundation
import os
import SwiftData

@MainActor
final class ProgressService {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func recordAttempt(sentenceID: Int, score: Int, at date: Date = .now) -> SentenceProgress {
        let progress = fetchOrCreate(sentenceID: sentenceID)
        let isFirstToday = !Calendar.current.isDate(progress.lastPracticedAt ?? .distantPast,
                                                    inSameDayAs: date)
        progress.attempts += 1
        progress.latestScore = score
        progress.bestScore = max(progress.bestScore, score)
        progress.lastPracticedAt = date
        progress.isCompleted = progress.bestScore >= 85
        progress.recentScores.append(score)
        if progress.recentScores.count > 20 { progress.recentScores.removeFirst() }
        ReviewScheduler.apply(score: score, to: progress, on: date)

        let day = Calendar.current.startOfDay(for: date)
        let activity = fetchOrCreateActivity(day: day)
        activity.attemptCount += 1
        activity.totalScore += score
        if isFirstToday { activity.sentenceCount += 1 }

        do { try context.save() }
        catch { Log.data.error("save recordAttempt: \(error, privacy: .public)") }
        return progress
    }

    func resetAll() {
        try? context.delete(model: SentenceProgress.self)
        try? context.delete(model: DailyActivity.self)
        try? context.save()
        AttemptAudioRecorder.purgeTemporary()
    }

    private func fetchOrCreate(sentenceID: Int) -> SentenceProgress {
        let id = sentenceID
        let descriptor = FetchDescriptor<SentenceProgress>(
            predicate: #Predicate { $0.sentenceID == id }
        )
        if let existing = try? context.fetch(descriptor).first { return existing }
        let new = SentenceProgress(sentenceID: sentenceID)
        context.insert(new)
        return new
    }

    private func fetchOrCreateActivity(day: Date) -> DailyActivity {
        let descriptor = FetchDescriptor<DailyActivity>(
            predicate: #Predicate { $0.day == day }
        )
        if let existing = try? context.fetch(descriptor).first { return existing }
        let new = DailyActivity(day: day)
        context.insert(new)
        return new
    }
}
