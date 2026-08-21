import SwiftUI

struct SentenceRow: View {
    let sentence: LearningSentence
    let mode: PracticeMode
    let isRevealed: Bool
    let onReveal: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text(sentence.french)
                .font(.title2)
                .multilineTextAlignment(.center)

            if mode.showsEnglishBeforeRecording || isRevealed {
                Text(sentence.english)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .transition(.opacity.combined(with: .blurReplace))
            } else {
                Button {
                    withAnimation(.easeOut(duration: 0.25)) { onReveal() }
                } label: {
                    Label("Show the answer", systemImage: "eye")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Reveals the English sentence. Your score won't count as unaided.")
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.25), value: isRevealed)
        .accessibilityElement(children: .combine)
    }
}
