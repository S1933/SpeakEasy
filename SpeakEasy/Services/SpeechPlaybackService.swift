import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class SpeechPlaybackService: NSObject {
    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking = false
    var localeIdentifier: String = "en-US"
    /// 0.5 = very slow ("careful listening" mode), 1.0 = natural pace.
    var rateMultiplier: Double = 1.0

    /// Resumes the caller of `speakAwaitingCompletion(_:)` when the
    /// utterance ends (delegate) or is cut short (`stop()`).
    private var speakContinuation: CheckedContinuation<Void, Never>?

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, slow: Bool = false) {
        stop()
        isSpeaking = true
        synthesizer.speak(Self.utterance(text, localeIdentifier: localeIdentifier,
                                         rateMultiplier: rateMultiplier, slow: slow))
    }

    /// Speaks and suspends until the utterance finishes or is cancelled.
    /// Used by the reading dialogue mode, which must not resume the
    /// transcription tap while the synthesizer is still talking.
    func speakAwaitingCompletion(_ text: String, slow: Bool = false) async {
        stop()
        isSpeaking = true
        let utterance = Self.utterance(text, localeIdentifier: localeIdentifier,
                                       rateMultiplier: rateMultiplier, slow: slow)
        await withCheckedContinuation { continuation in
            speakContinuation = continuation
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            // Triggers didCancel → the delegate resumes the continuation.
            synthesizer.stopSpeaking(at: .immediate)
        } else {
            speakContinuation?.resume()
            speakContinuation = nil
            isSpeaking = false
        }
    }

    private func finishSpeaking() {
        isSpeaking = false
        speakContinuation?.resume()
        speakContinuation = nil
    }

    private static func utterance(_ text: String, localeIdentifier: String,
                                  rateMultiplier: Double, slow: Bool) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = bestVoice(for: localeIdentifier)
        let base = AVSpeechUtteranceDefaultSpeechRate
        let multiplier = slow ? rateMultiplier * 0.65 : rateMultiplier
        utterance.rate = Float(Double(base) * multiplier)
        utterance.postUtteranceDelay = 0.1
        return utterance
    }

    /// Prefers a premium/enhanced voice if the user has downloaded it,
    /// otherwise falls back to the compact voice, then to any English.
    private static func bestVoice(for identifier: String) -> AVSpeechSynthesisVoice? {
        let candidates = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == identifier }

        let ranked = candidates.sorted { lhs, rhs in
            rank(lhs.quality) > rank(rhs.quality)
        }
        return ranked.first
            ?? AVSpeechSynthesisVoice(language: identifier)
            ?? AVSpeechSynthesisVoice(language: "en-US")
    }

    private static func rank(_ q: AVSpeechSynthesisVoiceQuality) -> Int {
        switch q {
        case .premium: 3
        case .enhanced: 2
        default: 1
        }
    }
}

extension SpeechPlaybackService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finishSpeaking() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.finishSpeaking() }
    }
}
