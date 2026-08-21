import Accelerate
import AVFoundation
import Foundation
import Observation
import Speech

@MainActor
@Observable
final class SpeechRecognitionService {
    enum Status: Sendable, Equatable {
        case idle
        case preparing
        case recording
        case transcribing
    }

    private(set) var status: Status = .idle
    private(set) var elapsed: TimeInterval = 0

    /// Niveau audio lu par l'UI à 30 Hz (aucune invalidation @Observable).
    let meter = AudioLevelMeter()

    private let locale: Locale
    private let maxDuration: TimeInterval
    private let audioSession = AudioSessionController()

    /// Converter temps réel, créé au setup — réutilisé, jamais ré-alloué par callback.
    private var audioConverter: AudioFormatConverter?

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var audioEngine: AVAudioEngine?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var collectionTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    /// Segments définitivement figés, concaténés.
    private var finalizedTranscript: String = ""
    /// Hypothèse en cours, remplacée à chaque émission.
    private(set) var volatileTranscript: String = ""
    private(set) var streamFailure: Error?

    /// Ce que l'UI affiche en direct (cf. S5.1).
    var liveTranscript: String {
        [finalizedTranscript, volatileTranscript]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    /// Ce qu'on envoie au scoring après finalisation.
    private(set) var collectedTranscript: String {
        get { finalizedTranscript }
        set { finalizedTranscript = newValue }
    }

    nonisolated init(locale: Locale = Locale(identifier: "en-US"),
                     maxDuration: TimeInterval = 15) {
        self.locale = locale
        self.maxDuration = maxDuration
    }

    func startRecording() async throws {
        guard status == .idle || status == .transcribing else { return }
        finalizedTranscript = ""
        volatileTranscript = ""
        streamFailure = nil
        elapsed = 0
        amplitude = 0
        status = .preparing

        guard await ensureMicrophone() else {
            status = .idle
            throw RecordingError.microphoneDenied
        }
        guard await ensureSpeech() else {
            status = .idle
            throw RecordingError.speechDenied
        }

        do {
            try await audioSession.activateForRecording()
            try await setupPipeline()
            try startAudioEngine()
        } catch let error as RecordingError {
            await cleanup()
            throw error
        } catch {
            await cleanup()
            throw RecordingError.framework(error.localizedDescription)
        }

        status = .recording
        startTimer()
    }

    func stopRecording() async throws -> String {
        guard status == .recording else { return collectedTranscript }
        status = .transcribing

        timerTask?.cancel()
        timerTask = nil

        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        inputContinuation?.finish()
        inputContinuation = nil

        if let analyzer {
            try? await analyzer.finalizeAndFinishThroughEndOfInput()
        }

        await collectionTask?.value
        collectionTask = nil

        if let streamFailure {
            await cleanup()
            status = .idle
            throw RecordingError.framework(streamFailure.localizedDescription)
        }

        let transcript = (finalizedTranscript.isEmpty ? volatileTranscript : finalizedTranscript)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        await cleanup()
        status = .idle
        guard !transcript.isEmpty else {
            throw RecordingError.noSpeech
        }
        return transcript
    }

    func cancel() async {
        timerTask?.cancel()
        timerTask = nil
        if let engine = audioEngine {
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
        }
        inputContinuation?.finish()
        inputContinuation = nil
        collectionTask?.cancel()
        collectionTask = nil
        await cleanup()
        status = .idle
    }

    private func ensureMicrophone() async -> Bool {
        if PermissionService.microphoneStatus() == .granted { return true }
        return await PermissionService.requestMicrophone()
    }

    private func ensureSpeech() async -> Bool {
        let current = PermissionService.speechStatus()
        if current == .authorized { return true }
        if current == .denied || current == .restricted { return false }
        let requested = await PermissionService.requestSpeech()
        return requested == .authorized
    }

    private func setupPipeline() async throws {
        let transcriber = SpeechTranscriber(locale: locale, preset: .progressiveTranscription)
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
        self.transcriber = transcriber

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        guard let analyzerFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        ) else {
            throw RecordingError.framework("could not create analyzer format")
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let audioConverter = AudioFormatConverter(from: inputFormat, to: analyzerFormat) else {
            throw RecordingError.framework("converter unavailable")
        }
        self.audioConverter = audioConverter
        let meter = self.meter

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = continuation

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { buffer, _ in
            // Thread temps réel : aucune allocation, aucun verrou bloquant, aucun Task.
            meter.ingest(buffer)
            guard let converted = audioConverter.convert(buffer) else { return }
            continuation.yield(AnalyzerInput(buffer: converted))
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        self.analyzer = analyzer

        startCollecting(from: transcriber)

        Task { [analyzer] in
            do {
                try await analyzer.start(inputSequence: stream)
            } catch {
                Log.speech.error("Analyzer pipeline failed: \(error, privacy: .public)")
            }
        }

        self.audioEngine = engine
    }

    private func startCollecting(from transcriber: SpeechTranscriber) {
        collectionTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    let text = String(result.text.characters)
                    let isFinal = result.isFinal
                    await MainActor.run {
                        guard let self else { return }
                        if isFinal {
                            self.finalizedTranscript = self.finalizedTranscript.isEmpty
                                ? text
                                : self.finalizedTranscript + " " + text
                            self.volatileTranscript = ""
                        } else {
                            self.volatileTranscript = text
                        }
                    }
                }
            } catch is CancellationError {
                // Arrêt normal.
            } catch {
                Log.speech.error("Flux de résultats interrompu: \(error, privacy: .public)")
                await MainActor.run { self?.streamFailure = error }
            }
        }
    }

    private func startAudioEngine() throws {
        guard let engine = audioEngine else {
            throw RecordingError.framework("audio engine missing")
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            throw RecordingError.framework(error.localizedDescription)
        }
    }

    private func startTimer() {
        timerTask = Task { [weak self, maxDuration] in
            let tickInterval: TimeInterval = 0.1
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(tickInterval))
                tick += 1
                guard let self, self.status == .recording else { return }
                self.elapsed = Double(tick) * tickInterval
                if self.elapsed >= maxDuration { return }
            }
        }
    }

    private func cleanup() async {
        audioEngine = nil
        analyzer = nil
        transcriber = nil
        await audioSession.deactivate()
    }

    static func computeAmplitude(buffer: AVAudioPCMBuffer) -> Double {
        let frames = vDSP_Length(buffer.frameLength)
        guard frames > 0 else { return 0 }

        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            guard let data = buffer.floatChannelData else { return 0 }
            var rms: Float = 0
            vDSP_rmsqv(data[0], 1, &rms, frames)          // canal 0 suffit pour un VU-mètre
            return min(1, Double(rms) * 4)

        case .pcmFormatInt16:
            guard let data = buffer.int16ChannelData else { return 0 }
            var floats = [Float](repeating: 0, count: Int(frames))
            vDSP_vflt16(data[0], 1, &floats, 1, frames)
            var rms: Float = 0
            vDSP_rmsqv(floats, 1, &rms, frames)
            return min(1, Double(rms) / Double(Int16.max) * 4)

        default:
            return 0
        }
    }
}
