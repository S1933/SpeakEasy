# SpeakEasy

Practice spoken English, one sentence at a time.

SpeakEasy is a SwiftUI app that uses Apple's new **SpeechAnalyzer** API (iOS 26) to score your pronunciation against French→English practice sentences in real time.

## Features

- **Listen** — Hear the English sentence read aloud before you speak
- **Record** — Speak the sentence; progressive transcription streams as you talk
- **Score** — Per-attempt score (0–100) with token-by-token feedback (correct / missing / incorrect / extra)
- **Progress** — Tracks today's attempts, completed sentences, and difficult ones to review
- **Settings** — Adjustable session size

## Requirements

- **Xcode 17+** (Apple SpeechAnalyzer SDK ships with Xcode 26 toolchain)
- **iOS 26.0+** device or simulator
- Microphone and Speech Recognition permissions

## Setup

```bash
git clone git@github.com:S1933/SpeakEasy.git
cd SpeakEasy
open SpeakEasy.xcodeproj
```

Build and run on a real device for best results — the simulator has no real microphone and the new `SpeechTranscriber` assets may not be installed.

## Permissions

Required `Info.plist` keys (already configured):

- `NSMicrophoneUsageDescription` — "SpeakEasy uses the microphone so you can practice spoken English."
- `NSSpeechRecognitionUsageDescription` — "SpeakEasy uses speech recognition to compare what you say with the practice sentence."

## Architecture

```
SpeakEasy/
├── Features/
│   ├── Home/         Stats + Start CTA
│   ├── Practice/     Recording flow + per-sentence view
│   ├── Settings/     Session size
│   └── Summary/      End-of-session recap
├── Services/
│   ├── Speech/       SpeechRecognitionService, AudioSession, Permissions
│   ├── Scoring/      SentenceScoringService (token-level diff via Levenshtein-like DP)
│   └── Progress/     SwiftData persistence
├── Models/           LearningSentence, AttemptResult, etc.
├── Data/             sentences.json, SentenceRepository
└── Shared/
    └── Components/   MicrophoneButton, SentenceRow, etc.
```

**Key technical decisions:**

- **SpeechAnalyzer pipeline** — uses `SpeechAnalyzer` + `SpeechTranscriber` with the `.progressiveTranscription` preset for streaming results. Audio is captured via `AVAudioEngine` tap at the hardware format (typically 48 kHz Float32), then converted per-buffer to **16 kHz Int16 mono interleaved** with `AVAudioConverter`. A fresh `AVAudioConverter` is allocated for each tap callback because the converter retains internal resampler state across calls.
- **Concurrency** — `@Observable` + `@MainActor`; `SpeechRecognitionService` is main-actor isolated; long-running work (`analyzer.start(inputSequence:)`, result collection) is dispatched as unstructured `Task`s with explicit error handling.
- **Persistence** — SwiftData with two models: `SentenceProgress` (per-sentence score history) and `AppSettings` (session size).

## Tests

```bash
xcodebuild test -project SpeakEasy.xcodeproj -scheme SpeakEasy \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

24 unit tests cover scoring, normalization, and feedback.

## License

Private project — all rights reserved.
