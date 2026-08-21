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

        let pool = repository.all.filter {
            categories.map { set in set.contains($0.category) } ?? true
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
        append(pool
            .filter { (progress[$0.id]?.dueDate).map { $0 <= now } ?? false }
            .sorted { ($0.dueDate(in: progress) ?? .distantPast)
                    < ($1.dueDate(in: progress) ?? .distantPast) })

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
        append(pool
            .filter { progress[$0.id]?.isCompleted == true }
            .sorted { ($0.lastPracticed(in: progress) ?? .distantPast)
                    < ($1.lastPracticed(in: progress) ?? .distantPast) })

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
