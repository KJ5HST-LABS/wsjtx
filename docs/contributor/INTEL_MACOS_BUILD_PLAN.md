# Intel macOS (x86_64) Build Job — Implementation Plan

**Issue:** KJ5HST-LABS/wsjtx-internal#8
**Author:** Session 24
**Status:** DRAFT — evidence-verified, ready for implementation

---

## Architecture Decision: Two Jobs vs. Universal Binary

**Recommendation: Two separate jobs, two separate `.pkg` installers.**

| Approach | Complexity | Maintenance | User Experience |
|----------|-----------|-------------|-----------------|
| Two jobs, two `.pkg` files | Low — each job is self-contained | Moderate — shared logic parameterized | Users download the `.pkg` matching their Mac |
| Universal binary (fat binary) | High — must build all deps (Qt5, Hamlib, FFTW, Boost, GCC runtime) twice and `lipo` them | High — Homebrew doesn't provide universal bottles; custom cross-build for every dep | Single download works on all Macs |

**Why not universal:** Homebrew does not ship universal (fat) bottles. Building universal Qt5, Hamlib, FFTW, Boost, and the GCC Fortran runtime from source doubles the dependency build time and adds significant `lipo`-merge complexity. The macOS ecosystem norm is separate architecture-specific downloads (Apple itself ships separate Intel and Apple Silicon installers for many tools). Two `.pkg` files is the pragmatic choice.

---

## Implementation Strategy: Parameterize `build-macos.yml`

**Recommendation: Add `arch` and `runner` inputs to the existing `build-macos.yml` rather than creating a duplicate file.**

### Why parameterize, not duplicate

The current `build-macos.yml` is 434 lines. The differences between arm64 and x86_64 are confined to ~15 specific locations (see inventory below). Duplicating the entire file creates 434 lines of maintenance debt — any future fix to signing, notarization, dylib bundling, or packaging must be applied twice. Parameterization keeps a single source of truth.

### What differs between arm64 and x86_64

| Aspect | ARM64 (current) | Intel x86_64 (new) |
|--------|-----------------|---------------------|
| Runner | `macos-15` | `macos-13` |
| Homebrew prefix | `/opt/homebrew` | `/usr/local` |
| Deployment target | `11.0` | `10.13` |
| gfortran fallback path | `/opt/homebrew/bin/gfortran-*` | `/usr/local/bin/gfortran-*` |
| Qt5 symlink target | `/opt/homebrew/mkspecs`, `/opt/homebrew/plugins` | `/usr/local/mkspecs`, `/usr/local/plugins` |
| Architecture verify | `lipo -archs ... | grep -q arm64` | `lipo -archs ... | grep -q x86_64` |
| Stage dir | `stage/wsjtx-$version-arm64` | `stage/wsjtx-$version-x86_64` |
| PKG identifier | `org.k1jt.wsjtx.arm64` | `org.k1jt.wsjtx.x86_64` |
| Artifact `.pkg` name | `wsjtx-$version-arm64-macOS.pkg` | `wsjtx-$version-x86_64-macOS.pkg` |
| Artifact upload name | `wsjtx-$version-arm64-macOS.pkg` | `wsjtx-$version-x86_64-macOS.pkg` |
| Individual binaries name | `individual-binaries-macos` | `individual-binaries-macos-intel` |
| Hamlib cache key | `hamlib-macos-$branch-$hash` | `hamlib-macos-intel-$branch-$hash` |
| Dylib bundling path checks | Hardcoded `/opt/homebrew` | Must use `$HOMEBREW_PREFIX` |

### What stays the same

Everything else: `brew install` commands (Homebrew resolves arch automatically), Hamlib build process, CMake configure (except deployment target), build step, entire signing pipeline, entire notarization pipeline, entire packaging pipeline, entire dylib bundling logic (once paths are parameterized).

---

## Grep-Based Inventory: All Lines Requiring Changes

### `.github/workflows/build-macos.yml` — parameterize

