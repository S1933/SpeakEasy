import Foundation
import SwiftData
import Testing
@testable import SpeakEasy

@Suite("Migration")
struct SchemaMigrationTests {

    @Test("Migration V1 → V2 sans perte")
    func migration() throws {
        let url = URL.temporaryDirectory.appending(path: "\(UUID()).store")
        defer { try? FileManager.default.removeItem(at: url) }

        // 1. Écrire avec le schéma V1
        do {
            let c = try ModelContainer(
                for: Schema(versionedSchema: SpeakEasySchemaV1.self),
                configurations: ModelConfiguration(url: url))
            c.mainContext.insert(SentenceProgress(sentenceID: 7, attempts: 3, bestScore: 90))
            try c.mainContext.save()
        }

        // 2. Rouvrir avec le plan complet
        let c2 = try ModelContainer(
            for: Schema(versionedSchema: SpeakEasySchemaV2.self),
            migrationPlan: SpeakEasyMigrationPlan.self,
            configurations: ModelConfiguration(url: url))

        let restored = try c2.mainContext.fetch(FetchDescriptor<SentenceProgress>())
        #expect(restored.count == 1)
        #expect(restored[0].bestScore == 90)
        #expect(restored[0].dueDate != nil)      // renseigné par didMigrate
    }
}
