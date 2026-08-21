import AVFoundation

/// Les appels AVAudioSession sont bloquants : jamais sur le main actor.
actor AudioSessionController {

    func activateForRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,             // traitement d'entrée actif, sortie à volume normal
            options: [.duckOthers, .defaultToSpeaker, .allowBluetoothHFP]
        )
        // Buffer court = latence perçue plus faible sur le VU-mètre.
        try? session.setPreferredIOBufferDuration(0.02)
        try session.setActive(true)
        Log.audio.debug("Session active, route: \(session.currentRoute.inputs.first?.portName ?? "?", privacy: .public)")
    }

    func deactivate() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            Log.audio.error("Désactivation: \(error, privacy: .public)")
        }
    }
}
