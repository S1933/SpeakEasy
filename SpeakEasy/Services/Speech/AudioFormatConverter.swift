import AVFoundation

/// Convertit les buffers du micro vers le format attendu par SpeechAnalyzer.
/// Instance unique, réutilisée à chaque callback : aucune allocation
/// sur le thread audio temps réel.
///
/// Safety (Swift 6) : accédé exclusivement depuis deux points sans chevauchement —
/// création/`reset()` sur le main actor, `convert(_:)` sur le seul thread audio.
final class AudioFormatConverter: @unchecked Sendable {
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private let ratio: Double

    /// Buffer de sortie réutilisé — évite une allocation par callback.
    private var scratch: AVAudioPCMBuffer

    init?(from input: AVAudioFormat, to output: AVAudioFormat, maxInputFrames: AVAudioFrameCount = 8192) {
        guard let converter = AVAudioConverter(from: input, to: output) else { return nil }
        self.ratio = output.sampleRate / input.sampleRate
        let capacity = AVAudioFrameCount(Double(maxInputFrames) * ratio) + 64
        guard let scratch = AVAudioPCMBuffer(pcmFormat: output, frameCapacity: capacity) else { return nil }

        converter.primeMethod = .none        // pas de latence de priming
        self.converter = converter
        self.outputFormat = output
        self.scratch = scratch
    }

    /// - Returns: un buffer **détenu par le converter**. À consommer
    ///   immédiatement (ici : yield dans l'AsyncStream, qui en fait une copie
    ///   via AnalyzerInput). Ne pas conserver de référence.
    func convert(_ input: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
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
                outStatus.pointee = .noDataNow   // le converter reste réutilisable
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
                Log.audio.error("Conversion échouée: \(error.localizedDescription, privacy: .public)")
            }
            return nil
        @unknown default:
            return nil
        }
    }

    /// À appeler entre deux enregistrements pour repartir d'un état propre.
    func reset() { converter.reset() }
}
