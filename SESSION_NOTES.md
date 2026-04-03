# Session Notes

## ACTIVE TASK
**Task:** Phase 2: GitHub templates and guards (after v3.0.0 GA April 8)
**Status:** Blocked until v3.0.0 GA releases April 8, 2026. Also need WRITE access — currently READ-only.
**Session:** 3 complete
**Started:** 2026-04-02

---

### Session 1 Handoff Evaluation (by Session 2)
- **Score: 8/10**
- **What helped:** Thorough key files list with line numbers (commons.h, NetworkMessage.hpp, CMakeLists.txt:69). The gotchas section about `.p12` files and the two-layer architecture revision caught real issues. The "What's next" list was prioritized and actionable.
- **What was missing:** No mention of methodology bootstrap status — Session 2 had to discover that SAFEGUARDS.md and SESSION_RUNNER.md were missing. The SESSION_NOTES.md itself existed but the rest of the methodology wasn't in place.
- **What was wrong:** Nothing factually wrong.
- **ROI:** Yes — the key files list and architecture notes saved significant orientation time.

---

### What Session 2 Did
**Deliverable:** Methodology bootstrap — COMPLETE
**Started:** 2026-04-03
**Status:** All files committed.

**What was produced:**
1. `CLAUDE.md` — Project-level agent instructions with session protocol block, project context, architecture summary, and safety rules (.p12 files, GPL boundary)
2. `SESSION_RUNNER.md` — Copied from methodology starter kit (cockpit checklist)
3. `SAFEGUARDS.md` — Copied from methodology starter kit (safety rails)
4. `docs/methodology/` — Full framework tree: ITERATIVE_METHODOLOGY.md, HOW_TO_USE.md, README.md, 5 workstream docs
5. `docs/methodology/sessions/` — Empty directory for future session output documents
6. `methodology_dashboard.py` — Health scanner copied from methodology tools
7. `.gitignore` — Added `dashboard.html` (generated artifact)

**Commit:** `787e850` — "Bootstrap Iterative Session Methodology" (13 files)

**Key discovery during session:**
- GitHub org access is now confirmed (user reported access arrived 2026-04-03). This unblocks Phase 1 repo audit.

**Dashboard results:**
- Health: 81/100 (up from 68 pre-bootstrap)
- Risk: medium
- Methodology compliance now satisfied

