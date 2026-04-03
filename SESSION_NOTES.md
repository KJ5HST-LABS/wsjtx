# Session Notes

## ACTIVE TASK
**Task:** Accept WSJT-X org invitation, begin Phase 1 repo audit (or Phase 6 upstream patches if access is delayed)
**Status:** Waiting on GitHub invitation
**Session:** 1 complete
**Started:** 2026-04-02

---

### What Session 1 Did
**Deliverable:** Strategic contribution plan for WSJT-X team — COMPLETE
**Started:** 2026-04-02
**Status:** Plan written and committed.

**What was done:**
- Oriented on project state: clean main branch, no prior sessions, methodology not yet bootstrapped
- Researched WSJT-X GitHub org: no CI/CD, no templates, no branch protection, no releases, PR #1 (issue templates) pending since Feb 2026, PR #2 (v3.0.0 test) with 4,550 commits
- Reviewed local build pipeline (`build.yml`) — proven macOS ARM64 CI/CD with signing, notarization, packaging
- Key reframe from user: John G4KLA already builds ARM releases manually. **Our value is automation, not the binary.**
- Wrote 6-phase contribution plan: `docs/planning/WSJTX_TEAM_CONTRIBUTION_PLAN.md`
- Bootstrapped methodology: SESSION_NOTES.md, BACKLOG.md created
- Saved project context to memory (team membership, GitHub state, user profile)

**What's next:**
1. Accept GitHub invitation when it arrives
2. Start Phase 1 (repo audit of wsjtx + wsjtx-internal) once access is confirmed
3. If access is delayed, Phase 6 (CMake upstream patches) can be done locally — patches are in `build.yml` lines 46-50 and configure step lines 56-62

**Key files:**
- `docs/planning/WSJTX_TEAM_CONTRIBUTION_PLAN.md` — the plan (full read required before Phase 1)
- `.github/workflows/build.yml` — proven CI/CD pipeline, template for org workflows
- `WSJT-X_BUILD_FIXES.md` — documents the CMake patches
- `BUILD_GUIDE.md` — manual build instructions
- `entitlements.plist` — JIT entitlements for Fortran runtime (needed for code signing)

**Gotchas:**
- The v3.0.0 PR (#2) has 4,550 commits — this is likely their entire dev branch squashed into one PR. Understanding their branching model is critical before proposing CI/CD (Phase 1 audit).
- wsjtx vs wsjtx-internal relationship is unknown — workflows may need to go in the private repo if that's where active dev happens.
- Code signing for org builds requires their Apple Developer certs as GitHub secrets — this is a coordination task, not a technical one.

**Self-assessment:**
- (+) Good reframe on ARM builds vs CI/CD — user corrected initial assumption and the plan reflects the correction
- (+) Plan is phased with clear session boundaries per methodology
- (+) "Serve, don't preach" framing respects the team's 25 years of experience
- (-) No access to org repos yet limits the plan's specificity — Phase 1 audit will sharpen everything
- (-) Could have explored SourceForge release history more thoroughly to understand current release process
- Score: 7/10

**Previous session handoff evaluation:** N/A — this is Session 1.
