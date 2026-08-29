# Phase 0 — Spike run notes

## Run metadata

| Field | Value |
|---|---|
| Date | 2026-08-23 |
| Device | iPhone 12 (iPhone13,2), iOS 27.0 |
| Xcode | 26.6 (17F113), SDK iphoneos 26.5 |
| Sample file | `sample.wav` (REPEAT=4), 176.10 s, 16 kHz mono int16 |
| Model | en-US already installed on device (install path not timed) |
| Input mode | `SpeechAnalyzer(inputAudioFile:finishAfterFile:)` — file, not mic |

## Console output

```
[16:56:58.715] FILE /var/containers/Bundle/Application/…/Spike_Spike.bundle/sample.wav
[16:56:58.735] SpeechTranscriber.isAvailable: true
[16:56:58.962] LOCALES supported: ["en-ZA","en-CA","zh-TW","en-NZ","pa-IN","zh-HK","ml-IN","en-US",… 46 locales total]
[16:56:58.962] CHECK 1 supported en-US: ✓
[16:56:58.964] LOCALES installed: ["fr-BE","en-CA","en-ZA","en-IE","fr-CA","en-US","en-AU","en-IN","en-NZ","en-GB","fr-FR","en-SG","fr-CH"]
[16:56:58.964] CHECK 2 model already installed ✓
[16:56:58.968] FILE duration=176.10s, channels=1, rate=16000Hz, common=1
[16:56:59.452] EMIT 0.47s VOLATILE words=1 runs=1 text="The"
[… 965 VOLATILE emissions, visibly revising mid-word …]
[16:56:59.602] EMIT 0.62s FINAL words=9 runs=9 text="The quick brown fox jumps over the lazy dog."
[16:56:59.680] EMIT 0.70s FINAL words=8 runs=8 text=" Pack my box with 5 dozen liquor jugs."
[… 36 FINAL emissions total …]
[16:57:05.189] EMIT 6.21s FINAL words=8 runs=8 text=" Crazy Frederick bought many very exquisite opal jewels."
[16:57:06.766] EMIT 7.79s FINAL words=62 runs=62 text=" We promptly judged antique ivory buckles for the next prize, a mad bo…"
[16:57:06.845] CHECK 3 task completed within ~file duration: file=176.10s observed=7.86s (file looped? — see notes.md)
[16:57:06.846] CHECK 4 isFinal distinct: ✓ final present, ✓ volatile present, longest volatile streak = 127
[16:57:06.846] CHECK 5 audioTimeRange: 1450/1450 runs carry a timestamp ✓
[16:57:06.846] CHECK 6 run granularity: avg 1.4 runs/emission, 12.2 words/emission, ≈8.39 words/run → ⚠ (raw verdict — see corrected analysis below)
[16:57:06.846] FIRST audioTimeRange start: 0.000s
```

Full raw log: 1001 lines, ~88 KB. See `Spike/spike-raw-log.txt`.

## The six questions

### Q1 — supported locales — **✓**

`en-US` present among 46 supported locales. `SpeechTranscriber.isAvailable == true` on device (vs `false` on simulator).

### Q2 — model install — **✓ (pre-installed)**

Model was already on the device (13 locales installed). The download path (`AssetInventory.assetInstallationRequest`) was therefore NOT exercised — first-launch download time remains unmeasured. Risk is low: this is the standard iOS on-demand asset flow, but worth logging timing when it first happens in the wild.

### Q3 — task stability — **✓ with caveat**

The task processed **176.10 s of continuous audio in one uninterrupted run** (1001 emissions, no error, no early termination). Wall-clock time was 7.86 s — file input is processed ~22× faster than real-time, so the file test does **not** stress the real-time path. The "2 minutes live without dying" question needs the mic route (Phase 3 device testing) for a definitive answer. But: 3 minutes of continuous audio content through one analyzer task without failure is strong evidence the engine handles long-form.

### Q4 — `isFinal` semantics — **✓ (textbook)**

