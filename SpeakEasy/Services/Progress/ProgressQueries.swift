import Foundation
import SwiftData

@MainActor
enum ProgressQueries {

    static func completedCount(in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<SentenceProgress>(
            predicate: #Predicate { $0.isCompleted }
        ))) ?? 0
    }

    static func difficultCount(in context: ModelContext) -> Int {
        (try? context.fetchCount(FetchDescriptor<SentenceProgress>(
            predicate: #Predicate { $0.attempts >= 3 && $0.bestScore < 85 }
        ))) ?? 0
    }

    /// Nombre de **tentatives** du jour, pas de phrases distinctes.
    static func todayAttemptCount(in context: ModelContext) -> Int {
        let start = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<DailyActivity>(
            predicate: #Predicate { $0.day == start }
        )
        return (try? context.fetch(descriptor).first?.attemptCount) ?? 0
    }

    /// Série de jours consécutifs. Aujourd'hui inclus ; si aujourd'hui n'est
    /// pas encore pratiqué, la série repart d'hier.
    static func currentStreak(in context: ModelContext) -> Int {
        let days = ((try? context.fetch(FetchDescriptor<DailyActivity>())) ?? [])
            .map(\.day)
            .reduce(into: Set<Date>()) { $0.insert($1) }

        let calendar = Calendar.current
        var cursor = calendar.startOfDay(for: .now)
        if !days.contains(cursor) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }
}
