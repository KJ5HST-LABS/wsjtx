# Two-Repo CI/CD Proof of Concept

## Context

The WSJT-X team uses a two-repo model: `wsjtx-internal` (private, `develop` branch) for active development, `wsjtx` (public, `master` branch) for tagged releases. They have no CI/CD. We replicate their workflow under KJ5HST-LABS with three-platform CI/CD, prove it works with 3 test changes, then share with the team.

## Status

| Phase | Status | Sessions |
|-------|--------|----------|
| Phase 1: Repo setup | **COMPLETE** | Session 5 |
| Phase 2: CI workflows | **90% — release.yml remaining** | Sessions 6–7 |
| Phase 3: Test changes | Not started | — |
| Phase 4: Document & share | Not started | — |

**Proof run:** `24213369265` — all three platforms green (2026-04-09).

## Phase 1: Repo Setup — COMPLETE

1. **Renamed** `WSJT-X-MAC-ARM64` → `KJ5HST-LABS/wsjtx-internal`
2. **Renamed `main` → `develop`** — imported upstream `WSJTX/wsjtx` v3.0.0 source
3. **Created `KJ5HST-LABS/wsjtx`** (private, `main` default)
4. **Deploy keys** in place: `WSJTX_DEPLOY_KEY` (wsjtx-internal), `INTERNAL_DEPLOY_KEY` (wsjtx). Both read-write. Untested — `release.yml` not yet written.

## Phase 2: CI Workflows

### Architecture: reusable workflows (no duplication)

```
.github/workflows/
├── build-macos.yml      (reusable via workflow_call) — GREEN
├── build-linux.yml      (reusable via workflow_call) — GREEN
├── build-windows.yml    (reusable via workflow_call) — GREEN
├── ci.yml               (calls all three on push/PR to develop) — GREEN
└── release.yml          (TODO: tag-triggered, publishes to wsjtx)
```

Each `build-*.yml` uses `on: workflow_call` with shared inputs (version, hamlib_branch). `ci.yml` is a thin orchestrator — no build logic, just `uses:` calls. Separate per-platform workflows because build steps are radically different across platforms.

Old workflows (`build.yml`, `build-3.0.0.yml`) removed — superseded by this architecture.

### Platform builds (two-stage: Hamlib → WSJT-X)

**macOS** (`macos-15`, ARM64)
- brew deps + Hamlib 4.7.0 static build + WSJT-X cmake build
- Full signing + notarization via org secrets
- Hamlib cached (~5 min saved)

**Linux** (`ubuntu-24.04`)
- apt deps + same two-stage build, unsigned
- Hamlib cached

**Windows** (`windows-latest` + MSYS2 MINGW64)
- Hamlib 4.7.0 as shared lib
- OmniRig downloaded and installed silently; type library path passed via `-DOMNIRIG_TYPE_LIB`
- `dumpcpp-qt5` symlinked to `dumpcpp` (MSYS2 rename)
- MAP65 skipped (GCC 15 rejects legacy Fortran)
- FFTW3 FindModule patched for MSYS2 threads split
- MSYS Makefiles generator, unsigned
- Hamlib + MSYS2 cached

### Key CMakeLists.txt change

Lines 940–957: `OMNIRIG_TYPE_LIB` CMake variable. When set, bypasses the `dumpcpp -getfile` COM registry query and uses the provided file path directly. Backward-compatible — local builds with OmniRig installed work exactly as before. This change is upstream-submittable.

### Caching

- **Hamlib:** cached install prefix per OS + branch hash (saves 5–10 min/platform)
- **MSYS2:** built-in `cache: true` parameter
- **brew/apt:** not cached (fast enough, fragile invalidation)

### Windows CI findings (Session 6–7)

1. OmniRig installs to `C:\Program Files (x86)\Afreet\OmniRig\` on CI runners
2. MSYS2 renames Qt5 ActiveQt tools with `-qt5` suffix (`dumpcpp-qt5.exe`)
3. Upstream `find_program` check is buggy: `if (DUMPCPP-NOTFOUND)` checks a literal string variable, never fires
4. OmniRig.zip from dxatlas.com contains an InnoSetup installer (`/VERYSILENT /NORESTART`)
5. `dumpcpp -o <outfile> <infile>` works without COM registration — `LoadTypeLib()` from disk
6. Windows build: ~32 min (Hamlib cached), ~45 min without cache

### Remaining workflow patches (sed in CI, not upstreamed)

| Patch | Why | Upstream path |
|-------|-----|---------------|
| `FindFFTW3.cmake` threads fix | MSYS2 splits FFTW threads into separate lib | Could be a CMake change like the OmniRig one |
| MAP65 `add_subdirectory` skip | GCC 15 rejects legacy Fortran `decode0.f90` | Upstream Fortran modernization (not our problem) |
| `dumpcpp-qt5` → `dumpcpp` symlink | MSYS2 naming convention | MSYS2-specific, no upstream fix |

## Phase 3: Three Test Changes

1. **README badge** — push to `develop` → verify all 3 platforms build
2. **CMake deployment target fix** — real code change → verify rebuilds
3. **Version bump + tag `v3.0.0.1`** → `release.yml` fires, artifacts land on `KJ5HST-LABS/wsjtx` as GitHub Release

## Phase 4: Document & Share

- Update email draft (`docs/contributor/drafts/email_cicd_proposal.md`) with concrete results
- Share with team

## Build Order

```
Phase 1: Repo setup ✓
Phase 2: CI workflows
  → build-macos.yml + ci.yml ✓
  → build-linux.yml ✓
  → build-windows.yml ✓
  → release.yml (NEXT)
Phase 3: Three test changes
Phase 4: Document & share
```
