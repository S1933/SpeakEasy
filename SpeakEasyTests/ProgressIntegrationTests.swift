import Foundation
import SwiftData
import Testing
@testable import SpeakEasy

/// Priority integration test (#3): walks the real layers
/// ModelContainer → recordAttempt → finalizeReview (SM-2) → dueDate
/// → snapshot → SessionPlanner, and verifies the due sentence comes out first.
/// More meaningful than isolated unit tests (integration A→B).
@MainActor
@Suite("Progression integration (SM-2 → planner)")
struct ProgressIntegrationTests {

    @Test("Attempt → SM-2 → dueDate → planner surfaces the due sentence first")
    func sm2DueDateDrivesPlanner() throws {
        let schema = Schema([SentenceProgress.self, AppSettings.self, DailyActivity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: config)
        let context = container.mainContext

        let repo = SentenceRepository(sentences: [
            LearningSentence(id: 5, category: .opinions, french: "fr",
                             english: "I think it is fine.", difficulty: 1, keywords: []),
            LearningSentence(id: 6, category: .opinions, french: "fr",
                             english: "I love this place.", difficulty: 1, keywords: []),
        ])

        // 1. Analytics: several attempts do NOT advance SM-2.
        let service = ProgressService(context: context)
        service.recordAttempt(sentenceID: 5, score: 45)
        service.recordAttempt(sentenceID: 5, score: 70)

        // 2. SM-2 planning: applied only ONCE, when the sentence is validated.
        service.finalizeReview(sentenceID: 5, score: 92)
        try context.save()

        // 3. SentenceProgress has a due date (dueDate non nil).
        let progress = try context.fetch(FetchDescriptor<SentenceProgress>()).first
        #expect(progress != nil)
        #expect(progress?.sentenceID == 5)
        #expect(progress?.attempts == 2)          // both attempts count
        #expect(progress?.repetitions == 1)       // but SM-2 only ran once
        #expect(progress?.dueDate != nil)

        // 4. Snapshot → planner (now in the future) → the due sentence comes out first.
        let snapshots = [5: SessionPlanner.Snapshot(
            attempts: progress?.attempts ?? 0,
            bestScore: progress?.bestScore ?? 0,
            lastPracticedAt: progress?.lastPracticedAt,
            dueDate: progress?.dueDate,
            isCompleted: progress?.isCompleted ?? false)]

        let future = Date().addingTimeInterval(2 * 86_400)  // dueDate = aujourd'hui + 1 j
        let plan = SessionPlanner(repository: repo).buildQueue(size: 10, progress: snapshots, now: future)
        #expect(plan.first?.id == 5)
    }
}