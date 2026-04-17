# Phase 3 — Decoder regression test catalog

This plan supplements `CTEST_PFUNIT_INTEGRATION_PLAN.md` §Phase 3. It documents the architecture and a phased, session-scoped execution path for integrating Steven Franke's decoder test corpus into the ctest-driven test suite.

## Context

Steve Franke's `decoder_tests.bash` — received by email 2026-04-17 and referenced by Joe Taylor's 2026-04-10 note as "the script that tests the decoders for each of our supported modes" — is a bug-bust corpus. Each of its 17 decoder invocations was collected because a specific bug surfaced on that `(mode, options, sample)` tuple. The **value** is the coverage; the **form** (bash + sox + hard-coded paths + CWD temp files + v3.0.1 baseline diff) is incidental.

Porting the script verbatim into CI would buy known failures:
- Linux case-sensitivity on two JT4 sample filenames (`.WAV` in-tree vs. `.wav` in the script);
- CWD collision on `ctest -j` (the script uses shared temp filenames in the current directory);
- a new `sox` runtime dependency on four CI platforms;
- Steve's personal paths hard-coded at the top (`/opt/local/bin/sox`, `~/Library/...`);
- baseline drift — Steve's baseline captures output against an internal `v3.0.1` build (per Joe's 2026-04-10 note, tagged on `wsjtx-internal/v3.0.0_test`, not `develop`), so byte-diffing against our `develop` CI build will always be noisy.

None of that preserves regression protection. It adds test-infrastructure debt that each future contributor has to fight through.

**This plan's position:** treat tests as declarative data, keep the coverage, discard the form. Extend Phase 2's pure-CMake test driver to absorb every case Steve exercises, with a growth path for future bug-busts — "we saw bug X on sample Y" becomes a one-line catalog entry, not a new script.

## Architectural principles

1. **Tests are data, not scripts.** Each case = `(name, decoder, options, samples, expected-tokens, provenance)`. Adding a future bug-bust = one catalog entry.
2. **No bash, no runtime sox.** Pure CMake driver (Phase 2 pattern). Any sample pre-processing happens once at commit time and is captured in the repo.
3. **Deterministic grep-for-token matching.** "At least one of these callsigns must appear in stdout." Tolerates weak-decode drift between decoder revisions (noise-floor decodes at SNR < -20 are not regression signal); pin on strong decodes.
4. **Parallel-safe.** No shared temp files; CMake assigns each test a working directory.
5. **Attribution preserved.** Each catalog entry carries a `PROVENANCE` field naming the source. Steve's script is vendored as reference, not executed.
6. **Extension-friendly.** The catalog IS the interface for future contributors; documented with a walkthrough example.
7. **Fast path preserved.** Phase 2's `decoder_ft8_smoke` / `decoder_wspr_smoke` kept as `ctest -L smoke` for contributor laptops; full catalog is `ctest -L franke`.

## Approach

### Driver extension (`tests/decoders/run_decoder_test.cmake`)

Add two capabilities to the Phase 2 driver, preserving full backwards compatibility:

- **Multi-sample input** (`SAMPLES` — semicolon-separated list, passed as positional args to the decoder). Covers JT65B odd-avg / even-avg and Q65 3-file averaging.
- **Any-of expected tokens** (`EXPECTED_TOKENS` — semicolon-separated; pass if ANY appears in stdout). `EXPECTED` remains as the single-token shorthand.

Phase 2's existing invocations (`DECODER`, `SAMPLE`, `EXPECTED`, `MODE_FLAG`) continue to work unchanged.

### Catalog helper macro (`tests/decoders/CMakeLists.txt`)

Thin `add_decoder_test()` wrapper so each case is one dense, readable block:

```cmake
add_decoder_test(
  NAME            decoder_ft8_standard
  DECODER         jt9
  OPTIONS         "-8;-d;3;-q"
  SAMPLES         "${CMAKE_SOURCE_DIR}/samples/FT8/210703_133430.wav"
  EXPECTED_TOKENS "W1FC;F5BZB;WM3PEN"  # top-SNR decodes in the known-good baseline
  PROVENANCE      "Franke decoder_tests.bash — FT8 standard decoder"
)
```

Gates on `TARGET ${DECODER}` and `EXISTS ${sample}` per sample (Phase 2 pattern); attaches labels `decoder;franke` for `ctest -L franke`.

### Pre-processed samples — commit-time, not run-time

Several cases in Steve's script use `sox` to resample, trim, or pad samples before decode:

