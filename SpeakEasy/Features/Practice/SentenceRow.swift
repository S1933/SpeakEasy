import SwiftUI

struct SentenceRow: View {
    let sentence: LearningSentence

    var body: some View {
        VStack(spacing: 24) {
            Text(sentence.french)
                .font(.title2)
                .multilineTextAlignment(.center)
            Text(sentence.english)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}
