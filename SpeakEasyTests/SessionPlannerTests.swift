import Foundation
import Testing
@testable import SpeakEasy

@Suite("SessionPlanner")
struct SessionPlannerTests {

    /// Petit corpus dédié — aucun lien avec le JSON embarqué ni Bundle.main
    /// (Phases 2 #17/8 : les tests ne dépendent pas du catalogue réel).
    private func makeRepository() -> SentenceRepository {
        let sentences = [
            sentence(id: 10, diff: 1, text: "I eat an apple."),
            sentence(id: 11, diff: 1, text: "I drink water."),
            sentence(id: 12, diff: 1, text: "I read a book."),
            sentence(id: 13, diff: 1, text: "I like coffee."),
            sentence(id: 14, diff: 1, text: "I walk to work."),
            sentence(id: 20, diff: 2, text: "I need to check the logs."),
            sentence(id: 21, diff: 2, text: "The meeting starts at nine."),
            sentence(id: 30, diff: 3, text: "The inventory is up to date."),
            sentence(id: 31, diff: 3, text: "We will finalize the contract."),
        ]
        return SentenceRepository(sentences: sentences)
    }

    private func sentence(id: Int, diff: Int, text: String) -> LearningSentence {
        LearningSentence(id: id, category: .organization, french: "fr",
                         english: text, difficulty: diff, keywords: [])
    }

    @Test("Une session neuve commence par les phrases les plus faciles")
    func coldStart() {
        let q = SessionPlanner(repository: makeRepository()).buildQueue(size: 5, progress: [:])
        #expect(q.count == 5)
        #expect(q.allSatisfy { $0.difficulty == 1 })
    }

    @Test("Les phrases difficiles passent devant les inédites")
    func difficultFirst() {
        let hard = SessionPlanner.Snapshot(
            attempts: 4, bestScore: 40, lastPracticedAt: .now,
            dueDate: nil, isCompleted: false)
        let q = SessionPlanner(repository: makeRepository())
            .buildQueue(size: 3, progress: [21: hard])
        #expect(q.first?.id == 21)
    }

    @Test("Une phrase due passe en première position")
    func dueDateFirst() {
        let due = SessionPlanner.Snapshot(
            attempts: 1, bestScore: 70, lastPracticedAt: .now,
            dueDate: .now.addingTimeInterval(-3600), isCompleted: false)
        let q = SessionPlanner(repository: makeRepository())
            .buildQueue(size: 3, progress: [20: due])
        #expect(q.first?.id == 20)
    }

    @Test("Aucun doublon dans la file")
    func noDuplicates() {
        let q = SessionPlanner(repository: makeRepository()).buildQueue(size: 20, progress: [:])
        #expect(Set(q.map(\.id)).count == q.count)
    }

    @Test("La file ne dépasse jamais la taille du corpus")
    func clampedToCatalog() {
        let repo = makeRepository()
        let q = SessionPlanner(repository: repo).buildQueue(size: 999, progress: [:])
        #expect(q.count == repo.count)
    }

    @Test("Aucun id dupliqué dans le corpus de test")
    func uniqueIDs() {
        let ids = makeRepository().all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}