| Case | Samples | Sox operation |
|---|---|---|
| JT4A | `DF2ZC_070926_040700.wav` | `-b 16 rate 12000` + `pad 0 1.0` |
| JT4F | `OK1KIR_141105_175700.wav` | `-b 16 rate 12000` + `pad 0 1.0` |
| JT65B odd-avg | 4 files (`000000_0001/0003/0005/0007.wav`) | `trim 2.1` + `pad 0 2.1` |
| JT65B even-avg | 3 files (`0002/0004/0006.wav`) | `trim 2.1` + `pad 0 2.1` |
| JT65B DL7UAE | `DL7UAE_040308_002400.wav` | `-b 16 rate 12000` + `pad 0 3.0` + `trim 3.0` |
| Q65-60A | `210106_1621.wav` | `trim 2.5` + `pad 0 2.5` |
| Q65-60D | `201212_1838.wav` | `trim 2.5` + `pad 0 2.5` |

Pre-process once locally with sox, commit the outputs under `samples/<mode>/preprocessed/`, document commands in `samples/PREPROCESSING.md`. Test catalog references the pre-processed files directly. **No sox in CI.**

Sample-blob impact: on the order of 7 additional WAVs, low-single-digit MB total. Acceptable for regression coverage.

### Case-sensitivity fix

Two in-tree JT4 samples are `.WAV` (uppercase); Linux is case-sensitive. Rename to `.wav` as a precondition for any JT4 case to run on the Linux runner:

- `samples/JT4/JT4A/DF2ZC_070926_040700.WAV` → `.wav`
- `samples/JT4/JT4F/OK1KIR_141105_175700.WAV` → `.wav`

No other samples are affected.

### Expected-token extraction methodology

For each of the 17 cases, pick 2–3 highest-SNR decodes from the known-good baseline as expected tokens. Strong decodes (SNR > 0) generally don't regress with decoder tweaks; weak decodes (SNR < -20) can drift noisily. Any-of matching against 2–3 strong decodes gives robust regression signal without false alarms.

For the FT8 MT decoder case, expected tokens should **overlap** with the FT8 standard decoder's tokens — the two decoders should agree on strong decodes. This gives a cross-decoder consistency property at no extra cost.

This methodology is documented in `tests/decoders/franke/README.md` so future bug-bust additions follow the same rule.

### Reference vendor (Steve's materials)

After receiving written GPLv3 vendoring consent from the original author:

- `tests/decoders/franke/reference/decoder_tests.bash` — Steve's script, preserved as-is, with a **prepended attribution header** (author, date, "vendored with permission under GPLv3"). Not executed by CI.
- `tests/decoders/franke/reference/decoder_test_results_v3.0.1.txt` — baseline capture.
- `tests/decoders/franke/README.md` — origin story, translation methodology, and a walkthrough of adding a new bug-bust case.

Script and baseline remain available for human inspection ("did the MT decoder ever produce decode X?"), but the test oracle is the catalog, not the script.

### Phase 2 disposition

**Keep.** Phase 2's two smoke tests (`decoder_ft8_smoke`, `decoder_wspr_smoke`) run in seconds and pin FT8 + WSPR. They carry label `smoke`; the Phase 3 catalog carries label `franke`. `ctest -L smoke` is a fast path for contributor laptops; CI runs the full set.

## Out of scope

- Python / ffmpeg rewrite of the script itself. Unnecessary — we want the coverage, not a reimplementation.
- Baseline-diff comparison against Steve's `v3.0.1` capture. Brittle; our `develop` branch build will not match byte-for-byte.
- Automatic decoder-output artifact archive for manual review. Phase 6 (`publish-ctest-summary.py` + ctest JUnit) already provides this.
- `sox` as a CI dependency on any platform.
- Windows-specific workarounds beyond what Phase 2 already handles.

## Files to change (evidence-based inventory)

**Modify:**

- `tests/decoders/run_decoder_test.cmake` — add `SAMPLES` (multi-arg) support, add `EXPECTED_TOKENS` (any-of) matching, preserve `SAMPLE` / `EXPECTED` as single-value aliases.
- `tests/decoders/CMakeLists.txt` — add `add_decoder_test()` helper macro; add 17 catalog entries; attach label `smoke` to Phase 2 tests and `franke` to the new entries.

**Add (new files):**

- `samples/JT4/JT4A/preprocessed/DF2ZC_070926_040700_12k_pad1.wav`
- `samples/JT4/JT4F/preprocessed/OK1KIR_141105_175700_12k_pad1.wav`
- `samples/JT65/JT65B/preprocessed/000000_000{1,3,5,7}_trim2.1_pad2.1.wav` (4 files)
- `samples/JT65/JT65B/preprocessed/000000_000{2,4,6}_trim2.1_pad2.1.wav` (3 files)
- `samples/JT65/JT65B/preprocessed/DL7UAE_040308_002400_12k_pad3_trim3.wav`
- `samples/Q65/60A_EME_6m/preprocessed/210106_1621_trim2.5_pad2.5.wav`
- `samples/Q65/60D_EME_10GHz/preprocessed/201212_1838_trim2.5_pad2.5.wav`
- `samples/PREPROCESSING.md` — sox commands used, reproduction steps, relationship to the catalog.
- `tests/decoders/franke/reference/decoder_tests.bash` — vendored, attribution-headered (after consent).
- `tests/decoders/franke/reference/decoder_test_results_v3.0.1.txt` — vendored baseline (after consent).
- `tests/decoders/franke/README.md` — origin, translation methodology, extension walkthrough.

