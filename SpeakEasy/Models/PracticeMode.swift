import Foundation

/// Primary learning dimension: what the user must produce.
enum PracticeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// English visible. Target: pronunciation, rhythm, stress.
    case repeatAfter
    /// French only. Target: production, lexical recall, structure.
    case translate
    /// English shown then hidden. Target: working memory.
    case recall

    var id: String { rawValue }

    var title: String {
        switch self {
        case .repeatAfter: return "Repeat"
        case .translate:   return "Translate"
        case .recall:      return "Recall"
        }
    }

    var subtitle: String {
        switch self {
        case .repeatAfter: return "The English is shown. Focus on pronunciation."
        case .translate:   return "Only French is shown. Say it in English."
        case .recall:      return "Read it, then say it from memory."
        }
    }

    var showsEnglishBeforeRecording: Bool { self == .repeatAfter }

    /// In Translate, the lexical error margin must be more generous:
    /// a correct variant must not be punished as a mistake.
    var scoringProfile: ScoringProfile {
        switch self {
        case .repeatAfter: .strict
        case .translate:   .lenient
        case .recall:      .balanced
        }
    }
}
