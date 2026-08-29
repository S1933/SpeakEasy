import AVFoundation
import Foundation
import Speech

// Phase 0 spike — verifies the SpeechAnalyzer surface against a real
// transcriber running on a known audio input. The design document's Phase 0
// lists six questions; this answers them with observed values, not assumptions.
//
// Usage:
//   1. ./generate-sample.sh   → produces Resources/sample.wav (bundled with the app)
//   2. open Package.swift in Xcode, select an iPhone, ⌘R
//
// The sample file is fed via SpeechAnalyzer(inputAudioFile:), so this runs
// without a microphone. The simulator captures Mac audio only if you actually
// want to test the mic path; the file route is enough to verify the API.
//
// Override the input by passing a file path as the first argument.

@main
struct Spike {
    static func main() async throws {
        let url = try resolveSampleURL()
        log("FILE \(url.path)")

        // --- CHECK 1: supportedLocales ---
        log("SpeechTranscriber.isAvailable: \(SpeechTranscriber.isAvailable)")
        let supported = await SpeechTranscriber.supportedLocales
        let supportedIDs = supported.map { $0.identifier(.bcp47) }
        log("LOCALES supported: \(supportedIDs)")
        let enUS = supportedIDs.contains("en-US")
        log("CHECK 1 supported en-US: \(enUS ? "✓" : "✗")")
        guard enUS else {
            log("HINT: empty list usually means the simulator. SpeechTranscriber")
            log("      is unavailable on the iOS simulator as of SDK 26 — the spike")
            log("      must be run on a real device.")
            exit(1)
        }

        // --- CHECK 2: model availability + install ---
        let transcriber = SpeechTranscriber(
            locale: Locale(identifier: "en-US"),
            transcriptionOptions: [],
            reportingOptions: [.volatileResults],
            attributeOptions: [.audioTimeRange]
        )
        let installed = await SpeechTranscriber.installedLocales
        log("LOCALES installed: \(installed.map { $0.identifier(.bcp47) })")
        let hasEnUS = installed.contains { $0.identifier(.bcp47) == "en-US" }
        if hasEnUS {
            log("CHECK 2 model already installed ✓")
        } else {
            log("CHECK 2 model not installed — requesting download…")
            do {
                guard let request = try await AssetInventory
                        .assetInstallationRequest(supporting: [transcriber]) else {
                    log("ABORT: AssetInventory returned no request (simulator without speech support?)")
                    exit(1)
                }
                let downloadStart = Date.now
                try await request.downloadAndInstall()
                log("CHECK 2 install ✓ (took \(String(format: "%.1f", Date.now.timeIntervalSince(downloadStart)))s)")
            } catch {
                log("ABORT: download failed: \(error)")
                exit(1)
            }
        }

        // --- Load audio file ---
        let file = try AVAudioFile(forReading: url)
        let fileDuration = Double(file.length) / file.processingFormat.sampleRate
        let format = file.processingFormat
        log("FILE duration=\(String(format: "%.2f", fileDuration))s, "
            + "channels=\(format.channelCount), "
            + "rate=\(Int(format.sampleRate))Hz, "
            + "common=\(format.commonFormat.rawValue)")

        // --- CHECK 3-6: feed and observe ---
        // finishAfterFile=true → analyzer ends when the file ends. If the file
        // is short (say 30 s) and the task completes in ~30 s, that's the API
        // working as documented. For the 2-minute test, run the script with a
        // longer sample (see generate-sample.sh REPEAT=N flag).
        // `analyzer` is never read but must be retained: releasing it ends
        // the transcription.
        let analyzer = try await SpeechAnalyzer(
            inputAudioFile: file, modules: [transcriber],
            finishAfterFile: true)
        _ = analyzer

        let started = Date.now
        var emissionCount = 0
        var finalCount = 0
        var volatileCount = 0
        var firstRunStart: Double?
        var runsWithoutAudioTime = 0
        var totalRuns = 0
        var runsPerEmission: [Int] = []
        var wordsPerEmission: [Int] = []
        var lastVolatileText: String?
        var volatileRevisions = 0
        var longestVolatileRun: Int = 0
        var currentVolatileStreak = 0

        do {
            for try await result in transcriber.results {
                emissionCount += 1
                let text = String(result.text.characters)
                let words = text.split(separator: " ").count
                let runs = result.text.runs.count
                let runStarts = result.text.runs
                    .compactMap { $0.audioTimeRange?.start.seconds }

                if firstRunStart == nil, let first = runStarts.first {
                    firstRunStart = first
                }
                totalRuns += runs
                runsWithoutAudioTime += zip(result.text.runs, runStarts)
                    .filter { $0.0.audioTimeRange == nil }.count
                runsPerEmission.append(runs)
                wordsPerEmission.append(words)

                let t = String(format: "%.2f", Date.now.timeIntervalSince(started))
                let preview = text.prefix(70)
                if result.isFinal {
                    finalCount += 1
                    currentVolatileStreak = 0
                    log("EMIT \(t)s FINAL words=\(words) runs=\(runs) text=\"\(preview)\"")
                } else {
                    volatileCount += 1
                    currentVolatileStreak += 1
                    longestVolatileRun = max(longestVolatileRun, currentVolatileStreak)
                    if text != lastVolatileText {
                        volatileRevisions += 1
                        log("EMIT \(t)s VOLATILE words=\(words) runs=\(runs) text=\"\(preview)\"")
                    }
                }
                lastVolatileText = text
            }
        } catch is CancellationError {
            log("EMIT stream cancelled (normal)")
        } catch {
            log("EMIT stream error: \(error)")
        }

        let elapsed = Date.now.timeIntervalSince(started)
        let avgRunsPerEmit = emissionCount > 0
            ? Double(totalRuns) / Double(emissionCount) : 0
        let avgWordsPerEmit = emissionCount > 0
            ? Double(wordsPerEmission.reduce(0, +)) / Double(emissionCount) : 0
        let wordsPerRun = totalRuns > 0
            ? Double(wordsPerEmission.reduce(0, +)) / Double(totalRuns) : 0

        log("DONE \(emissionCount) emissions in \(String(format: "%.2f", elapsed))s — "
            + "\(finalCount) final, \(volatileCount) volatile, \(volatileRevisions) volatile revisions")
        log("CHECK 3 task completed within ~file duration: "
            + "file=\(String(format: "%.2f", fileDuration))s observed=\(String(format: "%.2f", elapsed))s \(abs(elapsed - fileDuration) < 1.0 ? "✓" : "(file looped? — see notes.md)")")
        log("CHECK 4 isFinal distinct: "
            + "\(finalCount > 0 ? "✓" : "✗") final present, "
            + "\(volatileCount > 0 ? "✓" : "✗") volatile present, "
            + "longest volatile streak = \(longestVolatileRun)")
        log("CHECK 5 audioTimeRange: "
            + "\(totalRuns - runsWithoutAudioTime)/\(totalRuns) runs carry a timestamp "
            + "\(runsWithoutAudioTime == 0 && totalRuns > 0 ? "✓" : "⚠")")
        log("CHECK 6 run granularity: "
            + "avg \(String(format: "%.1f", avgRunsPerEmit)) runs/emission, "
            + "\(String(format: "%.1f", avgWordsPerEmit)) words/emission, "
            + "≈\(String(format: "%.2f", wordsPerRun)) words/run → "
            + granularityVerdict(wordsPerRun: wordsPerRun))

        if let first = firstRunStart {
            log("FIRST audioTimeRange start: \(String(format: "%.3f", first))s")
        } else {
            log("FIRST audioTimeRange start: nil")
        }
    }
}

