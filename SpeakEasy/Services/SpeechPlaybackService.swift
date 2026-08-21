import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class SpeechPlaybackService: NSObject {
    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking = false
    var localeIdentifier: String = "en-US"
    /// 0,5 = très lent (mode « écoute attentive »), 1,0 = débit naturel.
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

    /// Privilégie une voix premium/enhanced si l'utilisateur l'a téléchargée,
    /// sinon retombe sur la voix compacte, puis sur n'importe quel anglais.
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
