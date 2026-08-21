import Foundation
import SwiftData

@Model
final class AppSettings {
    var sessionSize: Int
    var voiceLocale: String
    var preferredMode: String

    init(sessionSize: Int = 10,
         voiceLocale: String = "en-US",
         preferredMode: String = PracticeMode.repeatAfter.rawValue) {
        self.sessionSize = sessionSize
        self.voiceLocale = voiceLocale
        self.preferredMode = preferredMode
    }
}

enum VoiceOption: String, CaseIterable, Identifiable, Sendable {
    case enUS = "en-US"
    case enGB = "en-GB"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .enUS: return "English (US)"
        case .enGB: return "English (UK)"
        }
    }
}

enum SessionSizeOption: Int, CaseIterable, Identifiable, Sendable {
    case five = 5
    case ten = 10
    case twenty = 20

    var id: Int { rawValue }

    var displayName: String { "\(rawValue)" }
}

extension AppSettings {
    /// Récupère l'unique instance, la crée si absente.
    /// ⚠️ Ne jamais appeler depuis `body` — uniquement depuis `.task`, `onAppear`
    /// ou l'init de l'app.
    @MainActor
    static func current(in context: ModelContext) -> AppSettings {
        var descriptor = FetchDescriptor<AppSettings>()
        descriptor.fetchLimit = 1
        if let existing = try? context.fetch(descriptor).first { return existing }

        let created = AppSettings()
        context.insert(created)
        do { try context.save() }
        catch { Log.data.error("Création AppSettings: \(error, privacy: .public)") }
        return created
    }
}