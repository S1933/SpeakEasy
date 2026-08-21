import Foundation

/// Construit la file de phrases d'une session à partir de la progression stockée.
///
/// Priorité (du plus urgent au moins urgent) :
///   1. Phrases dues à révision (S4.5 — planning SM-2)
///   2. Phrases difficiles : ≥ 2 tentatives et meilleur score < 85
///   3. Phrases jamais vues, difficulté croissante
///   4. Complément aléatoire parmi les phrases maîtrisées les plus anciennes
struct SessionPlanner: Sendable {

    struct Snapshot: Sendable {
        var attempts: Int
        var bestScore: Int
        var lastPracticedAt: Date?
        var dueDate: Date?          // alimenté en S4.5
        var isCompleted: Bool
    }

    private let repository: SentenceRepository

    init(repository: SentenceRepository = .shared) {
        self.repository = repository
    }

    func buildQueue(
        size: Int,
        progress: [Int: Snapshot],
        categories: Set<SentenceCategory>? = nil,
        now: Date = .now
    ) -> [LearningSentence] {

        let pool = repository.all.filter { sentence in
            categories?.contains(sentence.category) ?? true
        }
        guard !pool.isEmpty else { return [] }

        var queue: [LearningSentence] = []
        var used = Set<Int>()

        func append(_ candidates: [LearningSentence]) {
            for sentence in candidates where queue.count < size {
                guard used.insert(sentence.id).inserted else { continue }
                queue.append(sentence)
            }
        }

        // 1 — dues à révision, la plus en retard d'abord
        let dueCandidates = pool.filter { sentence in
            guard let dueDate = progress[sentence.id]?.dueDate else { return false }
            return dueDate <= now
        }
        let dueSorted = dueCandidates.sorted { lhs, rhs in
            let lhsDate = lhs.dueDate(in: progress) ?? .distantPast
            let rhsDate = rhs.dueDate(in: progress) ?? .distantPast
            return lhsDate < rhsDate
        }
        append(dueSorted)

        // 2 — difficiles, le plus faible score d'abord
        append(pool
            .filter {
                guard let p = progress[$0.id] else { return false }
                return p.attempts >= 2 && p.bestScore < 85
            }
            .sorted { ($0.bestScore(in: progress)) < ($1.bestScore(in: progress)) })

        // 3 — jamais vues, difficulté croissante puis ordre stable
        append(pool
            .filter { progress[$0.id] == nil }
            .sorted { ($0.difficulty, $0.id) < ($1.difficulty, $1.id) })

        // 4 — complément : maîtrisées les plus anciennes (entretien)
        let mastered = pool.filter { progress[$0.id]?.isCompleted == true }
        let masteredSorted = mastered.sorted { lhs, rhs in
            let lhsDate = lhs.lastPracticed(in: progress) ?? .distantPast
            let rhsDate = rhs.lastPracticed(in: progress) ?? .distantPast
            return lhsDate < rhsDate
        }
        append(masteredSorted)

        // 5 — filet de sécurité : petit catalogue / petits filtres
        if queue.count < size {
            append(pool.shuffled())
        }

        return queue
    }
}

private extension LearningSentence {
    func dueDate(in p: [Int: SessionPlanner.Snapshot]) -> Date? { p[id]?.dueDate }
    func bestScore(in p: [Int: SessionPlanner.Snapshot]) -> Int { p[id]?.bestScore ?? 0 }
    func lastPracticed(in p: [Int: SessionPlanner.Snapshot]) -> Date? { p[id]?.lastPracticedAt }
}
