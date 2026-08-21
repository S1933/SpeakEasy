import SwiftUI

struct SessionSummaryView: View {
    let attempts: [AttemptResult]
    let sentences: [LearningSentence]
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            header
            statsCard

            if let best = bestAttempt {
                sentenceCard(title: "Best", sentence: best.sentence.english, score: best.result.score)
            }

            if let weak = needsPractice,
               weak.sentence.id != bestAttempt?.sentence.id {
                sentenceCard(title: "Needs practice", sentence: weak.sentence.english, score: weak.result.score)
            }

            Spacer(minLength: 8)

            Button(action: onDone) {
                Text("Done")
            }
            .buttonStyle(PrimaryButtonStyle())
            .accessibilityLabel("Done with session")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .navigationTitle("Session complete")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session complete")
                .font(.largeTitle.weight(.semibold))
            Text("\(attempts.count) sentences practiced")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statsCard: some View {
        VStack(spacing: 12) {
            row("Average accuracy", averageText)
            Divider()
            row("Completed", "\(completedCount) of \(attempts.count)")
            Divider()
            row("To review", "\(attempts.count - completedCount)")
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.body.weight(.medium))
        }
    }

    private func sentenceCard(title: String, sentence: String, score: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text("\u{201C}\(sentence)\u{201D}")
                .font(.body)
            Text("\(score)%")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var averageText: String {
        guard !attempts.isEmpty else { return "—" }
        let avg = Double(attempts.map(\.score).reduce(0, +)) / Double(attempts.count)
        return "\(Int(avg.rounded()))%"
    }

    private var completedCount: Int {
        attempts.filter { $0.score >= 85 }.count
    }

    private var bestAttempt: (sentence: LearningSentence, result: AttemptResult)? {
        guard !attempts.isEmpty, attempts.count == sentences.count else { return nil }
        let pairs = zip(sentences, attempts)
        return pairs.max { $0.1.score < $1.1.score }
    }

    private var needsPractice: (sentence: LearningSentence, result: AttemptResult)? {
        guard !attempts.isEmpty, attempts.count == sentences.count else { return nil }
        let pairs = zip(sentences, attempts)
        return pairs.min { $0.1.score < $1.1.score }
    }
}

#Preview {
    NavigationStack {
        SessionSummaryView(
            attempts: [
                AttemptResult(expected: "A", transcript: "A", score: 100, tokens: []),
                AttemptResult(expected: "B", transcript: "B", score: 68, tokens: [])
            ],
            sentences: [
                LearningSentence(id: 1, category: .opinions, french: "A", english: "A", difficulty: 1, keywords: []),
                LearningSentence(id: 2, category: .opinions, french: "B", english: "B", difficulty: 1, keywords: [])
            ],
            onDone: {}
        )
    }
}