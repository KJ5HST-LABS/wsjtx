# WSJT-X Team Contribution Plan

**Author:** Session 1 (2026-04-02)
**Status:** DRAFT — pending org access and team feedback
**Scope:** Strategic plan for contributing to the WSJT-X project as a team member
**Governing principle:** `docs/SYMBIOTIC_OPEN_SOURCE.md` — read before acting on any phase

---

## Situation

The WSJT-X development team (K1JT, K9AN, N9ADG, G4KLA, DL3WDG, W3SZ) recently migrated from BitBucket to GitHub. The team has deep domain expertise (signal processing, radio physics, protocol design) but limited experience with GitHub-native workflows and automation.

### What They Have
- 10,982 commits of production code (C++/Fortran/Python/Qt5)
- A working build system (CMake superbuild with Hamlib)
- ARM macOS builds (John G4KLA handles this manually)
- Two repos: `wsjtx` (public) and `wsjtx-internal` (private, both in WSJTX org)
- Active v3.0.0 development (PR #2 with 4,550 commits; branch `v3.0.0_test`)
- Multi-platform releases (Windows, macOS, Linux) — currently via SourceForge

### What They Don't Have
- CI/CD (no GitHub Actions workflows)
- Branch protection rules
- Issue or PR templates (PR #1 pending since Feb 2026, on `bug-report-template` branch)
- CONTRIBUTING.md
- Published GitHub releases (releases likely done via SourceForge)
- Automated code signing or notarization
- Test framework or automated testing

### What We Bring
- A **working GitHub Actions pipeline** that builds, signs, notarizes, and packages WSJT-X for macOS ARM64
- Deep understanding of the CMake superbuild system (from debugging it)
- CMake 4.x compatibility patches (target name conflicts, deployment target)
- Apple Developer ID code signing and notarization pipeline
- GitHub automation experience
- Disciplined development process (Iterative Session Methodology)

---

## Strategic Framing

**Our ARM binary is not the contribution.** John G4KLA already builds ARM releases. Our value is the **automation infrastructure** — turning what the team does manually into repeatable, reliable pipelines.

The existing `build.yml` in this repo is proof-of-concept that the full lifecycle (build, sign, notarize, package, release) can be automated. The plan is to generalize this into multi-platform CI/CD for the official repos.

**Approach: serve, don't preach.** These are scientists and experienced developers who have been shipping software for 25 years. We show value through working infrastructure, not process lectures. The methodology governs *our* work; we don't impose it on the team.

**Symbiotic contribution.** Every contribution to WSJT-X must stand on its own merit for the open source project. See `docs/SYMBIOTIC_OPEN_SOURCE.md` for the full doctrine on the rad-con/WSJT-X relationship.

---

## Critical Technical Finding: The Two-Layer Architecture

The WSJT-X build system has two distinct layers that are easy to confuse:

### Layer 1: The Superbuild (SourceForge tarballs)
- **What:** A CMake wrapper (`ExternalProject_Add`) that downloads and builds both Hamlib and WSJT-X
- **Where:** SourceForge distribution tarballs (e.g., `wsjtx-3.0.0-rc1.tgz`)
- **Contains:** Top-level `CMakeLists.txt` with `project(wsjt-superbuild)`, plus `src/hamlib-4.7.tar.gz` and `src/wsjtx.tgz`
- **Key detail:** Still references BitBucket (`git@bitbucket.org:k1jt/wsjtx.git`) and SourceForge (`git://git.code.sf.net/u/bsomervi/hamlib`) as upstream sources
- **Builds Hamlib from:** Bill Somerville's (G4WJS) SourceForge fork, statically linked (`--disable-shared --enable-static`)
- **This is what our current `build.yml` uses** — downloads the tarball from SourceForge

### Layer 2: The Actual Source (GitHub repo)
- **What:** The WSJT-X application source code directly
- **Where:** `WSJTX/wsjtx` on GitHub
- **Contains:** `CMakeLists.txt` with `project(wsjtx ...)`, all C++/Fortran source files, `find_package(Hamlib REQUIRED)`
- **Key detail:** Expects Hamlib to be **pre-installed** on the system — does NOT build it
- **Dependencies:** Hamlib, Qt5, FFTW3, Boost, libusb (all must be available before cmake)

### Why This Matters for CI/CD
Our existing `build.yml` downloads the SourceForge superbuild tarball. To build CI/CD for the GitHub repo, we need a **two-stage workflow**:
1. **Stage 1:** Build patched Hamlib from source (clone fork → bootstrap → configure → make install)
2. **Stage 2:** Build WSJT-X from GitHub source (`cmake -DCMAKE_PREFIX_PATH=$HAMLIB_PREFIX`)

The superbuild automates this via `ExternalProject_Add`. A GitHub Actions workflow would do the same thing as discrete job steps.

---

## The Hamlib Fork Situation

WSJT-X depends on a **patched fork** of Hamlib, not the official release. This is the central dependency management challenge.

### Why a fork exists
- Hamlib is a separate open source project (LGPL-2.1) for radio rig control
- Official Hamlib releases lag behind what WSJT-X needs
- Bill Somerville (G4WJS) maintained a fork at `git://git.code.sf.net/u/bsomervi/hamlib` with patches not yet accepted upstream
- WSJT-X requires specific rig control behaviors (split operation, CAT polling, PTT timing) that upstream may not prioritize

### Current state (what we know)
- The superbuild pins to `hamlib-4.7` tarball in `src/`
- The `hamlib.patch` file in the 3.0.0-rc1 tarball is **empty** — meaning either no additional patches are needed on top of the fork, or the fork already includes everything
- The superbuild statically links Hamlib — the binary ships with Hamlib baked in
- Bill Somerville's SourceForge fork status is unknown (may be stale)

### Open questions (Phase 1 audit)
1. Is Bill's fork still the canonical Hamlib source for WSJT-X?
2. Has the team moved the Hamlib fork to GitHub (possibly in wsjtx-internal)?
3. Does v3.0.0 still need patched Hamlib, or have patches landed upstream?
4. What is the exact Hamlib commit/tag that 3.0.0 requires?

### CI/CD implications
| Approach | Pros | Cons |
|----------|------|------|
| System Hamlib (`brew install` / `apt install`) | Simple, fast | May lack patches WSJT-X needs |
| Build from Bill's fork | Exact match to superbuild | Fork may be stale; another SF dependency |
| Official Hamlib + `hamlib.patch` | Uses upstream + delta | Patch may not apply to every version |
| Pin specific Hamlib release that works | Reproducible | Requires knowing which version |

---

## The Dependency Chain

This is the full chain from rad-con to the source code:

```
rad-con (commercial, proprietary)
  │
  │  downloads pre-built binaries (subprocess boundary — GPL stays here)
  ▼
KJ5HST-LABS/WSJT-X-MAC-ARM64 (this repo, GPL-3.0 output)
  │
  │  builds from SourceForge superbuild tarball
  ▼
SourceForge superbuild (wsjtx-3.0.0-rc1.tgz)
  │
  ├── src/wsjtx.tgz ──► WSJT-X source (now on GitHub: WSJTX/wsjtx)
  │
  └── src/hamlib-4.7.tar.gz ──► Hamlib fork (SourceForge: u/bsomervi/hamlib)
```

This repo must remain independent from the WSJTX org. See `docs/SYMBIOTIC_OPEN_SOURCE.md`.

---

## Team GitHub Accounts

| Person | Callsign | GitHub | Notes |
|--------|----------|--------|-------|
| Joe Taylor | K1JT | `k1jt` | Org owner/admin. Created 2013. |
| John Nelson | G4KLA | `g4kla` | ARM macOS builds. Created 2019. |
| Steve Franke | K9AN | `k9an` | 2 public repos. Created 2013. |
| Brian Moran | N9ADG | `bmo` | 32 public repos. Contributor to wsjtx. Created 2008. |
| Bill Somerville | G4WJS | `g4wjs` | Hamlib fork maintainer. Created 2013. Notable contributor (not on original member list). |
| Charlie Suckling | DL3WDG | unknown | Not found on GitHub |
| Roger Rehr | W3SZ | unknown | Not found on GitHub |

---

## Phase 1: Access and Reconnaissance (1 session)

**Deliverable:** Audit document of wsjtx-internal repo structure and current workflow

**Prerequisites:**
- [ ] GitHub invitation accepted
- [ ] Access to wsjtx-internal confirmed

**Tasks:**
1. Clone both repos (wsjtx, wsjtx-internal)
2. Map the branching strategy (how do they use branches? where does active dev happen?)
3. Understand the release process (how do builds get to users today? SourceForge? Manual?)
4. Identify the relationship between wsjtx and wsjtx-internal (mirror? fork? independent?)
5. **Find the superbuild** — does it live in wsjtx-internal? Is it a separate artifact?
6. **Resolve the Hamlib fork question** — where is the patched Hamlib source now? Still Bill's SF fork?
7. Document build dependencies and platform-specific requirements
8. Identify existing CI/CD artifacts (scripts, Makefiles, build docs) even if not GitHub Actions
9. Check if URLs in CMakeLists.txt, README, INSTALL have been updated from BitBucket/SourceForge to GitHub

**Verification:**
- Audit document written to `docs/planning/wsjtx_repo_audit.md`
- All questions above answered with evidence
- Hamlib source location confirmed

**Session boundary:** This phase is one session. Close out when the audit is written.

---

## Phase 2: Quick Wins — Templates and Guards (1 session)

**Deliverable:** PR to wsjtx with issue templates, PR template, and CONTRIBUTING.md

**Why first:** Low risk, immediate visibility, establishes our presence as a contributor. Also unblocks the team's PR #1 (issue templates) which has been pending since February on the `bug-report-template` branch.

**Tasks:**
1. Review and complete their PR #1 (issue templates)
2. Create PR template (checklist: build tested, platforms, related issues)
3. Write CONTRIBUTING.md (build instructions, PR conventions, coding style notes)
4. Propose branch protection for master (require PR, no force push)

**Verification:**
- PR submitted and passing any checks
- Templates render correctly in GitHub UI

**Session boundary:** This phase is one session. Close out when the PR is submitted.

---

## Phase 3: CI/CD Foundation — macOS Build (1-2 sessions)

**Deliverable:** GitHub Actions workflow for macOS builds in the org repo

**Why macOS first:** We have a proven pipeline. Adapting it for the org repo is lower risk than building Linux/Windows from scratch.

**Critical change from original plan:** The org repo is the raw source, not the superbuild. The workflow must:
1. **Build Hamlib first** — clone the correct fork/tag, configure, build, install to a local prefix
2. **Build WSJT-X** — point `CMAKE_PREFIX_PATH` at the local Hamlib install
3. Handle code signing and notarization (requires team's Apple Developer credentials)

**Tasks:**
1. Design two-stage workflow (Hamlib → WSJT-X) based on Phase 1 audit findings
2. Configure secrets (code signing certs, Apple credentials) — requires team coordination
3. Set up build matrix (ARM64 initially, Intel as stretch goal)
4. Artifact publishing to GitHub Releases

**Key decision:** Code signing requires Apple Developer credentials. Options:
- Team provides their existing Developer ID certs as GitHub secrets
- We use KJ5HST-LABS certs (temporary, for proving the pipeline works)
- Build unsigned for CI validation, sign separately for release

**Verification:**
- Workflow triggers on push/PR and produces a working .pkg
- `codesign --verify` and `spctl --assess` pass on the output

**Session boundary:** Each platform is a separate session.

---

## Phase 4: CI/CD Expansion — Linux and Windows (2-3 sessions)

**Deliverable:** GitHub Actions workflows for Linux (Ubuntu/Fedora) and Windows builds

**Tasks per platform:**
1. Identify build dependencies (package manager commands)
2. Determine Hamlib build approach for each platform
3. Write workflow with build matrix (OS versions, architectures)
4. Test with the current v3.0.0 branch
5. Package artifacts (AppImage/deb for Linux, NSIS installer for Windows)

**Verification per platform:**
- Build completes on all matrix entries
- Artifacts install and run on target OS

**Session boundary:** Each platform is a separate session.

---

## Phase 5: Release Automation (1 session)

**Deliverable:** Tag-triggered release workflow that builds all platforms and publishes

**Tasks:**
1. Create release workflow triggered by version tags (e.g., `v3.0.1`)
2. Fan out to platform-specific build jobs (each builds Hamlib + WSJT-X)
3. Collect all artifacts and create GitHub Release with download table
4. Include checksums (SHA256) for all artifacts
5. Optionally mirror to SourceForge if team wants to maintain that channel

**Verification:**
- Create a test tag, verify all artifacts appear in the release
- Download and verify checksums match

**Session boundary:** This phase is one session.

---

## Phase 6: Upstream Patches (1 session)

**Deliverable:** PRs for CMake compatibility fixes and stale URL updates

**Patches identified:**

### Superbuild (if it lives in a repo we can access)
1. **CMake 4.x target name conflict** — `add_custom_target(install ...)` and `add_custom_target(package ...)` use reserved names in CMake 4.0+. Fix: rename to `wsjtx-do-install` and `wsjtx-do-package`.
   - File: top-level `CMakeLists.txt`, line ~198
2. **BitBucket URL** — `set (wsjtx_repo git@bitbucket.org:k1jt/wsjtx.git)` needs updating to GitHub
   - File: top-level `CMakeLists.txt`, line 69
3. **SourceForge Hamlib URL** — may need updating depending on where the fork now lives
   - File: top-level `CMakeLists.txt`, line 67

### WSJT-X source (GitHub repo)
4. **macOS ARM64 deployment target** — Hardcoded to 10.12 (Sierra), but ARM64 requires macOS 11.0+ (Big Sur).
   - File: `CMakeLists.txt`, line 13
5. **SourceForge URLs** in README, INSTALL, and CMakeLists.txt (PROJECT_HOMEPAGE, PROJECT_MANUAL_DIRECTORY_URL, etc.)
   - File: `CMakeLists.txt`, lines 85-89; `README`; `INSTALL`

**Verification:**
- Patches apply cleanly to current HEAD
- Build succeeds with CMake 4.x on macOS ARM64

**Session boundary:** This phase is one session.

---

## What We Do NOT Do

- **Rewrite their code.** We contribute infrastructure, not opinions about their C++ style.
- **Impose process.** The methodology governs our sessions, not their workflow.
- **Compete with John's ARM builds.** We automate what he already does. If he wants to keep doing it manually, that's fine — the CI/CD is a complement, not a replacement.
- **Move fast and break things.** PRs, not direct pushes. Discussions, not declarations.
- **Over-engineer.** A working build pipeline beats a perfect one. Ship incrementally.
- **Cross the GPL boundary.** See `docs/SYMBIOTIC_OPEN_SOURCE.md`. No exceptions.
- **Merge this repo into the WSJTX org.** This repo serves rad-con's needs independently.

---

## Communication Protocol

The team uses email to the full group for communication. For our GitHub contributions:
- PRs with clear descriptions explaining what and why
- Tag relevant team members for review
- Email the group for anything that changes the build or release process
- Be transparent about tooling (Claude Code) — Terrell already set that expectation

---

## Dependencies and Blockers

| Blocker | Impact | Mitigation |
|---------|--------|------------|
| No org access yet | Can't start Phase 1 | Work on Phase 6 patches locally; invitation instructions sent to Joe |
| Hamlib fork location unknown | Can't design CI/CD Stage 1 | Phase 1 audit resolves this |
| Superbuild location unknown | Can't submit superbuild patches | Phase 1 audit resolves this |
| Code signing certs | Can't fully implement Phase 3 | Build unsigned first, add signing when certs available |
| Team buy-in on CI/CD | Can't merge workflows | Demo in fork first, present results via email |
| v3.0.0_test branch has dev artifacts | Suggests unconventional branch usage | Phase 1 audit maps their actual workflow |

---

## Timeline Estimate

Phases 1-6 represent approximately 7-9 sessions. Phase 1 is gated on org access. Phase 6 can be done in parallel (no access needed — patches are local).

**Next action:** Accept invitation when it arrives. Start with Phase 1 (audit) or Phase 6 (upstream patches), whichever unblocks first.
