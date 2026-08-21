import Foundation
import SwiftData
import Testing
@testable import SpeakEasy

/// Test d'intégration PRIORITAIRE (#3) : traverse les couches réelles
/// ModelContainer → recordAttempt → finalizeReview (SM-2) → dueDate
/// → snapshot → SessionPlanner, et vérifie que la phrase due ressort en premier.
/// Plus significatif que des tests unitaires isolés (integration A→B).
@Suite("Intégration progression (SM-2 → planner)")
struct ProgressIntegrationTests {

    @Test("Tentative → SM-2 → dueDate → le planner sort la phrase due en premier")
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

        // 1. Analytics : plusieurs tentatives ne font PAS avancer SM-2.
        let service = ProgressService(context: context)
        service.recordAttempt(sentenceID: 5, score: 45)
        service.recordAttempt(sentenceID: 5, score: 70)

        // 2. Planning SM-2 : UNE seule fois, à la validation de la phrase.
        service.finalizeReview(sentenceID: 5, score: 92)
        try context.save()

        // 3. SentenceProgress a bien une échéance (dueDate non nil).
        let progress = try context.fetch(FetchDescriptor<SentenceProgress>()).first
        #expect(progress != nil)
        #expect(progress?.sentenceID == 5)
        #expect(progress?.attempts == 2)          // les 2 tentatives comptent
        #expect(progress?.repetitions == 1)       // mais SM-2 n'a tourné qu'une fois
        #expect(progress?.dueDate != nil)

        // 4. Snapshot → planner (now dans le futur) → la phrase due sort en premier.
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