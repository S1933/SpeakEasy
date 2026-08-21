import Foundation

/// Source unique des seuils de progression. Trois écrans les utilisaient
/// avec des valeurs divergentes (2 vs 3 tentatives) — tout passe ici.
enum ProgressRules {
    /// Une phrase est « difficile » si elle a au moins ce nombre de tentatives
    /// sans atteindre la maîtrise.
    static let difficultMinimumAttempts = 2

    /// Score à partir duquel un essai est considéré « maîtrisé ».
    static let masteryScore = 85
}