| Line(s) | Current Content | Change |
|---------|----------------|--------|
| 1 | `name: Build macOS arm64` | `name: Build macOS ${{ inputs.arch }}` (or remove arch from name) |
| 4-14 | `inputs:` block (version, hamlib_branch) | Add `arch` (required, string), `runner` (required, string), `deployment_target` (required, string) inputs |
| 18 | `runs-on: macos-15` | `runs-on: ${{ inputs.runner }}` |
| 20+ | (after checkout) | Add new step: "Set Homebrew prefix" — `echo "HOMEBREW_PREFIX=$(brew --prefix)" >> "$GITHUB_ENV"` |
| 29 | `ls /opt/homebrew/bin/gfortran-*` | `ls $HOMEBREW_PREFIX/bin/gfortran-*` |
| 36 | `[ -e /opt/homebrew/mkspecs ]` | `[ -e $HOMEBREW_PREFIX/mkspecs ]` |
| 36 | `ln -s "${QT5_PREFIX}/mkspecs" /opt/homebrew/mkspecs` | `ln -s "${QT5_PREFIX}/mkspecs" $HOMEBREW_PREFIX/mkspecs` |
| 37 | `[ -e /opt/homebrew/plugins ]` | `[ -e $HOMEBREW_PREFIX/plugins ]` |
| 37 | `ln -s "${QT5_PREFIX}/plugins" /opt/homebrew/plugins` | `ln -s "${QT5_PREFIX}/plugins" $HOMEBREW_PREFIX/plugins` |
| 44 | `key: hamlib-macos-${{ inputs.hamlib_branch }}-...` | `key: hamlib-macos-${{ inputs.arch }}-${{ inputs.hamlib_branch }}-...` |
| 65 | `-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0` | `-DCMAKE_OSX_DEPLOYMENT_TARGET=${{ inputs.deployment_target }}` |
| 76 | `grep -q arm64` | `grep -q ${{ inputs.arch }}` |
| 83 | `STAGE=stage/wsjtx-${{ inputs.version }}-arm64` | `STAGE=stage/wsjtx-${{ inputs.version }}-${{ inputs.arch }}` |
| 117 | `if [[ "$lib" == /opt/homebrew/* ]]` | `if [[ "$lib" == $HOMEBREW_PREFIX/* ]]` |
| 121 | `for dir in "$GCC_LIB" /opt/homebrew/lib` | `for dir in "$GCC_LIB" "$HOMEBREW_PREFIX/lib"` |
| 129 | `grep -E '(/opt/homebrew\|@rpath)'` | `grep -E "($HOMEBREW_PREFIX\|@rpath)"` |
| 164 | `grep /opt/homebrew` | `grep "$HOMEBREW_PREFIX"` |
| 221 | `grep /opt/homebrew` | `grep "$HOMEBREW_PREFIX"` |
| 304 | `PKG_ID="org.k1jt.wsjtx.arm64"` | `PKG_ID="org.k1jt.wsjtx.${{ inputs.arch }}"` |
| 348 | `"wsjtx-${{ inputs.version }}-arm64-macOS.pkg"` | `"wsjtx-${{ inputs.version }}-${{ inputs.arch }}-macOS.pkg"` |
| 377 | `notarize_and_staple "wsjtx-...-arm64-macOS.pkg"` | `notarize_and_staple "wsjtx-...-${{ inputs.arch }}-macOS.pkg"` |
| 410-411 | `name:` / `path:` with `-arm64-` | Replace `arm64` with `${{ inputs.arch }}` |
| 432 | `name: individual-binaries-macos` | `name: individual-binaries-macos-${{ inputs.arch }}` |

**Total: ~25 line changes in `build-macos.yml`.** All are mechanical substitutions — no logic changes.

### `.github/workflows/ci.yml` — add Intel job call

| Line(s) | Current Content | Change |
|---------|----------------|--------|
| 11-16 | `macos:` job (arm64 only) | Keep as-is but add explicit inputs |
| (new) | — | Add `macos-intel:` job block calling `build-macos.yml` with `arch: "x86_64"`, `runner: "macos-13"`, `deployment_target: "10.13"` |

Current `ci.yml` is 30 lines. After change: ~45 lines.

### `.github/workflows/release.yml` — add Intel job call

| Line(s) | Current Content | Change |
|---------|----------------|--------|
| 23-29 | `macos:` job | Add explicit `arch`, `runner`, `deployment_target` inputs |
| (new, after line 29) | — | Add `macos-intel:` job block with Intel inputs |
| 49 | `needs: [prepare, macos, linux, windows]` | `needs: [prepare, macos, macos-intel, linux, windows]` |

Current `release.yml` is 114 lines. After change: ~125 lines.

### `docs/contributor/1_CICD_EXECUTIVE_SUMMARY.md` — update platform lists

