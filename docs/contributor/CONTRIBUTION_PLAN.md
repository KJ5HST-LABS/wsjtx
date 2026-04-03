# WSJT-X GitHub Contribution Plan

**Author:** KJ5HST
**Status:** DRAFT — pending team review
**Scope:** Strategic plan for contributing GitHub infrastructure to the WSJT-X project

---

## Situation

The WSJT-X development team (K1JT, K9AN, N9ADG, G4KLA, DL3WDG, W3SZ) recently migrated from BitBucket to GitHub. The team has deep domain expertise (signal processing, radio physics, protocol design) but limited experience with GitHub-native workflows and automation.

### What They Have
- 10,982 commits of production code (C++/Fortran/Python/Qt5)
- A working build system (CMake superbuild with Hamlib)
- ARM macOS builds (John G4KLA handles manually)
- Two repos: `wsjtx` (public) and `wsjtx-internal` (private, both in WSJTX org)
- Active v3.0.0 development (PR #2 with 4,550 commits; branch `v3.0.0_test`)
- Multi-platform releases (Windows, macOS, Linux) via SourceForge

### What They Don't Have
- CI/CD (no GitHub Actions workflows)
- Branch protection rules
- CONTRIBUTING.md
- Published GitHub Releases
- Automated code signing or notarization
- Test framework or automated testing (beyond one test file)

### What We Bring
- GitHub Actions CI/CD experience for CMake-based multi-platform projects
- Understanding of the CMake superbuild system and its dependency chain
- CMake 4.x compatibility patches (target name conflicts, deployment target)
- Apple Developer ID code signing and notarization experience
- GitHub automation and infrastructure experience

---

## Strategic Framing

**Approach: serve, don't preach.** These are scientists and experienced developers who have been shipping software for 25 years. We show value through working infrastructure, not process lectures.

Every contribution must stand on its own merit for the open source project. If a contribution doesn't help WSJT-X regardless of who submits it, don't submit it.

---

## Critical Technical Finding: The Two-Layer Architecture

The WSJT-X build system has two distinct layers:

### Layer 1: The Superbuild (SourceForge tarballs)
- **What:** A CMake wrapper (`ExternalProject_Add`) that downloads and builds both Hamlib and WSJT-X
- **Where:** SourceForge distribution tarballs (e.g., `wsjtx-3.0.0-rc1.tgz`)
- **Contains:** Top-level `CMakeLists.txt` with `project(wsjt-superbuild)`, plus `src/hamlib-4.7.tar.gz` and `src/wsjtx.tgz`
- **Key detail:** Still references BitBucket and SourceForge as upstream sources
- **Builds Hamlib from:** Bill Somerville's (G4WJS) SourceForge fork, statically linked

### Layer 2: The Actual Source (GitHub repo)
- **What:** The WSJT-X application source code directly
- **Where:** `WSJTX/wsjtx` on GitHub
- **Contains:** `CMakeLists.txt` with `project(wsjtx ...)`, all C++/Fortran source files, `find_package(Hamlib REQUIRED)`
- **Key detail:** Expects Hamlib to be pre-installed — does NOT build it

### Why This Matters for CI/CD
The GitHub repos contain the raw source, not the superbuild. CI/CD for the org needs a **two-stage workflow**:
1. **Stage 1:** Build Hamlib from source (clone → bootstrap → configure → make install)
2. **Stage 2:** Build WSJT-X from GitHub source (`cmake -DCMAKE_PREFIX_PATH=$HAMLIB_PREFIX`)

---

## The Hamlib Dependency

**Resolved:** The INSTALL file in wsjtx-internal directs builders to the **official Hamlib GitHub repo**:

```
$ git clone https://github.com/Hamlib/Hamlib src
$ cd src
$ git checkout integration
```

The `integration` branch of the official Hamlib repo is the recommended source. Bill Somerville's SourceForge fork appears superseded.

**CI/CD implication:** Stage 1 of the workflow clones from `github.com/Hamlib/Hamlib` — no SourceForge dependency needed.

---

## Team GitHub Accounts

| Person | Callsign | GitHub | Notes |
|--------|----------|--------|-------|
| Joe Taylor | K1JT | `k1jt` | Org owner/admin. Primary committer. |
| John Nelson | G4KLA | `g4kla` | ARM macOS builds. |
| Steve Franke | K9AN | `k9an` | Active committer (JTTY mode, signal processing). |
| Brian Moran | N9ADG | `bmo` | GitHub tooling champion. Issue templates, pFUnit PR, refactoring issues. |
| Charlie Suckling | DL3WDG | `g3wdg` | User guide, EME features. |
| Roger Rehr | W3SZ | `w3sz` | Active on v3.0.0 (Q65 decode, OTP parsing, wav metadata). |
| Uwe Risse | DG2YCB | `DG2YCB` | Release notes, Hamlib DLL URLs. Runs "WSJT-X Improved" variant. |
| Terrell Galyon | KJ5HST | `KJ5HST` | Infrastructure contributions. Invited 2026-04-03. |

---

## Phase 1: Access and Reconnaissance (COMPLETE)

**Deliverable:** Audit document of WSJTX org structure and current workflow
**Status:** Complete. See `docs/contributor/REPO_AUDIT.md`

---

## Phase 2: Quick Wins — Templates and Guards (1 session)

**Deliverable:** PR to wsjtx-internal with CONTRIBUTING.md and PR template

**Why first:** Low risk, immediate visibility, establishes contributor presence. Unblocks the team's stale PR #1 and issue #1.

**Revised scope** (post-audit):
1. Submit CONTRIBUTING.md with build instructions, PR conventions, coding style notes
2. Create PR template (checklist: build tested, platforms, related issues)
3. Close orphaned PR #1 on wsjtx (template already merged in wsjtx-internal)
4. Close stale issue #1 on wsjtx-internal (template already merged)
5. Propose branch protection for master and develop (document, not unilateral)

**Blocked:** Requires WRITE access (currently READ-only) and v3.0.0 GA (April 8).

---

## Phase 3: CI/CD Foundation — macOS Build (1-2 sessions)

**Deliverable:** GitHub Actions workflow for macOS build verification in the org repo

**Why macOS first:** The two-stage Hamlib → WSJT-X build has been tested on macOS. Adapting it for the org repo is lower risk than building other platforms from scratch.

**The workflow must:**
1. Build Hamlib from `github.com/Hamlib/Hamlib` (integration branch)
2. Build WSJT-X from the org repo source
3. Verify the build produces working ARM64 binaries
4. Run tests when they exist (pFUnit, test_qt_helpers)

**Key decision: code signing.** Build verification does not require signing. Signing is a release automation concern (Phase 5). Keep Phase 3 focused on "does the code compile and produce correct binaries."

---

## Phase 4: CI/CD Expansion — Linux and Windows (2-3 sessions)

**Deliverable:** GitHub Actions workflows for Linux and Windows build verification

**Per platform:**
1. Identify build dependencies
2. Determine Hamlib build approach
3. Write workflow with build matrix (OS versions, architectures)
4. Test against current development branch
5. Package artifacts (AppImage/deb for Linux, installer for Windows)

**Risk:** Windows build toolchain is undocumented. Need team input on whether they use MinGW, MSVC, or something else. Linux is straightforward — all dependencies are in apt.

---

## Phase 5: Release Automation (1 session)

**Deliverable:** Tag-triggered release workflow that builds all platforms and publishes to GitHub Releases

**Tasks:**
1. Create release workflow triggered by version tags (e.g., `v3.0.1`)
2. Fan out to platform-specific build jobs
3. Collect artifacts and create GitHub Release with download table
4. Include SHA256 checksums for all artifacts
5. Integrate code signing for macOS (requires team's Apple Developer credentials)

**GitHub Releases as a new distribution channel** — positioned alongside SourceForge, not replacing it. The team decides whether to eventually consolidate.

---

## Phase 6: Upstream Patches (1 session)

**Deliverable:** PRs for CMake compatibility fixes and stale URL updates

### WSJT-X source (GitHub repo — can PR to wsjtx-internal)
1. **CMake 4.x target name conflict** — `add_custom_target(install ...)` and `add_custom_target(package ...)` use reserved names in CMake 4.0+. Fix: rename to `wsjtx-do-install` and `wsjtx-do-package`.
2. **macOS ARM64 deployment target** — Hardcoded to 10.12 (Sierra), but ARM64 requires macOS 11.0+ (Big Sur).
3. **Stale URLs** — BitBucket and SourceForge references in CMakeLists.txt, README, INSTALL.

### Superbuild (SourceForge-only — no PR target)
The same CMake 4.x and URL issues exist in the superbuild, but it has no GitHub repo. These patches would need to be communicated to the team via email or proposed as part of a discussion about moving the superbuild to GitHub.

---

## Communication Protocol

- PRs with clear descriptions explaining what and why
- Tag relevant team members for review (Brian/bmo is the natural reviewer for infrastructure)
- Email the full group for anything that changes the build or release process
- Demo in a fork first, propose to the org second

---

## Dependencies and Blockers

| Blocker | Impact | Mitigation |
|---------|--------|------------|
| WRITE access not yet granted | Can't submit PRs to org repos | Fork and PR from fork, or request access from Joe/Brian |
| Hamlib fork location | Resolved — official GitHub, integration branch | |
| Superbuild not on GitHub | Can't submit superbuild patches via PR | Email patches to team; discuss moving superbuild to GitHub |
| Code signing credentials | Can't fully implement Phase 5 | Build unsigned first, add signing when team provides certs |
| Team buy-in on CI/CD | Can't merge workflows | Demo in fork first, present results via email |
| GitHub Actions may not be enabled at org level | Can't run workflows | Admin must enable — ask Brian |

---

## Timeline

| Phase | Sessions | When |
|-------|----------|------|
| Phase 1 (audit) | 1 | COMPLETE |
| Phase 2 (templates/guards) | 1 | After v3.0.0 GA (April 8) + WRITE access |
| Phase 3 (macOS CI/CD) | 1-2 | April 15-30 |
| Phase 4 (Linux + Windows CI/CD) | 2-3 | May-June |
| Phase 5 (release automation) | 1-2 | June |
| Phase 6 (upstream patches) | 1 | Anytime (no access needed) |
| **Total** | **7-10 sessions** | **~3 months** |

---

## What We Do Not Decide

These are the team's decisions. We propose, demonstrate, and support:

- Whether to retire SourceForge as a release channel
- Whether to move the superbuild to GitHub
- Which signing identity to use for official releases
- Whether to adopt Qt6
- Whether to merge wsjtx and wsjtx-internal into one repo
- How to handle feature branches in CI
