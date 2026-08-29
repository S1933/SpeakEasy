import Testing
@testable import SpeakEasy

@MainActor
@Suite("PracticeMode")
struct PracticeModeTests {

    @Test("Translate does not reveal the answer")
    func translateHidesAnswer() {
        #expect(PracticeMode.translate.showsEnglishBeforeRecording == false)
    }

    @Test("Repeat shows English before recording")
    func repeatShowsEnglish() {
        #expect(PracticeMode.repeatAfter.showsEnglishBeforeRecording == true)
    }

    @Test("Scoring profiles are consistent with the mode")
    func profiles() {
        #expect(PracticeMode.repeatAfter.scoringProfile == .strict)
        #expect(PracticeMode.translate.scoringProfile == .lenient)
    }

    @Test("Only two modes remain")
    func modeCount() {
        #expect(PracticeMode.allCases.count == 2)
        #expect(PracticeMode.allCases.contains(.repeatAfter))
        #expect(PracticeMode.allCases.contains(.translate))
    }

    @Test("Repeat shows the English only, never the French")
    func repeatIsEnglishOnly() {
        #expect(PracticeMode.repeatAfter.showsFrenchPrompt == false)
        #expect(PracticeMode.translate.showsFrenchPrompt == true)
    }

    @Test("Repeat has nothing to reveal")
    func repeatHasNoReveal() {
        #expect(PracticeMode.repeatAfter.allowsReveal == false)
        #expect(PracticeMode.translate.allowsReveal == true)
    }

    @Test("A retired persisted mode falls back to Repeat")
    func resolvesLegacyRawValue() {
        #expect(PracticeMode.resolve("recall") == .repeatAfter)
        #expect(PracticeMode.resolve(nil) == .repeatAfter)
        #expect(PracticeMode.resolve("translate") == .translate)
    }
}
