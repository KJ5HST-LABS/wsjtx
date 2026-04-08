# Two-Repo CI/CD Proof of Concept

## Context

The WSJT-X team uses a two-repo model: `wsjtx-internal` (private, `develop` branch) for active development, `wsjtx` (public, `master` branch) for tagged releases. They have no CI/CD. We replicate their workflow under KJ5HST-LABS with three-platform CI/CD, prove it works with 3 test changes, then share with the team.

## Phase 1: Repo Setup

1. **Rename** `WSJT-X-MAC-ARM64` → `wsjtx-internal`
2. **Rename `main` → `develop`** — import upstream `WSJTX/wsjtx` v3.0.0 source, add CI workflows
3. **Create `KJ5HST-LABS/wsjtx`** (private, `main` default)
4. **Deploy key** for cross-repo push (internal → public)

## Phase 2: CI Workflows

### Architecture: reusable workflows (no duplication)

```
.github/workflows/
├── build-macos.yml      (reusable via workflow_call)
├── build-linux.yml      (reusable via workflow_call)
├── build-windows.yml    (reusable via workflow_call)
├── ci.yml               (calls all three on push/PR to develop)
└── release.yml          (calls all three on tag push, then publishes to wsjtx)
```

Each `build-*.yml` uses `on: workflow_call` with shared inputs (version, hamlib branch). `ci.yml` and `release.yml` are thin orchestrators — no build logic, just `uses:` calls. Separate per-platform workflows instead of matrix because build steps are radically different across platforms.

### Platform builds (two-stage: Hamlib → WSJT-X)

**macOS** (`macos-15`, ARM64) — proven, adapted from existing pipeline
- brew deps + Hamlib static build + WSJT-X cmake build
- Full signing + notarization

**Linux** (`ubuntu-24.04`)
- apt deps + same two-stage build, unsigned

**Windows** (`windows-latest` + MSYS2 MINGW64)
- Hamlib as shared lib (per team's Windows process)
- MSYS Makefiles generator, unsigned

### Caching

- **Hamlib:** cached install prefix per OS + branch (saves 5-10 min/platform)
- **MSYS2:** built-in cache parameter
- **brew/apt:** not cached (fast enough, fragile invalidation)

## Phase 3: Three Test Changes

1. **README badge** — push to `develop` → verify all 3 platforms build
2. **CMake deployment target fix** — real code change → verify rebuilds
3. **Version bump + tag `v3.0.0.1`** → release.yml fires, artifacts land on `KJ5HST-LABS/wsjtx` as GitHub Release

## Phase 4: Document & Share

- Update this doc with links to green builds and release artifacts
- Update email draft with concrete results
- Share with team

## Build Order

```
Phase 1: Repo setup (rename, branch, create wsjtx, deploy key)
Phase 2: One platform at a time:
  → build-macos.yml + ci.yml (macOS only) → verify green
  → build-linux.yml → verify green
  → build-windows.yml → verify green
  → release.yml → test with dummy tag
Phase 3: Three test changes
Phase 4: Document
```
