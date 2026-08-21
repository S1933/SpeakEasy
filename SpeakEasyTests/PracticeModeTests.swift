import Testing
@testable import SpeakEasy

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
        #expect(PracticeMode.recall.scoringProfile == .balanced)
    }
}
