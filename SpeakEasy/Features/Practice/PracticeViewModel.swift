import Foundation
import Observation
import os
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
    /// Meilleure tentative par phrase (id) pour la session — sert de score de
    /// finalisation SM-2 quand on passe à la phrase suivante (#13).
    private var sessionBest: [Int: Int] = [:]

    private let playback: SpeechPlaybackService
    let recognition: any SpeechRecognizing
    private let scoring: SentenceScoringService
    private let feedback: FeedbackService
    private let recordAttempt: @MainActor (Int, Int) -> Void
    private let finalizeReview: @MainActor (Int, Int) -> Void
    let onSessionComplete: ([AttemptResult], [LearningSentence]) -> Void
    private var timeoutTask: Task<Void, Never>?
    private var interruptionMonitor: AudioInterruptionMonitor?
    private var isTransitioning = false

    let maxRecordingDuration: TimeInterval
    let mode: PracticeMode

    /// L'utilisateur a-t-il révélé la réponse de la phrase courante ? (S4.1)
    private(set) var isAnswerRevealed = false

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
        recognition: any SpeechRecognizing = SpeechRecognitionService(),
        scoring: SentenceScoringService = SentenceScoringService(),
        feedback: FeedbackService = FeedbackService(),
        recordAttempt: @escaping @MainActor (Int, Int) -> Void = { _, _ in },
        finalizeReview: @escaping @MainActor (Int, Int) -> Void = { _, _ in },
        maxRecordingDuration: TimeInterval = 15,
        mode: PracticeMode = .repeatAfter,
        onSessionComplete: @escaping ([AttemptResult], [LearningSentence]) -> Void = { _, _ in }
    ) {
        self.queue = queue
        self.playback = playback
        self.recognition = recognition
        self.scoring = scoring
        self.feedback = feedback
        self.recordAttempt = recordAttempt
        self.finalizeReview = finalizeReview
        self.maxRecordingDuration = maxRecordingDuration
        self.mode = mode
        self.onSessionComplete = onSessionComplete
    }

    func speakCurrent() {
        guard let sentence = currentSentence else { return }
        playback.speak(sentence.english)
    }

    func stopPlayback() {
        playback.stop()
    }

    func revealAnswer() {
        isAnswerRevealed = true
    }

    func toggleRecording() async {
        guard !isTransitioning else { return }
        isTransitioning = true
        defer { isTransitioning = false }
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
        // SM-2 une SEULE fois par phrase, au passage à la suivante (#13).
        if let id = currentSentence?.id, let best = sessionBest[id] {
            finalizeReview(id, best)
            sessionBest[id] = nil
        }
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

    func feedback(for result: AttemptResult) -> FeedbackService.Feedback {
        feedback.feedback(for: result)
    }

    private func beginRecording() async {
        playback.stop()
        isAnswerRevealed = false
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
            var result = scoring.score(sentence: sentence, transcript: transcript, mode: mode)
            result = result.withRevealed(!mode.showsEnglishBeforeRecording && isAnswerRevealed)
            result = result.withRecordingURL(recognition.recordingURL)
            sessionAttempts.append((sentence, result))
            recordAttempt(sentence.id, result.effectiveScore)
            sessionBest[sentence.id] = max(sessionBest[sentence.id] ?? 0, result.effectiveScore)
            if result.score >= ProgressRules.masteryScore {
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

    /// À appeler depuis `onAppear` — abonne le VM aux interruptions audio.
    func onAppear() {
        interruptionMonitor = AudioInterruptionMonitor { [weak self] event in
            guard let self else { return }
            switch event {
            case .interrupted, .routeLost:
                guard self.phase == .recording else { return }
                self.timeoutTask?.cancel()
                Task { await self.recognition.cancel() }
                Haptics.notify(.warning)
                self.phase = .error(.audioInterruption)   // le case mort devient vivant
            case .resumable:
                break   // on ne relance pas automatiquement : l'utilisateur décide
            }
        }
    }

    /// Passe en arrière-plan pendant l'enregistrement → on coupe proprement.
    func handleBackgrounding() {
        guard phase == .recording else { return }
        timeoutTask?.cancel()
        Task { await recognition.cancel() }
        Haptics.notify(.warning)
        phase = .error(.audioInterruption)
    }

    private func finalizeSession() {
        let attempts = sessionAttempts.map(\.1)
        let sentences = sessionAttempts.map(\.0)
        sessionAttempts.removeAll()
        onSessionComplete(attempts, sentences)
        AttemptAudioRecorder.purgeTemporary()
    }
}
