import os
import AVFoundation
import Speech

/// Sendable bridge between the real-time audio tap and the AsyncStream that
/// feeds `SpeechAnalyzer`. The audio thread calls `receive(_:)`; the analyzer
/// reads from the stream. No allocation on the audio path, no MainActor
/// capture — concurrency-safe under Swift 6 strict.
final class AudioSink: @unchecked Sendable {
    private let continuation: AsyncStream<AnalyzerInput>.Continuation
    private let converter: AudioFormatConverter

    init?(continuation: AsyncStream<AnalyzerInput>.Continuation,
          inputFormat: AVAudioFormat,
          targetFormat: AVAudioFormat) {
        self.continuation = continuation
        guard let converter = AudioFormatConverter(from: inputFormat, to: targetFormat) else {
            return nil
        }
        self.converter = converter
    }

    /// Called on the audio thread.
    nonisolated func receive(_ buffer: AVAudioPCMBuffer) {
        guard let converted = converter.convert(buffer) else { return }
        continuation.yield(AnalyzerInput(buffer: converted))
    }

    /// Called between two recordings.
    nonisolated func reset() { converter.reset() }

    /// Called on stop: drains the analyzer.
    nonisolated func finish() { continuation.finish() }
}
