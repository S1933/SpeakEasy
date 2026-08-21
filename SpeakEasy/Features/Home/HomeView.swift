import SwiftUI
import SwiftData

enum HomeRoute: Hashable {
    case practice
    case summary
    case settings
}

struct HomeView: View {
    @Environment(SpeechPlaybackService.self) var playback
    @Query var allProgress: [SentenceProgress]
    @Query var settingsList: [AppSettings]
    @State var path = NavigationPath()
    @State var sessionResults: SessionResults?

    struct SessionResults: Identifiable {
        let id = UUID()
        let attempts: [AttemptResult]
        let sentences: [LearningSentence]
    }

    private var totalSentences: Int { SentenceRepository().count }
    private var categories: Int { SentenceCategory.allCases.count }

    private var settings: AppSettings? { settingsList.first }

    private var todayCount: Int { ProgressQueries.todayAttemptCount(in: allProgress) }
    private var completedCount: Int { ProgressQueries.completedCount(in: allProgress) }
    private var difficultCount: Int { ProgressQueries.difficultCount(in: allProgress) }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(alignment: .leading, spacing: 24) {
                Spacer()

                VStack(alignment: .leading, spacing: 12) {
                    Text("SpeakEasy")
                        .font(.largeTitle.weight(.semibold))

                    Text("Practice your English,\none sentence at a time.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                statsCard

                ctas

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: HomeRoute.settings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .practice:
                    let size = settings?.sessionSize ?? 10
                    PracticeView(
                        playback: playback,
                        sessionSize: size,
                        onSessionComplete: { results, sentences in
                            sessionResults = SessionResults(
                                attempts: results,
                                sentences: sentences
                            )
                            path.append(HomeRoute.summary)
                        }
                    )
                case .summary:
                    if let results = sessionResults {
                        SessionSummaryView(
                            attempts: results.attempts,
                            sentences: results.sentences,
                            onDone: {
                                sessionResults = nil
                                path.removeLast(path.count)
                            }
                        )
                    }
                case .settings:
                    SettingsView()
                }
            }
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            statRow("Today", "\(todayCount) practiced")
            statRow("Progress", "\(completedCount) / \(totalSentences)")
            statRow("Difficult", "\(difficultCount) to review")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.body)
        }
    }

    private var ctas: some View {
        VStack(spacing: 12) {
            NavigationLink(value: HomeRoute.practice) {
                Text(primaryCTATitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.tint, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel(primaryCTATitle)

            Text("\(totalSentences) sentences across \(categories) categories")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private var primaryCTATitle: String {
        if allProgress.isEmpty { return "Start practicing" }
        return "Start practicing"
    }
}

#Preview {
    HomeView()
        .environment(SpeechPlaybackService())
        .modelContainer(for: [SentenceProgress.self, AppSettings.self], inMemory: true)
}