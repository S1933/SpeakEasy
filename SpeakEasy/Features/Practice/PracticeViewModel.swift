import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class PracticeViewModel {
    enum Phase: Sendable, Equatable {
        case ready
        case recording
        case processing
        case result(AttemptResult)
        case error(RecordingError)
    }

    /// Pourquoi l'enregistrement s'est terminé (S1.3)
    enum StopReason {
        case user
        case timeout
        case interruption
    }

    private(set) var phase: Phase = .ready
    private let queue: [LearningSentence]
    private(set) var queueIndex: Int = 0
    private(set) var sessionAttempts: [(LearningSentence, AttemptResult)] = []

    private let playback: SpeechPlaybackService
    let recognition: SpeechRecognitionService
    private let scoring: SentenceScoringService
    private let feedback: FeedbackService
    private let recordAttempt: @MainActor (Int, Int) -> Void
    let onSessionComplete: ([AttemptResult], [LearningSentence]) -> Void
    private var timeoutTask: Task<Void, Never>?

    let maxRecordingDuration: TimeInterval

    var currentSentence: LearningSentence? {
        queue.indices.contains(queueIndex) ? queue[queueIndex] : nil
    }

    var elapsed: TimeInterval { recognition.elapsed }
    var meter: AudioLevelMeter { recognition.meter }

    /// Un seul compteur, cohérent sur TOUS les écrans (cf. S1.7).
    var progressText: String {
        "\(min(queueIndex + 1, queue.count)) of \(queue.count)"
    }

    var isLastInSession: Bool { queueIndex >= queue.count - 1 }
    var sessionComplete: Bool { queueIndex >= queue.count }

    var nextButtonTitle: String {
        sessionComplete ? "See summary" : "Next sentence"
    }

    init(
        queue: [LearningSentence],
        playback: SpeechPlaybackService,
        recognition: SpeechRecognitionService = SpeechRecognitionService(),
        scoring: SentenceScoringService = SentenceScoringService(),
        feedback: FeedbackService = FeedbackService(),
        recordAttempt: @escaping @MainActor (Int, Int) -> Void = { _, _ in },
        maxRecordingDuration: TimeInterval = 15,
        onSessionComplete: @escaping ([AttemptResult], [LearningSentence]) -> Void = { _, _ in }
    ) {
        self.queue = queue
        self.playback = playback
        self.recognition = recognition
        self.scoring = scoring
        self.feedback = feedback
        self.recordAttempt = recordAttempt
        self.maxRecordingDuration = maxRecordingDuration
        self.onSessionComplete = onSessionComplete
    }

    func speakCurrent() {
        guard let sentence = currentSentence else { return }
        playback.speak(sentence.english)
    }

    func stopPlayback() {
        playback.stop()
    }

    func toggleRecording() async {
        switch phase {
        case .ready, .error:
            await beginRecording()
        case .recording:
            await finishRecording(reason: .user)
        case .processing, .result:
            break
        }
    }

    func retry() {
        guard case .result = phase else { return }
        sessionAttempts.removeLast()
        // Pas de rollback : `attempts` doit refléter l'effort réel.
        // Mais `bestScore` est un max, donc un retry raté ne dégrade jamais l'acquis.
        phase = .ready
    }

    func goToNext() {
        guard case .result = phase else { return }
        playback.stop()
        queueIndex += 1
        if sessionComplete {
            finalizeSession()
            return
        }
        phase = .ready
    }

    func dismissError() {
        phase = .ready
    }

    var lastResult: AttemptResult? {
        if case .result(let r) = phase { return r }
        return nil
    }

    var lastError: RecordingError? {
        if case .error(let e) = phase { return e }
        return nil
    }

    func feedback(for result: AttemptResult) -> String {
        feedback.feedback(for: result)
    }

    private func beginRecording() async {
        playback.stop()
        phase = .recording
        Haptics.impact(.light)
        do {
            try await recognition.startRecording()
            timeoutTask = Task { [weak self, maxRecordingDuration] in
                try? await Task.sleep(for: .seconds(maxRecordingDuration))
                guard let self, !Task.isCancelled, self.phase == .recording else { return }
                Log.speech.notice("Auto-stop après \(maxRecordingDuration, privacy: .public)s")
                await self.finishRecording(reason: .timeout)
            }
        } catch let error as RecordingError {
            Haptics.notify(.warning)
            phase = .error(error)
        } catch {
            Haptics.notify(.error)
            phase = .error(.framework(error.localizedDescription))
        }
    }

    private func finishRecording(reason: StopReason = .user) async {
        timeoutTask?.cancel(); timeoutTask = nil
        guard phase == .recording else { return }   // idempotent
        phase = .processing
        do {
            let transcript = try await recognition.stopRecording()
            guard let sentence = currentSentence else {
                phase = .error(.framework("sentence missing"))
                return
            }
            let result = scoring.score(expected: sentence.english, transcript: transcript)
            sessionAttempts.append((sentence, result))
            recordAttempt(sentence.id, result.score)
            if result.score >= 85 {
                Haptics.notify(.success)
            } else if result.score >= 50 {
                Haptics.impact(.medium)
            } else {
                Haptics.impact(.heavy)
            }
            phase = .result(result)
        } catch let error as RecordingError {
            Haptics.notify(.warning)
            phase = .error(error)
        } catch {
            Haptics.notify(.error)
            phase = .error(.framework(error.localizedDescription))
        }
    }

    func cancelSession() async {
        timeoutTask?.cancel(); timeoutTask = nil
        playback.stop()
        await recognition.cancel()
    }

    private func finalizeSession() {
        let attempts = sessionAttempts.map(\.1)
        let sentences = sessionAttempts.map(\.0)
        sessionAttempts.removeAll()
        onSessionComplete(attempts, sentences)
    }
}
