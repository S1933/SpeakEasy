import SwiftUI

struct LiveTranscriptView: View {
    let finalized: String
    let volatile: String

    var body: some View {
        Group {
            if finalized.isEmpty && volatile.isEmpty {
                Text("Listening…")
                    .foregroundStyle(.tertiary)
            } else {
                (Text(finalized).foregroundStyle(.primary)
                 + Text(finalized.isEmpty || volatile.isEmpty ? "" : " ")
                 + Text(volatile).foregroundStyle(.secondary))
                    .contentTransition(.interpolate)
            }
        }
        .font(.title3)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .center)
        .animation(.easeOut(duration: 0.15), value: volatile)
        .accessibilityLabel("Live transcription")
        .accessibilityValue(finalized + " " + volatile)
    }
}