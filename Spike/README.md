# Spike — SpeechAnalyzer surface verification

Throwaway iOS executable, **outside the SpeakEasy Xcode project**. It answers
the six questions from `docs/reading-mode.md` §16 with observed values, not
assumptions.

The audio source is a **file**, not a microphone. `SpeechAnalyzer(inputAudioFile:)`
takes an `AVAudioFile` directly, so this would run on a real device without
routing any audio.

## ⚠ Critical finding (Phase 0 first run)

On iOS 26.5 simulator, the spike reports:

```
SpeechTranscriber.isAvailable: false
LOCALES supported: []
```

**`SpeechTranscriber.isAvailable == false` is the canonical signal that
on-device speech recognition is unavailable on the current device.** The iOS
simulator does not bundle speech recognition assets and cannot download them.
This means:

- The simulator cannot validate `SpeechAnalyzer` behavior.
- Phase 0 **must** be run on a real iOS device (iPhone or iPad with the
  en-US speech model installed).
- Phase 3+ code (LiveTranscriptionService) **cannot be smoke-tested on the
  simulator** — only the build and the surface. Real testing requires a
  device.

The simulator build still verifies:
- That the API compiles against the iOS 26.5 SDK (signatures, attributes).
- That the structure of the pipeline is sound.
- That `MainActor` / `nonisolated` interactions with the audio thread are
  correct.

It does **not** verify the six runtime questions — those need a device.

## Run on simulator (compile check only)

```bash
cd Spike
./generate-sample.sh                          # writes Sources/Spike/Resources/sample.wav
xcodebuild -scheme Spike -destination 'platform=iOS Simulator,name=iPhone 16' build
xcrun simctl spawn booted \
  ./build/Build/Products/Debug-iphonesimulator/Spike
```

The simulator run will report `SpeechTranscriber.isAvailable: false` —
expected, the simulator can't run on-device speech recognition. It's only
useful as a wiring check.

## Run on a real device (the actual Phase 0)

```bash
cd Spike
./generate-sample.sh                          # 1) bundle sample.wav into the app
open Package.swift                            # 2) Xcode opens
# 3) In Xcode: select a connected iPhone → ⌘R
```

The sample is bundled into the app via `Package.swift` resources, so it's
available to the running process at `Bundle.module`. No path juggling needed
on device.

The first launch on device downloads the en-US model (~150 MB). Subsequent
launches are immediate.

## What the spike logs

Each emission prints:

```
[timestamp] EMIT <elapsed>s {FINAL|VOLATILE} words=<N> runs=<M> text="…"
```

Plus a summary block at the end:

```
CHECK 1 supported en-US: ✓
CHECK 2 model already installed ✓ (or: install ✓ (took N s))
CHECK 3 task completed within ~file duration: ✓
CHECK 4 isFinal distinct: ✓ final present, ✓ volatile present
CHECK 5 audioTimeRange: K/N runs carry a timestamp ✓
CHECK 6 run granularity: avg X runs/emission, Y words/run → verdict
```

## Reading the verdict

| Check | What it tells you | Next step |
|---|---|---|
| 1 | `en-US` is offered by `SpeechAnalyzer` on this SDK/device | Phase 3 viable |
| 2 | The model downloads and installs in a tolerable time | OK as first-launch |
| 3 | The task runs to completion on the file | For the 2-min test, run with a longer sample |
| 4 | `result.isFinal` actually fires (≥1) and volatiles fire (≥1) | The display-state lock in §5.4 is safe |
| 5 | `audioTimeRange` is reliably non-nil | Per-word timing for hesitations works |
| 6 | Runs correspond to ~1 word | Hesitations per word are accurate |

**Critical fallback** if check 6 lands in the "unreliable" zone: the design
document §16 specifies a repli (`SFSpeechRecognizer` +
`requiresOnDeviceRecognition = true`, with an 800 ms cursor heuristic).

## Extending the sample

```bash
REPEAT=4 ./generate-sample.sh     # ~2-min sample for the §16 duration test
```

The script concatenates the base corpus by repeating it `REPEAT` times
before handing it to `say`. Re-runs of `⌘R` pick up the regenerated file
automatically (Xcode copies the resource bundle on each build).

## Output: notes.md

After running on a device, paste the console output into `notes.md` and
fill in the verdict fields. The decisions in Phase 3 onward all depend on
the answers the spike returns.
