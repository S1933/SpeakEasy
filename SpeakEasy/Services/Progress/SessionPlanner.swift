import Foundation

/// Builds the queue of sentences for a session from stored progress.
///
/// Priority (most urgent to least):
///   1. Sentences due for review (S4.5 — SM-2 planning)
///   2. Difficult sentences: ≥ 2 attempts and best score < 85
///   3. Never-seen sentences, increasing difficulty
///   4. Random filler among the oldest mastered sentences
struct SessionPlanner: Sendable {

    struct Snapshot: Sendable {
        var attempts: Int
        var bestScore: Int
        var lastPracticedAt: Date?
        var dueDate: Date?          // populated in S4.5
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

        // 1 — due for review, most overdue first
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

        // 2 — difficult, lowest score first
        append(pool
            .filter {
                guard let p = progress[$0.id] else { return false }
                return p.attempts >= ProgressRules.difficultMinimumAttempts
                    && p.bestScore < ProgressRules.masteryScore
            }
            .sorted { ($0.bestScore(in: progress)) < ($1.bestScore(in: progress)) })

        // 3 — never seen, increasing difficulty then stable order
        append(pool
            .filter { progress[$0.id] == nil }
            .sorted { ($0.difficulty, $0.id) < ($1.difficulty, $1.id) })

        // 4 — filler: oldest mastered (maintenance)
        let mastered = pool.filter { progress[$0.id]?.isCompleted == true }
        let masteredSorted = mastered.sorted { lhs, rhs in
            let lhsDate = lhs.lastPracticed(in: progress) ?? .distantPast
            let rhsDate = rhs.lastPracticed(in: progress) ?? .distantPast
            return lhsDate < rhsDate
        }
        append(masteredSorted)

        // 5 — safety net: small catalog / tight filters
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
