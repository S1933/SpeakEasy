import AVFoundation
import Synchronization

/// Niveau audio partagé entre le thread temps réel (écriture) et l'UI (lecture).
/// Aucune notification : l'UI échantillonne à 30 Hz via TimelineView.
final class AudioLevelMeter: Sendable {
    private struct State {
        var level: Double = 0
        /// 64 dernières valeurs, pour un waveform défilant réel (cf. S5.2).
        var history: [Double] = Array(repeating: 0, count: 64)
        var cursor: Int = 0
    }

    private let state = Mutex(State())

    /// Appelé depuis le thread audio. Lissage exponentiel : attaque rapide,
    /// relâchement lent — comportement d'un VU-mètre physique.
    func ingest(_ buffer: AVAudioPCMBuffer) {
        let raw = SpeechRecognitionService.computeAmplitude(buffer: buffer)
        state.withLock { s in
            let alpha = raw > s.level ? 0.6 : 0.15
            s.level += (raw - s.level) * alpha
            s.history[s.cursor] = s.level
            s.cursor = (s.cursor + 1) % s.history.count
        }
    }

    var level: Double { state.withLock { $0.level } }

    /// Historique remis dans l'ordre chronologique (le plus ancien en premier).
    var waveform: [Double] {
        state.withLock { s in
            Array(s.history[s.cursor...] + s.history[..<s.cursor])
        }
    }

    func reset() {
        state.withLock { $0 = State() }
    }
}
