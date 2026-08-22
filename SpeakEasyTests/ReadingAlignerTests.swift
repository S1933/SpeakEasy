import Testing
@testable import SpeakEasy

@Suite("ReadingAligner — DP, display lock, segments")
struct ReadingAlignerTests {

    // Reference commune : 6 tokens (the cat walked on the mat).
    private func makeAligner() -> ReadingAligner {
        ReadingFixtures.aligner("the cat walked on the mat")
    }

    @Test("Une lecture parfaite ne produit aucune erreur")
    func perfectReading() {
        let snapshot = makeAligner().align(
            ReadingFixtures.heard("the cat walked on the mat"))
        #expect(snapshot.states.allSatisfy { $0 == .correct })
        #expect(snapshot.insertions == 0)
        #expect(snapshot.cursor == 6)
    }

    @Test("Un mot sauté est marqué manquant, pas les suivants")
    func skippedMiddleWord() {
        let snapshot = makeAligner().align(
            ReadingFixtures.heard("the cat on the mat"))
        #expect(snapshot.states[2] == .missed)     // walked sauté
        #expect(snapshot.states[3] == .correct)    // on
    }

    @Test("Un mot répété compte comme insertion, pas comme erreur")
    func repeatedWordIsInsertion() {
        let snapshot = makeAligner().align(
            ReadingFixtures.heard("the cat walked walked on the mat"))
        #expect(snapshot.insertions == 1)
        #expect(snapshot.states.filter { $0 == .correct }.count == 6)
    }

    @Test("Une auto-correction ('the… their') est une insertion, cible correcte")
    func selfCorrection() {
        let aligner = ReadingFixtures.aligner("their cat walked on the mat")
        let snapshot = aligner.align(
            ReadingFixtures.heard("the their cat walked on the mat"))
        #expect(snapshot.insertions == 1)          // "the" de départ
        #expect(snapshot.states.allSatisfy { $0 == .correct })
    }

    @Test("Quasi-correspondance long mot → substituted, jamais missed")
    func nearMissIsSubstituted() {
        let snapshot = makeAligner().align(
            ReadingFixtures.heard("the cat walkd on the mat"))
        if case .substituted(heard: let heard) = snapshot.states[2] {
            #expect(heard == "walkd")
        } else {
            Issue.record("expected .substituted(heard: \"walkd\"), got \(snapshot.states[2])")
        }
    }

    @Test("Erreur volatile devant le curseur est calculée mais pas affichée")
    func provisionalErrorHidden() {
        let snapshot = makeAligner().align(
            [HypToken(normalized: "the", start: 0.4, isFinalized: true),
             HypToken(normalized: "cat", start: 0.8, isFinalized: true),
             HypToken(normalized: "walkd", start: 1.2, isFinalized: false)])
        // calculée comme substitution…
        if case .substituted = snapshot.states[2] {
            // ok
        } else {
            Issue.record("expected substituted, got \(snapshot.states[2])")
        }
        // …mais pas affichée (curseur ne l'a pas dépassée de deux mots)
        #expect(snapshot.displayState(at: 2) == .pending)
    }

    @Test("Erreur finalisée s'affiche immédiatement quand le curseur l'a dépassée")
    func finalizedErrorShown() {
        let snapshot = makeAligner().align(
            ReadingFixtures.heard("the cat walkd on the mat", finalized: true))
        // curseur = 6, index 2 <= 6-2=4 → settled
        if case .substituted = snapshot.displayState(at: 2) {
            // ok
        } else {
            Issue.record("expected substituted shown, got \(snapshot.displayState(at: 2))")
        }
    }

    @Test("Hypothèse vide → tous pending, curseur à 0")
    func emptyHypothesis() {
        let snapshot = makeAligner().align([])
        #expect(snapshot.states.allSatisfy { $0 == .pending })
        #expect(snapshot.cursor == 0)
        #expect(snapshot.insertions == 0)
    }

