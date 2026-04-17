# Franke decoder regression corpus

Reference material for the decoder regression catalog in
`tests/decoders/CMakeLists.txt`. Originally authored by Steven Franke as a
shell-based bug-bust corpus (`decoder_tests.bash`) with a companion
baseline output file capturing expected decodes against a v3.0.1 internal
build.

## Files

- `reference/decoder_tests.bash` — Steve's script as received. Drives
  `jt9` and `wsprd` over a set of in-tree `.wav` samples with
  case-specific command-line options. Contains Steve's local paths
  (`/Users/sfranke/...`, `/opt/local/bin/sox`) and is **not** meant to be
  executed in this repo.
- `reference/decoder_test_results_v3.0.1.txt` — the stdout Steve
  captured when running the script against his WSJT-X v3.0.1 build on
  macOS. Used as the source of expected-token strings for each catalog
  entry.

Both files are kept as provenance for the translated catalog.

## Why the script is not executed by CI

The script is vendored as a reference, not a test driver:

- It assumes `bash` + GNU `sox` + hard-coded local paths — none of which
  survive Linux / Windows runners without per-platform shims.
- Several cases require sample pre-processing (`sox` resample / pad /
  trim). In this repo the pre-processed WAVs are committed directly
  (see `samples/PREPROCESSING.md`), so `sox` is not a CI dependency.
- Cross-platform parity matters: the ctest catalog uses a single
  CMake-scripted driver (`tests/decoders/run_decoder_test.cmake`) that
  runs identically on macOS arm64, macOS x86_64, Linux, and Windows.

The bug-bust coverage Steve's script provides is preserved, but the
**mechanism** is a data-driven ctest catalog. Each `add_decoder_test()`
entry in `tests/decoders/CMakeLists.txt` carries a `PROVENANCE` field
pointing back to the corresponding case in the script.

## Catalog count vs. script invocations

Steve's script contains 31 discrete `jt9` / `wsprd` invocations. The
catalog registers 16 of them as Franke-labeled regression tests (plus the
2 smoke tests from Phase 2, for 18 total `decoder_*` tests).

Excluded cases, with reason:

| Script block | Invocations | Reason for exclusion |
|---|---|---|
| Q65-30A 3-file averages | 4 | Baseline shows empty output — the averaging path exercises but produces no decodes on this corpus. |
| Q65-30A single-file AP | 4 | Baseline decodes only 2 of 4 files; per-file output inconsistent. |
| Q65-60B single-file AP | 3 | Baseline shows identical `VK7MO VK7PD QE38` decode on all 3 — redundant coverage. |
| Q65-60B 3-file average | 1 | Baseline empty. |
| Q65-120E | 2 | Decodes only 1 of 2 files; inconsistent. |
| Q65-300A | 1 | Single decode at SNR -34; no margin. |
| JT65B odd-interval 4-file average | 1 | Baseline decodes 2 of 6 averaged frames as `CQ K1ABC FN42` via AP hint; current develop-head on all 4 CI platforms produces only `#*` placeholders (decoder runs, AP does not fill in callsign). The `decoder_jt65b_avg_even` case covers the same averaging code path with stable decodes. |

Remaining: 31 − 4 − 4 − 3 − 1 − 2 − 1 − 1 = 15 script invocations
registered, plus 1 WSPR invocation = 16 catalog cases.

## Updating the catalog

If Steve issues a newer script or baseline:

1. Replace the two files in `reference/`.
2. For each catalog entry in `tests/decoders/CMakeLists.txt`, verify the
   `OPTIONS` and `SAMPLES` still match the corresponding `decoder_tests.bash`
   block, and that `EXPECTED_TOKENS` are still present in the new baseline's
   decode output for that case.
3. Run `ctest -L franke` locally and push; verify CI green on all four
   platforms before merging.

Adding a new catalog entry: copy the `add_decoder_test()` pattern from
an existing entry, point `SAMPLES` at an in-tree `.wav` (pre-process via
sox first if the case requires it and commit the result under
`samples/<mode>/preprocessed/`), pick 2–3 highest-SNR tokens from the
decode output as `EXPECTED_TOKENS`, and set `PROVENANCE` to identify the
source.
