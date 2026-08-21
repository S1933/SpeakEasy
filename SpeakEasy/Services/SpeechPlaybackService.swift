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

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, slow: Bool = false) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: localeIdentifier)

        let base = AVSpeechUtteranceDefaultSpeechRate
        let multiplier = slow ? rateMultiplier * 0.65 : rateMultiplier
        utterance.rate = Float(Double(base) * multiplier)
        utterance.postUtteranceDelay = 0.1

        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
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
        Task { @MainActor in
            self.isSpeaking = false
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
        }
    }
}
