import Foundation

/// Single source of truth for progress thresholds. Three screens were using
/// them with diverging values (2 vs 3 attempts) — everything flows here.
enum ProgressRules {
    /// A sentence is "difficult" if it has at least this many attempts
    /// without reaching mastery.
    static let difficultMinimumAttempts = 2

    /// Score at and above which an attempt is considered "mastered".
    static let masteryScore = 85
}