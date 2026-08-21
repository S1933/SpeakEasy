import os
import AVFoundation

/// Converts microphone buffers to the format expected by SpeechAnalyzer.
/// A single instance reused on every callback: no allocation on the
/// real-time audio thread.
///
/// Safety (Swift 6): accessed exclusively from two non-overlapping points —
/// construction / `reset()` on the main actor, `convert(_:)` on the audio
/// thread only.
final class AudioFormatConverter: @unchecked Sendable {
    nonisolated(unsafe) private let converter: AVAudioConverter
    nonisolated(unsafe) private let outputFormat: AVAudioFormat
    nonisolated(unsafe) private let ratio: Double

    /// Output buffer reused — avoids one allocation per callback.
    nonisolated(unsafe) private var scratch: AVAudioPCMBuffer

    nonisolated init?(from input: AVAudioFormat, to output: AVAudioFormat, maxInputFrames: AVAudioFrameCount = 8192) {
        guard let converter = AVAudioConverter(from: input, to: output) else { return nil }
        self.ratio = output.sampleRate / input.sampleRate
        let capacity = AVAudioFrameCount(Double(maxInputFrames) * ratio) + 64
        guard let scratch = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else { return nil }

        converter.primeMethod = .none        // no priming latency
        self.converter = converter
        self.outputFormat = output
        self.scratch = scratch
    }

    /// - Returns: a buffer **owned by the converter**. Consume it
    ///   immediately (here: yield into the AsyncStream, which copies it
    ///   via AnalyzerInput). Do not retain a reference.
    nonisolated func convert(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        let needed = AVAudioFrameCount(Double(input.frameLength) * ratio) + 64
        if scratch.frameCapacity < needed {
            guard let bigger = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: needed) else { return nil }
            scratch = bigger
        }
        scratch.frameLength = 0

        var supplied = false
        var error: NSError?
        let status = converter.convert(to: scratch, error: &error) { _, outStatus in
            if supplied {
                outStatus.pointee = .noDataNow   // the converter stays reusable
                return nil
            }
            supplied = true
            outStatus.pointee = .haveData
            return input
        }

        switch status {
        case .haveData, .inputRanDry:
            return scratch.frameLength > 0 ? scratch : nil
        case .endOfStream:
            return nil
        case .error:
            if let error {
                Log.audio.error("Conversion failed: \(error.localizedDescription, privacy: .public)")
            }
            return nil
        @unknown default:
            return nil
        }
    }

    /// Call between two recordings to start from a clean state.
    nonisolated func reset() { converter.reset() }
}
