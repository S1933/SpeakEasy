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
    private(set) var amplitude: Double = 0
    private(set) var elapsed: TimeInterval = 0

    private let locale: Locale
    private let maxDuration: TimeInterval
    private let audioSession = AudioSessionController()

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private var audioEngine: AVAudioEngine?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var collectionTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?

    private(set) var collectedTranscript: String = ""

    nonisolated init(locale: Locale = Locale(identifier: "en-US"),
                     maxDuration: TimeInterval = 15) {
        self.locale = locale
        self.maxDuration = maxDuration
    }

    func startRecording() async throws {
        guard status == .idle || status == .transcribing else { return }
        collectedTranscript = ""
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
            try audioSession.activateForRecording()
            try await setupPipeline()
            try startAudioEngine()
        } catch let error as RecordingError {
            cleanup()
            throw error
        } catch {
            cleanup()
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

        cleanup()

        let transcript = collectedTranscript.trimmingCharacters(in: .whitespaces)
        status = .idle
        guard !transcript.isEmpty else {
            throw RecordingError.noSpeech
        }
        return transcript
    }

    func cancel() {
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
        cleanup()
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

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = continuation

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: nil) { [weak self] buffer, _ in
            let amp = Self.computeAmplitude(buffer: buffer)
            guard let converter = AVAudioConverter(from: inputFormat, to: analyzerFormat),
                  let converted = Self.convert(buffer: buffer, using: converter, to: analyzerFormat) else {
                return
            }
            continuation.yield(AnalyzerInput(buffer: converted))
            Task { @MainActor [weak self] in
                self?.amplitude = amp
            }
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        try await analyzer.prepareToAnalyze(in: analyzerFormat)
        self.analyzer = analyzer

        collectionTask = Task { [weak self] in
            do {
                let resultStream = transcriber.results
                for try await result in resultStream {
                    let text = String(result.text.characters)
                    await MainActor.run {
                        self?.collectedTranscript = text
                    }
                }
            } catch {
                Log.speech.error("Result stream failed: \(error, privacy: .public)")
            }
        }

        Task { [analyzer] in
            do {
                try await analyzer.start(inputSequence: stream)
            } catch {
                Log.speech.error("Analyzer pipeline failed: \(error, privacy: .public)")
            }
        }

        self.audioEngine = engine
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
            let totalTicks = Int(maxDuration / tickInterval)
            for tick in 1...totalTicks {
                try? await Task.sleep(for: .seconds(tickInterval))
                guard let self, !Task.isCancelled, self.status == .recording else { return }
                self.elapsed = Double(tick) * tickInterval
                if self.elapsed >= maxDuration {
                    _ = try? await self.stopRecording()
                    return
                }
            }
        }
    }

    private func cleanup() {
        audioEngine = nil
        analyzer = nil
        transcriber = nil
        audioSession.deactivate()
    }

    private static func computeAmplitude(buffer: AVAudioPCMBuffer) -> Double {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }
        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            guard let channelData = buffer.floatChannelData else { return 0 }
            let channels = Int(buffer.format.channelCount)
            var sumSquares: Float = 0
            for c in 0..<channels {
                let samples = channelData[c]
                for f in 0..<frames {
                    let s = samples[f]
                    sumSquares += s * s
                }
            }
            let rms = (sumSquares / Float(channels * frames)).squareRoot()
            return min(1.0, Double(rms) * 4)
        case .pcmFormatInt16:
            guard let channelData = buffer.int16ChannelData else { return 0 }
            let channels = Int(buffer.format.channelCount)
            var sumSquares: Double = 0
            for c in 0..<channels {
                let samples = channelData[c]
                for f in 0..<frames {
                    let s = Double(samples[f])
                    sumSquares += s * s
                }
            }
            let rms = (sumSquares / Double(channels * frames)).squareRoot() / Double(Int16.max)
            return min(1.0, rms * 4)
        default:
            return 0
        }
    }

    private static func convert(
        buffer: AVAudioPCMBuffer,
        using converter: AVAudioConverter,
        to format: AVAudioFormat
    ) -> AVAudioPCMBuffer? {
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio + 32)
        guard let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        var supplied = false
        var error: NSError?
        converter.convert(to: out, error: &error) { _, status in
            if supplied {
                status.pointee = .endOfStream
                return nil
            }
            supplied = true
            status.pointee = .haveData
            return buffer
        }
        if error != nil { return nil }
        return out
    }
}
