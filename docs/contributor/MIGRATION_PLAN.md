# WSJT-X: BitBucket/SourceForge to GitHub Migration & CI/CD Plan

**Author:** KJ5HST
**Status:** DRAFT — requires team review and buy-in
**Input:** `docs/contributor/REPO_AUDIT.md`

---

## Executive Summary

The WSJT-X project has migrated its source code from BitBucket to GitHub but the move is incomplete. The superbuild remains on SourceForge, releases go through SourceForge, there is no CI/CD, no branch protection, and no automation. This plan lays out the work required to complete the migration and bring the project to a fully automated CI/CD setup on GitHub.

---

## Where Things Stand Today (April 3, 2026)

| Component | Location | Status |
|-----------|----------|--------|
| WSJT-X source | GitHub (`WSJTX/wsjtx`, `WSJTX/wsjtx-internal`) | **Migrated** — wsjtx public master is 18 months stale; PR #2 (4,550 commits) pending merge at GA |
| Superbuild | SourceForge tarballs only | **Not migrated** — still references BitBucket and Bill's SF Hamlib fork |
| Hamlib dependency | `github.com/Hamlib/Hamlib` (`integration` branch) | **Resolved** — official GitHub repo is canonical |
| Releases | SourceForge downloads | **Not migrated** — GitHub Releases not used |
| CI/CD | None | **Does not exist** |
| Branch protection | None | **Does not exist** |
| CONTRIBUTING.md | None | **Does not exist** |
| Code signing (macOS) | Unknown — John G4KLA builds manually | **Unresolved** — Apple Developer account ownership unknown |
| Code signing (Windows) | Unknown | **Unresolved** |

---

## The Migration: Five Workstreams

### Workstream 1: Repository Hygiene (Post-GA)

**Goal:** Clean up the GitHub repos so they are ready for CI/CD and external contribution.

| Task | Repo | Effort | Dependency |
|------|------|--------|------------|
| Merge PR #2 (v3.0.0_test → master) | wsjtx | Team action | v3.0.0 GA (April 8) |
| Close orphaned PR #1 | wsjtx | 5 min | WRITE access |
| Close stale issue #1 | wsjtx-internal | 5 min | WRITE access |
| Delete typo branch `feat_mmty_interface` | wsjtx-internal | 5 min | WRITE access |
| Clean "IMPROVED by DG2YCB" from INSTALL/README | wsjtx-internal | 1 PR | Team consensus |
| Update stale URLs (BitBucket, SourceForge) in source | wsjtx-internal | 1 PR | List of URLs to change |

### Workstream 2: Contribution Infrastructure (Post-GA)

**Goal:** Make it possible for people to contribute safely.

| Task | Deliverable | Effort | Dependency |
|------|-------------|--------|------------|
| CONTRIBUTING.md | Build instructions, PR conventions, coding style | 1 session | WRITE access |
| PR template | Checklist (build tested, platforms, related issues) | included above | WRITE access |
| Branch protection on `master` (wsjtx) | Require PR, disable force-push | Team proposal + admin action | ADMIN access |
| Branch protection on `develop` (wsjtx-internal) | Same | Same | Same |
| Feature request template | Optional issue template | 1 PR | WRITE access |

### Workstream 3: CI/CD — Build Verification (Core Work)

**Goal:** Every push and PR gets an automated build. Developers know immediately if their change breaks the build.

#### 3A: macOS Build Workflow

```
Trigger: push to develop, PR to develop
Runner: macos-15 (GitHub-hosted, Apple Silicon)

Stage 1 — Build Hamlib:
  git clone https://github.com/Hamlib/Hamlib
  git checkout integration
  ./bootstrap && ./configure --prefix=$PREFIX --disable-shared --enable-static
  make && make install

Stage 2 — Build WSJT-X:
  cmake -S . -B build \
    -DCMAKE_PREFIX_PATH="$PREFIX;$(brew --prefix qt@5);..." \
    -DCMAKE_Fortran_COMPILER=$(brew --prefix gcc)/bin/gfortran \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0
  cmake --build build

Verify:
  lipo -archs build/jt9 | grep arm64
  # Run tests when they exist
```

**Estimated effort:** 1 session. The two-stage approach has been validated on macOS.

#### 3B: Linux Build Workflow

```
Trigger: push to develop, PR to develop
Runner: ubuntu-24.04 (GitHub-hosted)

Dependencies (apt):
  cmake gcc gfortran libfftw3-dev libboost-all-dev
  qtbase5-dev qttools5-dev qtmultimedia5-dev libqt5serialport5-dev
  libusb-1.0-0-dev libudev-dev

Stage 1 — Build Hamlib:
  (same as macOS, different configure flags)

Stage 2 — Build WSJT-X:
  cmake -S . -B build -DCMAKE_PREFIX_PATH="$PREFIX"
  cmake --build build

Verify:
  file build/jt9  # ELF 64-bit LSB executable, x86-64
```

**Estimated effort:** 1 session. All dependencies are in apt.

