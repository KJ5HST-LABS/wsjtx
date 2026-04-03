# WSJT-X Team Contribution Plan

**Author:** Session 1 (2026-04-02)
**Status:** DRAFT — pending org access and team feedback
**Scope:** Strategic plan for contributing to the WSJT-X project as a team member

---

## Situation

The WSJT-X development team (K1JT, K9AN, N9ADG, G4KLA, DL3WDG, W3SZ) recently migrated from BitBucket to GitHub. The team has deep domain expertise (signal processing, radio physics, protocol design) but limited experience with GitHub-native workflows and automation.

### What They Have
- 10,982 commits of production code (C++/Fortran/Python/Qt5)
- A working build system (CMake superbuild with Hamlib)
- ARM macOS builds (John G4KLA handles this manually)
- Two repos: `wsjtx` (public) and `wsjtx-internal` (private)
- Active v3.0.0 development (PR #2 with 4,550 commits)
- Multi-platform releases (Windows, macOS, Linux)

### What They Don't Have
- CI/CD (no GitHub Actions workflows)
- Branch protection rules
- Issue or PR templates (PR #1 pending)
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

---

## Phase 1: Access and Reconnaissance (1 session)

**Deliverable:** Audit document of wsjtx-internal repo structure and current workflow

**Prerequisites:**
- [ ] GitHub invitation accepted
- [ ] Access to wsjtx-internal confirmed

**Tasks:**
1. Clone both repos (wsjtx, wsjtx-internal)
2. Map the branching strategy (how do they use branches? where does active dev happen?)
3. Understand the release process (how do builds get to users today?)
4. Identify the relationship between wsjtx and wsjtx-internal (mirror? fork? independent?)
5. Document build dependencies and platform-specific requirements
6. Identify existing CI/CD artifacts (scripts, Makefiles, build docs) even if not GitHub Actions

**Verification:**
- Audit document written to `docs/planning/wsjtx_repo_audit.md`
- All questions above answered with evidence

**Session boundary:** This phase is one session. Close out when the audit is written.

---

## Phase 2: Quick Wins — Templates and Guards (1 session)

**Deliverable:** PR to wsjtx with issue templates, PR template, and CONTRIBUTING.md

**Why first:** Low risk, immediate visibility, establishes our presence as a contributor. Also unblocks the team's PR #1 (issue templates) which has been pending since February.

**Tasks:**
1. Review and complete their PR #1 (issue templates)
2. Create PR template (checklist: build tested, platforms, related issues)
3. Write CONTRIBUTING.md (build instructions, PR conventions, coding style notes)
4. Propose branch protection for main/master (require PR, no force push)

**Verification:**
- PR submitted and passing any checks
- Templates render correctly in GitHub UI

**Session boundary:** This phase is one session. Close out when the PR is submitted.

---

## Phase 3: CI/CD Foundation — macOS Build (1-2 sessions)

**Deliverable:** GitHub Actions workflow for macOS ARM64 builds in the org repo

**Why macOS first:** We have a proven pipeline. Adapting it for the org repo is lower risk than building Linux/Windows from scratch. It also directly helps John G4KLA by automating what he currently does manually.

**Tasks:**
1. Adapt `build.yml` from this repo to work with the org's source structure
2. Handle source acquisition (from repo, not SourceForge download)
3. Configure secrets (code signing certs, Apple credentials) — requires team coordination
4. Set up build matrix (ARM64 initially, Intel as stretch goal)
5. Artifact publishing to GitHub Releases

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
2. Write workflow with build matrix (OS versions, architectures)
3. Test with the current v3.0.0 branch
4. Package artifacts (AppImage/deb for Linux, NSIS installer for Windows)

**Verification per platform:**
- Build completes on all matrix entries
- Artifacts install and run on target OS

**Session boundary:** Each platform is a separate session.

---

## Phase 5: Release Automation (1 session)

**Deliverable:** Tag-triggered release workflow that builds all platforms and publishes

**Tasks:**
1. Create release workflow triggered by version tags (e.g., `v3.0.1`)
2. Fan out to platform-specific build jobs
3. Collect all artifacts and create GitHub Release with download table
4. Include checksums (SHA256) for all artifacts
5. Optionally mirror to SourceForge if team wants to maintain that channel

**Verification:**
- Create a test tag, verify all artifacts appear in the release
- Download and verify checksums match

**Session boundary:** This phase is one session.

---

## Phase 6: Upstream Patches (1 session)

**Deliverable:** PRs for CMake compatibility fixes

**Patches identified:**
1. **CMake 4.x target name conflict** — `add_custom_target(install ...)` and `add_custom_target(package ...)` use reserved names in CMake 4.0+. Fix: rename to `wsjtx-do-install` and `wsjtx-do-package`.
   - File: top-level `CMakeLists.txt` (superbuild), lines ~199
2. **macOS ARM64 deployment target** — Hardcoded to 10.12 (Sierra), but ARM64 requires macOS 11.0+ (Big Sur).
   - File: inner WSJT-X `CMakeLists.txt`

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
| No org access yet | Can't start Phase 1 | Work on Phase 6 patches locally |
| Code signing certs | Can't fully implement Phase 3 | Build unsigned first, add signing when certs available |
| Team buy-in on CI/CD | Can't merge workflows | Demo in fork first, present results via email |
| Understanding wsjtx vs wsjtx-internal split | Affects where workflows go | Phase 1 audit answers this |

---

## Timeline Estimate

Phases 1-6 represent approximately 7-9 sessions. Phase 1 is gated on org access. Phase 6 can be done in parallel (no access needed — patches are local).

**Next action:** Accept invitation when it arrives. Start with Phase 1 (audit) or Phase 6 (upstream patches), whichever unblocks first.
