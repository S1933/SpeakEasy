import Foundation

struct LearningSentence: Identifiable, Codable, Sendable, Hashable {
    let id: Int
    let category: SentenceCategory
    let french: String
    let english: String
    let difficulty: Int
    let keywords: [String]
}
