import AVFoundation
import Foundation

final class AudioSessionController {
    func activateForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.duckOthers, .defaultToSpeaker]
        )
        try session.setActive(true, options: [])
    }

    func deactivate() {
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
