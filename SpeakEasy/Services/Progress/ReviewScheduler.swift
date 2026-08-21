import Foundation

/// Variante de SM-2 (SuperMemo) adaptée : la « qualité de rappel » n'est pas
/// saisie par l'utilisateur mais dérivée du score de prononciation.
enum ReviewScheduler {

    /// Score 0–100 → qualité 0–5 attendue par SM-2.
    static func quality(from score: Int) -> Int {
        switch score {
        case 95...100: 5
        case 85..<95:  4
        case 70..<85:  3
        case 50..<70:  2
        case 25..<50:  1
        default:       0
        }
    }

    @MainActor
    static func apply(score: Int, to progress: SentenceProgress, on date: Date = .now) {
        let q = quality(from: score)

        if q < 3 {
            // Échec : on réinitialise l'intervalle, la phrase revient très vite.
            progress.repetitions = 0
            progress.intervalDays = 1
        } else {
            progress.repetitions += 1
            progress.intervalDays = switch progress.repetitions {
            case 1: 1
            case 2: 4
            default: Int((Double(progress.intervalDays) * progress.easeFactor).rounded())
            }
        }

        // Ajustement du facteur de facilité (formule SM-2 d'origine).
        let delta = 0.1 - Double(5 - q) * (0.08 + Double(5 - q) * 0.02)
        progress.easeFactor = max(1.3, progress.easeFactor + delta)

        // Plafond : au-delà de 6 mois, l'intervalle n'apporte plus rien.
        progress.intervalDays = min(progress.intervalDays, 180)

        progress.dueDate = Calendar.current.date(
            byAdding: .day, value: progress.intervalDays, to: date) ?? date
    }
}