**What's next:**
1. **Phase 1: Repo audit** — NOW UNBLOCKED. Explore the WSJT-X GitHub org. Key tasks from BACKLOG.md:
   - Find the superbuild repo (wsjtx-internal? or separate?)
   - Resolve Hamlib fork location and status
   - Map branching strategy and release process
   - Identify who owns the Apple Developer account (Gap #9)
   - Check for existing protocol documentation (Gap #2/12)
2. Start by running `gh org list` or browsing the wsjtx org repos via `gh` CLI
3. Read `docs/planning/WSJTX_TEAM_CONTRIBUTION_PLAN.md` Phase 1 section for the full audit checklist

**Key files:**
- `CLAUDE.md` — new, project agent instructions
- `SESSION_RUNNER.md` — new, cockpit checklist (follow this every session)
- `SAFEGUARDS.md` — new, safety rails
- `BACKLOG.md:10-16` — Phase 1 audit subtasks
- `docs/planning/WSJTX_TEAM_CONTRIBUTION_PLAN.md` — Phase 1 details
- `docs/planning/GPL_COMPLIANCE_GAPS.md` — gaps to investigate during audit
- `.github/workflows/build.yml` — existing CI/CD pipeline (uses superbuild)

**Gotchas for next session:**
- The org just got access — repos may be sparse, empty, or mid-migration. Don't assume structure.
- The superbuild repo name is unknown. Could be `wsjtx-superbuild`, `wsjtx-internal`, or something else. Search, don't assume.
- 3 unpushed commits on main (2 from Session 1 + 1 from Session 2). Push when ready.
- `.p12` files still sitting in repo root (untracked). Never commit them.
- `OUTREACH.md`, `jt9_wisdom.dat`, `timer.out` are also untracked — ask user about these if relevant.

**Self-assessment:**
- (+) Clean, complete bootstrap — all 7 checklist items from BOOTSTRAP.md satisfied
- (+) CLAUDE.md includes project-specific context, not just the protocol block
- (+) Dashboard health score improved 68 → 81
- (+) Session was focused — one deliverable, no scope creep
- (+) Caught that Session 1 left methodology partially bootstrapped (only SESSION_NOTES + BACKLOG)
- (-) No customization of SESSION_RUNNER.md task mapping table — used starter-kit defaults. Acceptable for now since the defaults cover this project's workstreams.
- Score: 8/10

---

### Session 2 Handoff Evaluation (by Session 3)
- **Score: 9/10**
- **What helped:** The "What's next" section was perfectly structured — 5 specific audit subtasks matching BACKLOG.md, plus the tip to start with `gh` CLI. Key files list with BACKLOG line numbers (`:10-16`) was immediately actionable. The gotcha about "superbuild repo name is unknown — search, don't assume" was prophetic — it turned out the superbuild isn't on GitHub at all. The unpushed commits warning was also useful (pushed 4 before starting work).
- **What was missing:** No mention of the v3.0.0 GA timeline — Session 3 discovered the April 8 release date, which is critical context for deciding what actions to take and when. Also no mention that our viewer permission is READ-only, which affects Phase 2 planning.
- **What was wrong:** "3 unpushed commits" was actually 4 (Session 2's close-out commit made it 4). Minor.
- **ROI:** Excellent. The structured audit subtask list saved significant planning time.

---

### What Session 3 Did
**Deliverable:** Phase 1 repo audit of WSJT-X GitHub org — COMPLETE
**Started:** 2026-04-03
**Status:** Audit report written and committed.

**What was produced:**
1. `docs/planning/wsjtx_repo_audit.md` — Comprehensive audit of the WSJTX GitHub org (2 repos, 24 branches, 7 PRs, 7 issues, org membership, CI/CD status, Hamlib resolution, protocol docs, v3.0.0 timeline)

**Key discoveries:**
1. **Superbuild is NOT on GitHub.** Only exists in SourceForge tarballs. Neither wsjtx nor wsjtx-internal is the superbuild.
2. **Hamlib fork RESOLVED.** INSTALL file directs to official `github.com/Hamlib/Hamlib` repo, `integration` branch. Bill's SF fork appears superseded.
3. **Protocol documentation RESOLVED.** Comprehensive UDP protocol spec lives in `Network/NetworkMessage.hpp` (not a separate doc).
4. **v3.0.0 GA is April 8, 2026** — 5 days away. Team is in release mode. Do not submit disruptive PRs.
5. **Our permission is READ-only.** Cannot create branches in org repos. Must fork, or request WRITE access.
6. **Brian Moran (N9ADG/`bmo`) is the GitHub champion.** Created all issues, all PRs, bug template, and is pushing testing. Natural ally.
7. **Previously unknown GitHub accounts found:** `g3wdg` (Charlie DL3WDG), `w3sz` (Roger Rehr W3SZ), `DG2YCB` (Uwe Risse).
8. **No CI/CD, no branch protection, no CONTRIBUTING.md** on either repo.
9. **Relationship:** wsjtx-internal (private, `develop`) is active dev. wsjtx (public, `master`) is release target. Not forks — separate repos.
10. **Apple Developer account: UNRESOLVED.** Must ask team via email.

**What's next:**
1. **Wait for v3.0.0 GA (April 8).** Do not submit PRs during release freeze.
2. **Request WRITE access** from Joe (k1jt) or Brian (bmo) via email. Currently READ-only.
3. **Phase 2: Templates and guards** — after GA. Revised scope:
   - Bug template already exists in wsjtx-internal (skip that part)
   - Focus on: CONTRIBUTING.md, branch protection proposal, close orphaned PR #1 on wsjtx, close issue #1 on wsjtx-internal
4. **Ask team about Apple Developer account** (Gap #9) — who signs macOS releases? John G4KLA?
5. **Consider:** Gap #1 fix (source tarball in release workflow) can be done in this repo independently.

**Key files:**
- `docs/planning/wsjtx_repo_audit.md` — THIS SESSION'S OUTPUT. Full audit with 9 findings.
- `docs/planning/WSJTX_TEAM_CONTRIBUTION_PLAN.md` — Updated impact table at bottom of audit
- `BACKLOG.md:10-16` — Phase 1 subtasks (all now addressed)
- `Network/NetworkMessage.hpp` (in WSJTX/wsjtx-internal) — Protocol documentation
- `INSTALL` (in WSJTX/wsjtx-internal) — Build instructions, Hamlib source info
- `Release_Notes.txt:5` (on v3.0.0_test branch) — "April 8, 2026" GA date

**Gotchas for next session:**
- v3.0.0 GA is April 8. Do NOT submit PRs to the WSJTX org repos before then.
- We have READ-only access. Need WRITE before Phase 2 can execute.
- PR #2 on wsjtx (v3.0.0_test → master, 4550 commits) will be merged around GA — may change master significantly.
- The "IMPROVED by DG2YCB" branding in wsjtx-internal INSTALL/README is confusing but low priority. Don't touch during release freeze.
- `.p12` files still in repo root (untracked). Never commit.
- `OUTREACH.md`, `jt9_wisdom.dat`, `timer.out` still untracked.

**Self-assessment:**
- (+) All 5 audit subtasks from BACKLOG.md addressed with evidence
- (+) Discovered v3.0.0 GA date (April 8) — critical timing info not in any prior session notes
- (+) Resolved 3 open questions: superbuild location, Hamlib fork, protocol docs
- (+) Found all previously-unknown GitHub accounts (g3wdg, w3sz, DG2YCB)
- (+) Identified Brian Moran as GitHub champion — strategic insight for Phases 2-5
- (+) Permission level (READ) discovered — would have blocked Phase 2 without this finding
- (+) Clean single-deliverable session, no scope creep
- (-) Apple Developer account remains unresolved (expected — not discoverable from repos)
- (-) Did not examine wiki content (wiki enabled on wsjtx but content unknown)
- Score: 9/10
