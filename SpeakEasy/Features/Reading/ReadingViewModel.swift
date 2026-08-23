import Foundation
import Observation
import os

/// Orchestrates one reading session:
/// 1. starts the on-device transcription (paused on interruption, resumed 2
///    words before the cursor),
/// 2. feeds the aligner at most every 100 ms (10 Hz cap — the transcriber can
///    emit faster than the eye can follow),
/// 3. closes the session with a `ReadingResult` from the scorer.
///
/// In dialogue mode (`spokenSpeaker != nil`), the session alternates: the
/// user's lines are transcribed live, the other characters' lines are spoken
/// by TTS with the audio tap REMOVED so the synthesizer never leaks into the
/// hypothesis (§10 of the design document).
@MainActor
@Observable
final class ReadingViewModel {

    enum Phase: Equatable {
        case ready
        case reading
        case interrupted
        case finished(ReadingResult)
        case failed(String)
    }

    private(set) var phase: Phase = .ready
    private(set) var snapshot: AlignmentSnapshot
    private(set) var session = ReadingSession()

    /// Per-line projection of `snapshot.states` so the view can drive each
    /// `ReadingLineView` with a small, isolated slice — the line view only
    /// re-renders when its own slice changes, not on every full-snapshot
    /// update at 10 Hz.
    private(set) var statesByLine: [Int: [ReadingTokenState]] = [:]

    /// Line the UI should keep visible: the TTS line while it plays in
    /// dialogue mode, otherwise the line under the reading cursor.
    private(set) var highlightedLineID: Int?

    /// Estimated reading position driving the underline and scroll. Runs
    /// ahead of `snapshot.cursor` between transcriber emissions (see
    /// `CursorAnticipator`) — alignment stays the source of truth for
    /// colors, this only keeps the guide visually glued to the voice.
    private(set) var displayCursor: Int = 0

    /// Cached for the bottom bar: O(1) reads instead of re-filtering the
    /// whole `states` array on every render.
    private(set) var correctCount: Int = 0

    let text: ReadingText
    let tokens: [ReadingToken]
    /// `lineIndex → tokens of that line` — precomputed once so the view's
    /// `ForEach` no longer does an O(N) `.filter` per line on each render.
    let tokensByLine: [Int: [ReadingToken]]
    /// Speaker picked for dialogue mode (nil = read all lines, no TTS).
    let spokenSpeaker: String?

    private let aligner: ReadingAligner
    private let transcription: LiveTranscriptionService
    private let playback: SpeechPlaybackService
    private let scorer = ReadingScorer()
    private var segmentStartedAt = Date.now
    /// Wall time of the last transcriber emission — anchors the anticipatory
    /// underline. Updated on EVERY emission, before any throttling.
    private var lastEmissionAt = Date.now
    /// Hypothesis the current snapshot was aligned against — a tick with an
    /// unchanged hypothesis is a no-op.
    private var lastAlignedHypothesis: [HypToken] = []
    /// 10 Hz loop: applies pending alignments (trailing edge — the last
    /// result of a phrase is never dropped) and refreshes the display cursor.
    private var displayTimer: Task<Void, Never>?
    private let anticipator = CursorAnticipator()
    private var interruptionMonitor: AudioInterruptionMonitor?
    /// Set by `finish()`/`cancel()` — stops the dialogue alternation loop.
    private var sessionEnded = false

    init(text: ReadingText,
         spokenSpeaker: String? = nil,
         transcription: LiveTranscriptionService = LiveTranscriptionService(),
         playback: SpeechPlaybackService) {
        self.text = text
        self.spokenSpeaker = spokenSpeaker
        self.tokens = ReadingTokenizer.tokenize(text, spokenSpeaker: spokenSpeaker)
        var byLine: [Int: [ReadingToken]] = [:]
        for token in self.tokens {
            byLine[token.lineIndex, default: []].append(token)
        }
        self.tokensByLine = byLine
        self.aligner = ReadingAligner(reference: self.tokens)
        self.transcription = transcription
        self.playback = playback
        self.snapshot = AlignmentSnapshot(
            states: Array(repeating: .pending, count: self.tokens.count),
            cursor: 0, committedUpTo: 0, insertions: 0, timings: [:])
        // Pre-populate the per-line projection so the very first render
        // shows every line in its pending state, not an empty Text.
        self.statesByLine = self.projectDisplayStatesByLine(self.snapshot)
    }

    // MARK: - Lifecycle

    /// Guarded so a re-appear (popping back from the result screen) never
    /// restarts a finished session.
    func start() async {
        guard phase == .ready, !sessionEnded else { return }
        do {
            try await transcription.prepare()
            segmentStartedAt = .now
            attachInterruptionMonitor()
            try await transcription.start { [weak self] finalized, volatile in
                self?.ingest(finalized + volatile)
            }
            phase = .reading
            startDisplayTimer()
            if let role = spokenSpeaker, text.kind == .conversation {
                await runDialogue(readingAs: role)
            }
        } catch let error as ReadingError {
            phase = .failed(error.errorDescription ?? "Could not start.")
        } catch {
            phase = .failed(String(describing: error))
        }
    }

