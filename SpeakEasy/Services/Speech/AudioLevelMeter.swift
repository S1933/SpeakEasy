import AVFoundation
import Synchronization

/// Shared audio level between the real-time thread (write) and the UI (read).
/// No notifications: the UI samples at 30 Hz via TimelineView.
final class AudioLevelMeter: Sendable {
    private struct State {
        var level: Double = 0
        /// Last 64 values, for a real scrolling waveform (see S5.2).
        var history: [Double] = Array(repeating: 0, count: 64)
        var cursor: Int = 0
    }

    private let state = Mutex(State())

    /// Called from the audio thread. Exponential smoothing: fast attack,
    /// slow release — the behavior of a physical VU meter.
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

    /// History returned in chronological order (oldest first).
    var waveform: [Double] {
        state.withLock { s in
            Array(s.history[s.cursor...] + s.history[..<s.cursor])
        }
    }

    func reset() {
        state.withLock { $0 = State() }
    }
}
