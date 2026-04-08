# Two-Repo CI/CD Proof of Concept

## Context

The WSJT-X team uses a two-repo model: `wsjtx-internal` (private, `develop` branch) for active development, `wsjtx` (public, `master` branch) for tagged releases. They have no CI/CD. We're going to replicate their workflow under KJ5HST-LABS with three-platform CI/CD, prove it works with 3 test changes, then share it with the team.

## Phase 1: Repo Setup

1. **Rename** `WSJT-X-MAC-ARM64` → `wsjtx-internal`
   - `gh repo rename wsjtx-internal`
   - Update local remote: `git remote set-url origin git@github.com:KJ5HST-LABS/wsjtx-internal.git`

2. **Rename `main` → `develop`** to match upstream's branch naming
   - Rename branch, set `develop` as default
   - Import upstream `WSJTX/wsjtx` v3.0.0 source into `develop`
   - Add `.github/workflows/ci.yml`, `.github/workflows/release.yml`

3. **Create `KJ5HST-LABS/wsjtx`** (private, empty, `main` default)
   - `gh repo create KJ5HST-LABS/wsjtx --private`

4. **Cross-repo auth**: deploy key for pushing tags from internal → public
   - Generate key pair, public key → wsjtx deploy key (write), private key → wsjtx-internal secret `WSJTX_DEPLOY_KEY`

## Phase 2: CI Workflows

Two workflow files on `develop`:

### `ci.yml` — Build verification
- **Triggers:** push to `develop`, PR to `develop`, manual dispatch
- **Jobs:** 3 parallel platform builds

### `release.yml` — Tag-triggered release
- **Triggers:** tag push matching `v*`
- **Jobs:** 3 parallel builds → `publish` job that pushes tag + code to `KJ5HST-LABS/wsjtx` and creates GitHub Release with artifacts

### Platform builds (two-stage: Hamlib → WSJT-X)

**macOS** (`macos-15`, ARM64) — proven, adapt from `build-3.0.0.yml`
- brew deps + Hamlib static build + WSJT-X cmake build
- Full signing + notarization (org secrets already in place)

**Linux** (`ubuntu-24.04`) — straightforward
- apt deps: `cmake gfortran libfftw3-dev libboost-all-dev qtbase5-dev qttools5-dev qtmultimedia5-dev libqt5serialport5-dev libusb-1.0-0-dev autoconf automake libtool`
- Same two-stage build, unsigned

**Windows** (`windows-latest` + MSYS2) — needs iteration
- `msys2/setup-msys2` action with MINGW64 subsystem
- Packages: `mingw-w64-x86_64-{gcc,gcc-fortran,cmake,qt5-base,qt5-multimedia,qt5-serialport,qt5-tools,qt5-websockets,fftw,boost,libusb,portaudio}`
- Hamlib as shared lib (per team's documented Windows process)
- Generator: `MSYS Makefiles`
- Unsigned

## Phase 3: Three Test Changes

1. **README badge** — add CI status badge, push to `develop` → verify all 3 platforms build
2. **CMake deployment target fix** — real code change, push to `develop` → verify all 3 platforms build
3. **Version bump + tag** — bump to 3.0.0.1, tag `v3.0.0.1`, push → verify release.yml fires, artifacts appear on `KJ5HST-LABS/wsjtx` as a GitHub Release

## Phase 4: Document & Share

- Update this doc with links to green builds and release artifacts
- Update the email draft (`docs/contributor/drafts/email_cicd_proposal.md`) with concrete results
- Share with team

## Build Order

```
Repo setup (rename, branch, create wsjtx, deploy key)
  → macOS CI job (working first) → Linux CI job → Windows CI job
    → release.yml → Test change 1 → Test change 2 → Test change 3 + tag
      → Document
```

## Key Files

- `.github/workflows/build-3.0.0.yml` — proven macOS two-stage build to adapt
- `entitlements.plist` — macOS Fortran JIT entitlements, must carry to `develop`
- `docs/contributor/drafts/email_cicd_proposal.md` — email draft to update with results