    /// Idempotent: the Done button, the dialogue loop and view teardown can
    /// all race to finish; only the first wins.
    func finish() async {
        sessionEnded = true
        if case .finished = phase { return }
        displayTimer?.cancel()
        interruptionMonitor = nil
        playback.stop()                       // cut any TTS line mid-playback
        await transcription.stop()            // flushes pending finals
        session.current.activeDuration += Date.now.timeIntervalSince(segmentStartedAt)
        session.current.hypothesis = transcription.finalized
        // Last alignment on the committed state, without throttling.
        applyAlignedSnapshot(aligner.align(session: session))
        displayCursor = min(snapshot.cursor, max(0, tokens.count - 1))
        phase = .finished(scorer.score(snapshot: snapshot,
                                       tokenCount: tokens.count,
                                       duration: session.activeDuration))
    }

    func cancel() async {
        sessionEnded = true
        displayTimer?.cancel()
        interruptionMonitor = nil
        playback.stop()
        await transcription.stop()
        // Keep the terminal state — popping back from the result screen must
        // not resurrect the session into "Preparing…".
        if case .finished = phase { return }
        phase = .ready
    }

    // MARK: - Dialogue mode (§10)

    /// Alternates between the user's lines (mic on) and the other
    /// characters' lines (TTS, tap removed). The reference excludes the
    /// other role's tokens, so the aligner's cursor walks only the lines
    /// the user actually reads.
    private func runDialogue(readingAs role: String) async {
        for (index, line) in text.lines.enumerated() {
            if sessionEnded || Task.isCancelled { return }
            if line.speaker == role {
                await awaitUserReading(lineIndex: index)
            } else {
                highlightedLineID = line.id
                transcription.pause()          // remove the tap: the mic must not hear the synth
                await playback.speakAwaitingCompletion(line.text)
                transcription.resume()
            }
        }
        await finish()
    }

