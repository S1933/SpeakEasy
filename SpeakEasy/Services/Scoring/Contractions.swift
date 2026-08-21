import Foundation

/// Gestion des contractions dans l'alignement (S4.2) :
/// `it's` (1 token) ≡ `it is` (2 tokens) — une transition plusieurs-vers-un.
enum Contractions {
    /// forme contractée → forme développée
    static let expansions: [String: [String]] = [
        "it's": ["it", "is"],       "i'm": ["i", "am"],
        "don't": ["do", "not"],     "doesn't": ["does", "not"],
        "didn't": ["did", "not"],   "can't": ["can", "not"],
        "won't": ["will", "not"],   "i'll": ["i", "will"],
        "you'll": ["you", "will"],  "we'll": ["we", "will"],
        "there's": ["there", "is"], "that's": ["that", "is"],
        "let's": ["let", "us"],     "i've": ["i", "have"],
        "isn't": ["is", "not"],     "aren't": ["are", "not"],
        "we're": ["we", "are"],     "they're": ["they", "are"],
        "you're": ["you", "are"],   "i'd": ["i", "would"]
    ]

    /// Vrai si `single` est la contraction exacte de `pair`.
    static func matches(single: String, pair: [String]) -> Bool {
        expansions[single] == pair
    }
}
