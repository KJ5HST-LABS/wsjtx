# Sample pre-processing

Pre-processed sample WAVs under `samples/<mode>/preprocessed/` are committed
to the repository. They are **produced once at commit time**, not regenerated
by CI. `sox` is **not** a CI dependency.

The decoder test catalog in `tests/decoders/CMakeLists.txt` references the
pre-processed files directly.

## Why pre-process

Several of Steve Franke's `decoder_tests.bash` cases resample, trim, or pad
the raw captures before feeding them to `jt9`. Examples:

- JT4A / JT4F — resample to 12 kHz and pad an extra 1.0 s of silence to
  extend the capture past the decoder's window.
- JT65B averaging cases — trim 2.1 s of lead-in and pad 2.1 s of trailing
  silence to align with the mode's TR window.
- Q65-60A / 60D — trim 2.5 s lead-in and pad 2.5 s trailing silence.
- JT65B DL7UAE — resample, pad, and trim.

The transformation is stable: the input capture doesn't change, the sox
command doesn't change, so the output file doesn't change either. Running
`sox` once at commit time and checking the output into the repo removes the
need for every CI job on every platform to install sox and re-run the
transforms on every build.

## Reproducing the pre-processed files

Requirements:

- `sox` on your `PATH` (macOS: `brew install sox`).
- Repo checkout with the raw samples present (they already are — see
  `samples/JT4/`, `samples/JT65/JT65B/`, `samples/Q65/`).

Run from the repo root:

```bash
mkdir -p samples/JT4/JT4A/preprocessed \
         samples/JT4/JT4F/preprocessed \
         samples/JT65/JT65B/preprocessed \
         samples/Q65/60A_EME_6m/preprocessed \
         samples/Q65/60D_EME_10GHz/preprocessed

# JT4A: resample to 12 kHz, pad 1.0 s, 16-bit output
sox samples/JT4/JT4A/DF2ZC_070926_040700.wav -b 16 \
    samples/JT4/JT4A/preprocessed/DF2ZC_070926_040700_12k_pad1.wav \
    rate 12000 pad 0 1.0

# JT4F: resample to 12 kHz, pad 1.0 s, 16-bit output
sox samples/JT4/JT4F/OK1KIR_141105_175700.wav -b 16 \
    samples/JT4/JT4F/preprocessed/OK1KIR_141105_175700_12k_pad1.wav \
    rate 12000 pad 0 1.0

# JT65B odd-avg (1, 3, 5, 7) + even-avg (2, 4, 6): trim 2.1 s, pad 2.1 s
for n in 1 2 3 4 5 6 7; do
    sox samples/JT65/JT65B/000000_000${n}.wav \
        samples/JT65/JT65B/preprocessed/000000_000${n}_trim2.1_pad2.1.wav \
        trim 2.1 pad 0 2.1
done

# JT65B DL7UAE: resample to 12 kHz, pad 3.0 s, trim 3.0 s, 16-bit output
sox samples/JT65/JT65B/DL7UAE_040308_002400.wav -b 16 \
    samples/JT65/JT65B/preprocessed/DL7UAE_040308_002400_12k_pad3_trim3.wav \
    rate 12000 pad 0 3.0 trim 3.0

# Q65-60A: trim 2.5 s, pad 2.5 s
sox samples/Q65/60A_EME_6m/210106_1621.wav \
    samples/Q65/60A_EME_6m/preprocessed/210106_1621_trim2.5_pad2.5.wav \
    trim 2.5 pad 0 2.5

# Q65-60D: trim 2.5 s, pad 2.5 s
sox samples/Q65/60D_EME_10GHz/201212_1838.wav \
    samples/Q65/60D_EME_10GHz/preprocessed/201212_1838_trim2.5_pad2.5.wav \
    trim 2.5 pad 0 2.5
```

The sox effect chain is applied left-to-right. The commands above collapse
each of Steve's multi-pass sox invocations (rate → pad, trim → pad, etc.)
into a single invocation with the effects in the same order.

## Command-to-output map

| Source mode | Raw input | Pre-processed output | Sox effects |
|---|---|---|---|
| JT4A | `samples/JT4/JT4A/DF2ZC_070926_040700.wav` | `samples/JT4/JT4A/preprocessed/DF2ZC_070926_040700_12k_pad1.wav` | `-b 16 rate 12000 pad 0 1.0` |
| JT4F | `samples/JT4/JT4F/OK1KIR_141105_175700.wav` | `samples/JT4/JT4F/preprocessed/OK1KIR_141105_175700_12k_pad1.wav` | `-b 16 rate 12000 pad 0 1.0` |
| JT65B odd-avg | `samples/JT65/JT65B/000000_000{1,3,5,7}.wav` | `samples/JT65/JT65B/preprocessed/000000_000{1,3,5,7}_trim2.1_pad2.1.wav` | `trim 2.1 pad 0 2.1` |
| JT65B even-avg | `samples/JT65/JT65B/000000_000{2,4,6}.wav` | `samples/JT65/JT65B/preprocessed/000000_000{2,4,6}_trim2.1_pad2.1.wav` | `trim 2.1 pad 0 2.1` |
| JT65B DL7UAE | `samples/JT65/JT65B/DL7UAE_040308_002400.wav` | `samples/JT65/JT65B/preprocessed/DL7UAE_040308_002400_12k_pad3_trim3.wav` | `-b 16 rate 12000 pad 0 3.0 trim 3.0` |
| Q65-60A | `samples/Q65/60A_EME_6m/210106_1621.wav` | `samples/Q65/60A_EME_6m/preprocessed/210106_1621_trim2.5_pad2.5.wav` | `trim 2.5 pad 0 2.5` |
| Q65-60D | `samples/Q65/60D_EME_10GHz/201212_1838.wav` | `samples/Q65/60D_EME_10GHz/preprocessed/201212_1838_trim2.5_pad2.5.wav` | `trim 2.5 pad 0 2.5` |

All pre-processed outputs are 12 kHz, 16-bit, mono WAV. Durations match the
mode's expected TR window after pre-processing.

## Case-sensitivity fix

The two JT4 raw captures were originally committed as `.WAV` (uppercase).
macOS is case-insensitive-preserving, so the mismatch was invisible locally,
but Linux CI is case-sensitive and any test referring to `.wav` would have
failed to find them. Renamed to `.wav` as part of the same commit.

## Adding new pre-processed samples

When a future bug-bust adds a new case that needs pre-processing:

1. Add a row to the table above.
2. Append the `sox` command to the reproduction block.
3. Run the command, commit the output under
   `samples/<mode>/preprocessed/<descriptive_name>.wav`.
4. Reference the pre-processed file in
   `tests/decoders/CMakeLists.txt` via `add_decoder_test(...)`.

Keep the output filename descriptive — include the operations in the stem
(`_12k`, `_pad1`, `_trim2.5`) so the relationship to this file is obvious at
a glance.
