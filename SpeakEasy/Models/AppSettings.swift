import Foundation
import SwiftData

@Model
final class AppSettings {
    var sessionSize: Int
    var voiceLocale: String

    init(sessionSize: Int = 10, voiceLocale: String = "en-US") {
        self.sessionSize = sessionSize
        self.voiceLocale = voiceLocale
    }
}

enum VoiceOption: String, CaseIterable, Identifiable, Sendable {
    case enUS = "en-US"
    case enGB = "en-GB"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .enUS: return "English (US)"
        case .enGB: return "English (UK)"
        }
    }
}

enum SessionSizeOption: Int, CaseIterable, Identifiable, Sendable {
    case five = 5
    case ten = 10
    case twenty = 20

    var id: Int { rawValue }

    var displayName: String { "\(rawValue)" }
}