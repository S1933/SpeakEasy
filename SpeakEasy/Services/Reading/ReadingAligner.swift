import Foundation

/// Un mot entendu, issu du transcripteur.
struct HypToken: Sendable, Equatable {
    let normalized: String
    let start: TimeInterval?     // début audio, si disponible
    let isFinalized: Bool        // false = hypothèse volatile, encore révisable
}

enum ReadingTokenState: Sendable, Equatable {
    case pending                       // pas encore atteint
    case correct
    case substituted(heard: String)
    case missed                        // sauté
}

struct AlignmentSnapshot: Sendable, Equatable {
    /// Un état par token de référence.
    var states: [ReadingTokenState]
    /// Prochain token attendu — le curseur de lecture.
    var cursor: Int
    /// Dernier index dont l'état est définitif (adossé à du finalisé).
    var committedUpTo: Int
    /// Mots prononcés en trop (bafouillages, répétitions).
    var insertions: Int
    /// Instant de début associé à chaque token lu, pour le scoring.
    var timings: [Int: TimeInterval]
}

struct ReadingAligner: Sendable {

    let reference: [ReadingToken]

    // Coûts. Une quasi-correspondance coûte peu : « walked » pour « walks »
    // est une erreur de lecture mineure, pas un mot sauté.
    private let costSubstitute = 1.0
    private let costNearMiss   = 0.35
    private let costDelete     = 1.0   // mot de référence non prononcé
    private let costInsert     = 0.7   // mot prononcé en trop

    private enum Move { case diagonal, up, left, none }

    func align(_ hypothesis: [HypToken]) -> AlignmentSnapshot {
        let n = reference.count
        let m = hypothesis.count

        guard n > 0 else {
            return AlignmentSnapshot(states: [], cursor: 0, committedUpTo: 0,
                                     insertions: m, timings: [:])
        }

        var cost = Array(repeating: Array(repeating: 0.0, count: m + 1), count: n + 1)
        var move = Array(repeating: Array(repeating: Move.none, count: m + 1), count: n + 1)

        for i in 1...n { cost[i][0] = Double(i) * costDelete; move[i][0] = .up }
        if m > 0 {
            for j in 1...m { cost[0][j] = Double(j) * costInsert; move[0][j] = .left }
        }

        for i in 1...n where m > 0 {
            for j in 1...m {
                let sub = cost[i-1][j-1] + substitutionCost(reference[i-1], hypothesis[j-1])
                let del = cost[i-1][j]   + costDelete
                let ins = cost[i][j-1]   + costInsert

                if sub <= del && sub <= ins      { cost[i][j] = sub; move[i][j] = .diagonal }
                else if del <= ins               { cost[i][j] = del; move[i][j] = .up }
                else                             { cost[i][j] = ins; move[i][j] = .left }
            }
        }

        return backtrace(move: move, hypothesis: hypothesis)
    }

    private func substitutionCost(_ ref: ReadingToken, _ hyp: HypToken) -> Double {
        if ref.normalized == hyp.normalized { return 0 }
        if isNearMiss(ref.normalized, hyp.normalized) { return costNearMiss }
        return costSubstitute
    }

    /// Distance de Levenshtein normalisée. Le seuil 0.7 reprend l'esprit de
    /// `nearMissRatio` dans ScoringProfile, pour rester cohérent avec le mode Repeat.
    private func isNearMiss(_ a: String, _ b: String) -> Bool {
        let maxLen = max(a.count, b.count)
        guard maxLen >= 4 else { return false }   // trop court : « in » vs « on » est une vraie erreur
        // Cheap reject: the maximum Levenshtein distance between two strings
        // is bounded by the absolute difference in length. If that lower
        // bound already exceeds the threshold (1.0 - 0.7 = 0.3 of `maxLen`),
        // no amount of character work can rescue it. Skipping the O(a·b) DP
        // here is the hot path at 10 Hz × n·m cells.
        let minLen = min(a.count, b.count)
        let maxPossibleRatio = 1.0 - Double(maxLen - minLen) / Double(maxLen)
        guard maxPossibleRatio >= 0.7 else { return false }
        let distance = levenshtein(Array(a), Array(b))
        return 1.0 - Double(distance) / Double(maxLen) >= 0.7
    }

