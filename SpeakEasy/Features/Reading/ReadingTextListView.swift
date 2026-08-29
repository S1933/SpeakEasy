import SwiftUI
import SwiftData

/// Catalog of all reading texts. Sorted by difficulty, with a per-text
/// progress badge. No gating — all texts are accessible from the start.
///
/// Navigation is driven by an `onSelect` callback rather than internal
/// `NavigationLink(value:)` — the host stack handles the actual push, so
/// this view does not embed its own `NavigationStack`.
struct ReadingTextListView: View {
    @Query(sort: \ReadingProgress.bestAccuracy, order: .reverse)
    private var progress: [ReadingProgress]

    var onSelect: (ReadingText) -> Void = { _ in }

    var body: some View {
        List {
            ForEach(ReadingRepository.shared.all) { text in
                Button {
                    onSelect(text)
                } label: {
                    row(for: text)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    private func row(for text: ReadingText) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(text.title)
                    .font(.body.weight(.medium))
                Spacer()
                difficultyBadge(text.difficulty)
            }
            Text(subtitle(for: text))
                .font(.caption)
                .foregroundStyle(.secondary)
            if let best = bestAccuracy(for: text.id), best > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Best: \(best)%")
                }
                .font(.caption2)
                .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private func difficultyBadge(_ level: Int) -> some View {
        Text("Lvl \(level)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.tint.opacity(0.15), in: Capsule())
            .foregroundStyle(.tint)
    }

    private func subtitle(for text: ReadingText) -> String {
        let kind = text.kind == .conversation ? "Dialogue" : "Story"
        return "\(kind) · \(text.wordCount) words"
    }

    private func bestAccuracy(for textId: Int) -> Int? {
        progress.first { $0.textId == textId }?.bestAccuracy
    }
}
