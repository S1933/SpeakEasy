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

    private(set) var phase: Phase = .ready
    private(set) var sentenceIndex: Int = 0
    private(set) var sessionAttempts: [(LearningSentence, AttemptResult)] = []

    private let repository: SentenceRepository
    private let playback: SpeechPlaybackService
    let recognition: SpeechRecognitionService
    private let scoring: SentenceScoringService
    private let feedback: FeedbackService
    let sessionSize: Int
    let onSessionComplete: ([AttemptResult], [LearningSentence]) -> Void

    var elapsed: TimeInterval { recognition.elapsed }
    var amplitude: Double { recognition.amplitude }

    init(
        repository: SentenceRepository = SentenceRepository(),
        playback: SpeechPlaybackService,
        recognition: SpeechRecognitionService = SpeechRecognitionService(),
        scoring: SentenceScoringService = SentenceScoringService(),
        feedback: FeedbackService = FeedbackService(),
        sessionSize: Int,
        onSessionComplete: @escaping ([AttemptResult], [LearningSentence]) -> Void = { _, _ in }
    ) {
        self.repository = repository
        self.playback = playback
        self.recognition = recognition
        self.scoring = scoring
        self.feedback = feedback
        self.sessionSize = sessionSize
        self.onSessionComplete = onSessionComplete
    }

    var currentSentence: LearningSentence? {
        repository.sentence(at: sentenceIndex)
    }

    var totalCount: Int { repository.count }

    var progressText: String {
        "\(sentenceIndex + 1) of \(totalCount)"
    }

    var sessionProgressText: String {
        let current = sessionAttempts.count + 1
        return "\(min(current, sessionSize)) of \(sessionSize)"
    }

    var isLastInCatalog: Bool {
        sentenceIndex >= totalCount - 1
    }

    var isLastInSession: Bool {
        sessionAttempts.count >= sessionSize - 1
    }

    var sessionComplete: Bool {
        sessionAttempts.count >= sessionSize
    }

    var nextButtonTitle: String {
        sessionComplete ? "See summary" : "Next sentence"
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
            await finishRecording()
        case .processing, .result:
            break
        }
    }

    func retry() {
        guard case .result = phase else { return }
        sessionAttempts.removeLast()
        phase = .ready
    }

    func goToNext() {
        guard case .result = phase else { return }
        playback.stop()

        if sessionComplete {
            finalizeSession()
            return
        }

        if !isLastInCatalog {
            sentenceIndex += 1
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
        } catch let error as RecordingError {
            Haptics.notify(.warning)
            phase = .error(error)
        } catch {
            Haptics.notify(.error)
            phase = .error(.framework(error.localizedDescription))
        }
    }

    private func finishRecording() async {
        phase = .processing
        do {
            let transcript = try await recognition.stopRecording()
            guard let sentence = currentSentence else {
                phase = .error(.framework("sentence missing"))
                return
            }
            let result = scoring.score(expected: sentence.english, transcript: transcript)
            sessionAttempts.append((sentence, result))
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

    private func finalizeSession() {
        let attempts = sessionAttempts.map(\.1)
        let sentences = sessionAttempts.map(\.0)
        sessionAttempts.removeAll()
        onSessionComplete(attempts, sentences)
    }
}