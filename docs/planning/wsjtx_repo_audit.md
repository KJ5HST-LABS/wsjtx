# WSJT-X GitHub Org Audit

**Session:** 3
**Date:** 2026-04-03
**Scope:** WSJTX GitHub organization — all repos, branches, PRs, issues, infrastructure
**Auditor permission level:** READ on both repos

---

## Audit Summary

- **Scope:** 2 repos (wsjtx, wsjtx-internal), org membership, branches, PRs, issues, CI/CD, templates, documentation
- **Coverage:** All items examined
- **Critical finding count:** 2 critical, 4 moderate, 3 minor

---

## Organization Overview

| Property | Value |
|----------|-------|
| Org name | WSJTX |
| Repos | 2 (wsjtx public, wsjtx-internal private) |
| Members | 7: k1jt, g4kla, k9an, bmo, g3wdg, w3sz, KJ5HST |
| GitHub Pages | Active at `wsjtx.github.io/wsjtx` (from `feat-web-pages` branch) |
| Wiki | Enabled on wsjtx (content unknown) |
| GitHub Releases | None on either repo |
| CI/CD | None — no GitHub Actions workflows |
| Branch protection | None on either repo |

### Updated Team GitHub Accounts

| Person | Callsign | GitHub | Notes |
|--------|----------|--------|-------|
| Joe Taylor | K1JT | `k1jt` | Org owner/admin. Primary committer. |
| John Nelson | G4KLA | `g4kla` | ARM macOS builds. |
| Steve Franke | K9AN | `k9an` | Active committer (JTTY mode, signal processing). |
| Brian Moran | N9ADG | `bmo` | GitHub tooling champion. Issue templates, pFUnit PR, refactoring issues. |
| Charlie Suckling | DL3WDG | `g3wdg` | User guide, EME features. |
| Roger Rehr | W3SZ | `w3sz` | Active on v3.0.0 (Q65 decode, OTP parsing, wav metadata). |
| Uwe Risse | DG2YCB | `DG2YCB` | Release notes, Hamlib DLL URLs. Runs "WSJT-X Improved" variant. |
| Terrell | KJ5HST | `KJ5HST` | This audit. Invited 2026-04-03. |

**Correction to contribution plan:** Charlie is DL3WDG but his GitHub is `g3wdg` (a separate callsign). Roger Rehr (W3SZ) and Charlie (DL3WDG) were previously listed as "unknown" — both are active contributors with GitHub accounts.

---

## Repo 1: WSJTX/wsjtx (Public)

| Property | Value |
|----------|-------|
| Default branch | `master` |
| Disk usage | 239 MB |
| License | GPL-3.0 |
| Primary language | C++ (4.9 MB) |
| Created | 2026-02-06 |
| Last push | 2026-03-31 |
| Stars | 1 |
| Forks | 2 |
| Tags | `v2.7.0` |

### Branches (4)

| Branch | Purpose | Last Activity |
|--------|---------|---------------|
| `master` | Default. Contains v2.7.0 release + Joe's web page experiments (Mar 2026). | 2026-03-25 |
| `v3.0.0_test` | Massive PR #2 — 4,550 commits, 517K additions. All of v3.0.0 dev history. | 2026-03-31 |
| `bug-report-template` | PR #1 (open since Feb 2026). Issue template. | 2026-02-10 |
| `feat-web-pages` | Joe's GitHub Pages site. Source for `wsjtx.github.io/wsjtx`. | 2026-03-27 |

### Pull Requests

| # | Title | State | Author | Branch | Notes |
|---|-------|-------|--------|--------|-------|
| 2 | V3.0.0 test | OPEN | k1jt | v3.0.0_test → master | 4,550 commits, 517K additions. The v3.0.0 merge. |
| 1 | Update issue templates | OPEN | (unknown) | bug-report-template → master | Stale since Feb 2026. Already merged in wsjtx-internal. |

### Key Observations

- `master` last received real code in Feb 2025 (BitBucket merge). March 2026 commits are web page work.
- The commit message `b4f9a431` says "Merge branch 'develop' of bitbucket.org:k1jt/wsjtx" — confirms BitBucket was the prior home.
- PR #2 is the v3.0.0 release merge. When merged, it brings master up to date with 18+ months of development.
- PR #1 is orphaned — the same issue template was already merged in wsjtx-internal via PRs #2 and #3.

