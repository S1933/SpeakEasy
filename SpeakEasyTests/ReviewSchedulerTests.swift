import Testing
@testable import SpeakEasy

@MainActor
@Suite("ReviewScheduler")
struct ReviewSchedulerTests {

    @Test("A perfect score lengthens the interval")
    func successGrows() {
        let p = SentenceProgress(sentenceID: 1)
        ReviewScheduler.apply(score: 100, to: p)   // 1 j
        ReviewScheduler.apply(score: 100, to: p)   // 4 j
        ReviewScheduler.apply(score: 100, to: p)   // ~11 j
        #expect(p.intervalDays > 4)
        #expect(p.easeFactor > 2.5)
    }

    @Test("A failure resets the interval but not the factor")
    func failureResets() {
        let p = SentenceProgress(sentenceID: 1)
        for _ in 0..<4 { ReviewScheduler.apply(score: 100, to: p) }
        let easeBefore = p.easeFactor
        ReviewScheduler.apply(score: 20, to: p)
        #expect(p.intervalDays == 1)
        #expect(p.repetitions == 0)
        #expect(p.easeFactor < easeBefore)
        #expect(p.easeFactor >= 1.3)      // floor respected
    }

    @Test("The interval is capped at 180 days")
    func capped() {
        let p = SentenceProgress(sentenceID: 1)
        for _ in 0..<40 { ReviewScheduler.apply(score: 100, to: p) }
        #expect(p.intervalDays == 180)
    }
}
