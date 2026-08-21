import Foundation
import Observation

/// Abstraction boundary for SpeechRecognitionService: makes the
/// `PracticeViewModel` testable (scriptable doubles in S3.3).
@MainActor
protocol SpeechRecognizing: AnyObject, Observable {
    var status: SpeechRecognitionService.Status { get }
    var elapsed: TimeInterval { get }
    var liveTranscript: String { get }
    var finalizedTranscript: String { get }
    var volatileTranscript: String { get }
    var recordingURL: URL? { get }
    var meter: AudioLevelMeter { get }

    func startRecording() async throws
    func stopRecording() async throws -> String
    func cancel() async
}

extension SpeechRecognitionService: SpeechRecognizing {}
