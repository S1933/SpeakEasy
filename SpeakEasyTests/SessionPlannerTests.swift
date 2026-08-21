import Foundation
import Testing
@testable import SpeakEasy

@Suite("SessionPlanner")
struct SessionPlannerTests {
    private let planner = SessionPlanner()

    @Test("Une session neuve commence par les phrases les plus faciles")
    func coldStart() {
        let q = planner.buildQueue(size: 5, progress: [:])
        #expect(q.count == 5)
        #expect(q.allSatisfy { $0.difficulty == 1 })
    }

    @Test("Les phrases difficiles passent devant les inédites")
    func difficultFirst() {
        let hard = SessionPlanner.Snapshot(
            attempts: 4, bestScore: 40, lastPracticedAt: .now,
            dueDate: nil, isCompleted: false
        )
        let q = planner.buildQueue(size: 3, progress: [42: hard])
        #expect(q.first?.id == 42)
    }

    @Test("Aucun doublon dans la file")
    func noDuplicates() {
        let q = planner.buildQueue(size: 20, progress: [:])
        #expect(Set(q.map(\.id)).count == q.count)
    }

    @Test("La file ne dépasse jamais la taille du catalogue")
    func clampedToCatalog() {
        let q = planner.buildQueue(size: 999, progress: [:])
        #expect(q.count == SentenceRepository.shared.count)
    }

    @Test("Aucun id dupliqué dans le catalogue")
    func uniqueIDs() {
        let ids = SentenceRepository.shared.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
