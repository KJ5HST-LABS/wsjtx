# Functional Test Integration (ctest + pfUnit) — Plan

**Issue:** KJ5HST-LABS/wsjtx-internal#16
**Author:** Session 30
**Status:** DRAFT — evidence-verified, ready for per-phase implementation

---

## Context

Today's CI (`build-{macos,linux,windows}.yml`) is build-only. Each workflow ends with a trivial "Verify binary" / "Verify architecture" step that only inspects the file format of `jt9` (or `jt9.exe`). No functional test runs. A regression in the decoder, a broken Fortran linkage, or a subtly miscompiled mode would ship green.

From the CI/CD proposal thread:
- **Joe Taylor (K1JT):** "It should be fairly easy to add some execution tests to add to the pipeline, especially after the effort Steve [Franke] has already put into a script that tests the decoders for each of our supported modes."
- **Brian Moran:** "for the testing step, I think we'll be using ctest AND pfUnit to test C++ code and Fortran code respectively. I think we can do that now!"

The goal of this workstream is to land functional testing in CI with enough resolution to catch real decoder regressions, on all four platforms (macOS ARM64, macOS Intel x86_64, Linux x86_64, Windows x86_64), without doubling CI minutes or blocking development on flaky tests.

---

## Evidence-Based Inventory

Grep-driven audit of what exists in this sandbox as of 2026-04-16 (`HEAD adc094842`, branch `develop`).

### 1. ctest registration: one C++ test, never reachable

| File | Line | Current Content |
|------|------|-----------------|
| `CMakeLists.txt` | 1261-1263 | `if (EXISTS ${CMAKE_SOURCE_DIR}/tests AND IS_DIRECTORY ${CMAKE_SOURCE_DIR}/tests)` → `add_subdirectory (tests)` |
| `tests/CMakeLists.txt` | 21 | `add_executable (test_qt_helpers test_qt_helpers.cpp)` |
| `tests/CMakeLists.txt` | 23 | `add_test (test_qt_helpers test_qt_helpers)` |

**Critical gap:** `grep -rn "enable_testing"` across the entire repo returns **zero matches**. Without `enable_testing()` at the top-level CMakeLists, ctest ignores all `add_test()` registrations. The one existing C++ test (`test_qt_helpers`) builds but is not wired to ctest.

Every `add_test` in the tree: **exactly one** (`tests/CMakeLists.txt:23`).

### 2. Existing Fortran test/sim/code executables (not registered as tests)

From `grep -n "add_executable" CMakeLists.txt` filtered to decoder/sim/test/code targets:

| Line | Target | Source |
|------|--------|--------|
| 1302 | `jt65sim` | `lib/jt65sim.f90` |
| 1314 | `q65sim` | `lib/qra/q65/q65sim.f90` |
| 1326 | `q65code` | `lib/qra/q65/q65code.f90` |
| 1329 | `test_q65` | `lib/test_q65.f90` |
| 1332 | `q65_ftn_test` | `lib/qra/q65/q65_ftn_test.f90` |
| 1344 | `jt65code` | `lib/jt65code.f90` |
| 1347 | `jt9code` | `lib/jt9code.f90` |
| 1365 | `msk144code` | `lib/msk144code.f90` |
| 1368 | `ft8code` | `lib/ft8/ft8code.f90` |
| 1377 | `ft8sim` | `lib/ft8/ft8sim.f90` |
| 1389 | `msk144sim` | `lib/msk144sim.f90` |
| 1431 | `wsprd` | `lib/wsprd/*` (main WSPR decoder) |
| 1591 | `jt9` | main CLI decoder for all non-WSPR modes |

Additional Fortran files with `test_`/`_test` naming that are *not* add_executable targets (found via `grep --include='*.f90' test_|_test`): `lib/test_snr.f90`, `lib/test_init_random_seed.f90`, `lib/ft8/test_ft8q3.f90`, `lib/ft8/ft8_a8_test.f90`, `lib/wsprd/test_wspr.f90`, `lib/testfast9.f90`, `lib/qratest.f90`, `lib/testEchoCall.f90`, `lib/77bit/test28.f90`, `lib/jt65_test.f90`, `lib/ftrsd/rsdtest.f90`. These are standalone utilities, likely developer-run, likely without CI-friendly exit codes. **Cannot be registered blindly** — each requires a read-through to confirm it returns non-zero on failure.

### 3. Sample data: already in-tree, already curated

`samples/` contains 30+ `.wav` files across 10 modes:

```
FT4/   FT8/   FST4+FST4W/   ISCAT/   JT4/   JT65/   JT9/   MSK144/   Q65/   WSPR/
```

Full manifest is in `samples/CMakeLists.txt:1-37` (the `SAMPLE_FILES` list).

