import SwiftUI
import SwiftData

struct PracticeView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(SpeechPlaybackService.self) var playback
    @State var viewModel: PracticeViewModel

    init(
        queue: [LearningSentence],
        playback: SpeechPlaybackService,
        localeIdentifier: String = "en-US",
        recordAttempt: @escaping @MainActor (Int, Int) -> Void = { _, _ in },
        onSessionComplete: @escaping ([AttemptResult], [LearningSentence]) -> Void = { _, _ in }
    ) {
        let recognition = SpeechRecognitionService(locale: Locale(identifier: localeIdentifier))
        _viewModel = State(initialValue: PracticeViewModel(
            queue: queue,
            playback: playback,
            recognition: recognition,
            recordAttempt: recordAttempt,
            onSessionComplete: onSessionComplete
        ))
    }

    var body: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.cancelSession()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .accessibilityLabel("Close practice")
            }
        }
        .onDisappear {
            viewModel.cancelSession()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let sentence = viewModel.currentSentence {
            phaseContent(sentence: sentence)
                .id(phaseKey)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.85), value: viewModel.phase)
        } else {
            Text("No sentences available")
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func phaseContent(sentence: LearningSentence) -> some View {
        switch viewModel.phase {
        case .ready:
            ReadyContent(
                sentence: sentence,
                progressText: viewModel.progressText,
                isSpeaking: playback.isSpeaking,
                onListen: viewModel.speakCurrent,
                onRecord: { Task { await viewModel.toggleRecording() } }
            )
        case .recording:
            RecordingContent(
                sentence: sentence,
                progressText: viewModel.progressText,
                elapsed: viewModel.elapsed,
                amplitude: viewModel.amplitude,
                onStop: { Task { await viewModel.toggleRecording() } }
            )
        case .processing:
            ProcessingContent(progressText: viewModel.progressText)
        case .result(let result):
            ResultContent(
                progressText: viewModel.progressText,
                result: result,
                feedback: viewModel.feedback(for: result),
                retryTitle: "Try again",
                nextTitle: viewModel.nextButtonTitle,
                onRetry: viewModel.retry,
                onNext: viewModel.goToNext
            )
        case .error(let error):
            ErrorContent(
                progressText: viewModel.progressText,
                error: error,
                onRetry: { Task { await viewModel.toggleRecording() } },
                onDismiss: viewModel.dismissError
            )
        }
    }

    private var phaseKey: String {
        switch viewModel.phase {
        case .ready: return "ready"
        case .recording: return "recording"
        case .processing: return "processing"
        case .result: return "result"
        case .error: return "error"
        }
    }
}

#Preview {
    NavigationStack {
        PracticeView(
            queue: Array(SentenceRepository().all.prefix(10)),
            playback: SpeechPlaybackService(),
            onSessionComplete: { _, _ in }
        )
    }
    .modelContainer(for: [SentenceProgress.self, AppSettings.self], inMemory: true)
}
