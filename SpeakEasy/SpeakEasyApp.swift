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
        case recoveredFromCorruption   // store recreated, progress lost
        case ephemeral                 // in-memory, nothing will be saved
    }

    init() {
        let (container, health) = Self.makeContainer()
        self.container = container
        _storeHealth = State(initialValue: health)
    }

    private static func makeContainer() -> (ModelContainer, StoreHealth) {
        let schema = Schema([SentenceProgress.self, AppSettings.self,
                             DailyActivity.self, ReadingProgress.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        // Stage 1 — nominal.
        do {
            let c = try ModelContainer(for: schema, configurations: config)
            return (c, .healthy)
        } catch {
            Log.data.error("Unable to open store: \(error, privacy: .public)")
        }

        // Stage 2 — unreadable store: set it aside and start fresh.
        // We ARCHIVE rather than delete (recoverable via support), including
        // the WAL/SHM journals which would render the store unreadable again
        // if left next to a recreated store.
        if FileManager.default.fileExists(atPath: config.url.path) {
            archiveStore(at: config.url, timestamp: Int(Date.now.timeIntervalSince1970))
            Log.data.fault("Store archived to \(config.url.lastPathComponent, privacy: .public)")
            if let c = try? ModelContainer(for: schema, configurations: config) {
                return (c, .recoveredFromCorruption)
            }
        }

        // Stage 3 — last resort: ephemeral session. The app remains usable.
        let memory = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let c = try! ModelContainer(for: schema, configurations: memory)
        Log.data.fault("Falling back to ephemeral storage")
        return (c, .ephemeral)
    }

    /// Archives the store and its WAL/SHM journals under a timestamped suffix,
    /// to allow manual recovery if needed. Never deletes.
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
