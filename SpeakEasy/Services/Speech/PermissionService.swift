import AVFoundation
import Foundation
import Speech

enum PermissionService {
    nonisolated static func microphoneStatus() -> AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    /// The TCC callback is delivered on a background queue (not main).
    /// We isolate the function so the closure passed to the API is nonisolated.
    nonisolated static func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    nonisolated static func speechStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    nonisolated static func requestSpeech() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
