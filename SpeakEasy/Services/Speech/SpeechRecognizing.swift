import Foundation
import Observation

/// Frontière d'abstraction de SpeechRecognitionService : rend le
/// `PracticeViewModel` testable (doubles scriptables en S3.3).
@MainActor
protocol SpeechRecognizing: AnyObject, Observable {
    var status: SpeechRecognitionService.Status { get }
    var elapsed: TimeInterval { get }
    var liveTranscript: String { get }
    var meter: AudioLevelMeter { get }

    func startRecording() async throws
    func stopRecording() async throws -> String
    func cancel() async
}

extension SpeechRecognitionService: SpeechRecognizing {}
