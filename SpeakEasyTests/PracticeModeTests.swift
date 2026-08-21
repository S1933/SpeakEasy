import Testing
@testable import SpeakEasy

@Suite("PracticeMode")
struct PracticeModeTests {

    @Test("Translate ne divulgue pas la réponse")
    func translateHidesAnswer() {
        #expect(PracticeMode.translate.showsEnglishBeforeRecording == false)
    }

    @Test("Repeat affiche l'anglais avant l'enregistrement")
    func repeatShowsEnglish() {
        #expect(PracticeMode.repeatAfter.showsEnglishBeforeRecording == true)
    }

    @Test("Les profils de scoring sont cohérents avec le mode")
    func profiles() {
        #expect(PracticeMode.repeatAfter.scoringProfile == .strict)
        #expect(PracticeMode.translate.scoringProfile == .lenient)
        #expect(PracticeMode.recall.scoringProfile == .balanced)
    }
}
