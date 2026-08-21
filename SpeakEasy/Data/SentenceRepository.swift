import Foundation

struct SentenceRepository: Sendable {
    private let sentences: [LearningSentence]

    nonisolated init() {
        self.sentences = SentenceRepository.loadBundled()
    }

    nonisolated init(sentences: [LearningSentence]) {
        self.sentences = sentences
    }

    var all: [LearningSentence] { sentences }

    var count: Int { sentences.count }

    func sentence(at index: Int) -> LearningSentence? {
        guard sentences.indices.contains(index) else { return nil }
        return sentences[index]
    }

    private nonisolated static func loadBundled() -> [LearningSentence] {
        guard let url = Bundle.main.url(forResource: "sentences", withExtension: "json") else {
            assertionFailure("sentences.json missing from bundle")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode([LearningSentence].self, from: data)
        } catch {
            assertionFailure("Failed to decode sentences.json: \(error)")
            return []
        }
    }
}