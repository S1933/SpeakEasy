import Foundation
import SwiftData

@MainActor
final class ProgressService {
    let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    @discardableResult
    func recordAttempt(sentenceID: Int, score: Int, at date: Date = .now) -> SentenceProgress {
        let id = sentenceID
        let descriptor = FetchDescriptor<SentenceProgress>(
            predicate: #Predicate { $0.sentenceID == id }
        )
        let progress: SentenceProgress
        if let existing = try? context.fetch(descriptor).first {
            progress = existing
        } else {
            let new = SentenceProgress(sentenceID: sentenceID)
            context.insert(new)
            progress = new
        }
        progress.attempts += 1
        progress.latestScore = score
        if score > progress.bestScore { progress.bestScore = score }
        progress.lastPracticedAt = date
        progress.isCompleted = progress.bestScore >= 85
        try? context.save()
        return progress
    }

    func resetAll() {
        try? context.delete(model: SentenceProgress.self)
        try? context.save()
    }
}

@MainActor
enum ProgressQueries {
    static func completedCount(in entries: [SentenceProgress]) -> Int {
        entries.filter { $0.isCompleted }.count
    }

    static func todayAttemptCount(in entries: [SentenceProgress]) -> Int {
        let start = Calendar.current.startOfDay(for: .now)
        return entries.filter { ($0.lastPracticedAt ?? .distantPast) >= start }.count
    }

    static func difficultCount(in entries: [SentenceProgress]) -> Int {
        entries.filter {
            $0.attempts >= 3 && $0.bestScore < 85
        }.count
    }
}