/// One run per word → granular timing works for hesitations.
/// Two words per run → still acceptable, half the resolution.
/// More → hesitations become unreliable.
private func granularityVerdict(wordsPerRun: Double) -> String {
    switch wordsPerRun {
    case 0..<1.5: "✓ one word per run — timing is reliable"
    case 1.5..<2.5: "~ 1-2 words/run — acceptable, half resolution"
    default: "⚠ >\(Int(wordsPerRun)) words/run — timing unreliable, abandon per-word hesitations"
    }
}

import os

private let spikeLogger = Logger(subsystem: "com.s1933.spike", category: "run")

/// File-backed log sink: writes to Documents/spike-output.txt so the output
/// survives process exit and can be pulled from the device via
/// `devicectl device copy from --domain-type appDataContainer`.
/// Opened lazily on first log line, flushed after every write.
private let logFileURL: URL = {
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    return docs.appendingPathComponent("spike-output.txt")
}()

private let logFileHandle: FileHandle? = {
    FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
    return FileHandle(forWritingAtPath: logFileURL.path)
}()

private func log(_ s: String) {
    let ts = Date.now.formatted(.dateTime.hour().minute().second().secondFraction(.fractional(3)))
    let line = "[\(ts)] \(s)\n"
    print(line, terminator: "")
    spikeLogger.notice("\(line, privacy: .public)")
    if let handle = logFileHandle {
        handle.write(Data(line.utf8))
        try? handle.synchronize()
    }
}

/// Resolves the audio file. Order of preference:
///   1. Path passed on the command line (lets the user point at any file).
///   2. `sample.wav` bundled into the package via Package.swift's resources.
///   3. ABORT — clear instruction so the user knows what to run first.
private func resolveSampleURL() throws -> URL {
    if let arg = CommandLine.arguments.dropFirst().first {
        let url = URL(fileURLWithPath: arg)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        log("ABORT: \(url.path) does not exist")
        exit(1)
    }
    if let url = Bundle.module.url(forResource: "sample", withExtension: "wav") {
        return url
    }
    log("ABORT: sample.wav not found in bundle. Run ./generate-sample.sh first.")
    exit(1)
}
