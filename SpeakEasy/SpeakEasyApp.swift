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
        let schema = Schema([SentenceProgress.self, AppSettings.self, DailyActivity.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Palier 1 — nominal.
        do {
            let c = try ModelContainer(for: schema, configurations: config)
            return (c, .healthy)
        } catch {
            Log.data.error("Ouverture du store impossible: \(error, privacy: .public)")
        }

        // Palier 2 — store illisible : on le met de côté et on repart à neuf.
        // On ARCHIVE plutôt que de supprimer (récupérable via support), en
        // incluant les journaux WAL/SHM qui rendraient le store à nouveau
        // illisible s'ils étaient laissés à côté d'un store recréé.
        if let url = config.url, FileManager.default.fileExists(atPath: url.path) {
            archiveStore(at: url, timestamp: Int(Date.now.timeIntervalSince1970))
            Log.data.fault("Store archivé vers \(url.lastPathComponent, privacy: .public)")
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

    /// Archive le store et ses journaux WAL/SHM sous un suffixe horodaté, pour
    /// permettre une récupération manuelle si besoin. Ne supprime jamais.
    private static func archiveStore(at url: URL, timestamp: Int) {
        let archive = url.appendingPathExtension("corrupt-\(timestamp)")  // default.store.corrupt-<ts>
        for (sidecar, archived) in [("", ""), ("-wal", "-wal"), ("-shm", "-shm")] {
            let src = URL(fileURLWithPath: url.path + sidecar)
            guard FileManager.default.fileExists(atPath: src.path) else { continue }
            let destination = URL(fileURLWithPath: archive.path + archived)
            try? FileManager.default.moveItem(at: src, to: destination)
        }
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