| Line | Current Content | Change |
|------|----------------|--------|
| 7 | "three platforms (macOS ARM64, Linux x86_64, Windows x86_64)" | "four platforms (macOS ARM64, macOS Intel x86_64, Linux x86_64, Windows x86_64)" |
| 27 | macOS ARM64 row only | Add row: `\| macOS Intel x86_64 \| ~10 min \| Yes \| Developer ID + Apple Notarization, Gatekeeper-ready \|` |
| 47 | "Five workflow files" | Still five files (parameterized, not a new file) |

### `docs/contributor/2_DEVELOPMENT_WORKFLOW.md` — update platform lists

| Line | Current Content | Change |
|------|----------------|--------|
| 182 | `- **macOS ARM64** — builds, signs, and notarizes` | Add line: `- **macOS Intel x86_64** — builds, signs, and notarizes` |
| 306 | "all three platforms (macOS ARM64, Linux x86_64, Windows x86_64)" | "all four platforms (macOS ARM64, macOS Intel x86_64, Linux x86_64, Windows x86_64)" |
| 332 | Runner table — macOS row | Add row: `\| macOS Intel \| \`macos-13\` \| x86_64 \| 10x multiplier \|` |
| 336 | "~80 minutes of billed time" | Update estimate (~110 min with second macOS build) |
| 358 | Release overview "1. Build macOS ARM64" | Add "2. Build macOS Intel x86_64" (renumber) |
| 459 | RC platform list | Add "macOS Intel x86_64" |
| 483 | Release artifact table — macOS row | Add row for `wsjtx-3.0.1-x86_64-macOS.pkg` |
| 685 | Release flow diagram — macOS line | Add Intel macOS line |

### `docs/contributor/3_CICD_DEPLOYMENT_PLAYBOOK.md` — update architecture + tables

| Line | Current Content | Change |
|------|----------------|--------|
| 69-70 | `build-macos.yml` description: "macOS ARM64 build" | "macOS build (arm64 or x86_64, parameterized)" |
| 89 | `build-macos.yml (parallel)` | Add second line: `├─→ build-macos.yml [Intel] (parallel)` |
| 99 | Same pattern | Same addition |
| 639 | "Three-platform CI" | "Four-platform CI" |
| 699-701 | Build time table | Add Intel macOS row |
| 950 | File inventory table | Update `build-macos.yml` description |

---

## Risk: `macos-13` Runner Deprecation

GitHub Actions `macos-13` is the **last Intel macOS runner**. All `macos-14+` runners are Apple Silicon. GitHub has not announced a deprecation date for `macos-13` as of 2026-04-16, but the trend is clear — Intel runners will eventually be removed.

**When `macos-13` is deprecated, options are:**

1. **Cross-compilation on ARM64 runner** — Use `CMAKE_OSX_ARCHITECTURES=x86_64` on `macos-15`. Works for C/C++ (Clang supports it natively). **Risk:** Homebrew `gfortran` may not cross-compile x86_64 on ARM64. Would need to verify or install an x86_64 cross-toolchain.
2. **Self-hosted Intel runner** — Run a Mac Mini (Intel) as a GitHub Actions runner. Full control but adds infrastructure.
3. **Drop Intel macOS** — If the Intel Mac user base shrinks enough.

**Mitigation for now:** Document this risk in the workflow file as a comment. When `macos-13` deprecation is announced, evaluate cross-compilation feasibility (specifically, gfortran cross-arch support).

---

## Gotcha: Homebrew on `macos-13`

On `macos-13` (Intel), Homebrew installs to `/usr/local`, not `/opt/homebrew`. The current `build-macos.yml` has `/opt/homebrew` hardcoded in 8 locations (dylib bundling, gfortran fallback, Qt5 symlinks). The parameterization replaces these with `$HOMEBREW_PREFIX` (set from `brew --prefix` at runtime), making the workflow work on both architectures without conditionals.

**Verification:** After implementation, check the Intel CI run's "Bundle dylibs" step output for any remaining `/opt/homebrew` references (which would indicate a missed substitution).

---

## Gotcha: Qt5 on `macos-13`

Homebrew's `qt@5` may behave differently on Intel. Verify:
- `brew --prefix qt@5` returns a valid path on `macos-13`
- Qt5 mkspecs and plugins symlinks work at `/usr/local/mkspecs` and `/usr/local/plugins`
- `macdeployqt` is available and functional

If Qt5 is unavailable or broken on `macos-13`, the build will fail at the Configure or "Bundle dylibs" step.

---

## Gotcha: Build Time and Billing

