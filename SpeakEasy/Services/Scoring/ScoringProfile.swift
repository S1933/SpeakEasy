import Foundation

/// Pondération du scoring, par mode (S4.1) / profil.
struct ScoringProfile: Sendable, Equatable {
    var missing: Double
    var wrong: Double
    var extra: Double
    /// Multiplicateur appliqué aux mots listés dans `keywords`.
    var keywordMultiplier: Double
    /// Multiplicateur appliqué aux mots fonctionnels (articles, auxiliaires…).
    var functionWordMultiplier: Double
    /// Coût d'une substitution phonétiquement proche (cf. S4.3).
    var nearMissRatio: Double

    static let strict   = ScoringProfile(missing: 1.0, wrong: 1.0, extra: 0.5,
                                         keywordMultiplier: 1.5, functionWordMultiplier: 0.5,
                                         nearMissRatio: 0.5)
    static let balanced = ScoringProfile(missing: 1.0, wrong: 1.0, extra: 0.4,
                                         keywordMultiplier: 1.5, functionWordMultiplier: 0.35,
                                         nearMissRatio: 0.4)
    static let lenient  = ScoringProfile(missing: 1.0, wrong: 0.8, extra: 0.25,
                                         keywordMultiplier: 1.5, functionWordMultiplier: 0.2,
                                         nearMissRatio: 0.3)
}

/// Mots grammaticaux : leur omission n'entrave pas la compréhension.
enum FunctionWords {
    static let set: Set<String> = [
        "a", "an", "the", "of", "to", "in", "on", "at", "for", "with",
        "is", "are", "was", "were", "be", "been", "am",
        "do", "does", "did", "have", "has", "had",
        "that", "this", "it", "so", "and", "but", "or"
    ]
}
