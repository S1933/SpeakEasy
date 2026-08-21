import os
import AVFoundation
import Foundation

/// Writes the microphone stream to a temporary file, in parallel with
/// analysis. AVAudioFile writes are asynchronous internally; calling it
/// from the audio thread is the one recommended by Apple.
final class AttemptAudioRecorder: @unchecked Sendable {
    nonisolated(unsafe) private var file: AVAudioFile?
    nonisolated(unsafe) private(set) var url: URL?

    nonisolated func begin(format: AVAudioFormat) {
        let url = URL.temporaryDirectory.appending(path: "attempt-\(UUID().uuidString).caf")
        do {
            file = try AVAudioFile(forWriting: url, settings: format.settings)
            self.url = url
        } catch {
            Log.audio.error("Opening file: \(error, privacy: .public)")
        }
    }

    /// Called from the audio thread.
    nonisolated func write(_ buffer: AVAudioPCMBuffer) {
        guard let file else { return }
        do { try file.write(from: buffer) }
        catch { Log.audio.error("Write: \(error, privacy: .public)") }
    }

    /// Closes the file and returns its URL. The caller is responsible for cleanup.
    nonisolated func finish() -> URL? {
        file = nil
        defer { url = nil }
        return url
    }

    /// Removes orphan recordings on startup.
    static func purgeTemporary() {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: .temporaryDirectory,
                                                 includingPropertiesForKeys: nil)) ?? []
        for item in items where item.lastPathComponent.hasPrefix("attempt-") {
            try? fm.removeItem(at: item)
        }
    }
}