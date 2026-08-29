import SwiftUI
import SwiftData

/// Result screen for one reading session. Loads the previous best ONCE
/// (guarded so a re-appearance after recording doesn't capture the attempt
/// it just wrote), then records the new one.
struct ReadingResultView: View {
    let result: ReadingResult
    let text: ReadingText
    /// Same filter the session used — the result's token indices refer to
    /// the filtered reference, so the revisit list must match it.
    let spokenSpeaker: String?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allProgress: [ReadingProgress]

    @State private var previousBest: ReadingProgress?
    @State private var saved = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                scoreHeader

                if let previous = previousBest, previous.attempts > 0 {
                    comparisonRow(previous: previous)
                }

                metricsSection
                missedWordsSection
            }
            .padding()
        }
        .navigationTitle("Result")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .task {
            snapshotPreviousBest()
            recordAttempt()
        }
    }

    // MARK: - Sections

    private var scoreHeader: some View {
        VStack(spacing: 8) {
            Text("\(result.accuracy)%")
                .font(.system(size: 64, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(scoreColor(result.accuracy))
            Text("accuracy")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func comparisonRow(previous: ReadingProgress) -> some View {
        let delta = result.accuracy - previous.bestAccuracy
        return HStack {
            Label("Best so far", systemImage: "trophy")
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(previous.bestAccuracy)%")
                .foregroundStyle(.secondary)
            Text(delta >= 0 ? "+\(delta)" : "\(delta)")
                .foregroundStyle(delta >= 0 ? .green : .secondary)
                .monospacedDigit()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var metricsSection: some View {
        HStack(spacing: 12) {
            metricCard(title: "WCPM", value: "\(result.wcpm)",
                       subtitle: result.paceBand.label, tint: .blue)
            metricCard(title: "Insertions", value: "\(result.insertions)",
                       subtitle: "extra words", tint: .purple)
        }
    }

    private func metricCard(title: String, value: String,
                            subtitle: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var missedWordsSection: some View {
        // Token ids ARE the absolute reference indices the scorer reported.
        if !wordsToRevisit.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Words to revisit")
                    .font(.headline)
                Text(wordsToRevisit.joined(separator: " · "))
                    .font(.body)
                    .foregroundStyle(.orange)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Helpers

    /// Raw words of the tokens the scorer flagged, in reading order.
    private var wordsToRevisit: [String] {
        let flagged = Set(result.missedIndices).union(result.substitutedIndices)
        return ReadingTokenizer.tokenize(text, spokenSpeaker: spokenSpeaker)
            .filter { flagged.contains($0.id) }
            .map(\.raw)
    }

    private func scoreColor(_ accuracy: Int) -> Color {
        switch accuracy {
        case 90...:  .green
        case 70..<90: .yellow
        default:     .orange
        }
    }

    /// Captures the previous best BEFORE we write the new attempt — and only
    /// once. Without the guard, a re-appearance (navigation bounce) would
    /// capture the attempt this very view just recorded and compare it to
    /// itself.
    private func snapshotPreviousBest() {
        guard previousBest == nil else { return }
        previousBest = allProgress.first { $0.textId == text.id && $0.attempts > 0 }
    }

    private func recordAttempt() {
        guard !saved else { return }
        saved = true
        let entry = allProgress.first { $0.textId == text.id }
            ?? ReadingProgress(textId: text.id)
        entry.attempts += 1
        entry.bestAccuracy = max(entry.bestAccuracy, result.accuracy)
        entry.bestWCPM = max(entry.bestWCPM, result.wcpm)
        entry.lastReadAt = .now
        if entry.modelContext == nil {
            context.insert(entry)
        }
        try? context.save()
    }
}

private extension PaceBand {
    var label: String {
        switch self {
        case .tooSlow: "too slow"
        case .good:    "good pace"
        case .tooFast: "rushed"
        }
    }
}
