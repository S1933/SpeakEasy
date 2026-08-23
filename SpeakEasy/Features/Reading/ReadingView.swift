import SwiftUI

struct ReadingView: View {
    @State private var viewModel: ReadingViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var onFinish: (ReadingResult) -> Void = { _ in }

    init(text: ReadingText,
         spokenSpeaker: String? = nil,
         playback: SpeechPlaybackService,
         onFinish: @escaping (ReadingResult) -> Void = { _ in }) {
        _viewModel = State(initialValue: ReadingViewModel(
            text: text,
            spokenSpeaker: spokenSpeaker,
            playback: playback
        ))
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            content
            if case .interrupted = viewModel.phase {
                InterruptedOverlay(
                    cursor: viewModel.snapshot.cursor,
                    onResume: { Task { await viewModel.resumeFromInterruption() } },
                    onCancel: {
                        Task {
                            await viewModel.cancel()
                            dismiss()
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    // finish() flushes finals and flips the phase; the
                    // onChange below is the SINGLE place that forwards the
                    // result — no duplicate pushes.
                    Task { await viewModel.finish() }
                }
            }
        }
        .task {
            await viewModel.start()
        }
        .onChange(of: viewModel.phase) { _, newPhase in
            if case .finished(let result) = newPhase {
                onFinish(result)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                Task { await viewModel.cancel() }
            }
        }
        .onDisappear {
            Task { await viewModel.cancel() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.phase {
        case .ready:
            ProgressView("Preparing…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .reading, .interrupted:
            sessionBody
        case .finished:
            // Transient: onChange pushes the result screen which replaces
            // this view in the navigation stack.
            ProgressView("Computing result…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            failureView(message: message)
        }
    }

    private var sessionBody: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(Array(viewModel.text.lines.enumerated()),
                                id: \.element.id) { lineIndex, line in
                            ReadingLineView(
                                line: line,
                                tokens: viewModel.tokensByLine[lineIndex] ?? [],
                                states: viewModel.statesByLine[lineIndex] ?? [],
                                // Scoped per line so a cursor move only
                                // invalidates the two lines it touches.
                                cursorTokenID: viewModel.cursorLineIndex == lineIndex
                                    ? viewModel.cursorTokenID : nil
                            )
                            .equatable()
                            .id(line.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.highlightedLineID) { _, newValue in
                    guard let newValue else { return }
                    // No animation: at 10 Hz the cursor advances faster than a
                    // 0.3 s ease can finish, so each new line interrupts the
                    // previous scroll and the cursor visibly lags.
                    proxy.scrollTo(newValue, anchor: .center)
                }
            }
            liveBar
        }
    }

    private var liveBar: some View {
        HStack {
            Label("\(viewModel.liveAccuracy)%", systemImage: "checkmark.circle")
            Spacer()
            Label("\(viewModel.liveWPM) wpm", systemImage: "speedometer")
        }
        .font(.footnote.monospacedDigit())
        .padding()
        .background(.bar)
    }

    private func failureView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text(message)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Close") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
