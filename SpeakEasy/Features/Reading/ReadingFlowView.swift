import SwiftUI
import SwiftData

/// A route pushed onto the host NavigationStack. Splitting it from HomeRoute
/// keeps the host declaration's switch exhaustive and readable.
enum ReadingDestination: Hashable {
    /// Speaker-picker for a dialogue. ReadingSetupView then pushes `.read`.
    case setup(text: ReadingText)
    /// The actual reading session. ReadingView pushes `.result` on finish.
    case read(text: ReadingText, spokenSpeaker: String?)
    /// The post-session summary. Carries `spokenSpeaker` so the
    /// "words to revisit" indices line up with the filtered reference.
    case result(text: ReadingText, result: ReadingResult, spokenSpeaker: String?)
}

/// Reading mode entry: shows the text catalog once the speech model is ready,
/// then drives deeper navigation through the *enclosing* NavigationStack.
///
/// This view intentionally does NOT carry its own NavigationStack: doing so
/// inside a destination view breaks `navigationDestination` resolution in
/// iOS 17 (the outer NavigationLink cannot find a destination, hence the
/// runtime warning about HomeRoute). Instead, the host passes `path` in and
/// pushes deeper destinations onto it.
struct ReadingFlowView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allProgress: [ReadingProgress]

    /// The host's NavigationPath — pushed to navigate deeper.
    @Binding var path: NavigationPath

    enum ModelPhase: Equatable {
        case preparing
        case ready
        case failed(String)
    }

    @State private var modelPhase: ModelPhase = .preparing

    var body: some View {
        Group {
            switch modelPhase {
            case .preparing:
                // Purely presentational — the actual preparation runs in
                // this view's `.task`, single owner, no double-prepare.
                ModelDownloadView()
            case .failed(let message):
                ModelDownloadFailureView(message: message) {
                    modelPhase = .preparing
                    Task { await prepareModel() }
                }
            case .ready:
                ReadingTextListView { text in
                    if text.kind == .conversation {
                        path.append(ReadingDestination.setup(text: text))
                    } else {
                        path.append(ReadingDestination.read(text: text, spokenSpeaker: nil))
                    }
                }
            }
        }
        .navigationTitle("Reading")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Close") { dismiss() }
            }
        }
        .task {
            await prepareModel()
        }
    }

    private func prepareModel() async {
        do {
            try await LiveTranscriptionService().prepare()
            modelPhase = .ready
        } catch let error as ReadingError {
            modelPhase = .failed(error.errorDescription ?? "Unknown error")
        } catch {
            modelPhase = .failed(String(describing: error))
        }
    }
}

private struct ModelDownloadFailureView: View {
    let message: String
    var onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Speech model unavailable")
                .font(.title3.weight(.semibold))
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Try again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
