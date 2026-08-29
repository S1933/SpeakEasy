import os
import AVFoundation
import Foundation
import Observation
import Speech

/// Reads a text aloud: long-format on-device transcription via SpeechAnalyzer,
/// feeding `ReadingAligner` token-by-token. Differs from the existing
/// `SpeechRecognitionService` (one-shot mode Repeat) by being session-oriented:
/// the volatile/finalized split is exposed as separate `HypToken` arrays and
/// pause/resume happens without destroying the analyzer pipeline.
@MainActor
@Observable
final class LiveTranscriptionService {
    enum Phase: Sendable, Equatable {
        case idle
        case downloadingModel(Double)   // 0...1 progress
        case ready                      // prepared, not yet recording
        case listening
        case paused                     // tap removed, analyzer kept
        case stopped
        case failed(String)
    }

    /// Words the transcriber has committed. Append-only.
    private(set) var finalized: [HypToken] = []
    /// The current hypothesis, replaces itself on each volatile emission.
    private(set) var finalizedText: String = ""
    private(set) var volatile: [HypToken] = []

    /// Cumulative state for the caller.
    private(set) var phase: Phase = .idle

    private let locale: Locale
    private let audioSession = AudioSessionController()

    // MARK: - Pipeline pieces

    private var analyzer: SpeechAnalyzer?
    private var transcriber: SpeechTranscriber?
    private let audioEngine = AVAudioEngine()
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    /// Drains `transcriber.results` into `finalized`/`volatile`.
    private var resultsTask: Task<Void, Never>?
    /// Runs `analyzer.start(inputSequence:)` for the duration of the session.
    private var analyzerTask: Task<Void, Never>?
    private var sink: AudioSink?
    /// `true` while the tap is installed. Drives pause/resume.
    private var tapInstalled = false

    init(locale: Locale = Locale(identifier: "en-US")) {
        self.locale = locale
    }

    // MARK: - Lifecycle

    /// Verifies the model, downloads it if needed, prepares the analyzer.
    /// Idempotent: a second call is a no-op if already ready.
    func prepare() async throws {
        if case .ready = phase { return }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        self.transcriber = transcriber

        let supported = await SpeechTranscriber.supportedLocales
        guard supported.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) else {
            phase = .failed("locale unsupported")
            throw ReadingError.localeUnsupported
        }

        let installed = await SpeechTranscriber.installedLocales
        if !installed.contains(where: { $0.identifier(.bcp47) == locale.identifier(.bcp47) }) {
            guard let request = try await AssetInventory
                    .assetInstallationRequest(supporting: [transcriber]) else {
                phase = .failed("model unavailable")
                throw ReadingError.modelUnavailable
            }
            phase = .downloadingModel(0)
            try await request.downloadAndInstall()
        }

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        self.analyzer = analyzer

