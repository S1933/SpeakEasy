import AVFoundation
import Foundation
import Speech

enum PermissionService {
    nonisolated static func microphoneStatus() -> AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    /// The TCC callback is delivered on a background queue (not main).
    /// `isolation: nil` overrides `#isolation` so the body closure does NOT inherit
    /// MainActor from the @MainActor caller (SwiftUI view). Otherwise Swift 6's
    /// runtime rejects the TCC callback as off-actor.
    nonisolated static func requestMicrophone() async -> Bool {
        await withCheckedContinuation(isolation: nil) { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    nonisolated static func speechStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    nonisolated static func requestSpeech() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation(isolation: nil) { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
