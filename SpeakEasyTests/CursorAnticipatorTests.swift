import Testing
@testable import SpeakEasy

@Suite("CursorAnticipator — anticipation, pause decay, rate")
struct CursorAnticipatorTests {

    private let anticipator = CursorAnticipator()

    // MARK: displayCursor

    @Test("Sans hypothèse, le curseur ne devance jamais l'alignement")
    func noHypothesisNoLead() {
        let cursor = anticipator.displayCursor(
            alignedCursor: 3, previousDisplay: 3,
            elapsed: 5.0, rate: 2.2,
            hasHypothesis: false, tokenCount: 100)
        #expect(cursor == 3)
    }

    @Test("Le lead croît avec le silence et plafonne à maxLead")
    func leadGrowsAndCaps() {
        // Points explicites : le stride flottant peut dépasser
        // growthWindow (1.6 s) par arrondi et déclencher la décroissance.
        var previous = 10
        for elapsed in [0.0, 0.3, 0.6, 0.9, 1.2, 1.5] {
            let cursor = anticipator.displayCursor(
                alignedCursor: 10, previousDisplay: previous,
                elapsed: elapsed, rate: 2.5,
                hasHypothesis: true, tokenCount: 100)
            #expect(cursor >= previous)                       // monotone en lecture
            #expect(cursor <= 10 + anticipator.maxLead)       // plafond
            previous = cursor
        }
        // Silence long : le lead a atteint le plafond.
        #expect(previous == 10 + anticipator.maxLead)
    }

    @Test("Pendant la lecture, la position ne recule jamais")
    func neverGoesBackward() {
        let first = anticipator.displayCursor(
            alignedCursor: 20, previousDisplay: 24,
            elapsed: 0.1, rate: 2.0,
            hasHypothesis: true, tokenCount: 100)
        #expect(first == 24)
    }

    @Test("Pause longue : décroissance d'un mot par tick vers l'alignement, sans passer dessous")
    func pausedDecays() {
        var previous = 15
        for _ in 0..<30 {
            previous = anticipator.displayCursor(
                alignedCursor: 10, previousDisplay: previous,
                elapsed: 2.5, rate: 2.2,
                hasHypothesis: true, tokenCount: 100)
        }
        #expect(previous == 10)
    }

    @Test("Le curseur ne dépasse jamais le dernier token")
    func clampedToTokenCount() {
        let cursor = anticipator.displayCursor(
            alignedCursor: 9, previousDisplay: 9,
            elapsed: 1.0, rate: 4.0,
            hasHypothesis: true, tokenCount: 10)
        #expect(cursor == 9)
    }

    @Test("Texte vide → 0")
    func emptyText() {
        let cursor = anticipator.displayCursor(
            alignedCursor: 0, previousDisplay: 0,
            elapsed: 1.0, rate: 2.2,
            hasHypothesis: true, tokenCount: 0)
        #expect(cursor == 0)
    }

    @Test("Le latencyFloor garantit un lead ≥ 1 dès qu'un mot est entendu")
    func floorGivesMinimumLead() {
        let cursor = anticipator.displayCursor(
            alignedCursor: 7, previousDisplay: 7,
            elapsed: 0.0, rate: 2.2,
            hasHypothesis: true, tokenCount: 100)
        #expect(cursor > 7)
    }

    // MARK: rate

    @Test("Moins de 3 points de timing → débit par défaut")
    func defaultRateWithoutEnoughPoints() {
        #expect(CursorAnticipator.rate(from: []) == 2.2)
        #expect(CursorAnticipator.rate(from: [1.0]) == 2.2)
        #expect(CursorAnticipator.rate(from: [1.0, 2.0]) == 2.2)
    }

    @Test("Débit mesuré depuis les timestamps : 4 mots sur 2 s = 1,5 mots/s")
    func measuredRate() {
        let rate = CursorAnticipator.rate(from: [0.5, 1.0, 1.5, 2.5])
        #expect(abs(rate - 1.5) < 0.001)
    }

    @Test("Le débit est borné entre minRate et maxRate")
    func clampedRate() {
        // Lecture ultra-rapide : 9 mots en 1 s.
        let fast = CursorAnticipator.rate(from: Array(stride(from: 0.0, through: 1.0, by: 0.125)))
        #expect(fast == 4.0)
        // Lecture très lente : 3 mots en 10 s.
        let slow = CursorAnticipator.rate(from: [0.0, 5.0, 10.0])
        #expect(slow == 0.8)
    }
}
