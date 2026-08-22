import SwiftUI
import SwiftData

struct ReviewListView: View {
    // Same definition of "difficult" as ProgressQueries/SessionPlanner (#12).
    // #Predicate can't reference static type members directly — capture to locals first.
    private static let difficultPredicate: Predicate<SentenceProgress> = {
        let minAttempts = ProgressRules.difficultMinimumAttempts
        let mastery = ProgressRules.masteryScore
        return #Predicate<SentenceProgress> {
            $0.attempts >= minAttempts && $0.bestScore < mastery
        }
    }()

    @Environment(\.modelContext) private var context
    @Query(filter: ReviewListView.difficultPredicate,
           sort: \.bestScore)
    private var difficult: [SentenceProgress]

    /// Drives what the rows may show: in Repeat, French never appears.
    let mode: PracticeMode
    let onStartFocusedSession: ([LearningSentence]) -> Void

    var body: some View {
        List {
            if difficult.isEmpty {
                ContentUnavailableView(
                    "Nothing to review",
                    systemImage: "checkmark.circle",
                    description: Text("Sentences you struggle with will show up here."))
            } else {
                Section {
                    ForEach(difficult, id: \.sentenceID) { progress in
                        if let sentence = SentenceRepository.shared.sentence(id: progress.sentenceID) {
                            ReviewRow(sentence: sentence, progress: progress, mode: mode)
                        }
                    }
                } footer: {
                    Text("Sorted by lowest score. Practising these first is the fastest way to improve.")
                }
            }
        }
        .navigationTitle("To review")
        .safeAreaInset(edge: .bottom) {
            if !difficult.isEmpty {
                Button("Practise these \(difficult.count)") {
                    onStartFocusedSession(difficult.compactMap {
                        SentenceRepository.shared.sentence(id: $0.sentenceID)
                    })
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding()
                .background(.bar)
            }
        }
    }
}

struct ReviewRow: View {
    let sentence: LearningSentence
    let progress: SentenceProgress
    let mode: PracticeMode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(sentence.english).font(.body)
            if mode.showsFrenchPrompt {
                Text(sentence.french).font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Label("\(progress.bestScore)%", systemImage: "target")
                Label("\(progress.attempts)", systemImage: "arrow.counterclockwise")
                if let due = progress.dueDate {
                    Label(due.formatted(.relative(presentation: .named)),
                          systemImage: "calendar")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)

            ScoreSparkline(scores: progress.recentScores)
                .frame(height: 20)
        }
        .padding(.vertical, 4)
    }
}

struct ScoreSparkline: View {
    let scores: [Int]

    var body: some View {
        GeometryReader { geo in
            if scores.count >= 2 {
                let step = geo.size.width / CGFloat(scores.count - 1)
                let path = Path { p in
                    for (i, score) in scores.enumerated() {
                        let point = CGPoint(x: CGFloat(i) * step,
                                            y: geo.size.height * (1 - CGFloat(score) / 100))
                        i == 0 ? p.move(to: point) : p.addLine(to: point)
                    }
                }
                path.stroke(Theme.brand, lineWidth: 1.5)
            }
        }
        .accessibilityLabel("Score trend")
        .accessibilityValue(scores.map(String.init).joined(separator: ", "))
    }
}