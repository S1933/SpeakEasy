import os
import AVFoundation

/// AVAudioSession calls are blocking: they require a dedicated serialized
/// queue (internal AVAudioSession assertion). We isolate it behind an actor
/// for concurrent isolation and `sync` on it for each call.
actor AudioSessionController {

    private let queue = DispatchQueue(label: "com.speakeasy.audioSession", qos: .userInitiated)

    func activateForRecording() throws {
        try queue.sync {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(
                .playAndRecord,
                mode: .spokenAudio,             // input processing active, output at normal volume
                options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP]
            )
            // Short buffer = lower perceived latency on the VU meter.
            try? session.setPreferredIOBufferDuration(0.02)
            try session.setActive(true)
            Log.audio.debug("Session active, route: \(session.currentRoute.inputs.first?.portName ?? "?", privacy: .public)")
        }
    }

    func deactivate() {
        do {
            try queue.sync {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        } catch {
            Log.audio.error("Deactivation: \(error, privacy: .public)")
        }
    }
}
