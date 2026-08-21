import Foundation
import os

struct SentenceRepository: Sendable {
    /// Le catalogue est immuable et embarqué : une seule lecture par process.
    nonisolated static let shared = SentenceRepository()

    private let sentences: [LearningSentence]
    private let byID: [Int: LearningSentence]
    private let byCategory: [SentenceCategory: [LearningSentence]]

    private nonisolated init() {
        let loaded = Self.loadBundled()
        self.sentences = loaded
        self.byID = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
        self.byCategory = Dictionary(grouping: loaded, by: \.category)
    }

    /// Init d'injection — réservé aux tests.
    nonisolated init(sentences: [LearningSentence]) {
        self.sentences = sentences
        self.byID = Dictionary(loaded: sentences)
        self.byCategory = Dictionary(grouping: sentences, by: \.category)
    }

    nonisolated var all: [LearningSentence] { sentences }
    nonisolated var count: Int { sentences.count }

    nonisolated func sentence(id: Int) -> LearningSentence? { byID[id] }
    nonisolated func sentences(in category: SentenceCategory) -> [LearningSentence] { byCategory[category] ?? [] }

    private nonisolated static func loadBundled() -> [LearningSentence] {
        guard let url = Bundle.main.url(forResource: "sentences", withExtension: "json") else {
            Log.data.fault("sentences.json absent du bundle")
            assertionFailure("sentences.json missing from bundle")
            return []
        }
        do {
            return try JSONDecoder().decode([LearningSentence].self, from: Data(contentsOf: url))
        } catch {
            Log.data.fault("Décodage sentences.json: \(error, privacy: .public)")
            assertionFailure("Failed to decode sentences.json: \(error)")
            return []
        }
    }
}

private extension Dictionary where Key == Int, Value == LearningSentence {
    /// Tolère les doublons d'id en test (garde le premier) plutôt que de crasher.
    nonisolated init(loaded: [LearningSentence]) {
        self = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