---

## Repo 2: WSJTX/wsjtx-internal (Private)

| Property | Value |
|----------|-------|
| Default branch | `develop` |
| Disk usage | 240 MB |
| License | GPL-3.0 |
| Primary language | C++ (5.7 MB) |
| Created | 2026-02-05 |
| Last push | 2026-04-03 |
| Stars | 0 |
| Forks | 0 |
| Tags | `v3.0.0` |

### Branches (20)

| Branch | Purpose | Notes |
|--------|---------|-------|
| `develop` | Default. Main development trunk. | Active — last commit 2026-03-22 (G3WDG user guide). |
| `v3.0.0_test` | Release branch for v3.0.0 GA. | 26 ahead, 157 behind develop. Active — Roger W3SZ committed 2026-04-03. |
| `develop_test` | Testing trunk (target for pFUnit PR). | |
| `develop-fort` | Fortran development. | |
| `feat-jtty` | JTTY mode (new mode by K9AN). | Active feature work. |
| `feat-jtty-joe` / `feat-jtty-joe2` | Joe's JTTY variants. | |
| `feat_mmtty_interface` / `feat_mmty_interface` | MMTTY integration (note typo in one). | |
| `feat-charlie` | Charlie DL3WDG's feature branch. | |
| `4-mainwindow_cpp-cleanup` | Refactoring mainwindow.cpp (issue #4). | |
| `7-abbreviation-processing` | Country name abbreviations (issue #7). | |
| `9-pfunit` | Fortran testing with pFUnit (issue #9). | |
| `cleanup-joe` | Joe's cleanup work. | |
| `copilot/sub-pr-2` | Copilot-generated bug template fix. | Merged. |
| `fix-WA6BEV-issues` | Bug fixes. | |
| `issue-add-bug-report-template` | Bug report template. | Merged. |
| `pubdocs` | Public documentation. | |
| `refactor-fox-hound-speculative` | Fox/Hound mode refactoring. | |
| `refactor-readFromStdout` | readFromStdout refactoring (issue #6). | |

### Pull Requests

| # | Title | State | Author | Notes |
|---|-------|-------|--------|-------|
| 10 | Add initial FORTRAN test(s) | DRAFT | bmo | pFUnit framework. 103 additions. Targets `develop_test`. |
| 8 | Consolidate abbreviations | OPEN | bmo | Country name processing (issue #7). |
| 5 | mainwindow.cpp cleanup | DRAFT | bmo | Refactoring (issue #4). |
| 3 | Change TRANSMITTING to Transmitting | MERGED | copilot | Bug template fix. |
| 2 | Initial commit of bug report template | MERGED | bmo | Issue template. |

### Issues (7)

| # | Title | State | Labels | Notes |
|---|-------|-------|--------|-------|
| 12 | (closed) | CLOSED | | SJTTY defaults |
| 11 | MMTTY-like interface for JTTY | OPEN | | N1MM integration |
| 9 | Try pFunit for FORTRAN tests | OPEN | | Has draft PR #10 |
| 7 | Repetitive string substitutions | OPEN | | Has PR #8 |
| 6 | readFromStdout >1200 lines | OPEN | | Refactoring target |
| 4 | mainwindow.cpp line count too high | OPEN | | Has draft PR #5 |
| 1 | Add issue report template | OPEN | documentation, 3.0.0-GA | Already merged via PR #2, issue still open |

### Key Observations

- Brian Moran (N9ADG/`bmo`) is the GitHub tooling champion — he created all issues, all PRs, the bug template, and is pushing testing.
- Copilot was used to generate a PR (#3) — the team is open to AI tooling.
- Multiple feature branches for JTTY (new mode by K9AN) — significant ongoing development.
- The `develop_test` branch is separate from `develop` — Brian's testing work targets this, not the main development trunk.
- Some files have "IMPROVED by DG2YCB" branding (INSTALL, README) — Uwe Risse's WSJT-X Improved variant content appears mixed in.

### Extra Files (in wsjtx-internal but not wsjtx)

| File | Purpose |
|------|---------|
| `CMakeLists_wsjtx.txt` | Duplicate of CMakeLists.txt — possibly a backup or reference copy |
| `ALLCALL7.TXT`, `CALL3.TXT` | Test data files |
| `grid.dat`, `sat.dat` | Grid/satellite reference data |
| `mycustomspinbox.cpp/h` | Custom UI widget |
| `revision_utils_wsjtx.cpp` | Build revision utilities (variant) |
| `sounds/` | Audio alert files |
| `udp_export.h` | UDP export header |

---

## Relationship Between wsjtx and wsjtx-internal

| Dimension | wsjtx (public) | wsjtx-internal (private) |
|-----------|---------------|------------------------|
| Default branch | `master` | `develop` |
| Role | Public release repo | Active development repo |
| Last code commit | 2025-02-04 (BitBucket merge) | 2026-04-03 (active) |
| v3.0.0 work | PR #2 (4550 commits to merge) | v3.0.0_test branch + develop |
| Issues | 0 | 7 |
| PRs | 2 (both open) | 5 (2 merged, 1 open, 2 draft) |
| CI/CD | None | None |
| Templates | PR #1 pending | Bug template merged |

**The repos are NOT forks of each other.** They appear to be separate Git repos that share code. The internal repo has more code (5.7 MB C++ vs 4.9 MB), more Fortran (2.7 MB vs 1.9 MB), and extra files. The v3.0.0_test branch exists in BOTH repos with some shared commits (they diverge after `4bb581d0`, 2026-03-27).

**Workflow pattern:** Development happens on `develop` in wsjtx-internal. Release branches (v3.0.0_test) are cut from develop. When a release is ready, it gets pushed to the public wsjtx repo's v3.0.0_test branch, and eventually merged to master via PR.

---

## Superbuild Status

**The superbuild is NOT on GitHub.** Neither repo contains the superbuild CMake wrapper (`project(wsjt-superbuild)` with `ExternalProject_Add`). The superbuild continues to be distributed only via SourceForge tarballs (e.g., `wsjtx-3.0.0-rc1.tgz`).

This means:
- Our current `build.yml` (which downloads the SourceForge tarball) cannot point to GitHub
- Phase 3 CI/CD must use the two-stage approach: build Hamlib first, then build WSJT-X from the GitHub source
- Superbuild patches (Phase 6, items 1-3) have no GitHub target — they would need to be emailed or applied to SourceForge

---

## Hamlib Fork Resolution

**RESOLVED:** The INSTALL file in wsjtx-internal directs builders to the **official Hamlib GitHub repo**:

```
$ git clone https://github.com/Hamlib/Hamlib src
$ cd src
$ git checkout integration
```

The `integration` branch of the official Hamlib repo is the recommended source. This supersedes the previous assumption that Bill Somerville's SourceForge fork (`git://git.code.sf.net/u/bsomervi/hamlib`) was required.

| Component | Source | Status |
|-----------|--------|--------|
| Hamlib source (build from source) | `github.com/Hamlib/Hamlib` branch `integration` | Official, active |
| Hamlib Windows DLLs (runtime download) | `hamlib.sourceforge.net/snapshots-4.7/` | SourceForge hosted |
| Hamlib in superbuild tarball | `src/hamlib-4.7.tar.gz` | Pinned version in tarball |
| Bill's SF fork | `git.code.sf.net/u/bsomervi/hamlib` | Appears superseded |

**CI/CD implication:** We can `git clone https://github.com/Hamlib/Hamlib && git checkout integration` in CI. No need for SourceForge dependency or patched fork.

---

## Protocol Documentation (Gap #2/12)

**RESOLVED:** The UDP protocol is comprehensively documented in `Network/NetworkMessage.hpp`. The file contains:
- Full message format specification (header, payload, types)
- Schema negotiation protocol (versions 1-3)
- Backward compatibility rules
- All message types with field definitions (Heartbeat, Status, Decode, Clear, Reply, QSO Logged, Close, Replay, Halt Tx, Free Text, WSPRDecode, Location, LoggedADIF, HighlightCallsign, SwitchConfiguration, Configure)
- QDataStream serialization details

This IS the protocol reference. It lives in the source code, not a separate document. Any third-party application (including rad-con) should reference this file.

---

## Apple Developer Account (Gap #9)

**NOT DISCOVERABLE from repos.** No references to code signing identity, Apple Developer Team ID, or certificate names found in either repo. This must be resolved via email to the team.

John G4KLA handles ARM macOS builds manually — he likely holds the signing credentials (or builds unsigned). The team has no automated signing pipeline.

---

## v3.0.0 GA Release

**Release date: April 8, 2026** (from `Release_Notes.txt` on v3.0.0_test branch).

This is 5 days from today. Key implications:
- PR #2 on wsjtx (v3.0.0_test → master) will be merged soon
- Active last-minute work on v3.0.0_test in wsjtx-internal (Roger's patches, April 1-3)
- **Do NOT submit disruptive PRs right now** — the team is in release mode
- Phase 2 (templates/guards) should wait until after GA

---

## Findings

### Finding #1: No CI/CD on Either Repo
- **Severity:** Critical (for contribution plan)
- **Location:** Both repos, `.github/workflows/` does not exist
- **Description:** Neither repo has any GitHub Actions workflows, CI/CD pipelines, or automated build/test infrastructure.
- **Impact:** Every build is manual. No automated testing, no build verification on PRs, no release automation.
- **Recommendation:** Phase 3 of contribution plan addresses this. Start with macOS build workflow post-GA.

### Finding #2: No Branch Protection
- **Severity:** Critical
- **Location:** Both repos, all branches
- **Description:** No branch protection rules on master (wsjtx) or develop (wsjtx-internal). Anyone with write access can force-push.
- **Impact:** Accidental history rewrite could lose commits. PRs can be bypassed.
- **Recommendation:** Phase 2 of contribution plan. Propose at minimum: require PR for master, disable force-push.

### Finding #3: Superbuild Not on GitHub
- **Severity:** Moderate
- **Location:** SourceForge only
- **Description:** The superbuild wrapper (CMake ExternalProject_Add for Hamlib + WSJT-X) exists only in SourceForge tarballs, not in any GitHub repo.
- **Impact:** CI/CD for the org must use two-stage build. Phase 6 superbuild patches have no PR target. Source completeness (Gap #1) remains unresolved for the superbuild.
- **Recommendation:** Discuss with team whether superbuild should move to GitHub (possibly as a third repo).

### Finding #4: "IMPROVED" Branding in wsjtx-internal
- **Severity:** Moderate
- **Location:** `INSTALL`, `README` on develop branch
- **Description:** The INSTALL file references `wsjt-x-improved.sourceforge.io` and has "IMPROVED by DG2YCB" ASCII art. The README still says "Version 2.6.1."
- **Impact:** Confusion about whether wsjtx-internal is the official repo or Uwe's fork. README is stale.
- **Recommendation:** Low priority — likely a merge artifact. Could be cleaned up in a future PR, but NOT during release freeze.

### Finding #5: PR #1 Orphaned on wsjtx
- **Severity:** Moderate
- **Location:** wsjtx PR #1, `bug-report-template` branch
- **Description:** The bug report template PR has been open since Feb 2026. The same template was already merged in wsjtx-internal (PRs #2, #3).
- **Impact:** Stale PR creates clutter. The template exists in wsjtx-internal but not in the public wsjtx repo.
- **Recommendation:** Either close PR #1 (template will come with v3.0.0 merge), or merge it independently if the template should be in the public repo now.

### Finding #6: Issue #1 Still Open Despite Template Being Merged
- **Severity:** Moderate
- **Location:** wsjtx-internal issue #1
- **Description:** Issue #1 "Add an issue report template" is still open, but the bug report template was merged via PRs #2 and #3.
- **Impact:** Misleading open issue count.
- **Recommendation:** Close issue #1 with a reference to the merged PRs.

### Finding #7: Viewer Permission is READ
- **Severity:** Minor (for us)
- **Location:** Our account (KJ5HST) on both repos
- **Description:** Our permission level is READ, not WRITE or ADMIN.
- **Impact:** Cannot submit PRs from branches in the org repos. Must fork and submit PRs from our fork, or request write access.
- **Recommendation:** Ask Brian (bmo) or Joe (k1jt) for write access before Phase 2.

### Finding #8: Minimal Testing Infrastructure
- **Severity:** Minor
- **Location:** `tests/` directory, PR #10
- **Description:** One test file exists (`test_qt_helpers.cpp`). Brian's pFUnit PR (#10) would add Fortran testing but is still draft and targets `develop_test`, not `develop`.
- **Impact:** No automated test coverage. CI/CD in Phase 3 would have nothing to run beyond "does it compile."
- **Recommendation:** Support Brian's pFUnit effort. Include test running in CI/CD when tests exist.

### Finding #9: Duplicate Branch Names (Typo)
- **Severity:** Minor
- **Location:** wsjtx-internal branches `feat_mmtty_interface` and `feat_mmty_interface`
- **Description:** Two branches for the same feature, one with a typo (`mmty` vs `mmtty`).
- **Impact:** Minor confusion.
- **Recommendation:** Delete the typo branch if it has no unique commits.

---

## Structural Observations

1. **Brian Moran (N9ADG) is the GitHub champion.** He created all issues, all PRs, the bug template, and is driving testing and refactoring. He is our natural ally for Phases 2-5.

2. **The team is pragmatically adopting GitHub.** They used Copilot for a PR, Brian is driving templates and testing, Joe is experimenting with GitHub Pages. But the adoption is organic and incomplete — no CI/CD, no branch protection, no CONTRIBUTING.md.

3. **The two-repo model creates friction.** Having wsjtx (public) and wsjtx-internal (private) as separate repos (not forks) makes syncing manual. The v3.0.0_test branch exists in both with diverging commit histories. This is likely a legacy of the BitBucket migration.

4. **SourceForge is still the release channel.** Despite having GitHub Pages and repos, releases go through SourceForge. GitHub Releases are not used. The superbuild is SourceForge-only.

5. **Active new mode development (JTTY).** Steven Franke (K9AN) and Joe are building a new mode called JTTY with multiple feature branches. This is significant ongoing development.

---

## Recommendations (Prioritized)

### Immediate (before v3.0.0 GA on April 8)
1. **Do nothing disruptive.** The team is in release mode.
2. Request write access from Joe or Brian.

### Post-GA (Phase 2 timing)
3. Close orphaned PR #1 on wsjtx (or let v3.0.0 merge subsume it).
4. Close issue #1 on wsjtx-internal (template already merged).
5. Submit PR: CONTRIBUTING.md with build instructions.
6. Propose branch protection on master (wsjtx) and develop (wsjtx-internal).

### Medium-term (Phase 3+)
7. Build CI/CD using two-stage approach: Hamlib from `github.com/Hamlib/Hamlib` (integration branch), then WSJT-X from GitHub source.
8. Discuss with team: should the superbuild move to GitHub?
9. Support Brian's pFUnit testing effort.
10. Clean up "IMPROVED" branding in wsjtx-internal (post-GA).

---

## Impact on Contribution Plan

| Plan Item | Status After Audit |
|-----------|--------------------|
| Phase 1 (this audit) | COMPLETE |
| Phase 2 (templates/guards) | **REVISED:** Bug template already exists in wsjtx-internal. Focus on CONTRIBUTING.md, branch protection, and closing stale PR/issue. Need WRITE access first. Wait until after April 8 GA. |
| Phase 3 (CI/CD macOS) | **CONFIRMED:** Two-stage build approach required. Hamlib from official GitHub. No superbuild on GitHub. |
| Phase 4 (CI/CD expansion) | Unchanged |
| Phase 5 (Release automation) | **NOTE:** Team currently releases via SourceForge. GitHub Releases would be a new channel, not a replacement. |
| Phase 6 (upstream patches) | **REVISED:** Superbuild patches have no GitHub target (superbuild is SourceForge-only). WSJT-X source patches (deployment target, URLs) can be PRed to wsjtx-internal. |
| Hamlib fork | **RESOLVED:** Use official Hamlib GitHub repo, `integration` branch. |
| Apple Developer account | **UNRESOLVED:** Not discoverable from repos. Must ask team. |
| Protocol documentation | **RESOLVED:** Comprehensive in `Network/NetworkMessage.hpp`. |
