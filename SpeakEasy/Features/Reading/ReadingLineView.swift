import SwiftUI

/// Renders one `ReadingLine` as a single `Text` built from an `AttributedString`.
/// One view per line, not one per word — at 100 words × 10 Hz, the difference
/// between 1 view and 100 views is the difference between a smooth scroll and
/// a frozen one.
///
/// The view is `Equatable` and applied with `.equatable()` by the parent: a
/// full-snapshot update at 10 Hz only re-runs the `body` of the lines whose
/// per-line `states` actually changed — the rest are skipped entirely, so
/// their `AttributedString` is not rebuilt for nothing.
struct ReadingLineView: View, Equatable {
    let line: ReadingLine
    let tokens: [ReadingToken]
    let states: [ReadingTokenState]
    /// Absolute id of the token carrying the underline, or nil when the
    /// cursor is not on this line. Driven by the anticipatory display
    /// cursor — see `CursorAnticipator`.
    let cursorTokenID: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let speaker = line.speaker {
                Text(speaker)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Text(attributed)
                .font(.title3)
                .lineSpacing(8)
        }
    }

    /// The display-state table from §5.4 of the design doc: confirmed
    /// errors show, premature accusations don't. `states[i]` is the
    /// per-line slice projected by the view model.
    private var attributed: AttributedString {
        var out = AttributedString()
        for (i, token) in tokens.enumerated() {
            let state = i < states.count ? states[i] : .pending
            var piece = AttributedString(token.raw + " ")
            switch state {
            case .pending:
                // The underline marks the estimated reading position, which
                // may run a few words ahead of confirmed alignment.
                let isCursor = token.id == cursorTokenID
                piece.foregroundColor = isCursor ? .primary : .secondary
                if isCursor { piece.underlineStyle = .single }
            case .correct:
                piece.foregroundColor = .primary
            case .substituted:
                piece.foregroundColor = .orange
            case .missed:
                piece.foregroundColor = .secondary
                piece.underlineStyle = .init(pattern: .dot, color: .orange)
            }
            out += piece
        }
        return out
    }
}
