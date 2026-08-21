import AVFoundation
import Foundation
import Speech

enum RecordingError: Error, Sendable, LocalizedError, Equatable {
    case microphoneDenied
    case speechDenied
    case assetsUnavailable
    case noSpeech
    case audioInterruption
    case framework(String)

    var errorDescription: String? {
        switch self {
        case .microphoneDenied:
            return "Microphone access is disabled."
        case .speechDenied:
            return "Speech recognition is disabled."
        case .assetsUnavailable, .framework:
            return "Speech recognition isn't available right now."
        case .noSpeech:
            return "I couldn't hear anything."
        case .audioInterruption:
            return "Recording was interrupted."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .microphoneDenied, .speechDenied:
            return "Allow access in Settings to practice speaking."
        case .noSpeech:
            return "Try again and speak a little closer to your iPhone."
        default:
            return "Please try again."
        }
    }
}