    private func levenshtein(_ a: [Character], _ b: [Character]) -> Int {
        var d = Array(0...b.count)
        for (i, ca) in a.enumerated() {
            var prev = d[0]
            d[0] = i + 1
            for (j, cb) in b.enumerated() {
                let cur = d[j + 1]
                d[j + 1] = ca == cb ? prev : min(d[j] + 1, d[j + 1] + 1, prev + 1)
                prev = cur
            }
        }
        return d[b.count]
    }
}

// MARK: - Backtrace

extension ReadingAligner {

    private func backtrace(move: [[Move]], hypothesis: [HypToken]) -> AlignmentSnapshot {
        var states = Array(repeating: ReadingTokenState.pending, count: reference.count)
        var timings: [Int: TimeInterval] = [:]
        var insertions = 0
        var lastConsumedRef = -1        // plus grand index de référence touché
        var lastFinalizedRef = -1       // idem, mais adossé à une hypothèse finalisée

        var i = reference.count
        var j = hypothesis.count

        while i > 0 || j > 0 {
            switch move[i][j] {
            case .diagonal:
                let ref = reference[i-1], hyp = hypothesis[j-1]
                states[i-1] = ref.normalized == hyp.normalized
                    ? .correct
                    : .substituted(heard: hyp.normalized)
                if let start = hyp.start { timings[i-1] = start }
                lastConsumedRef = max(lastConsumedRef, i-1)
                if hyp.isFinalized { lastFinalizedRef = max(lastFinalizedRef, i-1) }
                i -= 1; j -= 1

            case .up:
                // Token de référence non prononcé. On ne le déclare sauté que s'il
                // est DERRIÈRE le curseur : devant, le lecteur ne l'a pas encore atteint.
                states[i-1] = .missed
                i -= 1

            case .left:
                insertions += 1
                j -= 1

            case .none:
                i = 0; j = 0
            }
        }

        // Tout ce qui suit le dernier token consommé n'a pas encore été lu.
        if lastConsumedRef + 1 < states.count {
            for k in (lastConsumedRef + 1)..<states.count { states[k] = .pending }
        }

        return AlignmentSnapshot(
            states: states,
            cursor: lastConsumedRef + 1,
            committedUpTo: lastFinalizedRef + 1,
            insertions: insertions,
            timings: timings
        )
    }
}

// MARK: - Affichage

extension AlignmentSnapshot {
    /// État à AFFICHER, plus conservateur que l'état calculé.
    /// - une erreur ne s'affiche que si elle est finalisée, ou si le curseur
    ///   l'a dépassée d'au moins deux mots ;
    /// - sinon on montre `pending`, c'est-à-dire rien de spécial.
    func displayState(at index: Int) -> ReadingTokenState {
        let state = states[index]
        switch state {
        case .pending, .correct:
            return state
        case .missed, .substituted:
            let isSettled = index < committedUpTo || index <= cursor - 2
            return isSettled ? state : .pending
        }
    }
}

// MARK: - Alignement segmenté (reprise après interruption)

extension ReadingAligner {

    /// Aligne une session entière. Chaque segment est aligné contre la portion
    /// de texte qui lui correspond, puis les résultats sont recollés.
    func align(session: ReadingSession) -> AlignmentSnapshot {
        var states = Array(repeating: ReadingTokenState.pending, count: reference.count)
        var timings: [Int: TimeInterval] = [:]
        var insertions = 0
        var cursor = 0
        var committed = 0
        var elapsedBefore: TimeInterval = 0

        for segment in session.segments {
            let start = segment.referenceStart
            guard start < reference.count else { break }

            let sub = ReadingAligner(reference: Array(reference[start...]))
                .align(segment.hypothesis)

            // Un segment ultérieur peut réécrire les états d'un précédent :
            // c'est voulu, le lecteur relit quelques mots après une interruption.
            for (offset, state) in sub.states.enumerated() where state != .pending {
                states[start + offset] = state
            }
            for (offset, time) in sub.timings {
                timings[start + offset] = elapsedBefore + time
            }

            insertions += sub.insertions
            cursor    = max(cursor,    start + sub.cursor)
            committed = max(committed, start + sub.committedUpTo)
            elapsedBefore += segment.activeDuration
        }

        return AlignmentSnapshot(states: states, cursor: cursor,
                                 committedUpTo: committed,
                                 insertions: insertions, timings: timings)
    }
}