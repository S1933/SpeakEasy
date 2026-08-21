import os
import SwiftUI
import SwiftData

@main
struct SpeakEasyApp: App {
    @State private var playback = SpeechPlaybackService()
    @State private var assetManager = SpeechAssetManager()
    @State private var storeHealth: StoreHealth
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    private let container: ModelContainer

    enum StoreHealth: Equatable {
        case healthy
        case recoveredFromCorruption   // store recréé, progression perdue
        case ephemeral                 // in-memory, rien ne sera sauvegardé
    }

    init() {
        let (container, health) = Self.makeContainer()
        self.container = container
        _storeHealth = State(initialValue: health)
    }

    private static func makeContainer() -> (ModelContainer, StoreHealth) {
        let schema = Schema(versionedSchema: SpeakEasySchemaV2.self)
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Palier 1 — nominal, avec plan de migration.
        var openError: (any Error)?
        do {
            let c = try ModelContainer(for: schema,
                                       migrationPlan: SpeakEasyMigrationPlan.self,
                                       configurations: config)
            return (c, .healthy)
        } catch {
            openError = error
            Log.data.error("Ouverture du store impossible: \(error, privacy: .public)")
        }

        // Palier 2 — store illisible : on le met de côté et on repart à neuf.
        // On ARCHIVE plutôt que de supprimer : récupérable via support.
        if let url = config.url as URL?, FileManager.default.fileExists(atPath: url.path) {
            let isLegacyPreV1 = (openError as NSError?)?.localizedDescription.contains("unknown model version") ?? false
            let suffix = isLegacyPreV1
                ? "legacy-preV1-\(Int(Date.now.timeIntervalSince1970))"
                : "corrupt-\(Int(Date.now.timeIntervalSince1970))"
            let backup = url.appendingPathExtension(suffix)
            try? FileManager.default.moveItem(at: url, to: backup)
            Log.data.fault("Store archivé vers \(backup.lastPathComponent, privacy: .public)")
            if let c = try? ModelContainer(for: schema, configurations: config) {
                return (c, .recoveredFromCorruption)
            }
        }

        // Palier 3 — dernier recours : session éphémère. L'app reste utilisable.
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let c = try! ModelContainer(for: schema, configurations: memory)
        Log.data.fault("Bascule en stockage éphémère")
        return (c, .ephemeral)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    HomeView()
                } else {
                    OnboardingView(
                        locale: Locale(identifier: "en-US"),
                        assets: assetManager,
                        onReady: { hasCompletedOnboarding = true }
                    )
                }
            }
            .environment(playback)
            .environment(assetManager)
            .storeHealthBanner(storeHealth)
            .task {
                let settings = AppSettings.current(in: container.mainContext)
                playback.localeIdentifier = settings.voiceLocale
            }
        }
        .modelContainer(container)
    }
}

extension View {
    @ViewBuilder
    func storeHealthBanner(_ health: SpeakEasyApp.StoreHealth) -> some View {
        switch health {
        case .healthy:
            self
        case .recoveredFromCorruption:
            safeAreaInset(edge: .top) {
                InlineBanner(icon: "arrow.counterclockwise",
                             text: "Your progress data couldn't be read and has been reset.")
            }
        case .ephemeral:
            safeAreaInset(edge: .top) {
                InlineBanner(icon: "exclamationmark.triangle",
                             text: "Progress won't be saved this session.")
            }
        }
    }
}
