import SwiftUI

struct SentenceRow: View {
    let sentence: LearningSentence
    let mode: PracticeMode
    let isRevealed: Bool
    let onReveal: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            if mode.showsEnglishBeforeRecording {
                // Repeat: the English sentence IS the exercise. Nothing else
                // is shown — no French, no reveal, no translation step.
                Text(sentence.english)
                    .font(.title2)
                    .multilineTextAlignment(.center)
            } else {
                Text(sentence.french)
                    .font(.title2)
                    .multilineTextAlignment(.center)

                if isRevealed {
                    Text(sentence.english)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .transition(.opacity.combined(with: .blurReplace))
                } else if mode.allowsReveal {
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
        }
        .frame(maxWidth: .infinity)
        .animation(.easeOut(duration: 0.25), value: isRevealed)
        .accessibilityElement(children: .combine)
    }
}
