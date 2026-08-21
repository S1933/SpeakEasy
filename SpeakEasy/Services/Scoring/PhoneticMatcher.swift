import Foundation

/// Détecte les quasi-homophones résultant des difficultés classiques
/// d'un locuteur francophone en anglais.
///
/// Ce n'est PAS un moteur phonétique général : c'est une heuristique ciblée
/// sur un ensemble fermé de substitutions, ce qui la rend prévisible et testable.
enum PhoneticMatcher {

    /// Réécritures appliquées avant comparaison. Deux mots dont les formes
    /// réduites coïncident sont considérés comme quasi-homophones.
    private static let reductions: [(pattern: String, replacement: String)] = [
        ("th", "s"),        // think→sink, three→sree  (/θ/ → /s/)
        ("ph", "f"),
        ("wh", "w"),
        ("ck", "k"), ("qu", "kw"), ("x", "ks"),
        ("ee", "i"), ("ea", "i"), ("ie", "i"),   // sheep/ship — /iː/ vs /ɪ/
        ("oo", "u"), ("ou", "u"),
        ("gh", ""),          // through, thought
        ("kn", "n"), ("wr", "r"), ("mb$", "m")
    ]

    /// Consonnes fréquemment amuïes ou substituées.
    private static let equivalents: [Character: Character] = [
        "z": "s", "v": "f", "b": "p", "d": "t", "g": "k", "j": "d"
    ]

    static func reduce(_ word: String) -> String {
        var s = word.lowercased()
        s = s.replacingOccurrences(of: "'", with: "")
        for (pattern, replacement) in reductions {
            s = s.replacingOccurrences(of: pattern, with: replacement,
                                       options: .regularExpression)
        }
        // Le /h/ initial est systématiquement muet en français.
        if s.hasPrefix("h") { s.removeFirst() }
        // Consonne finale muette : "walked" ≈ "walk"
        s = s.replacingOccurrences(of: "e$", with: "", options: .regularExpression)
        // Dévoisement / assourdissement
        s = String(s.map { equivalents[$0] ?? $0 })
        // Doublons de consonnes
        return s.reduce(into: "") { acc, ch in
            if acc.last != ch { acc.append(ch) }
        }
    }

    /// Vrai si les deux mots sont probablement le même mot mal prononcé.
    static func isNearMiss(_ a: String, _ b: String) -> Bool {
        guard a != b else { return false }
        let ra = reduce(a), rb = reduce(b)
        if ra == rb { return true }
        // Tolère une édition de caractère sur les formes réduites, pour les
        // mots longs uniquement (sinon "cat"/"cut" deviendrait un near-miss).
        return min(ra.count, rb.count) >= 4 && levenshtein(ra, rb) == 1
    }

    /// Décrit l'erreur pour le feedback (S4.4).
    static func diagnose(expected: String, actual: String) -> PhonemeIssue? {
        let e = expected.lowercased(), a = actual.lowercased()
        if e.contains("th"), !a.contains("th") {
            return .init(symbol: "θ", label: "the “th” sound",
                         tip: "Put the tip of your tongue between your teeth and blow.")
        }
        if (e.contains("ee") || e.contains("ea")), a.contains("i"), !a.contains("ee") {
            return .init(symbol: "iː", label: "the long “ee”",
                         tip: "Stretch it: “sheep”, not “ship”.")
        }
        if e.hasPrefix("h"), !a.hasPrefix("h") {
            return .init(symbol: "h", label: "the initial “h”",
                         tip: "Breathe out audibly before the vowel — it's never silent in English.")
        }
        return nil
    }

    static func levenshtein(_ a: String, _ b: String) -> Int {
        let a = Array(a), b = Array(b)
        if a.isEmpty { return b.count }
        if b.isEmpty { return a.count }
        var dp = Array(repeating: Array(repeating: 0, count: b.count + 1), count: a.count + 1)
        for i in 0...a.count { dp[i][0] = i }
        for j in 0...b.count { dp[0][j] = j }
        for i in 1...a.count {
            for j in 1...b.count {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                dp[i][j] = min(dp[i - 1][j] + 1, dp[i][j - 1] + 1, dp[i - 1][j - 1] + cost)
            }
        }
        return dp[a.count][b.count]
    }
}

struct PhonemeIssue: Sendable, Equatable {
    let symbol: String
    let label: String
    let tip: String
}