**Rename (case-sensitivity fix):**

- `samples/JT4/JT4A/DF2ZC_070926_040700.WAV` → `.wav`
- `samples/JT4/JT4F/OK1KIR_141105_175700.WAV` → `.wav`

**Unchanged:**

- `.github/workflows/build-macos.yml`, `build-linux.yml`, `build-windows.yml`, `ci.yml`. ctest is already wired in each (Phase 6 landed); no new CI steps, no sox install. This is the payoff for commit-time pre-processing.
- Root `CMakeLists.txt` — line 2034 `add_subdirectory(tests/decoders)` already present.
- `tests/CMakeLists.txt` — already minimal; no change.

## Implementation phases

Each phase is one session with an explicit STOP point. Do not bundle across sessions.

### Phase 3a — Driver extension

**Deliverable:** Extended `run_decoder_test.cmake` handling multi-sample input and any-of expected tokens. Backwards compatible — Phase 2 tests pass unchanged.

**Verification:**
- `cd wsjtx-build && ctest -R smoke --output-on-failure` → both Phase 2 tests pass (regression check).
- Manual: `cmake -DDECODER=$(pwd)/jt9 -DSAMPLES="a.wav;b.wav" -DEXPECTED_TOKENS="X;Y" -P tests/decoders/run_decoder_test.cmake` → invokes decoder once with both samples positional, passes if X or Y in stdout.
- CI green on all four platforms.

**STOP** after driver extension + regression pass + CI green.

### Phase 3b — Sample pre-processing + case-sensitivity rename

**Deliverable:** Pre-processed WAVs committed under `samples/**/preprocessed/`. `samples/PREPROCESSING.md` documents the sox invocations used to produce each file. The two `.WAV` → `.wav` renames landed. No test changes yet.

**Verification:**
- `ls samples/**/preprocessed/*.wav` shows all expected files.
- `samples/PREPROCESSING.md` reads clearly; another contributor could reproduce the pre-processing.
- CI green (sample layout additions don't break anything).

**STOP** after samples committed and CI green.

### Phase 3c — Populate test catalog

**Deliverable:** All 17 cases from Steve's script mapped to `add_decoder_test()` entries in `tests/decoders/CMakeLists.txt`. Each entry carries a `PROVENANCE` comment and 2–3 expected tokens drawn from the known-good baseline. `add_decoder_test()` helper macro lands in the same commit.

**Verification:**
- `ctest -L franke --output-on-failure` green locally.
- `gh run watch --repo KJ5HST-LABS/wsjtx-internal` green on all four platforms.
- `ctest -L smoke` still passes Phase 2 tests (no regression).

**STOP** after catalog green on all platforms.

### Phase 3d — Attribution vendor + Phase 3 close

**Precondition:** Written consent from the script's author (Steven Franke) for GPLv3 vendoring, plus preferred attribution line.

**Deliverable:** Steve's script + baseline vendored under `tests/decoders/franke/reference/` with attribution header. `tests/decoders/franke/README.md` written and includes a walkthrough of adding a new bug-bust case. `CTEST_PFUNIT_INTEGRATION_PLAN.md` §Phase 3 marked DONE.

**Verification:**
- Repo contains vendored materials with proper headers.
- README walks a fictional contributor through adding a new case end-to-end.

**STOP** after docs land. Phase 3 complete.

## Adding a future bug-bust case (walkthrough)

1. A bug surfaces on mode `M`, sample `S.wav`, with decoder options `O`.
2. On a known-good build, run `jt9 O S.wav` and capture stdout.
3. Pick 2–3 strong decodes (high SNR) as expected tokens.
4. Add to `tests/decoders/CMakeLists.txt`:
   ```cmake
   add_decoder_test(
     NAME            decoder_<mode>_<bug>
     DECODER         jt9
     OPTIONS         "<O>"
     SAMPLES         "${CMAKE_SOURCE_DIR}/samples/<path>/<S.wav>"
     EXPECTED_TOKENS "<token1>;<token2>;<token3>"
     PROVENANCE      "bug: <ticket or short description>"
   )
   ```
5. If the sample needs pre-processing, add it to `samples/PREPROCESSING.md` and commit the pre-processed WAV under `samples/<mode>/preprocessed/`.
6. Commit. CI green = regression pinned.

No scripts, no bash, no sox install.
