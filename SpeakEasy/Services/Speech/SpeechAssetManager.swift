import Foundation
import Observation
import os
import Speech

@MainActor @Observable
final class SpeechAssetManager {

    enum State: Equatable {
        case unknown
        case installed
        case downloading(progress: Double)
        case failed(String)
        case unsupported            // locale non prise en charge par l'appareil
    }

    private(set) var state: State = .unknown
    private var progressObservation: NSKeyValueObservation?

    func check(locale: Locale) async {
        guard await SpeechTranscriber.supportedLocales.contains(where: {
            $0.identifier(.bcp47) == locale.identifier(.bcp47)
        }) else {
            state = .unsupported
            return
        }
        let installed = await SpeechTranscriber.installedLocales
        state = installed.contains { $0.identifier(.bcp47) == locale.identifier(.bcp47) }
            ? .installed
            : .unknown
    }

    /// Télécharge en exposant une progression réelle.
    func install(locale: Locale) async {
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        do {
            guard let request = try await AssetInventory
                .assetInstallationRequest(supporting: [transcriber]) else {
                state = .installed
                return
            }

            state = .downloading(progress: 0)
            progressObservation = request.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
                Task { @MainActor in self?.state = .downloading(progress: progress.fractionCompleted) }
            }

            try await request.downloadAndInstall()
            progressObservation = nil

            // Empêche le système de récupérer l'espace en supprimant les assets.
            try? await AssetInventory.reserve(locale: locale)

            state = .installed
            Log.speech.notice("Assets installés pour \(locale.identifier, privacy: .public)")
        } catch {
            progressObservation = nil
            Log.speech.error("Installation assets: \(error, privacy: .public)")
            state = .failed(error.localizedDescription)
        }
    }
}