- 36 FINAL, 965 VOLATILE emissions — both paths fire.
- Volatiles visibly revise mid-word: `"jump"` → `"jumps"`, `"l"` → `"laz"` → `"lazy"` — partial hypotheses refining in real time.
- Finals commit per phrase/sentence and are never revised afterwards.
- Longest volatile streak = 127 consecutive volatile emissions without a final — on file input (22× real-time) this is expected; in real-time mode finals should interleave more.
- Exactly matches the `provisional`/`committed` split assumed by `ReadingAligner` and the `displayState(at:)` display lock (§5.4). **The design's core assumption holds.**

### Q5 — `audioTimeRange` presence — **✓ (100 %)**

1450/1450 runs carry a timestamp, first run starts at 0.000 s. No nil, no gaps.

### Q6 — run granularity — **✓ on the path that matters (corrected analysis)**

The spike's raw verdict (8.39 words/run) **mixed two populations**. Split by emission type:

| Emission type | Count | Avg words | Avg runs | **Words/run** |
|---|---|---|---|---|
| FINAL | 36 | 13.5 | 13.5 | **1.00** |
| VOLATILE | 965 | 12.1 | 1.0 | 12.11 |

- **Finalized results: exactly one run per word** — per-word timing is available and reliable.
- **Volatile results: one run per emission** — no per-word timing on the live path.

This maps **perfectly** onto the reading-mode design, which only needs per-word timing on the finalized path:
- `hesitations(in:)` and WCPM are computed at `finish()` from `session.current.hypothesis = transcription.finalized` → accurate per-word times.
- The live display (volatile path) uses word *identity and order*, not timing → unaffected.

**Verdict: per-word hesitations are viable. No design change needed.**

## Side observations

1. **ASR behaviour on TTS audio** (expected, but instructive):
   - `"quartz"` → `"chords"`, `"Jackdaws love"` → `"Jack does love"`, `"jump"` → `"job"` — context-based mis-hearings, confirming the §1 premise: this engine measures fluency, not pronunciation.
   - `"five dozen"` transcribed as **`"5 dozen"`** — the ASR writes digits. Our reference texts ban digits, and `SentenceNormalizer` does not map `"5"` ↔ `"five"`. **Risk to watch in device testing**: if real-voice reading triggers digit output, add number normalization to `SentenceNormalizer`. Not a blocker now.
2. **Emission volume**: 1001 emissions for 176 s of audio (≈5.7/s). The 10 Hz refresh cap in `ReadingViewModel` is correctly sized — without it, the aligner would run ~6×/s on volatile bursts.
3. **Batching at the tail**: the last FINAL covered 62 words at once — the transcriber can commit large chunks when audio ends. `finishAfterFile` semantics: the last emission arrives only at stream end, confirming the need for `finalizeAndFinishThroughEndOfInput()` in `stop()`.

## Decision

| Question | Verdict |
|---|---|
| Q1 | ✓ |
| Q2 | ✓ (install path unmeasured) |
| Q3 | ✓ (file route; real-time route to confirm in Phase 3) |
| Q4 | ✓ |
| Q5 | ✓ |
| Q6 | ✓ on finalized path (where timing matters) |

**Verdict: PROCEED AS DESIGNED.**

- `LiveTranscriptionService` (SpeechAnalyzer + volatile/finalized split) is validated — no fallback needed.
- The §16 repli (`SFSpeechRecognizer` + 800 ms heuristic) is **not** required.
- Remaining device-test items (already planned in §24): real-time 2-min stability via mic, interruption/resume, TTS contamination in dialogue mode.

## Reproduction

```bash
cd Spike
REPEAT=4 ./generate-sample.sh        # 176 s sample
# Build for device, assemble .app, install, launch, pull output:
xcrun devicectl device copy from --device <id> \
  --domain-type appDataContainer --domain-identifier s1933.SpeakEasy \
  --source Documents/spike-output.txt --destination /tmp/spike-out.txt
```
