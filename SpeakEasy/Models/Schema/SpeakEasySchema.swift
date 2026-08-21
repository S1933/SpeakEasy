import Foundation
import os
import SwiftData

/// Règle d'or : une fois une version publiée, ne JAMAIS modifier un
/// VersionedSchema existant — ajoute-en un nouveau et une étape de migration.
enum SpeakEasySchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SentenceProgress.self, AppSettings.self]
    }
}

enum SpeakEasySchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static var models: [any PersistentModel.Type] {
        [SentenceProgress.self, AppSettings.self, DailyActivity.self]
    }
}

enum SpeakEasyMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SpeakEasySchemaV1.self, SpeakEasySchemaV2.self]
    }

    static var stages: [MigrationStage] { [v1toV2] }

    /// V2 ajoute DailyActivity + les champs de planification SM-2
    /// (valeurs par défaut fournies par l'init) → migration légère suffisante.
    /// L'étape `didMigrate` reconstruit les échéances de révision à partir de
    /// l'historique existant, pour ne pas noyer l'utilisateur sous les révisions.
    static let v1toV2 = MigrationStage.custom(
        fromVersion: SpeakEasySchemaV1.self,
        toVersion: SpeakEasySchemaV2.self,
        willMigrate: nil,
        didMigrate: { context in
            let all = try context.fetch(FetchDescriptor<SentenceProgress>())
            for progress in all where progress.dueDate == nil {
                // Étale les échéances sur 7 jours pour lisser la charge.
                let offset = Double(progress.sentenceID % 7) * 86_400
                progress.dueDate = (progress.lastPracticedAt ?? .now).addingTimeInterval(offset)
                progress.easeFactor = progress.bestScore >= 85 ? 2.5 : 2.0
            }
            try context.save()
            Log.data.notice("Migration V1→V2: \(all.count, privacy: .public) enregistrements")
        }
    )
}