#### 3C: Windows Build Workflow

```
Trigger: push to develop, PR to develop
Runner: windows-latest (GitHub-hosted)

Dependencies:
  - MSYS2/MinGW-w64 or Visual Studio (team preference needed)
  - Qt5 (aqtinstall or pre-built)
  - FFTW3 (pre-built DLLs from fftw.org)
  - Boost (vcpkg or pre-built)
  - Hamlib (build from source or download pre-built DLLs)
```

**Estimated effort:** 2-3 sessions. Windows is the hardest platform — toolchain setup is complex, the team's current Windows build process is undocumented. Need team input on their toolchain before starting.

### Workstream 4: Superbuild Decision

**Goal:** Decide what happens to the superbuild.

| Option | Pros | Cons |
|--------|------|------|
| **A: Move superbuild to GitHub** (new repo) | Preserves existing build model. All source in one place. Enables PRs for fixes. | Another repo to maintain. |
| **B: Replace superbuild with CI/CD** | CI/CD does what the superbuild does. Cleaner architecture. | Developers lose the "one tarball" local build workflow. |
| **C: Keep superbuild on SourceForge** | No migration needed. | SourceForge dependency persists. URLs remain stale. |

**Recommendation:** Option B for CI/CD, Option C for developer convenience. The CI/CD pipeline replaces the superbuild's role in automated builds. The SourceForge tarball remains for developers who want the all-in-one local build experience.

**This decision belongs to Joe and the team.**

### Workstream 5: Release Automation

**Goal:** Tag a version, get signed installers for all platforms, published to GitHub Releases.

```
Trigger: tag push matching v*
Jobs: macOS-arm64, macOS-x86_64 (stretch), Linux-deb, Linux-AppImage, Windows-installer
Artifacts: signed packages + SHA256 checksums

Release flow:
  1. Developer tags: git tag v3.0.1 && git push --tags
  2. GitHub Actions builds all platforms
  3. Artifacts uploaded to GitHub Release (draft)
  4. Team reviews artifacts, marks release as published
  5. (Optional) Mirror to SourceForge for existing users
```

**Code signing requirements:**

| Platform | What's Needed | Who Has It | Status |
|----------|--------------|------------|--------|
| macOS | Apple Developer ID (Application + Installer certs) | Unknown (John G4KLA?) | **Must resolve** |
| Windows | Code signing certificate (EV or standard) | Unknown | **Must resolve** |
| Linux | GPG key for package signing | Team decision | Not blocking |

**Recommended approach:** Start with unsigned builds to prove the pipeline works. Add code signing when the team provides credentials. The workflow documents which secrets are needed and their format — the team configures the actual values.

---

## Prerequisites — What We Need

### Access

| Need | Current State | How to Get It | Blocks |
|------|---------------|---------------|--------|
| WRITE access to WSJTX org repos | READ-only | Email Joe or Brian | Workstreams 1, 2, 3, 5 |
| ADMIN access (or admin champion) | Not available | Brian (bmo) is natural candidate | Branch protection setup |
| Org-level GitHub Actions enabled | Unknown | Admin must verify in org settings | Workstream 3 |
| Secrets management access | Not available | Admin creates org-level secrets | Workstream 5 (signing) |

### Information

| Need | Why | How to Get It | Blocks |
|------|-----|---------------|--------|
| Apple Developer account ownership | macOS code signing | Ask team | Workstream 5 |
| Windows build toolchain details | Windows CI/CD | Ask Brian or Joe | Workstream 3C |
| Team's preference on superbuild | Architecture decision | Discuss after GA | Workstream 4 |
| Team's SourceForge release process | Know what we're supplementing | Ask Brian | Workstream 5 |
| Whether GitHub Actions is enabled at org level | Can't run workflows without it | Check org settings (needs admin) | Workstream 3 |

### Team Buy-In

| Decision | Who Decides | When to Ask | How to Present |
|----------|-------------|-------------|----------------|
| CI/CD on org repos | Joe (owner) | After GA | Working demo in a fork first |
| Branch protection | Joe (owner) | After GA, with CONTRIBUTING.md PR | Document as proposal |
| Superbuild future | Joe + team | After CI/CD proves value | Options table with recommendation |
| GitHub Releases as distribution channel | Joe + team | After release automation works | "Alongside SourceForge, not replacing it" |
| Code signing identity for official releases | Joe + team | When pipeline is ready | Present options with cost/effort |

### Technical Prerequisites

| Need | Why | Status |
|------|-----|--------|
| macOS GitHub-hosted runners are Apple Silicon | ARM64 builds require it (macos-14+ are M1) | Verified |
| Hamlib `integration` branch builds cleanly in CI | Foundation for all platform builds | Not yet tested in CI |
| Qt5 availability on all CI platforms | WSJT-X requires Qt5 | macOS: brew ✓. Linux: apt ✓. Windows: needs investigation |
| gfortran availability on all CI platforms | Fortran signal processing code | macOS: brew ✓. Linux: apt ✓. Windows: needs investigation |

