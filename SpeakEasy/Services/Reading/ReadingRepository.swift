import Foundation
import os

struct ReadingRepository: Sendable {
    /// The catalog is immutable and bundled: read once per process.
    nonisolated static let shared = ReadingRepository()

    private let texts: [ReadingText]
    private let byID: [Int: ReadingText]

    private nonisolated init() {
        let loaded = Self.loadBundled()
        self.texts = loaded
        self.byID = Dictionary(uniqueKeysWithValues: loaded.map { ($0.id, $0) })
    }

    nonisolated init(texts: [ReadingText]) {
        self.texts = texts
        self.byID = Dictionary(loaded: texts)
    }

    nonisolated var all: [ReadingText] { texts }
    nonisolated var count: Int { texts.count }

    nonisolated func text(id: Int) -> ReadingText? { byID[id] }

    private nonisolated static func loadBundled() -> [ReadingText] {
        guard let url = Bundle.main.url(forResource: "reading_texts", withExtension: "json") else {
            Log.data.fault("reading_texts.json absent du bundle")
            assertionFailure("reading_texts.json missing from bundle")
            return []
        }
        do {
            return try JSONDecoder().decode([ReadingText].self, from: Data(contentsOf: url))
        } catch {
            Log.data.fault("Décodage reading_texts.json: \(error, privacy: .public)")
            assertionFailure("Failed to decode reading_texts.json: \(error)")
            return []
        }
    }
}

private extension Dictionary where Key == Int, Value == ReadingText {
    /// Tolerates duplicate ids in tests (keeps the first) instead of crashing.
    nonisolated init(loaded: [ReadingText]) {
        self = Dictionary(loaded.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }
}