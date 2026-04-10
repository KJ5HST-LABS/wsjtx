# Two-Repo CI/CD Proof of Concept

## Context

The WSJT-X team uses a two-repo model: `wsjtx-internal` (private, `develop` branch) for active development, `wsjtx` (public, `master` branch) for tagged releases. They have no CI/CD. We replicate their workflow under KJ5HST-LABS with three-platform CI/CD, prove it works with 3 test changes, then share with the team.

## Status

| Phase | Status | Sessions |
|-------|--------|----------|
| Phase 1: Repo setup | **COMPLETE** | Session 5 |
| Phase 2: CI workflows | **COMPLETE** | Sessions 6–8 |
| Phase 3: Test changes | **COMPLETE** | Sessions 5–9 |
| Phase 4: Document & share | **COMPLETE** | Session 10 |

**Proof runs:**
- CI: `24222053261` — all three platforms green (2026-04-10)
- Release: `24224001691` — tag-triggered build + GitHub Release + public sync all green (2026-04-10)
- Test artifacts (`v3.0.0.1` release/tags, deploy key, failed runs) cleaned up in Session 10

## Phase 1: Repo Setup — COMPLETE

1. **Renamed** `WSJT-X-MAC-ARM64` → `KJ5HST-LABS/wsjtx-internal`
2. **Renamed `main` → `develop`** — imported upstream `WSJTX/wsjtx` v3.0.0 source
3. **Created `KJ5HST-LABS/wsjtx`** (private, `main` default)
4. **Secrets**: `CROSS_REPO_TOKEN` (fine-grained PAT, repo secret on wsjtx-internal) for public repo sync. `WSJTX_DEPLOY_KEY` removed (Session 10).

## Phase 2: CI Workflows

### Architecture: reusable workflows (no duplication)

```
.github/workflows/
├── build-macos.yml      (reusable via workflow_call) — GREEN
├── build-linux.yml      (reusable via workflow_call) — GREEN
├── build-windows.yml    (reusable via workflow_call) — GREEN
├── ci.yml               (calls all three on push/PR to develop) — GREEN
└── release.yml          (tag-triggered, publishes to wsjtx) — GREEN
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

### Release workflow (`release.yml`) — COMPLETE

Tag-triggered (`v*` tags). Calls all three platform builds, then:
1. Creates GitHub Release on `wsjtx-internal` with all artifacts
2. Pushes source to `KJ5HST-LABS/wsjtx` (public) via `CROSS_REPO_TOKEN`

**Key discovery:** Deploy keys cannot push `.github/workflows/` files (GitHub platform restriction). The error message ("OAuth App") is misleading. Fix: use a fine-grained PAT (`CROSS_REPO_TOKEN`) with Contents + Workflows write access over HTTPS.

**`CROSS_REPO_TOKEN`**: Fine-grained PAT (Token ID 13035353, expires 2027-04-03), scoped to all KJ5HST-LABS repos. Set as a repo secret on `wsjtx-internal`.

### Remaining workflow patches (sed in CI, not upstreamed)

| Patch | Why | Upstream path |
|-------|-----|---------------|
| `FindFFTW3.cmake` threads fix | MSYS2 splits FFTW threads into separate lib | Could be a CMake change like the OmniRig one |
| MAP65 `add_subdirectory` skip | GCC 15 rejects legacy Fortran `decode0.f90` | Upstream Fortran modernization (not our problem) |
| `dumpcpp-qt5` → `dumpcpp` symlink | MSYS2 naming convention | MSYS2-specific, no upstream fix |

## Phase 3: Three Test Changes — COMPLETE

1. **README badge** — commit `4edab10b1`, CI green ✓
2. **CMake deployment target fix** — commit `b446c9328`, CI green ✓
3. **Version bump + tag `v3.0.0.1`** → release run `24224001691`, GitHub Release created, public sync verified ✓

All three test changes pushed to `develop`, triggered CI, and passed on all three platforms. The tag-triggered release workflow created a GitHub Release with macOS/Linux/Windows artifacts and synced source to the public repo.

## Phase 4: Document & Share — COMPLETE

- Email draft updated with concrete results from all phases (`docs/contributor/drafts/email_cicd_proposal.md`)
- Test artifacts cleaned up:
  - Deleted `v3.0.0.1` release + tag from `wsjtx-internal`
  - Deleted `v3.0.0.1` tag from `wsjtx` (public)
  - Removed `WSJTX_DEPLOY_KEY` secret (superseded by `CROSS_REPO_TOKEN`)
  - Deleted failed/misleading release runs (`24223492593`, `24221494190`)

## Build Order

```
Phase 1: Repo setup ✓
Phase 2: CI workflows
  → build-macos.yml + ci.yml ✓
  → build-linux.yml ✓
  → build-windows.yml ✓
  → release.yml ✓
Phase 3: Three test changes ✓
Phase 4: Document & share ✓
```
