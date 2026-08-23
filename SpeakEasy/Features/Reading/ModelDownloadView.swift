import SwiftUI

/// Waiting screen shown while the on-device speech model downloads on first
/// launch of the reading mode. Purely presentational: the download itself is
/// owned by `ReadingFlowView` (single `.task`, no double-prepare).
///
/// The SDK's `downloadAndInstall()` exposes no progress callback, so this is
/// an indeterminate spinner rather than a progress bar.
struct ModelDownloadView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "arrow.down.circle")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Downloading speech model")
                    .font(.title2.weight(.semibold))
                Text("Required to transcribe your reading on this device.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            ProgressView()
                .controlSize(.large)

            Spacer()
        }
        .padding()
    }
}
