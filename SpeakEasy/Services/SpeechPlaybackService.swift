import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class SpeechPlaybackService: NSObject {
    private let synthesizer = AVSpeechSynthesizer()

    var isSpeaking: Bool = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        stop()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
            ?? AVSpeechSynthesisVoice(language: "en")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
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
