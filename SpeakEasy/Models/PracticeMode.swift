import Foundation

/// Dimension pédagogique de premier ordre : ce que l'utilisateur doit produire.
enum PracticeMode: String, Codable, CaseIterable, Identifiable, Sendable {
    /// Anglais visible. Cible : prononciation, rythme, accent tonique.
    case repeatAfter
    /// Français seul. Cible : production, rappel lexical, structure.
    case translate
    /// Anglais affiché puis masqué. Cible : mémoire de travail.
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

    /// En Translate, la marge d'erreur lexicale doit être plus généreuse :
    /// une variante correcte ne doit pas être punie comme une faute.
    var scoringProfile: ScoringProfile {
        switch self {
        case .repeatAfter: .strict
        case .translate:   .lenient
        case .recall:      .balanced
        }
    }
}
