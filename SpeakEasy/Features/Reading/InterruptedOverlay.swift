import SwiftUI

/// Shown when an audio interruption pauses the session. We don't auto-resume:
/// the user decides when to put the mic back on.
struct InterruptedOverlay: View {
    let cursor: Int
    var onResume: () -> Void
    var onCancel: () -> Void

    /// Where the reader will pick up — two words before the cursor so they
    /// have context to restart their phrasing.
    private var resumeAt: Int { max(0, cursor - 2) }

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "pause.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)

                Text("Reading paused")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)

                Text("Resume from word \(resumeAt + 1)")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.85))

                VStack(spacing: 12) {
                    Button {
                        onResume()
                    } label: {
                        Label("Resume here", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(role: .cancel) {
                        onCancel()
                    } label: {
                        Text("End session")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(.white)
                }
                .padding(.horizontal, 24)
            }
            .padding(32)
            .frame(maxWidth: 360)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
        .accessibilityElement(children: .contain)
    }
}