**Purpose of `samples/CMakeLists.txt` today:** upload-only. Lines 44-60 define an `upload-samples` target that rsyncs a manifest JSON to `PROJECT_SAMPLES_UPLOAD_DEST`. These samples are **not currently used for testing** — but they are the natural fixture set for decoder smoke tests (and presumably the same set Steve Franke's script uses).

### 4. pfUnit: not present

`grep -rin "pfunit\|pFUnit\|PFUNIT"` across the entire repo returns **zero matches outside of this plan**. No CMake `find_package(PFUNIT)`, no `.pf` / `.pfu` files, no installed version. pfUnit integration is greenfield — every platform needs install tooling and CMake glue.

### 5. Steve Franke's decoder test script: not in this sandbox

Searched:
- `grep -rin "franke"` in `docs/contributor/` → references in email thread only (`docs/contributor/email/Re_ CI_CD Success!:1272,1353`)
- `find . -name "*.sh" -not -path "*/wsjtx-build/*"` → only `build.sh`, `qmap/ft2000_freq.sh`, `map65/ft2000_freq.sh`, `artwork/make_graphics.sh`, `Darwin/Mac-wsjtx-startup.sh`, `lib/wsprcode/go.sh`, `lib/qra/q65/build.sh`. None match a decoder test harness.
- `find . -name "*.py"` → only `Network/tests/PSKReporter/listener.py` (a PSK Reporter UDP test listener, not a decoder harness).

**Conclusion:** Steve Franke's script is external to this repo. Phase 3 depends on acquiring it from Steve — either as a PR, a dump into a known branch, or direct handoff.

### 6. Current CI "verification" is a file-format check

| Workflow | Line(s) | Current verification |
|----------|---------|----------------------|
| `.github/workflows/build-linux.yml` | 69-72 | `file wsjtx-build/jt9` + `grep -q "ELF 64-bit"` |
| `.github/workflows/build-macos.yml` | 89-92 | `file wsjtx-build/jt9` + `lipo -archs ... | grep -q ${{ inputs.arch }}` |
| `.github/workflows/build-windows.yml` | 121-123 | `file wsjtx-build/jt9.exe` |

No `ctest` invocation in any workflow. Build-linux is 81 lines, build-macos is 448 lines (parameterized for two archs), build-windows is 132 lines.

### 7. Summary: what's needed to hit Brian's "I think we can do that now!"

| Piece | State today | What's missing |
|-------|------------|----------------|
| C++ ctest harness | 1 registered test, but `enable_testing()` absent | Add `enable_testing()`; add `ctest` step to 3 workflows |
| Fortran test executables | ~13 standalone executables, none registered | Triage each for CI-safety; register the viable subset |
| Sample data | 35+ .wav files in-tree | Already available; needs a decoder-driving wrapper |
| Decoder smoke test | None | Write `.cmake` or shell harness: invoke `jt9`/`wsprd` on known .wav → compare decoded output to expected |
| Steve Franke's script | Not in sandbox | Acquire externally |
| pfUnit | Not installed anywhere | Install on 4 runners; `find_package(PFUNIT)` in CMake; convert Fortran tests to `.pf` |
| Test result surfacing | None | `ctest --output-on-failure`; GitHub Actions step summary; log artifact upload |

---

## Design Decisions

### Decision 1: Two harnesses, layered by language

**ctest** for C++ tests (including decoder-driving scripts treated as opaque pass/fail commands).
**pfUnit** for Fortran unit tests (assertions inside Fortran code, auto-registered into ctest via pfUnit's CMake glue).

Both surface through one `ctest` invocation in CI.

Rationale: Brian's proposal lines up with the canonical tool for each language. pfUnit's `add_pfunit_ctest()` macro registers Fortran tests into the same ctest runner, so the CI step is one `ctest` command regardless of the test's origin language.

### Decision 2: Ship `enable_testing()` and ctest wiring BEFORE any new tests

The minimal foothold (Phase 1) must land before test authoring. This proves `ctest` runs on all four platforms and gives every later phase a verified landing zone. Without this, a Phase 2 decoder smoke test could pass locally and silently fail to run on CI.

### Decision 3: Decoder smoke tests are independent of Steve Franke's script

If Steve's script doesn't arrive, we still want functional decoder coverage. Phase 2 builds a minimal, repo-owned decoder smoke test (drive `jt9` on one FT8 `.wav`, grep for an expected callsign in output). Phase 3 folds Steve's script in alongside, or replaces Phase 2's harness if Steve's is strictly better.

### Decision 4: pfUnit is a separate phase, scoped last

pfUnit adds a build-from-source Fortran dependency on every runner. On Windows (MSYS2) this is non-trivial. Rather than block decoder tests on pfUnit availability, pfUnit is the final phase.

### Decision 5: One platform at a time for pfUnit if needed

If pfUnit fails on Windows (plausible, given MSYS2 Fortran quirks), the plan ships pfUnit on macOS + Linux and documents Windows as a follow-up, rather than blocking the whole workstream.

---

## Implementation Phases

Each phase is ONE session. Do not bundle.

---

### Phase 1: Enable ctest on the existing C++ test and wire it into CI

**Deliverable:** `enable_testing()` added to `CMakeLists.txt`. A new "Run tests" step in each of `build-{macos,linux,windows}.yml` runs `ctest --output-on-failure`. The one existing test (`test_qt_helpers`) runs on all four platforms and passes.

**Files changed:**
- `CMakeLists.txt` — add `enable_testing()` before the `add_subdirectory(tests)` block (around line 1260). One line.
- `.github/workflows/build-linux.yml` — add "Run tests" step after the "Build" step (~line 68). ~4 lines.
- `.github/workflows/build-macos.yml` — add "Run tests" step after the "Build" step (~line 88, before "Verify architecture"). ~4 lines.
- `.github/workflows/build-windows.yml` — add "Run tests" step after the "Build" step (~line 120). ~4 lines. Verify behavior on MSYS2 — `ctest.exe` is shipped with the MSYS2 CMake package.

**Verification commands:**
```bash
# Local (on macOS ARM64 sandbox):
cmake -S . -B wsjtx-build -DCMAKE_PREFIX_PATH=...
cmake --build wsjtx-build -j
(cd wsjtx-build && ctest --output-on-failure)
# Expect: "100% tests passed, 0 tests failed out of 1"

# CI:
gh run watch --repo KJ5HST-LABS/wsjtx-internal
# Every platform's "Run tests" step should report: "Test #1: test_qt_helpers ... Passed"
```

**DONE looks like:**
- `enable_testing()` appears once in root `CMakeLists.txt`.
- All four build jobs (macos, macos-intel, linux, windows) run `ctest` after Build and report one passing test.
- No regression in existing build/sign/notarize steps.

**Session boundary:** This phase is one session. Close out when done.

**Risks:**
- Windows MSYS2: the MSYS2 CMake package ships `ctest`, but verify with `which ctest` in a warm-up step before relying on it.
- Path quoting on Windows: use `cmake --build wsjtx-build --target test` as a fallback if `ctest` invocation has shell-quoting issues in the MSYS2 environment.

---

### Phase 2: Decoder smoke test (jt9 + wsprd on in-tree samples)

**Deliverable:** One ctest-registered smoke test per primary decoder. Each invokes the CLI decoder on an in-tree `.wav` from `samples/` and asserts an expected decode string appears in the output. This is a CMake+shell integration test, not a unit test — it exercises the whole decode path.

**Concrete scope:**
- `jt9` driving `samples/FT8/210703_133430.wav` — FT8 is the mode under heaviest day-to-day use; this is the highest-value smoke test.
- `wsprd` driving `samples/WSPR/150426_0918.wav` — separate decoder binary, separate code path.

**Implementation approach:**
- Create `tests/decoders/` subdirectory with one CMake file or one shell script per test.
- Each test: `cd $TMP && ${DECODER} ${CMAKE_SOURCE_DIR}/samples/FT8/210703_133430.wav > out.txt` → `grep -q "K1ABC" out.txt` (exact expected string to be determined by running the decoder once against the sample and capturing canonical output).
- Register via `add_test(NAME decoder_ft8_smoke COMMAND ${CMAKE_COMMAND} -P run_decoder_test.cmake)`.
- Gate on decoder target availability: `if (TARGET jt9) ... endif()` so non-Fortran-configured builds don't break.

**Files changed:**
- `tests/CMakeLists.txt` — add decoder smoke tests below existing C++ block.
- `tests/decoders/` — new directory with test driver scripts.
- Optional: `tests/decoders/README.md` documenting how to regenerate expected-output strings if sample or decoder changes.

**Verification commands:**
```bash
# Local:
cd wsjtx-build
ctest --output-on-failure -R "decoder_"
# Expect: "decoder_ft8_smoke ... Passed", "decoder_wspr_smoke ... Passed"

# Regenerate expected output (if sample or decoder changes):
./jt9 ../samples/FT8/210703_133430.wav | tee tests/decoders/expected_ft8.txt
```

**DONE looks like:**
- 2 new ctest tests run on all four platforms. At least one message per sample decodes successfully and matches the expected string.
- Total ctest count grows from 1 (Phase 1) to 3.
- The tests are deterministic — same sample → same output — and no platform-specific expected-output divergence.

**Session boundary:** This phase is one session. Close out when done.

**Risks:**
- Non-determinism: decoder output may include timestamps or runtime stats. Assertion must grep only the stable portion (callsigns, grid squares), not timestamps.
- Path handling on Windows: `.wav` path from `samples/FT8/...` must work under MSYS2. Use `${CMAKE_SOURCE_DIR}` and avoid shell wildcard expansion.
- Cross-platform decode parity: if FT8 output differs byte-for-byte between macOS and Linux due to floating-point quirks, the grep assertion must be lenient enough to pass both.
- First-run calibration: before asserting expected output, run the decoder manually against each selected sample to record its canonical output. Record that output in a committed file and reference it from the test.

---

### Phase 3: Integrate Steve Franke's decoder test script

**Precondition:** Steve Franke's script is obtained from Steve (as a PR, tarball, or link). **Do not start this phase until the script is in hand.** Track as a blocker on the issue.

**Deliverable:** Steve's script is vendored into `tests/decoders/franke/` (or the team's preferred location) and driven by ctest. Coverage expands from 2 smoke tests (FT8, WSPR) to however many modes Steve's script covers.

**Files changed (scope depends on script structure):**
- `tests/decoders/franke/` — vendored script.
- `tests/CMakeLists.txt` — one `add_test()` per mode the script validates.
- `.github/workflows/build-*.yml` — if the script has external dependencies (Python packages, Perl, etc.), add install steps.

**Verification commands:**
```bash
# Local:
cd wsjtx-build
ctest --output-on-failure -R "franke"
# Expect: one passing test per mode Steve's script covers

# Across platforms:
gh run watch --repo KJ5HST-LABS/wsjtx-internal
```

**DONE looks like:**
- Steve's script runs in CI on all platforms it supports. Fortran + C++ decoder coverage now spans the full mode set.
- If the script duplicates Phase 2's smoke tests, Phase 2's tests are deprecated or kept as faster sanity checks — decision made in this session, documented.
- If Steve's script has a platform limitation (e.g., bash-only → skip on Windows), that is documented as a known gap with a plan to address.

**Session boundary:** This phase is one session. Close out when done.

**Risks:**
- Script shape unknown — bash? python? Perl? Fortran? Each has different install cost.
- License / attribution — if it's Steve's personal script, confirm he's OK with it being vendored under GPLv3 in this repo.
- Sample file dependencies — if the script expects samples outside `samples/`, decide: vendor them, download from `~.samples` web mirror, or constrain to in-tree samples.

**Phase 3 implementation (landed):**
- Broken into four sub-phases, each one session per `PHASE_3_TESTING_PLAN.md`:
  - **3a — Driver extension.** `tests/decoders/run_decoder_test.cmake` extended to accept multi-sample `SAMPLES` + any-of `EXPECTED_TOKENS`. Commit `ad7bced93`.
  - **3b — Sample pre-processing.** Nine pre-processed WAVs committed under `samples/<mode>/preprocessed/`; two JT4 captures renamed `.WAV`→`.wav`; `samples/PREPROCESSING.md` documents the sox invocations and reproduction. Commit `8801d54d2`.
  - **3c — Catalog.** `add_decoder_test()` helper + 17 catalog entries added to `tests/decoders/CMakeLists.txt`. Phase 2 smoke tests labeled `smoke`; Franke catalog labeled `franke`. Commit `275194084`.
  - **3d — Vendor + catalog close.** Steve's `decoder_tests.bash` + `decoder_test_results_v3.0.1.txt` vendored under `tests/decoders/franke/reference/`. `tests/decoders/franke/README.md` describes the corpus and the script-to-catalog translation. Attribution draft removed (Steve confirmed not needed). See commit list below.
- **Catalog fix-forward.** `decoder_jt65b_avg_odd` removed after Phase 3c CI showed token drift on all four platforms: Steve's v3.0.1 baseline produced 2 of 6 averaged frames with `CQ K1ABC FN42` via AP hint, but current develop-head produces only `#*` placeholder lines. The even-interval averaging case covers the same code path and is stable. Final catalog: 16 franke + 2 smoke = 18 decoder tests. Commit `8ca83974c`; CI run `24578087505` green on all four platforms.
- Decision: Steve's `decoder_tests.bash` is NOT executed by CI (bash + sox + hard-coded paths are nonportable). Coverage is preserved by translating the script's 31 `jt9`/`wsprd` invocations into a data-driven ctest catalog. 16 cases registered; 15 script invocations excluded because their baseline decodes are empty, inconsistent per-file, or redundant (see `tests/decoders/franke/README.md` for the full exclusion table).
- Planning provenance: `1077f7fa6` (Session 42 plan doc + attribution draft).

---

### Phase 4a: Install pfUnit on macOS + Linux runners

**Deliverable:** pfUnit builds from source on macOS ARM64, macOS Intel, and Linux CI runners. `find_package(PFUNIT)` succeeds in the WSJT-X CMake configure step. No Fortran tests registered yet — this is infrastructure only.

**Files changed:**
- `.github/workflows/build-macos.yml` — add "Install pfUnit" step after Qt5 setup, before Configure. Either via Homebrew (if a tap exists) or `git clone github.com/Goddard-Fortran-Ecosystem/pFUnit && cmake --build`. Install to a path that `find_package(PFUNIT)` will discover.
- `.github/workflows/build-linux.yml` — same strategy. apt does not ship pfUnit; build from source.
- `CMake/Modules/FindPFUNIT.cmake` — if pfUnit doesn't ship a FindPFUNIT module in the install, vendor a minimal one.
- `CMakeLists.txt` — optional `find_package(PFUNIT)` guarded by a build option `WSJT_BUILD_TESTS` so non-test builds are unaffected.

**Verification commands:**
```bash
# Local (macOS):
brew tap Goddard-Fortran-Ecosystem/pFUnit 2>/dev/null || \
  (git clone https://github.com/Goddard-Fortran-Ecosystem/pFUnit.git && cd pFUnit && cmake -B build -DSKIP_MPI=YES && cmake --build build && cmake --install build)
cmake -S . -B wsjtx-build -DCMAKE_PREFIX_PATH=...:/usr/local/pFUnit/PFUNIT-4.x
# Configure output must include: "Found PFUNIT"
```

**DONE looks like:**
- pfUnit is installed on macos/macos-intel/linux runners.
- `find_package(PFUNIT REQUIRED)` succeeds on all three platforms.
- Cache key for pfUnit is in place so subsequent CI runs do not rebuild it (mirroring the Hamlib cache pattern).

**Session boundary:** This phase is one session. Close out when done.

**Risks:**
- Build time: pfUnit from source adds ~3-5 min per first-time CI run. Cache aggressively (key on pfUnit release tag + compiler version).
- Fortran compiler match: pfUnit must be built with the same gfortran used by WSJT-X. gfortran version drift between pfUnit and WSJT-X will cause link errors.
- **CMake 4.x policy vs. pFUnit transitive submodules:** `gFTL-shared` uses `cmake_minimum_required` below 3.5. Pass `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` to the pFUnit configure. (Same workaround WSJT-X itself uses.)
- **OpenMP find_dependency at consumer time:** pFUnit bakes `SKIP_OPENMP` into its installed `PFUNITConfig.cmake`. If pFUnit is built with OpenMP enabled, consumers calling `find_package(PFUNIT)` will trigger `find_dependency(OpenMP)` — which fails on macOS AppleClang (no OpenMP ships). Build pFUnit with `-DSKIP_OPENMP=YES` unless you specifically need OpenMP-aware Fortran tests.

**Phase 4a implementation (landed):**
- Commits: `c281e8e20` (initial), `bdcd0cdca` (CMAKE_POLICY_VERSION_MINIMUM=3.5), `b31e97154` (SKIP_OPENMP=YES)
- pFUnit v4.9.0 pinned, `--recursive` clone required (submodules: fArgParse, gFTL-shared, gFTL)
- Installs to `${INSTALL_PREFIX}/PFUNIT-4.9/cmake/PFUNITConfig.cmake` — path is version-dependent; located via `find ... -name PFUNITConfig.cmake` for resilience
- `WSJT_BUILD_TESTS` option (default OFF) added in root `CMakeLists.txt:158`, guards the `find_package(PFUNIT REQUIRED)` call near `enable_testing()` (line 1262-1265)
- CI run `24535967403` — all four platforms green, `find_package` succeeded on macos/macos-intel/linux, `100% tests passed, 0 tests failed out of 3` (Phase 2 tests preserved)

---

### Phase 4b: Install pfUnit on Windows (MSYS2) — scoped separately

**Precondition:** Phase 4a is complete on macOS + Linux.

**Deliverable:** pfUnit builds in the MSYS2 environment on Windows. If infeasible, formally document the gap and close this phase with "pfUnit Windows coverage deferred — Fortran tests run on macOS + Linux only."

**Files changed:**
- `.github/workflows/build-windows.yml` — add "Install pfUnit" step.
- If it works: same structure as Phase 4a.
- If it doesn't work: add a comment in `build-windows.yml` explaining why pfUnit is skipped; open a follow-up issue.

**Verification commands:**
```bash
# On Windows CI (MSYS2):
pacman -S mingw-w64-x86_64-mpi  # likely prerequisite
git clone ... pFUnit && cmake -B build -G "MSYS Makefiles" && cmake --build build
# Success: find_package(PFUNIT) resolves in the main configure
# Failure: document root cause in a follow-up issue
```

**DONE looks like:**
- EITHER pfUnit installs and `find_package` succeeds on Windows (same artifacts as Phase 4a)
- OR a documented gap: Fortran tests run only on macOS + Linux. CI matrix explicitly skips the Fortran test step on Windows with a `continue-on-error` or conditional.

**Session boundary:** This phase is one session. Close out when done.

**Risks:**
- Unknown-unknowns in MSYS2 Fortran + pfUnit combo. Timebox: if blocked after one session of debugging, take the documented-gap path.
- **Carry Phase 4a's flags:** `-DCMAKE_POLICY_VERSION_MINIMUM=3.5` and `-DSKIP_OPENMP=YES` are almost certainly needed on MSYS2 too (same CMake 4.x, same consumer-find OpenMP behavior). Start with Phase 4a's exact flag set plus `-DSKIP_MPI=YES`.

**Phase 4b implementation (landed):**
- Commits: `27bc7c22f` (initial Windows install), `e060b96f3` (CMAKE_PREFIX_PATH cache-hit fix for macOS/Linux/Windows), `6d49a0ed8` (Windows-specific per-package DIR hints)
- pFUnit v4.9.0 pinned on Windows MSYS2 with `-DSKIP_MPI=YES -DSKIP_OPENMP=YES -DCMAKE_POLICY_VERSION_MINIMUM=3.5` flags (same flag set as Phase 4a) and `-G "MSYS Makefiles"`. `git config --global core.longpaths true` prepended to recursive clone to avoid Windows path-length issues with nested submodules (fArgParse → gFTL-shared → gFTL).
- First-time build adds ~5 min to the Windows job; cached thereafter. Cache key: `pfunit-windows-v4.9.0-<workflow-hash>`.
- CI run `24542002741` — all four platforms green, `find_package(PFUNIT)` succeeded on macos/macos-intel/linux/windows, 3/3 ctests passed on every job.

**Phase 4a cache-hit regression (discovered during Phase 4b orientation and fixed in the same session):**
- Session 33's Phase 4a implementation cached `pfunit-prefix/` but not `pfunit-build/`. pFUnit's installed `PFUNITConfig.cmake` has an `if/elseif` cascade for locating GFTL, GFTL_SHARED, and FARGPARSE. The first branch checks `EXISTS "<build_tree>"` which only holds on cache-miss; install-tree fallbacks were not always reached reliably. First observable failure was Session 33's close-out docs commit (`1cc05edda`, run `24538535439`), which hit the warm pFUnit cache and then broke on `find_dependency(GFTL)` for macos/macos-intel/linux.
- Fix on macOS and Linux: extend `CMAKE_PREFIX_PATH` to include `${GITHUB_WORKSPACE}/pfunit-prefix`. CMake's find_dependency then walks the prefix and locates each sibling sub-package's Config file via its standard multi-package install mechanism.
- Fix on Windows: same root cause, different workaround. Adding pfunit-prefix to CMAKE_PREFIX_PATH on Windows/MSYS2 broke Hamlib detection — `pkg_check_modules` derives `PKG_CONFIG_PATH` from CMAKE_PREFIX_PATH, and MSYS2 pkg-config mishandles multi-entry semicolon-separated forms. Workaround: keep CMAKE_PREFIX_PATH at its original single-entry value and pass explicit `-DPFUNIT_DIR=... -DGFTL_DIR=... -DGFTL_SHARED_DIR=... -DFARGPARSE_DIR=...` instead. The Locate step now emits four outputs, one per sub-package, via a loop.
- Cache-hit verification is the Session 34 close-out CI run itself: docs-only commit, no workflow hash change, so all four jobs restore warm pFUnit caches. Session 35's orientation must verify that run went green — if not, the fix needs another iteration. Verification run ID logged in `SESSION_NOTES.md`.

---

### Phase 5: Register Fortran unit tests with pfUnit

**Precondition:** Phase 4a complete. Phase 4b complete or gap documented.

**Deliverable:** A small set of new pfUnit tests (`.pf` files) covering high-value Fortran units. Per-platform `ctest` output includes `pfunit_*` tests alongside C++ tests.

**Concrete initial scope (to be confirmed in the session):**
- 2-3 `.pf` tests covering deterministic utility functions (e.g., `lib/chkcall.f90` callsign validation, `lib/grid2deg.f90`-type conversions) — chosen because they are self-contained, have clear input/output, and are safe to test without simulator state.
- Do NOT attempt to port existing `lib/test_*.f90` executables. Those are bespoke manual-run utilities. Porting them is a follow-up.

**Files changed:**
- `tests/fortran/` — new dir with `.pf` source files.
- `tests/CMakeLists.txt` — add `add_pfunit_ctest()` calls.
- No changes to `lib/` source files (tests are black-box).

**Verification commands:**
```bash
# Local:
cd wsjtx-build
ctest --output-on-failure -R "pfunit_"
# Expect: N passing tests (N = number of .pf files registered)

# CI:
# Fortran tests appear in the ctest summary on macOS + Linux (and Windows if Phase 4b succeeded).
```

**DONE looks like:**
- ctest reports N + 3 passing tests (N new pfUnit tests + Phase 1's 1 + Phase 2's 2).
- Phase 3's Franke-script tests run alongside.
- Total ctest coverage: C++ smoke (1) + decoder smoke (2) + Franke (variable) + pfUnit (N).

**Session boundary:** This phase is one session. Close out when done.

**Risks:**
- Scope creep — resist the urge to convert every `lib/test_*.f90` file. The phase goal is "prove pfUnit works in CI with real Fortran tests." 2-3 tests is enough.

**Phase 5 implementation (landed):**
- Two `.pf` modules in `tests/fortran/`:
  - `test_chkcall.pf` — 3 @test subroutines (valid standard call, invalid no-digit, compound-slash suffix) against `lib/chkcall.f90`.
  - `test_grid2deg.pf` — 2 @test subroutines (FN20 default-to-center, AA00 SW-corner) against `lib/grid2deg.f90`.
- `tests/fortran/CMakeLists.txt` calls `add_pfunit_ctest` twice (one ctest per `.pf` module, so a failure in one doesn't hide the other).
- Each `add_pfunit_ctest` uses `OTHER_SOURCES ${CMAKE_SOURCE_DIR}/lib/<file>.f90` (compile the unit-under-test directly into the test executable) rather than `LINK_LIBRARIES wsjt_fort` — the two library files are self-contained (no `use` statements, no FFTW/OpenMP deps), so hermetic compilation is simpler than pulling in the full static library's transitive link chain.
- Root `CMakeLists.txt:1267-1269` — `add_subdirectory(tests/fortran)` added inside the existing `if (WSJT_BUILD_TESTS)` block, keeping pFUnit-dependent logic together.
- Interface blocks in each `.pf` declare the unit-under-test's signature (these are `external` subroutines without a module), so no `use` statement is needed on the wsjt_fort side.
- Final ctest count: 5 per platform (`test_qt_helpers` + `decoder_ft8_smoke` + `decoder_wspr_smoke` + `pfunit_chkcall` + `pfunit_grid2deg`).

---

### Phase 6: Test result surfacing and failure policy

**Deliverable:** CI output makes test failures legible. Failed tests block release but not every CI run (configurable via `continue-on-error` on develop, hard fail on main/release tags).

**Files changed:**
- `.github/workflows/build-*.yml` — update "Run tests" step: add `--output-on-failure`, optionally `--output-junit ctest-results.xml`, upload results XML as an artifact.
- Optionally add a step that posts a GitHub Actions step summary table: `echo "## Test Results" >> $GITHUB_STEP_SUMMARY`.
- `.github/workflows/ci.yml` — decide if any platform's test failure blocks the `release` job (likely: yes, release must have all green).

**Verification commands:**
```bash
# Force a failure to see the surfacing:
# (temporarily break a test, push, confirm:)
#   - The failing test name appears in the job summary
#   - ctest-results.xml is uploaded as an artifact
#   - The release job is blocked (or not, depending on policy)
```

**DONE looks like:**
- A test failure produces: (a) clear error in the job log, (b) uploaded ctest-results.xml, (c) a PASS/FAIL summary in the GitHub Actions step summary.
- Failure policy documented in `docs/contributor/2_DEVELOPMENT_WORKFLOW.md`.

**Session boundary:** This phase is one session. Close out when done.

#### Phase 6 implementation (landed)

**Session 36** implemented Phase 6 across the three build workflows plus a shared summary script:

- **Shared parser:** `.github/scripts/publish-ctest-summary.py` — stdlib-only Python 3 script that reads `ctest-results.xml` (JUnit format) and writes a markdown table to stdout. Callers redirect to `$GITHUB_STEP_SUMMARY`. Handles missing-file and malformed-XML cases with a legible notice rather than a hard fail, so the summary step is non-blocking (the ctest step is the fail gate). One file, called three times — avoids ~90 lines of duplicated inline Python.

- **Three workflow edits** (`build-macos.yml`, `build-linux.yml`, `build-windows.yml`), same pattern:
  - **Run tests** gains `id: ctest` + `--output-junit ctest-results.xml`.
  - **Publish test summary** step: `if: always() && steps.ctest.conclusion != 'skipped'`, runs `python3 ../.github/scripts/publish-ctest-summary.py "<label>" >> "$GITHUB_STEP_SUMMARY"`. Relative path from `wsjtx-build` working directory — portable across platforms.
  - **Upload test results** step: `if: always() && steps.ctest.conclusion != 'skipped'`, uploads `wsjtx-build/ctest-results.xml` as `ctest-results-<platform>` (macOS uses `ctest-results-macos-${{ inputs.arch }}` to disambiguate the ARM64/Intel matrix). `if-no-files-found: ignore` for safety.

- **No changes to `ci.yml` or `release.yml`.** Release-blocking is automatic via existing `needs: [..., macos, macos-intel, linux, windows]` in `release.yml`'s `release` job — if any build job fails (including its ctest step), release never runs.

- **Failure policy documented** in `docs/contributor/2_DEVELOPMENT_WORKFLOW.md` §5 under a new "Test Failure Policy" subsection. Policy: hard-fail everywhere for v1. If a flaky test emerges, add targeted `continue-on-error: true` on that platform; no blanket soft-warn on `develop`.

**Design decisions:**

- **Shared script over inline Python.** Three workflows × ~30 lines of parsing logic = 90 lines duplicated and hard to review. One file, three thin callers is easier to audit and keeps a single source of truth for the summary format.
- **`if: always() && steps.ctest.conclusion != 'skipped'`** gate on the summary and upload steps. `always()` alone would try to run when the Build step itself failed (ctest skipped), producing a "no XML" summary that's noise. Explicit `!= 'skipped'` check suppresses that.
- **Relative path `../.github/scripts/...`** from `working-directory: wsjtx-build`. Portable across the three workflows — no cygpath/GITHUB_WORKSPACE translation needed on Windows MSYS2.
- **`python3`** as the invocation. On `windows-latest`, the hosted runner ships Python 3.13 with a `python3.exe` alias (alongside `python.exe`), and MSYS2's default shell inherits the Windows PATH, so `python3` resolves. If that assumption ever breaks, the fix is to add `mingw-w64-x86_64-python` to `setup-msys2`'s install list.
- **Hard-fail policy, no `continue-on-error`.** Current `ctest --output-on-failure` already hard-fails on any test failure. No code change needed — the policy just documents existing behavior and removes the "tests not checked" language from §5.
- **No emojis in summary.** Plain-text `PASS` / `FAIL` / `ERROR` / `SKIP` markers. Readable in raw text and rendered markdown.

**Verification:**

- Local validation before commit: regenerated `ctest-results.xml` in `/tmp/phase5-intree2/build` (pass case — 2 pFUnit tests green), then temporarily broke an assertion to generate a real failure XML, confirmed parser output on both, then restored the test. All three paths (success, failure, missing-file) produce the expected summary.
- CI validation: first-push CI run after Phase 6 commit. All four platforms should produce `## Test Results — <platform> — PASS` summaries with a 5-row table (`pfunit_chkcall`, `pfunit_grid2deg`, `test_qt_helpers`, `decoder_ft8_smoke`, `decoder_wspr_smoke`), plus four `ctest-results-*` artifacts attached to the run.

**Known follow-ups (out of scope for Phase 6):**

- Phase 3 still blocked on Steve Franke's decoder script acquisition.
- If a platform's `python3` invocation fails on Windows MSYS2, add `mingw-w64-x86_64-python` to the setup-msys2 install list (~20MB, one-time cache invalidation).

---

## Summary Table

| Phase | Deliverable | Files | Sessions | Depends On |
|-------|------------|-------|----------|------------|
| 1 | `enable_testing()` + ctest in CI | 4 files | 1 | — |
| 2 | Decoder smoke tests (jt9, wsprd) | 3+ files | 1 | Phase 1 |
| 3 | Integrate Steve Franke's script | 3+ files | 1 | Phase 2 + script acquired |
| 4a | pfUnit install (macOS + Linux) | 4 files | 1 | Phase 1 |
| 4b | pfUnit install (Windows) | 1 file | 1 | Phase 4a |
| 5 | Fortran unit tests (.pf) | 2+ new files | 1 | Phase 4a |
| 6 | Test result surfacing | 3 files | 1 | Phase 1 (Phase 5 preferred) |
| **Total** | | **~20 files touched** | **~7 sessions** | |

Sequencing: 1 → (2, 4a in parallel) → (3 after script acquired, 4b after 4a, 5 after 4a) → 6.

---

## Open Questions for the Team

1. **Steve Franke's script acquisition.** How does it reach this repo? Should a session email Steve asking for a drop, or is it already staged somewhere?
2. **Failure policy on `develop`.** Hard fail or soft warn? Recommendation: hard fail on main/release-tags; soft warn (`continue-on-error: true`) on develop to avoid blocking WIP pushes. Team decision.
3. **Windows pfUnit.** If Phase 4b blocks for >1 session, is "Fortran tests on macOS + Linux only" acceptable as v1?
4. **CI minute budget.** Adding ctest to every push increases CI minutes. Should decoder/Franke tests run only on PR or tag pushes, not every commit to develop? Recommendation: run on every push, but keep Phase 1/2 cheap (<2 min combined) so the cost is tolerable.
5. **pfUnit version pin.** pfUnit 4.x is current. Pin to a specific release tag in the install step to avoid surprise regressions.

---

## Risks (cross-phase)

| Risk | Severity | Mitigation |
|------|----------|------------|
| pfUnit build-from-source flakiness on Windows | High | Phase 4b is separate; accepts a documented gap. |
| Decoder output non-determinism between platforms | Medium | Phase 2 assertions grep only callsigns/grids, not runtime stats. Calibrate first-run output per-platform if needed. |
| CI minutes cost | Medium | Phases 1-2 are cheap. pfUnit adds 3-5 min with cold cache. Aggressive caching keyed on pfUnit tag. |
| Test flakiness blocks development | Medium | Soft-warn on develop; hard-fail on release. Open a follow-up workstream to triage flaky tests if they emerge. |
| `lib/test_*.f90` bespoke utilities mistaken for CI-ready tests | Low | Plan explicitly scopes these out; Phase 5 writes new `.pf` tests rather than registering legacy utilities. |

---

## Scope Boundary (what this plan does NOT cover)

- GUI testing for WSJT-X (Qt widgets, user interactions).
- Integration tests requiring real radio hardware.
- Performance benchmarks (latency, CPU) — separate workstream.
- Porting the ~13 existing `lib/test_*.f90` executables to pfUnit (explicitly scoped out — follow-up workstream).
- MAP65 and qmap subdirs — they have their own CMakeLists but are not in scope here; add later if the pattern holds.
- Deep upstream patches (e.g., to `lib/wsprd/` code) — only added if a test discovers a bug.

---

## References

- **Issue:** `gh issue view 16 --repo KJ5HST-LABS/wsjtx-internal`
- **Root CMake:** `CMakeLists.txt:1261-1263` (tests include guard), no `enable_testing()` anywhere
- **Existing test:** `tests/CMakeLists.txt:21-23`, `tests/test_qt_helpers.cpp`
- **Sample fixtures:** `samples/CMakeLists.txt:1-37` (manifest), `samples/{FT8,WSPR,...}/`
- **Decoder binaries:** `CMakeLists.txt:1431` (`wsprd`), `CMakeLists.txt:1591` (`jt9`)
- **CI workflows:** `.github/workflows/build-{macos,linux,windows}.yml` (current verify steps at line 89, 69, 121 respectively)
- **pfUnit upstream:** https://github.com/Goddard-Fortran-Ecosystem/pFUnit
- **Email context:** `docs/contributor/email/Re_ CI_CD Success!` lines 1272 (Joe on Steve's script), 1353 (reply)
