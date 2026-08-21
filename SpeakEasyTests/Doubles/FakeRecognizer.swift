import Foundation
import Observation
@testable import SpeakEasy

@MainActor @Observable
final class FakeRecognizer: SpeechRecognizing {

    enum Script {
        case succeeds(String)
        case fails(RecordingError)
        case hangs                       // ne rend jamais la main
    }

    var script: Script
    var startDelay: Duration = .zero
    var stopDelay: Duration = .zero

    private(set) var status: SpeechRecognitionService.Status = .idle
    private(set) var elapsed: TimeInterval = 0
    private(set) var liveTranscript = ""
    let meter = AudioLevelMeter()

    // Journal d'appels, pour vérifier le cycle de vie.
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var cancelCount = 0

    init(script: Script = .succeeds("hello")) { self.script = script }

    func startRecording() async throws {
        startCount += 1
        if startDelay > .zero { try? await Task.sleep(for: startDelay) }
        if case .fails(let error) = script { throw error }
        status = .recording
    }

    func stopRecording() async throws -> String {
        stopCount += 1
        if stopDelay > .zero { try? await Task.sleep(for: stopDelay) }
        status = .idle
        switch script {
        case .succeeds(let text): return text
        case .fails(let error):   throw error
        case .hangs:              try await Task.sleep(for: .seconds(3600)); return ""
        }
    }

    func cancel() async {
        cancelCount += 1
        status = .idle
    }
}
