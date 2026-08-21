import os
import AVFoundation
import Foundation

/// Écrit le flux du micro dans un fichier temporaire, en parallèle de
/// l'analyse. L'écriture AVAudioFile est asynchrone en interne ; l'appel
/// depuis le thread audio est celui recommandé par Apple.
final class AttemptAudioRecorder: @unchecked Sendable {
    private var file: AVAudioFile?
    private(set) var url: URL?

    func begin(format: AVAudioFormat) {
        let url = URL.temporaryDirectory.appending(path: "attempt-\(UUID().uuidString).caf")
        do {
            file = try AVAudioFile(forWriting: url, settings: format.settings)
            self.url = url
        } catch {
            Log.audio.error("Ouverture fichier: \(error, privacy: .public)")
        }
    }

    /// Appelé depuis le thread audio.
    func write(_ buffer: AVAudioPCMBuffer) {
        guard let file else { return }
        do { try file.write(from: buffer) }
        catch { Log.audio.error("Écriture: \(error, privacy: .public)") }
    }

    /// Ferme le fichier et rend son URL. L'appelant est responsable du nettoyage.
    func finish() -> URL? {
        file = nil
        defer { url = nil }
        return url
    }

    /// Supprime les enregistrements orphelins au démarrage.
    static func purgeTemporary() {
        let fm = FileManager.default
        let items = (try? fm.contentsOfDirectory(at: .temporaryDirectory,
                                                 includingPropertiesForKeys: nil)) ?? []
        for item in items where item.lastPathComponent.hasPrefix("attempt-") {
            try? fm.removeItem(at: item)
        }
    }
}