        guard let analyzerFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: 16_000,
            channels: 1,
            interleaved: true
        ) else {
            phase = .failed("could not create analyzer format")
            throw ReadingError.framework("analyzer format")
        }
        try await analyzer.prepareToAnalyze(in: analyzerFormat)

        phase = .ready
    }

    /// Starts a new session. The completion runs on the MainActor for every
    /// finalized/volatile update — the caller can update UI directly.
    func start(onUpdate: @escaping @MainActor ([HypToken], [HypToken]) -> Void) async throws {
        guard case .ready = phase else {
            throw ReadingError.notPrepared
        }
        guard let transcriber, let analyzer else {
            throw ReadingError.notPrepared
        }

        finalized = []
        finalizedText = ""
        volatile = []

        try await audioSession.activateForRecording()

        let (stream, continuation) = AsyncStream<AnalyzerInput>.makeStream()
        self.inputContinuation = continuation

        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        let targetFormat = await SpeechAnalyzer
            .bestAvailableAudioFormat(compatibleWith: [transcriber]) ?? inputFormat

        guard let sink = AudioSink(
            continuation: continuation,
            inputFormat: inputFormat,
            targetFormat: targetFormat
        ) else {
            await audioSession.deactivate()
            throw ReadingError.framework("converter unavailable")
        }
        self.sink = sink

        installTap(inputFormat: inputFormat, sink: sink)
        startCollecting(from: transcriber, onUpdate: onUpdate)

        // The analyzer consumes the stream asynchronously; the audio engine
        // provides it. Both must be alive before we start.
        analyzerTask = Task { [weak self, analyzer] in
            do {
                try await analyzer.start(inputSequence: stream)
            } catch {
                Log.reading.error("Analyzer start failed: \(error, privacy: .public)")
                await MainActor.run { self?.phase = .failed(String(describing: error)) }
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            uninstallTap()
            await cleanupPipeline()
            await audioSession.deactivate()
            throw ReadingError.framework(error.localizedDescription)
        }

        phase = .listening
    }

    /// Pauses without losing analyzer context. Use during TTS playback in
    /// dialogue mode so the mic doesn't pick up synthesized speech.
    func pause() {
        guard phase == .listening else { return }
        uninstallTap()
        phase = .paused
    }

    /// Resumes a paused session. The analyzer pipeline is untouched.
    func resume() {
        guard phase == .paused else { return }
        guard let sink else { return }
        let inputFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        installTap(inputFormat: inputFormat, sink: sink)
        phase = .listening
    }

    /// Stops the session. Waits for the transcriber to flush its pending
    /// finals (`finalizeAndFinishThroughEndOfInput`) BEFORE tearing down the
    /// collection task — otherwise the last phrase is lost and the score
    /// misses the tail of the reading.
    func stop() async {
        uninstallTap()
        if audioEngine.isRunning { audioEngine.stop() }
        sink?.finish()
        sink = nil
        if let analyzer {
            try? await analyzer.finalizeAndFinishThroughEndOfInput()
        }
        // The results sequence ends once the analyzer is finalized; letting
        // the task run to completion delivers the flushed finals.
        await resultsTask?.value
        resultsTask = nil
        analyzerTask?.cancel()
        analyzerTask = nil
        await cleanupPipeline()
        await audioSession.deactivate()
        if case .failed = phase {} else { phase = .stopped }
    }

    /// Tear down + re-prepare, used after an audio interruption where we
    /// want a fresh hypothesis (the analyzer's context is gone after stop).
    func restart() async throws {
        await stop()
        try await prepare()
    }

    // MARK: - Internals

    private func installTap(inputFormat: AVAudioFormat, sink: AudioSink) {
        guard !tapInstalled else { return }
        audioEngine.inputNode.installTap(
            onBus: 0, bufferSize: 4_096, format: nil,
            block: Self.makeTapBlock(sink: sink)
        )
        tapInstalled = true
    }

    private func uninstallTap() {
        guard tapInstalled else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        tapInstalled = false
    }

    private func cleanupPipeline() async {
        inputContinuation?.finish()
        inputContinuation = nil
        analyzer = nil
        transcriber = nil
    }

    private func startCollecting(from transcriber: SpeechTranscriber,
                                 onUpdate: @escaping @MainActor ([HypToken], [HypToken]) -> Void) {
        resultsTask = Task { [weak self] in
            do {
                for try await result in transcriber.results {
                    let finalizedTokens = Self.tokens(
                        from: result.text, isFinalized: true)
                    let volatileTokens = result.isFinal ? [] : Self.tokens(
                        from: result.text, isFinalized: false)
                    await MainActor.run {
                        guard let self else { return }
                        if result.isFinal {
                            self.finalized.append(contentsOf: finalizedTokens)
                            self.finalizedText = (self.finalizedText.isEmpty ? "" : self.finalizedText + " ")
                                + finalizedTokens.map(\.normalized).joined(separator: " ")
                            self.volatile = []
                        } else {
                            self.volatile = volatileTokens
                        }
                        onUpdate(self.finalized, self.volatile)
                    }
                }
            } catch is CancellationError {
                // Normal stop.
            } catch {
                Log.reading.error("Result stream interrupted: \(error, privacy: .public)")
                await MainActor.run { self?.phase = .failed(String(describing: error)) }
            }
        }
    }

    /// The tap block must be CREATED in a nonisolated context: with
    /// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, a closure literal
    /// inherits the isolation of the function it is written in. AVFAudio
    /// invokes the tap on its RealtimeMessenger queue ("This callback may be
    /// invoked on a thread other than the main thread" — AVAudioNode.h),
    /// tripping `_swift_task_checkIsolatedSwift`.
    /// Real-time thread: no allocation, no blocking lock, no Task.
    private nonisolated static func makeTapBlock(sink: AudioSink)
        -> (AVAudioPCMBuffer, AVAudioTime) -> Void {
        { buffer, _ in
            sink.receive(buffer)
        }
    }

    /// Extracts normalized words from an `AttributedString` run. All words in
    /// a single run share the same `audioTimeRange.start` — coarse for the
    /// meter of hesitations, fine enough for the WPM band.
    static func tokens(from text: AttributedString, isFinalized: Bool) -> [HypToken] {
        var out: [HypToken] = []
        for run in text.runs {
            let piece = String(text[run.range].characters)
            let start = run.audioTimeRange.map { $0.start.seconds }
            for word in SentenceNormalizer.tokenize(piece) where !word.isEmpty {
                out.append(HypToken(normalized: word, start: start, isFinalized: isFinalized))
            }
        }
        return out
    }
}

enum ReadingError: Error, LocalizedError {
    case localeUnsupported
    case modelUnavailable
    case notPrepared
    case framework(String)

    var errorDescription: String? {
        switch self {
        case .localeUnsupported: "Locale not supported by on-device speech recognition."
        case .modelUnavailable:   "Speech model could not be downloaded."
        case .notPrepared:        "Service is not prepared. Call prepare() first."
        case .framework(let m):   m
        }
    }
}

extension Log {
    static let reading = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.speakeasy",
        category: "reading"
    )
}
