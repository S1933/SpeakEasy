import AVFoundation
import Foundation
import Speech

enum PermissionService {
    static func microphoneStatus() -> AVAudioApplication.recordPermission {
        AVAudioApplication.shared.recordPermission
    }

    static func requestMicrophone() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func speechStatus() -> SFSpeechRecognizerAuthorizationStatus {
        SFSpeechRecognizer.authorizationStatus()
    }

    static func requestSpeech() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
}
