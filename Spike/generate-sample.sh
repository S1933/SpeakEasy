#!/usr/bin/env bash
# Generate sample.wav for the SpeechAnalyzer spike.
#
# Usage:
#   ./generate-sample.sh           # default corpus, ~30 s
#   REPEAT=4 ./generate-sample.sh  # repeat the corpus 4× → ~2 min
#
# Produces sample.wav at 16 kHz, mono, signed 16-bit little-endian.
# This is the format SpeechAnalyzer expects on iOS 26.

set -euo pipefail

REPEAT="${REPEAT:-1}"
ROOT="$(cd "$(dirname "$0")" && pwd)"
# Output goes into the package's resource directory so Xcode bundles it
# with the app. The Spike.swift entry point reads it via Bundle.module.
OUT="$ROOT/Sources/Spike/Resources/sample.wav"
INTERMEDIATE="$ROOT/sample.aiff"

# Corpus: ~120 words (~40 s at 175 wpm). Repeated $REPEAT times by calling
# 'say' REPEAT times and concatenating AIFF audio data at the file level.
#
# Exercises:
#   - common function words (the, a, to, of)
#   - consonant clusters (sphinx, vexingly)
#   - homophones (jocks/jaw)
#   - named entities (Sphinx, Fredrick) — common English names
#   - punctuation spoken aloud (commas, periods)
CORPUS="The quick brown fox jumps over the lazy dog. \
Pack my box with five dozen liquor jugs. \
How vexingly quick daft zebras jump. \
The five boxing wizards jump quickly. \
Sphinx of black quartz, judge my vow. \
Two driven jocks help fax my big quiz. \
Jackdaws love my big sphinx of quartz. \
Crazy Fredrick bought many very exquisite opal jewels. \
We promptly judged antique ivory buckles for the next prize. \
A mad boxer shot a quick, gloved jab to the jaw of his dizzy opponent. \
The job of waxing linoleum frequently peeves chintzy kids. \
How razorback-jumping frogs can level six piqued gymnasts. \
Sphinx of black quartz, judge my vow. \
Bright vixens jump, dozy fowl quack. \
Quick wafting zephyrs vex bold Jim."

# Build a longer corpus by repeating the base.
LONG=""
for ((i=0; i<REPEAT; i++)); do
    LONG="$LONG $CORPUS"
done
CORPUS="$LONG"

# `say` ignores the requested duration but speaks the whole text. To get a
# sample close to a target length we loop the file. Simpler: just speak it
# once. The "duration" argument is for documentation — to hit a target, the
# user can edit CORPUS.

echo "speaking corpus via macOS 'say'…"
say -v Samantha -o "$INTERMEDIATE" --file-format=AIFF "$CORPUS"

echo "converting to 16 kHz mono int16 WAV…"
afconvert -d 'LEI16@16000' -f WAVE -c 1 "$INTERMEDIATE" "$OUT"
rm "$INTERMEDIATE"

ACTUAL=$(file "$OUT" | grep -oE '[0-9]+ Hz' | head -1)
echo "wrote $OUT ($ACTUAL, $(stat -f%z "$OUT") bytes)"

DUR=$(file "$OUT" | grep -oE '[0-9]+ Hz' | head -1 | awk '{print $1}')
# Quick sanity: 1 minute at 16 kHz mono int16 ≈ 1.92 MB. Less than 1 MB
# means the sample is suspiciously short.
SIZE=$(stat -f%z "$OUT")
if [ "$SIZE" -lt 1000000 ]; then
    echo
    echo "⚠ sample is short (${SIZE} bytes). For the 2-minute test, append more"
    echo "  text to CORPUS in this script, or feed sample.wav through the"
    echo "  spike in a loop."
fi