---

## Proposed Timeline

### Constraints

- v3.0.0 GA is **April 8, 2026** — no disruptive work before then
- We have **READ-only access** — many tasks require WRITE or ADMIN
- **Team bandwidth is limited** — don't overwhelm them
- The team communicates via **email** — PRs need email heads-up

### Phase 0: Pre-GA Preparation (Now → April 8)

Do not touch the org repos. Prepare locally.

| Task | Deliverable |
|------|-------------|
| Write this plan | `docs/contributor/MIGRATION_PLAN.md` |
| Email team: request WRITE access | Email |
| Email team: ask about Apple Developer account, Windows toolchain | Email |
| Prototype two-stage build workflow | Tested in a fork |
| Draft CONTRIBUTING.md | Ready to PR post-GA |

### Phase 1: Quick Wins (April 8-15, post-GA)

**Requires:** WRITE access. v3.0.0 merged to master.

| Task | Workstream |
|------|------------|
| Close stale PR #1 / issue #1 | 1 |
| Submit CONTRIBUTING.md + PR template | 2 |
| Propose branch protection | 2 |
| Delete typo branch | 1 |

### Phase 2: macOS CI/CD (April 15-30)

**Requires:** GitHub Actions enabled at org level. WRITE access.

| Task | Workstream |
|------|------------|
| macOS build verification workflow | 3A |
| Test workflow on a PR | 3A |
| Email team with results | — |

### Phase 3: Linux CI/CD (May 2026)

**Requires:** macOS workflow accepted by team.

| Task | Workstream |
|------|------------|
| Linux build verification workflow | 3B |
| Build matrix: Ubuntu 22.04, 24.04 | 3B |

### Phase 4: Windows CI/CD (May-June 2026)

**Requires:** Team input on Windows toolchain.

| Task | Workstream |
|------|------------|
| Windows build verification workflow | 3C |
| Toolchain investigation / team coordination | 3C |

### Phase 5: Release Automation (June 2026)

**Requires:** All four platforms building. Code signing decision made.

| Task | Workstream |
|------|------------|
| Tag-triggered release workflow | 5 |
| Code signing integration | 5 |
| GitHub Release with download table + checksums | 5 |

### Upstream Patches (Parallel Track — Anytime)

| Task | Workstream |
|------|------------|
| CMake 4.x patches PR to wsjtx-internal | Patches |
| Deployment target fix (10.12 → 11.0 for ARM64) | Patches |
| URL updates (BitBucket → GitHub) | Patches |

---

## Risk Register

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Team doesn't grant WRITE access | Low | Blocks all org work | Fork and PR from fork |
| Team rejects CI/CD proposal | Medium | Blocks workstreams 3-5 | Demo in fork first |
| GitHub Actions not enabled at org level | Medium | Blocks workstream 3 | Admin must enable — ask Brian |
| Windows build requires tribal knowledge | High | Delays workstream 3C | Ask team early |
| Apple Developer account is personal | Medium | Complicates code signing | Build unsigned first; team obtains project identity when ready |
| Team prefers SourceForge as primary | Medium | Limits GitHub Releases | Position GitHub as supplementary |
| Qt5 EOL creates future build issues | Low (near-term) | May disappear from CI runner images | Monitor; Qt6 migration is team's decision |

---

## Success Criteria

The migration is complete when:

1. **Every push to `develop` triggers automated builds** on at least macOS and Linux
2. **Every PR gets build verification** before merge
3. **Branch protection prevents direct pushes** to `master` and `develop`
4. **A version tag produces signed installers** for all supported platforms
5. **GitHub Releases contain downloadable artifacts** alongside SourceForge
6. **CONTRIBUTING.md exists** and matches actual practice
7. **No stale references to BitBucket** remain in any GitHub-hosted source

---

## What We Do Not Decide

These are the team's decisions:

- Whether to retire SourceForge
- Whether to move the superbuild to GitHub
- Which signing identity to use for official releases
- Whether to adopt Qt6
- Whether to merge wsjtx and wsjtx-internal into one repo
- How to handle feature branches in CI

We propose, demonstrate, and support. We do not impose.

---

## Estimated Total Effort

| Workstream | Sessions | Calendar Time |
|------------|----------|---------------|
| 0: Pre-GA prep | 1-2 | Now → April 8 |
| 1: Repo hygiene | 0.5 | April 8-15 |
| 2: Contribution infrastructure | 0.5 | April 8-15 |
| 3A: macOS CI/CD | 1 | April 15-30 |
| 3B: Linux CI/CD | 1 | May |
| 3C: Windows CI/CD | 2-3 | May-June |
| 4: Superbuild decision | 0 (discussion) | After CI/CD works |
| 5: Release automation | 1-2 | June |
| Upstream patches | 1 | Anytime |
| **Total** | **8-11 sessions** | **~3 months** |

Critical path: **WRITE access → quick wins → macOS CI/CD → Linux → Windows → release automation.**
