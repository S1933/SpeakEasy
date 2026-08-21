import SwiftUI
import SwiftData

@main
struct SpeakEasyApp: App {
    @State private var playback = SpeechPlaybackService()
    private let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: SentenceProgress.self, AppSettings.self
            )
        } catch {
            fatalError("Failed to set up SwiftData container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(playback)
        }
        .modelContainer(container)
    }
}