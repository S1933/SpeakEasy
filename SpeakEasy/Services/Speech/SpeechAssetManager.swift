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
        case unsupported            // locale not supported by the device
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

    /// Downloads while exposing real progress.
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

            // Prevent the system from reclaiming space by deleting the assets.
            try? await AssetInventory.reserve(locale: locale)

            state = .installed
            Log.speech.notice("Assets installed for \(locale.identifier, privacy: .public)")
        } catch {
            progressObservation = nil
            Log.speech.error("Asset installation: \(error, privacy: .public)")
            state = .failed(error.localizedDescription)
        }
    }
}
