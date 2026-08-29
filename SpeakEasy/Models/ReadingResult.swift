import Foundation

struct ReadingResult: Sendable, Equatable, Hashable {
    let accuracy: Int              // % de mots corrects sur le texte
    let wcpm: Int                  // mots corrects par minute
    let missedIndices: [Int]
    let substitutedIndices: [Int]
    let insertions: Int
    let hesitationIndices: [Int]
    let duration: TimeInterval

    /// Bande de débit. Un lecteur à 100 % de précision mais à 60 wpm
    /// n'est pas fluide : la précision seule ne suffit pas.
    var paceBand: PaceBand {
        switch wcpm {
        case ..<90:    .tooSlow
        case 90...160: .good
        default:       .tooFast
        }
    }
}

enum PaceBand: Sendable, Equatable {
    case tooSlow
    case good
    case tooFast
}