    @Test("Une ligne entière sautée produit des missed contigus, curseur au-delà")
    func wholeLineSkipped() {
        let text = ReadingText(
            id: 905, kind: .story, title: "two lines", difficulty: 1,
            lines: [
                ReadingLine(id: 0, speaker: nil, text: "the cat walked on the mat"),
                ReadingLine(id: 1, speaker: nil, text: "then the dog ran home"),
            ])
        let aligner = ReadingAligner(reference: ReadingTokenizer.tokenize(text))
        // Seule la phrase 2 est lue.
        let snapshot = aligner.align(
            ReadingFixtures.heard("then the dog ran home"))
        #expect((0..<6).allSatisfy { snapshot.states[$0] == .missed })
        // curseur engagé sur la phrase 1 sautée
        #expect(snapshot.cursor >= 6)
    }
}

@Suite("ReadingAligner — sessions segmentées après interruption")
struct ReadingAlignerSessionTests {

    @Test("Deux segments recollent les états, le second reprend au bon index")
    func twoSegmentSession() {
        let aligner = ReadingFixtures.aligner("the cat walked on the mat")
        var session = ReadingSession()
        // Segment 1 : the cat walked
        session.current.hypothesis = ReadingFixtures.heard("the cat walked")
        // Interruption : on reprend à cursor-2 = 1 (une relecture de deux mots)
        session.openSegment(at: 1)
        session.current.hypothesis = ReadingFixtures.heard("cat walked on the mat")

        let snapshot = aligner.align(session: session)
        #expect(snapshot.states.allSatisfy { $0 == .correct })
        #expect(snapshot.cursor == 6)
    }

    @Test("La relecture de deux mots après reprise n'ajoute pas d'insertion parasite")
    func resumeReReadNoParasiticInsertions() {
        let aligner = ReadingFixtures.aligner("the cat walked on the mat")
        var session = ReadingSession()
        session.current.hypothesis = ReadingFixtures.heard("the cat")
        session.openSegment(at: 0)   // reprise au tout début
        session.current.hypothesis = ReadingFixtures.heard("the cat walked on the mat")
        let snapshot = aligner.align(session: session)
        #expect(snapshot.insertions == 0)
        #expect(snapshot.states.allSatisfy { $0 == .correct })
    }
}

@Suite("ReadingScorer")
struct ReadingScorerTests {

    private let scorer = ReadingScorer()

    @Test("Un snapshot parfait à 6 mots en 12 s → 100 %, 30 wpm")
    func perfectScoring() {
        let snapshot = AlignmentSnapshot(
            states: Array(repeating: .correct, count: 6),
            cursor: 6, committedUpTo: 6, insertions: 0,
            timings: [0: 1.0, 1: 2.4, 2: 3.9, 3: 5.3, 4: 6.7, 5: 8.1])
        let result = scorer.score(snapshot: snapshot, tokenCount: 6, duration: 12)
        #expect(result.accuracy == 100)
        // 6 corrects / 0.2 min = 30 wpm
        #expect(result.wcpm == 30)
        #expect(result.paceBand == .tooSlow)
    }

    @Test("Les tokens pending comptent comme non acquis (missed)")
    func pendingCountAsMissed() {
        let snapshot = AlignmentSnapshot(
            states: [.correct, .correct, .correct, .pending, .pending, .pending],
            cursor: 3, committedUpTo: 3, insertions: 0, timings: [:])
        let result = scorer.score(snapshot: snapshot, tokenCount: 6, duration: 60)
        #expect(result.accuracy == 50)
        #expect(result.missedIndices.contains(3))
    }

    @Test("Une pause >1.2 s entre deux mots devient une hésitation")
    func hesitationDetection() {
        let snapshot = AlignmentSnapshot(
            states: Array(repeating: .correct, count: 4),
            cursor: 4, committedUpTo: 4, insertions: 0,
            timings: [0: 1.0, 1: 2.0, 2: 5.0, 3: 6.0])  // 3 s de pause entre "cat" et "walked"
        let result = scorer.score(snapshot: snapshot, tokenCount: 4, duration: 8)
        #expect(result.hesitationIndices == [2])
    }
}