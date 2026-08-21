import Foundation
import Testing
@testable import SpeakEasy

@Suite("SessionPlanner")
struct SessionPlannerTests {

    /// Small dedicated corpus — no link to the embedded JSON or Bundle.main
    /// (Phases 2 #17/8: tests do not depend on the real catalog).
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

    @Test("A new session starts with the easiest sentences")
    func coldStart() {
        let q = SessionPlanner(repository: makeRepository()).buildQueue(size: 5, progress: [:])
        #expect(q.count == 5)
        #expect(q.allSatisfy { $0.difficulty == 1 })
    }

    @Test("Difficult sentences come before unseen ones")
    func difficultFirst() {
        let hard = SessionPlanner.Snapshot(
            attempts: 4, bestScore: 40, lastPracticedAt: .now,
            dueDate: nil, isCompleted: false)
        let q = SessionPlanner(repository: makeRepository())
            .buildQueue(size: 3, progress: [21: hard])
        #expect(q.first?.id == 21)
    }

    @Test("A due sentence moves to first position")
    func dueDateFirst() {
        let due = SessionPlanner.Snapshot(
            attempts: 1, bestScore: 70, lastPracticedAt: .now,
            dueDate: .now.addingTimeInterval(-3600), isCompleted: false)
        let q = SessionPlanner(repository: makeRepository())
            .buildQueue(size: 3, progress: [20: due])
        #expect(q.first?.id == 20)
    }

    @Test("No duplicates in the queue")
    func noDuplicates() {
        let q = SessionPlanner(repository: makeRepository()).buildQueue(size: 20, progress: [:])
        #expect(Set(q.map(\.id)).count == q.count)
    }

    @Test("The queue never exceeds the catalog size")
    func clampedToCatalog() {
        let repo = makeRepository()
        let q = SessionPlanner(repository: repo).buildQueue(size: 999, progress: [:])
        #expect(q.count == repo.count)
    }

    @Test("No duplicate id in the test catalog")
    func uniqueIDs() {
        let ids = makeRepository().all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}