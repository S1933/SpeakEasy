import SwiftUI
import SwiftData

enum HomeRoute: Hashable {
    case practice
    case focused([LearningSentence])
    case review
    case summary
    case settings
    case reading
}

struct HomeView: View {
    @Environment(SpeechPlaybackService.self) var playback
    @Environment(\.modelContext) private var context
    @Query var settingsList: [AppSettings]
    @State var path = NavigationPath()
    @State var sessionResults: SessionResults?
    @State private var stats = HomeStats()
    @State private var selectedMode: PracticeMode = .repeatAfter

    struct SessionResults: Identifiable {
        let id = UUID()
        let attempts: [AttemptResult]
        let sentences: [LearningSentence]
    }

    struct HomeStats: Equatable {
        var today = 0, completed = 0, difficult = 0, streak = 0
    }

    private var totalSentences: Int { SentenceRepository.shared.count }
    private var categories: Int { SentenceCategory.allCases.count }
    private var settings: AppSettings? { settingsList.first }

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

                modePicker

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
                    makePracticeView(queue: buildPracticeQueue())
                case .focused(let queue):
                    makePracticeView(queue: queue)
                case .review:
                    ReviewListView(mode: selectedMode) { sentences in
                        path.append(HomeRoute.focused(sentences))
                    }
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
                case .reading:
                    ReadingFlowView(path: $path)
                }
            }
            .navigationDestination(for: ReadingDestination.self) { destination in
                switch destination {
                case .setup(let text):
                    ReadingSetupView(text: text) { spokenSpeaker in
                        path.append(ReadingDestination.read(text: text, spokenSpeaker: spokenSpeaker))
                    }
                case .read(let text, let spokenSpeaker):
                    ReadingView(text: text, spokenSpeaker: spokenSpeaker, playback: playback) { result in
                        path.append(ReadingDestination.result(text: text, result: result, spokenSpeaker: spokenSpeaker))
                    }
                case .result(let text, let result, let spokenSpeaker):
                    ReadingResultView(result: result, text: text, spokenSpeaker: spokenSpeaker)
                }
            }
            .task(id: path.count) {
                await refreshStats()
                let resolved = PracticeMode.resolve(settings?.preferredMode)
                selectedMode = resolved
                // Migrates a value persisted by an older build (e.g. "recall").
                if let settings, settings.preferredMode != resolved.rawValue {
                    settings.preferredMode = resolved.rawValue
                    try? context.save()
                }
            }
            .onChange(of: selectedMode) { _, newMode in
                if let settings {
                    settings.preferredMode = newMode.rawValue
                    try? context.save()
                }
            }
        }
    }

    private var modePicker: some View {
        VStack(spacing: 8) {
            Picker("Practice mode", selection: $selectedMode) {
                ForEach(PracticeMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Practice mode")

            Text(selectedMode.subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var statsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            statRow("Today", "\(stats.today) practiced")
            statRow("Progress", "\(stats.completed) / \(totalSentences)")
            NavigationLink(value: HomeRoute.review) {
                statRow("Difficult", "\(stats.difficult) to review")
            }
            .buttonStyle(.plain)
            if stats.streak > 1 { statRow("Streak", "\(stats.streak) days") }
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

    private func refreshStats() async {
        stats = HomeStats(
            today: ProgressQueries.todayAttemptCount(in: context),
            completed: ProgressQueries.completedCount(in: context),
            difficult: ProgressQueries.difficultCount(in: context),
            streak: ProgressQueries.currentStreak(in: context)
        )
    }

    private var ctas: some View {
        VStack(spacing: 12) {
            NavigationLink(value: HomeRoute.practice) {
                Text(primaryCTATitle)
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel(primaryCTATitle)

            NavigationLink(value: HomeRoute.reading) {
                Label("Reading mode", systemImage: "book")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityLabel("Reading mode")

            Text("\(totalSentences) sentences across \(categories) categories")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
        }
    }

    private var primaryCTATitle: String { "Start practicing" }

    private func makePracticeView(queue: [LearningSentence]) -> some View {
        PracticeView(
            queue: queue,
            playback: playback,
            localeIdentifier: settings?.voiceLocale ?? "en-US",
            mode: selectedMode,
            recordAttempt: { id, score in
                ProgressService(context: context).recordAttempt(sentenceID: id, score: score)
            },
            finalizeReview: { id, score in
                ProgressService(context: context).finalizeReview(sentenceID: id, score: score)
            },
            onSessionComplete: { results, sentences in
                sessionResults = SessionResults(attempts: results, sentences: sentences)
                path.append(HomeRoute.summary)
            }
        )
    }

    private func buildPracticeQueue() -> [LearningSentence] {
        let allProgress = (try? context.fetch(FetchDescriptor<SentenceProgress>())) ?? []
        let snapshots = Dictionary(
            uniqueKeysWithValues: allProgress.map {
                ($0.sentenceID, SessionPlanner.Snapshot(
                    attempts: $0.attempts,
                    bestScore: $0.bestScore,
                    lastPracticedAt: $0.lastPracticedAt,
                    dueDate: $0.dueDate,
                    isCompleted: $0.isCompleted
                ))
            }
        )
        return SessionPlanner().buildQueue(
            size: settings?.sessionSize ?? 10,
            progress: snapshots
        )
    }
}

#Preview {
    HomeView()
        .environment(SpeechPlaybackService())
        .modelContainer(for: [SentenceProgress.self, AppSettings.self, DailyActivity.self], inMemory: true)
}
