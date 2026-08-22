import Foundation

/// Primary learning dimension: what the user must produce.
enum PracticeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// English only, always visible. Target: pronunciation, rhythm, stress.
    case repeatAfter
    /// French only. Target: production, lexical recall, structure.
    case translate

    var id: String { rawValue }

    /// Resolves a persisted raw value, tolerating modes removed in earlier
    /// versions (e.g. the retired `recall`), which fall back to `.repeatAfter`.
    static func resolve(_ rawValue: String?) -> PracticeMode {
        PracticeMode(rawValue: rawValue ?? "") ?? .repeatAfter
    }

    var title: String {
        switch self {
        case .repeatAfter: return "Repeat"
        case .translate:   return "Translate"
        }
    }

    var subtitle: String {
        switch self {
        case .repeatAfter: return "Listen, read the English aloud, check your pronunciation."
        case .translate:   return "Only French is shown. Say it in English."
        }
    }

    /// Repeat is a pure pronunciation drill: the English target is the only
    /// prompt, visible before, during and after the recording.
    var showsEnglishBeforeRecording: Bool { self == .repeatAfter }

    /// The French prompt only carries information when English must be produced.
    var showsFrenchPrompt: Bool { self == .translate }

    /// Revealing only makes sense when something is hidden.
    var allowsReveal: Bool { !showsEnglishBeforeRecording }

    /// In Translate, the lexical error margin must be more generous:
    /// a correct variant must not be punished as a mistake.
    var scoringProfile: ScoringProfile {
        switch self {
        case .repeatAfter: .strict
        case .translate:   .lenient
        }
    }
}
