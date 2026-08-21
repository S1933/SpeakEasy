import os
import AVFoundation

/// Les appels AVAudioSession sont bloquants : ils exigent une queue sérialisée
/// dédiée (assertion interne AVAudioSession). On l'isole derrière un actor pour
/// l'isolation concurrente et on `sync` dessus pour chaque appel.
actor AudioSessionController {

    private let queue = DispatchQueue(label: "com.speakeasy.audioSession", qos: .userInitiated)

    func activateForRecording() throws {
        try queue.sync {
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
    }

    func deactivate() {
        do {
            try queue.sync {
                try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            }
        } catch {
            Log.audio.error("Désactivation: \(error, privacy: .public)")
        }
    }
}
