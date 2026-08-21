import SwiftUI

struct ResultContent: View {
    @ScaledMetric(relativeTo: .largeTitle) private var scoreSize: CGFloat = 56

    let progressText: String
    let result: AttemptResult
    let feedback: FeedbackService.Feedback
    let retryTitle: String
    let nextTitle: String
    let onRetry: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(progressText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Text(bucket.label)
                    .font(.title2.weight(.semibold))
                Text("\(result.score)%")
                    .font(.system(size: scoreSize, weight: .light, design: .rounded))
                    .monospacedDigit()
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(bucket.label), \(result.score) percent")

            TokenResultRow(tokens: result.tokens)

            VStack(alignment: .leading, spacing: 8) {
                Text("You said")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\"\(result.transcript)\"")
                    .font(.body)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(feedback.headline)
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let detail = feedback.detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let tip = feedback.tip {
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .italic()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button(action: onRetry) {
                    Text(retryTitle)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }

                Button(action: onNext) {
                    Text(nextTitle)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var bucket: ScoreBucket {
        ScoreBucket(score: result.score)
    }
}

enum ScoreBucket {
    case excellent, great, good, keep, tryAgain

    init(score: Int) {
        switch score {
        case 95...100: self = .excellent
        case 85...94: self = .great
        case 70...84: self = .good
        case 50...69: self = .keep
        default: self = .tryAgain
        }
    }

    var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .great: return "Great"
        case .good: return "Good attempt"
        case .keep: return "Keep practicing"
        case .tryAgain: return "Try again"
        }
    }
}

struct TokenResultRow: View {
    let tokens: [TokenResult]

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                tokenChip(token)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func tokenChip(_ token: TokenResult) -> some View {
        let style = chipStyle(token)
        HStack(spacing: 4) {
            if let symbol = style.symbol {
                Image(systemName: symbol)
                    .font(.caption2.weight(.bold))
                    .accessibilityHidden(true)
            }
            Text(token.text)
        }
        .font(.body.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(style.background, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(style.border, style: StrokeStyle(lineWidth: 1, dash: style.dashed ? [3, 2] : []))
        )
        .foregroundStyle(style.foreground)
        .accessibilityLabel(accessibilityLabel(for: token))
    }

    private struct ChipStyle {
        var background: Color
        var border: Color
        var foreground: Color
        var symbol: String?
        var dashed: Bool
    }

    /// Five states, three redundant channels (symbol + stroke + color):
    /// readable even in grayscale / for color blindness.
    private func chipStyle(_ token: TokenResult) -> ChipStyle {
        switch token.status {
        case .correct:
            return ChipStyle(background: .clear, border: .secondary.opacity(0.3),
                             foreground: .primary, symbol: nil, dashed: false)
        case .nearMiss:
            return ChipStyle(background: .yellow.opacity(0.2), border: .yellow.opacity(0.7),
                             foreground: .yellow, symbol: "waveform", dashed: false)
        case .missing:
            return ChipStyle(background: .red.opacity(0.15), border: .red.opacity(0.6),
                             foreground: .red, symbol: "minus.circle", dashed: true)
        case .incorrect:
            return ChipStyle(background: .orange.opacity(0.15), border: .orange.opacity(0.6),
                             foreground: .orange, symbol: "arrow.triangle.swap", dashed: false)
        case .extra:
            return ChipStyle(background: .gray.opacity(0.15), border: .gray.opacity(0.5),
                             foreground: .secondary, symbol: "plus.circle", dashed: true)
        }
    }

    private func accessibilityLabel(for token: TokenResult) -> String {
        switch token.status {
        case .correct: return "\(token.text), correct"
        case .nearMiss(let actual, _): return "\(token.text), close, you said \(actual)"
        case .missing: return "\(token.text), missing"
        case .incorrect(let actual): return "\(token.text), you said \(actual)"
        case .extra: return "\(token.text), extra"
        }
    }
}

struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var rows: [[CGSize]] = [[]]
        var currentWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if currentWidth + size.width > width, !rows[rows.count - 1].isEmpty {
                rows.append([])
                currentWidth = 0
            }
            rows[rows.count - 1].append(size)
            currentWidth += size.width + spacing
        }
        let height = rows.reduce(0) { sum, row in
            sum + (row.map(\.height).max() ?? 0) + spacing
        } - (rows.isEmpty ? 0 : spacing)
        let maxWidth = rows.map { row in row.reduce(0) { $0 + $1.width + spacing } - spacing }.max() ?? 0
        return CGSize(width: maxWidth, height: max(0, height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