    /// Waits until the reading cursor passes the last token of the line, or
    /// a generous per-line timeout elapses — a line the engine never picks
    /// up must not block the whole session.
    private func awaitUserReading(lineIndex: Int) async {
        guard let last = tokens.lastIndex(where: { $0.lineIndex == lineIndex }) else { return }
        let wordCount = text.lines[lineIndex].text.split(separator: " ").count
        let timeout = Double(wordCount) * 3.0 + 10.0
        let deadline = Date.now.addingTimeInterval(timeout)
        while !sessionEnded && !Task.isCancelled {
            if snapshot.cursor > last { return }
            if Date.now > deadline { return }
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    // MARK: - Live updates

    /// Called on every transcriber emission. Cheap by design: it only
    /// records the hypothesis; alignment and UI refresh happen in the 10 Hz
    /// loop (`tick`), which also gives trailing-edge behavior — the final
    /// result of a phrase can never be dropped by a throttle window.
    private func ingest(_ hypothesis: [HypToken]) {
        lastEmissionAt = .now
        session.current.hypothesis = hypothesis
    }

    /// Single place where the public state is mutated after an alignment.
    /// Keeps the per-line projection and the live counters in lockstep with
    /// `snapshot` so the view never has to recompute them. The projection
    /// stores DISPLAY states (the §5.4 "premature accusations don't show"
    /// rule) so the line view can render without knowing the global cursor.
    private func applyAlignedSnapshot(_ aligned: AlignmentSnapshot) {
        snapshot = aligned
        correctCount = aligned.states.lazy.filter { $0 == .correct }.count
        statesByLine = projectDisplayStatesByLine(aligned)
    }

    // MARK: - 10 Hz loop

    private func startDisplayTimer() {
        displayTimer?.cancel()
        displayTimer = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                self.tick()
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private func tick() {
        // Only while the mic is live: during TTS lines (dialogue) or an
        // interruption the pipeline is paused — freeze everything.
        guard transcription.phase == .listening else { return }
        let hypothesis = session.current.hypothesis
        if hypothesis != lastAlignedHypothesis {
            lastAlignedHypothesis = hypothesis
            applyAlignedSnapshot(aligner.align(session: session))
        }
        refreshDisplayCursor()
    }

    /// Advances (or decays) the anticipatory underline, then keeps the
    /// scroll target glued to it.
    private func refreshDisplayCursor() {
        let rate = CursorAnticipator.rate(from: Array(snapshot.timings.values))
        displayCursor = anticipator.displayCursor(
            alignedCursor: snapshot.cursor,
            previousDisplay: displayCursor,
            elapsed: Date.now.timeIntervalSince(lastEmissionAt),
            rate: rate,
            hasHypothesis: !session.current.hypothesis.isEmpty,
            tokenCount: tokens.count)
        highlightedLineID = lineID(forCursor: displayCursor) ?? highlightedLineID
    }

    /// Absolute id of the token the underline should sit on: the first not-
    /// yet-displayed word at or after the estimated position. nil once the
    /// text is fully read.
    var cursorTokenID: Int? {
        guard tokens.indices.contains(displayCursor) else { return nil }
        var i = max(displayCursor, 0)
        while i < snapshot.states.count {
            if snapshot.displayState(at: i) == .pending { return i }
            i += 1
        }
        return nil
    }

    /// Line index holding `cursorTokenID` — lets the view pass the cursor
    /// identity to exactly one `ReadingLineView`.
    var cursorLineIndex: Int? {
        cursorTokenID.map { tokens[$0].lineIndex }
    }

    private func projectDisplayStatesByLine(_ snap: AlignmentSnapshot)
        -> [Int: [ReadingTokenState]] {
        var out: [Int: [ReadingTokenState]] = [:]
        for token in tokens {
            out[token.lineIndex, default: []].append(snap.displayState(at: token.id))
        }
        return out
    }

    private func lineID(forCursor cursor: Int) -> Int? {
        guard tokens.indices.contains(cursor) else { return nil }
        let lineIndex = tokens[cursor].lineIndex
        guard text.lines.indices.contains(lineIndex) else { return nil }
        return text.lines[lineIndex].id
    }

    // MARK: - Live metrics for the bottom bar

    /// Live accuracy in percent — read from the cached count updated in
    /// `applyAlignedSnapshot`, so each render is O(1).
    var liveAccuracy: Int {
        guard !tokens.isEmpty else { return 0 }
        return Int(Double(correctCount) / Double(tokens.count) * 100)
    }

    /// Live words-per-minute over the active session time.
    var liveWPM: Int {
        let elapsed = Date.now.timeIntervalSince(segmentStartedAt)
        let minutes = max(elapsed / 60, 0.01)
        return Int(Double(correctCount) / minutes)
    }

    // MARK: - Interruption handling

    private func attachInterruptionMonitor() {
        interruptionMonitor = AudioInterruptionMonitor { [weak self] event in
            switch event {
            case .interrupted:
                Task { await self?.pauseForInterruption() }
            case .resumable, .routeLost:
                break   // no auto-resume: the user decides
            }
        }
    }

    /// Folds the current segment and stops the engine — but keeps the session
    /// so we can resume from `cursor - 2`. The hypothesis is captured AFTER
    /// `stop()` so the finals flushed by finalization are included.
    private func pauseForInterruption() async {
        guard phase == .reading else { return }
        session.current.activeDuration += Date.now.timeIntervalSince(segmentStartedAt)
        playback.stop()
        await transcription.stop()
        session.current.hypothesis = transcription.finalized
        // Last alignment so the displayed states are frozen, not stale.
        applyAlignedSnapshot(aligner.align(session: session))
        phase = .interrupted
    }

    /// Resumes after the user taps "Resume here". Re-opens at `cursor - 2`
    /// so the reader has two words of context to restart their phrasing.
    /// The pipeline was torn down by the interruption, so it goes through
    /// `restart()` (stop + re-prepare) before a fresh `start()`.
    func resumeFromInterruption() async {
        let resumeIndex = max(0, snapshot.cursor - 2)
        session.openSegment(at: resumeIndex)
        segmentStartedAt = .now
        // Fresh segment: reset emission tracking and pin the underline at
        // the resume point (the reader re-reads two words first).
        lastEmissionAt = .now
        lastAlignedHypothesis = []
        displayCursor = min(resumeIndex, max(0, tokens.count - 1))
        do {
            try await transcription.restart()
            attachInterruptionMonitor()
            try await transcription.start { [weak self] finalized, volatile in
                self?.ingest(finalized + volatile)
            }
            phase = .reading
            startDisplayTimer()
            if let role = spokenSpeaker, text.kind == .conversation {
                await resumeDialogueAfterInterruption(readingAs: role)
            }
        } catch let error as ReadingError {
            phase = .failed(error.errorDescription ?? "Could not resume.")
        } catch {
            phase = .failed(String(describing: error))
        }
    }

    /// After an interruption mid-dialogue, resume the alternation from the
    /// line that contains the resume cursor.
    private func resumeDialogueAfterInterruption(readingAs role: String) async {
        let resumeLine = tokens.first(where: { $0.id >= max(0, snapshot.cursor - 2) })?.lineIndex ?? 0
        for (index, line) in text.lines.enumerated() where index >= resumeLine {
            if sessionEnded || Task.isCancelled { return }
            if line.speaker == role {
                await awaitUserReading(lineIndex: index)
            } else {
                highlightedLineID = line.id
                transcription.pause()
                await playback.speakAwaitingCompletion(line.text)
                transcription.resume()
            }
        }
        await finish()
    }
}
