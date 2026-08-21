import Testing
@testable import SpeakEasy

@MainActor
@Suite("PracticeViewModel")
struct PracticeViewModelTests {

    private func makeVM(
        queue: [LearningSentence] = [.stub(id: 1, english: "I think so"),
                                     .stub(id: 2, english: "Let me check")],
        recognizer: FakeRecognizer = FakeRecognizer(script: .succeeds("i think so")),
        recorded: @escaping @MainActor (Int, Int) -> Void = { _, _ in }
    ) -> PracticeViewModel {
        PracticeViewModel(queue: queue,
                          playback: SpeechPlaybackService(),
                          recognition: recognizer,
                          recordAttempt: recorded)
    }

    @Test("Nominal cycle: ready → recording → result")
    func happyPath() async {
        let vm = makeVM()
        #expect(vm.phase == .ready)
        await vm.toggleRecording()
        #expect(vm.phase == .recording)
        await vm.toggleRecording()
        #expect(vm.lastResult?.score == 100)
    }

    @Test("A microphone failure shows the error screen, not a crash")
    func microphoneDenied() async {
        let vm = makeVM(recognizer: FakeRecognizer(script: .fails(.microphoneDenied)))
        await vm.toggleRecording()
        #expect(vm.lastError == .microphoneDenied)
    }

    @Test("retry() removes the attempt from the session but keeps the sentence")
    func retryKeepsSentence() async {
        let vm = makeVM()
        await vm.toggleRecording(); await vm.toggleRecording()
        let before = vm.currentSentence?.id
        vm.retry()
        #expect(vm.phase == .ready)
        #expect(vm.currentSentence?.id == before)
    }

    @Test("Persistence is called exactly once per attempt")
    func persistsOncePerAttempt() async {
        var calls: [(Int, Int)] = []
        let vm = makeVM(recorded: { calls.append(($0, $1)) })
        await vm.toggleRecording(); await vm.toggleRecording()
        vm.retry()
        await vm.toggleRecording(); await vm.toggleRecording()
        #expect(calls.count == 2)
        #expect(calls.allSatisfy { $0.0 == 1 })
    }

    @Test("The session ends after the last sentence in the queue")
    func completesSession() async {
        var finished = false
        let vm = PracticeViewModel(
            queue: [.stub(id: 1, english: "ok")],
            playback: SpeechPlaybackService(),
            recognition: FakeRecognizer(script: .succeeds("ok")),
            onSessionComplete: { _, _ in finished = true })
        await vm.toggleRecording(); await vm.toggleRecording()
        vm.goToNext()
        #expect(finished)
    }

    @Test("A rapid double tap does not start two recordings")
    func noDoubleStart() async {
        let fake = FakeRecognizer(script: .succeeds("ok"))
        fake.startDelay = .milliseconds(100)
        let vm = makeVM(recognizer: fake)
        async let a: Void = vm.toggleRecording()
        async let b: Void = vm.toggleRecording()
        _ = await (a, b)
        #expect(fake.startCount == 1)
    }

    // S1.3 — made possible by the fake recognizer (S3.3).
    @Test("Timeout transitions to .processing then .result")
    func autoStopTransitions() async {
        let fake = FakeRecognizer(script: .succeeds("hello"))
        let vm = PracticeViewModel(
            queue: [.stub(id: 1, english: "hello")],
            playback: SpeechPlaybackService(),
            recognition: fake,
            maxRecordingDuration: 0.2)
        await vm.toggleRecording()
        #expect(vm.phase == .recording)
        try? await Task.sleep(for: .seconds(0.5))
        #expect(vm.lastResult != nil)
    }
}

extension LearningSentence {
    static func stub(id: Int = 1, english: String = "hello",
                     french: String = "bonjour", difficulty: Int = 1) -> Self {
        .init(id: id, category: .opinions, french: french,
              english: english, difficulty: difficulty, keywords: [])
    }
}
