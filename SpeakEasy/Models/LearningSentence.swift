import Foundation

struct LearningSentence: Identifiable, Codable, Sendable, Hashable {
    let id: Int
    let category: SentenceCategory
    let french: String
    let english: String
    let difficulty: Int
    /// Mots porteurs de sens : pondérés plus lourd dans le score.
    let keywords: [String]
    /// Formulations alternatives acceptées (mode Translate).
    let acceptedVariants: [String]
    /// Phonèmes difficiles pour un francophone présents dans la phrase.
    let focusPhonemes: [String]

    enum CodingKeys: String, CodingKey {
        case id, category, french, english, difficulty, keywords
        case acceptedVariants, focusPhonemes
    }

    init(id: Int, category: SentenceCategory, french: String, english: String,
         difficulty: Int, keywords: [String], acceptedVariants: [String] = [],
         focusPhonemes: [String] = []) {
        self.id = id
        self.category = category
        self.french = french
        self.english = english
        self.difficulty = difficulty
        self.keywords = keywords
        self.acceptedVariants = acceptedVariants
        self.focusPhonemes = focusPhonemes
    }

    // Rétrocompatibilité avec le JSON actuel (les nouveaux champs sont absents).
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        category = try c.decode(SentenceCategory.self, forKey: .category)
        french = try c.decode(String.self, forKey: .french)
        english = try c.decode(String.self, forKey: .english)
        difficulty = try c.decode(Int.self, forKey: .difficulty)
        keywords = try c.decodeIfPresent([String].self, forKey: .keywords) ?? []
        acceptedVariants = try c.decodeIfPresent([String].self, forKey: .acceptedVariants) ?? []
        focusPhonemes = try c.decodeIfPresent([String].self, forKey: .focusPhonemes) ?? []
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(category, forKey: .category)
        try c.encode(french, forKey: .french)
        try c.encode(english, forKey: .english)
        try c.encode(difficulty, forKey: .difficulty)
        try c.encode(keywords, forKey: .keywords)
        try c.encodeIfPresent(acceptedVariants.isEmpty ? nil : acceptedVariants, forKey: .acceptedVariants)
        try c.encodeIfPresent(focusPhonemes.isEmpty ? nil : focusPhonemes, forKey: .focusPhonemes)
    }

    /// Toutes les formulations acceptables, la canonique en premier.
    var allTargets: [String] { [english] + acceptedVariants }
}