Adding a second macOS build job doubles the macOS Actions minutes cost:
- Current: 1 macOS job × 10x multiplier = ~80 min billed per CI run
- After: 2 macOS jobs × 10x multiplier = ~160 min billed per CI run
- Total per CI run: ~110 real min, ~210 billed min (with Linux + Windows)

On the free tier (2,000 min/month for private repos), this allows ~9-10 full CI runs/month. If the team pushes frequently, consider:
- Running Intel builds only on PRs (not every push to develop)
- Using a self-hosted Intel runner (0 billed minutes)

---

## Implementation Phases

### Phase 1: Parameterize `build-macos.yml` (1 session)

**Deliverable:** `build-macos.yml` accepts `arch`, `runner`, and `deployment_target` inputs. All hardcoded `/opt/homebrew` paths replaced with `$HOMEBREW_PREFIX`. Existing arm64 callers (`ci.yml`, `release.yml`) updated to pass the new required inputs. No behavior change for arm64 builds.

**Files changed:**
- `.github/workflows/build-macos.yml` (~25 line changes)
- `.github/workflows/ci.yml` (~5 line changes — add explicit inputs to existing `macos:` call)
- `.github/workflows/release.yml` (~5 line changes — add explicit inputs to existing `macos:` call)

**Verification:**
```bash
# Syntax check:
gh workflow view build-macos.yml --repo KJ5HST-LABS/wsjtx-internal

# Push to develop, verify arm64 CI still passes:
# (the Intel job is not wired up yet — this phase only parameterizes)
gh run watch --repo KJ5HST-LABS/wsjtx-internal
```

**DONE looks like:** ARM64 CI runs green with the parameterized workflow. No regression.

**Session boundary:** This phase is one session. Close out when done.

---

### Phase 2: Wire Intel job into CI and release (1 session)

**Deliverable:** `ci.yml` and `release.yml` each gain a `macos-intel:` job that calls the (now-parameterized) `build-macos.yml` with Intel inputs. Intel CI build runs and produces a signed, notarized `x86_64` `.pkg`.

**Files changed:**
- `.github/workflows/ci.yml` (~15 lines added — new `macos-intel:` block)
- `.github/workflows/release.yml` (~15 lines added — new `macos-intel:` block + `needs:` update)

**Verification:**
```bash
# Push to develop, verify both macOS jobs run:
gh run watch --repo KJ5HST-LABS/wsjtx-internal

# Check Intel job produces artifacts:
gh run view <RUN_ID> --repo KJ5HST-LABS/wsjtx-internal

# Verify the Intel .pkg artifact is uploaded:
# Look for wsjtx-*-x86_64-macOS.pkg in artifacts
```

**DONE looks like:** Both `macos` (arm64) and `macos-intel` (x86_64) jobs run green. Intel job produces `wsjtx-$version-x86_64-macOS.pkg` artifact.

**Session boundary:** This phase is one session. Close out when done.

**Note:** If the Intel build fails, debug in this session. Common failure points: Qt5 availability on `macos-13`, gfortran version differences, dylib bundling path issues. The arm64 build must remain green throughout.

---

### Phase 3: Update contributor docs (1 session)

**Deliverable:** Docs 1, 2, 3 updated to list both macOS targets. All "three platforms" references become "four platforms." Platform tables, diagrams, and artifact lists include Intel macOS.

**Files changed:**
- `docs/contributor/1_CICD_EXECUTIVE_SUMMARY.md` (~3 line changes)
- `docs/contributor/2_DEVELOPMENT_WORKFLOW.md` (~12 line changes)
- `docs/contributor/3_CICD_DEPLOYMENT_PLAYBOOK.md` (~8 line changes)

**Verification:**
```bash
# Grep for stale "three platform" references:
grep -rn "three platform" docs/contributor/
# Should return zero results

# Grep for missing Intel references in platform tables:
grep -n "macOS ARM64" docs/contributor/*.md
# Every line that lists ARM64 should have a corresponding Intel line nearby
```

**DONE looks like:** All contributor docs consistently reference four platforms. No "three platform" references remain. Issue #8 can be closed.

**Session boundary:** This phase is one session. Close out when done.

---

## Summary

| Phase | Deliverable | Files | Sessions |
|-------|------------|-------|----------|
| 1 | Parameterize `build-macos.yml` | 3 workflow files | 1 |
| 2 | Wire Intel job, get CI green | 2 workflow files | 1 |
| 3 | Update docs 1, 2, 3 | 3 doc files | 1 |
| **Total** | | **8 files** | **3 sessions** (+ this planning session) |
