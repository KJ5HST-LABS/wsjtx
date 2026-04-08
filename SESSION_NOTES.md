# Session Notes

## ACTIVE TASK
**Task:** Two-repo CI/CD proof of concept — Phase 2: CI workflows
**Status:** Phase 1 (repo setup) complete. Phase 2 ready to start.
**Session:** 5 complete
**Started:** 2026-04-02

---

### Session 4 Handoff Evaluation (by Session 5)
- **Score: 7/10**
- **What helped:** Persona framework, key file references, gotchas about release freeze and READ-only access.
- **What was missing:** No mention of org-level secrets having `visibility: all` but actually not reaching repos — Session 5 spent significant time debugging this. The ACTIVE TASK was stale (still said "blocked until GA + WRITE access" but WRITE was granted April 4 and GA shipped).
- **What was wrong:** "docs/planning/ no longer exists" was wrong — Session 5 created docs/planning/ for the CI/CD PoC plan.
- **ROI:** Moderate. The persona framework guidance was useful but the stale task/status info required re-orientation.

---

### What Session 5 Did
**Deliverable:** CI/CD proof-of-concept — Phase 1 repo setup + plan — COMPLETE
**Started:** 2026-04-06
**Status:** All Phase 1 steps committed and pushed.

**What was produced:**

1. **Build pipeline fixes:**
   - Fixed org-level secret visibility (`.p12` secrets had `visibility: private` with no repos selected)
   - Fixed notarization secret name (`APPLE_ID_PASSWORD` → `APPLE_APP_SPECIFIC_PASSWORD`)
   - Commit `6dab96d` — workflow fix for notarization secret

2. **WSJT-X 3.0.0 GA build workflow:**
   - `build-3.0.0.yml` — two-stage build from GitHub source (no SourceForge superbuild)
   - Clones WSJTX/wsjtx at tag, builds Hamlib from source, builds WSJT-X via cmake
   - Commit `95f326c` (initial), updated in `0ce8928`

3. **CI/CD proof-of-concept plan:**
   - `docs/planning/CICD_PROOF_OF_CONCEPT.md` — audited plan with reusable workflows, caching, external contribution flow
   - `docs/contributor/drafts/email_cicd_proposal.md` — team-facing email draft
   - `docs/contributor/drafts/email_bundle_fix.md` — email draft for bundle fix discussion

4. **Phase 1 repo setup (the main deliverable):**
   - Renamed `WSJT-X-MAC-ARM64` → `KJ5HST-LABS/wsjtx-internal`
   - Renamed `main` → `develop` branch, set as default
   - Imported WSJT-X v3.0.0 source from `WSJTX/wsjtx` (merge with `--allow-unrelated-histories`)
   - Created `KJ5HST-LABS/wsjtx` (private, `main` default)
   - Generated two deploy key pairs (release flow + sync flow)
   - Deploy keys installed on both repos, private keys stored as secrets

**Key discoveries:**
1. **Org-level secrets with `visibility: all` were not reaching repos.** Root cause unknown. Fixed by re-uploading secrets. Later moved to repo-level, then back to org-level after the user re-set them.
2. **`APPLE_ID_PASSWORD` secret was the wrong name.** The app-specific password was stored as `APPLE_APP_SPECIFIC_PASSWORD`. Workflow was referencing the wrong secret.
3. **Deploy keys were disabled by org policy.** Had to ask user to enable in org settings before keys could be added.
4. **Shallow clone caused push failures.** `git fetch --depth=1` left missing objects; needed full fetch before push would work.

**What's next:**
1. **Phase 2: CI workflows** — the next session's deliverable. Build order:
   - Write `build-macos.yml` (reusable workflow, adapt from `build-3.0.0.yml`)
   - Write `ci.yml` (thin orchestrator, macOS only first)
   - Push to `develop`, verify macOS builds green
   - Add `build-linux.yml`, verify
   - Add `build-windows.yml`, verify (expect 2-3 iterations)
   - Write `release.yml` (tag-triggered, pushes to wsjtx)
2. **Phase 3: Three test changes** to prove the workflow end-to-end
3. **Phase 4: Document results and share with team**

**Key files:**
- `docs/planning/CICD_PROOF_OF_CONCEPT.md` — the audited PoC plan (reusable workflows, caching, external contribution flow)
- `.github/workflows/build-3.0.0.yml` — proven macOS two-stage build to adapt for `build-macos.yml`
- `entitlements.plist` — macOS Fortran JIT entitlements, must be on `develop`
- `docs/contributor/drafts/email_cicd_proposal.md` — email draft to update with results after Phase 3

**Gotchas for next session:**
- **Repo is now `KJ5HST-LABS/wsjtx-internal`**, not `WSJT-X-MAC-ARM64`. Local remote is updated.
- **Branch is `develop`**, not `main`. Default branch on GitHub is `develop`.
- **WSJT-X source is in the repo root.** `CMakeLists.txt`, `INSTALL`, `COPYING`, etc. coexist with our docs and workflows.
- **The old `build.yml` and `build-3.0.0.yml` still exist on `develop`.** They trigger on push to `main` (which no longer exists) or workflow_dispatch. They won't auto-trigger but could be dispatched manually. Remove or update once `ci.yml` is in place.
- **Deploy keys are in place.** `WSJTX_DEPLOY_KEY` on wsjtx-internal, `INTERNAL_DEPLOY_KEY` on wsjtx. Both read-write.
- **Org secrets exist** (`visibility: all`): APPLE_ID, APPLE_APP_SPECIFIC_PASSWORD, APPLE_TEAM_ID, DEVELOPER_ID_CERTIFICATE_P12, DEVELOPER_ID_CERTIFICATE_PASSWORD, DEVELOPER_ID_INSTALLER_P12, DEVELOPER_ID_INSTALLER_PASSWORD.
- **`.p12` files still in repo root** (untracked). Never commit.
- **Windows build is highest risk** in Phase 2. MSYS2 MINGW64 approach planned, expect iterations.
- **The upstream remote `upstream` points to `WSJTX/wsjtx`.** Can be used to pull future upstream changes.

**Self-assessment:**
- (+) Fixed three separate build failures (secret visibility, secret name, org policy) — each required diagnosis
- (+) Phase 1 repo setup completed cleanly: rename, branch, source import, public repo, deploy keys
- (+) CI/CD plan audited for best practices: reusable workflows, caching, external contribution flow added
- (+) Identified and resolved the shallow clone push failure without data loss
- (+) Email draft written in contributor persona (clean, no consumer leakage)
- (-) Session was long and covered multiple concerns (build fixes, plan writing, plan auditing, repo setup) — more than "1 and done" strictly allows, but the user drove the scope
- (-) Did not commit the updated `docs/planning/CICD_PROOF_OF_CONCEPT.md` after the audit revision — it was committed before the audit but the post-audit version was committed separately
- (-) The `build-3.0.0.yml` on `develop` still references the old trigger pattern (workflow_dispatch only, SourceForge download removed but old build.yml still exists)
- Score: 7/10

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
3. Read `docs/contributor/CONTRIBUTION_PLAN.md` Phase 1 section for the full audit checklist

**Key files:**
- `CLAUDE.md` — new, project agent instructions
- `SESSION_RUNNER.md` — new, cockpit checklist (follow this every session)
- `SAFEGUARDS.md` — new, safety rails
- `BACKLOG.md:10-16` — Phase 1 audit subtasks
- `docs/contributor/CONTRIBUTION_PLAN.md` — Phase 1 details
- `docs/consumer/GPL_COMPLIANCE_GAPS.md` — gaps to investigate during audit
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
1. `docs/contributor/REPO_AUDIT.md` — Comprehensive audit of the WSJTX GitHub org (2 repos, 24 branches, 7 PRs, 7 issues, org membership, CI/CD status, Hamlib resolution, protocol docs, v3.0.0 timeline)

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
- `docs/contributor/REPO_AUDIT.md` — Session 3 audit output. Full audit with 9 findings.
- `docs/contributor/CONTRIBUTION_PLAN.md` — Contribution phases and timeline
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

---

### Session 3 Handoff Evaluation (by Session 4)
- **Score: 9/10**
- **What helped:** The "What's next" section was perfectly prioritized — "wait for GA, request WRITE, then Phase 2" was exactly right. Key files list included remote repo paths (NetworkMessage.hpp, INSTALL, Release_Notes.txt:5) which saved lookup time. The gotchas about release freeze timing and READ-only access prevented wasted effort.
- **What was missing:** No mention of the doc structure — all planning docs were in a flat `docs/planning/` directory with mixed contributor/consumer content. Session 4 had to reorganize everything when the persona framework was established. Not a fault of Session 3 (the framework didn't exist yet), but worth noting.
- **What was wrong:** Nothing factually wrong.
- **ROI:** Excellent. The structured next-steps and timing constraints were immediately actionable.

---

### What Session 4 Did
**Deliverable:** Migration/CI-CD plan + persona-based documentation reorganization — COMPLETE
**Started:** 2026-04-03
**Status:** All files written and references updated. Not yet committed.

**What was produced:**

1. **Migration/CI-CD plan** — `docs/contributor/MIGRATION_PLAN.md`
   - 5 workstreams: repo hygiene, contribution infrastructure, CI/CD (3 platforms), superbuild decision, release automation
   - Prerequisites matrix (access, information, buy-in, technical)
   - Timeline: 8-11 sessions over ~3 months
   - Risk register with mitigations

2. **Persona framework and documentation reorganization:**
   - Established Contributor and Consumer personas with strict one-way information flow
   - `docs/contributor/` — 3 docs (CONTRIBUTION_PLAN.md, REPO_AUDIT.md, MIGRATION_PLAN.md) — all verified zero consumer leakage via grep
   - `docs/consumer/` — 3 docs (SYMBIOTIC_OPEN_SOURCE.md, GPL_COMPLIANCE_GAPS.md, CONSUMER_STRATEGY.md)
   - `docs/planning/` — removed (content split into persona directories)
   - All references updated in CLAUDE.md, BACKLOG.md, SESSION_NOTES.md, SESSION_RUNNER.md, and cross-references within consumer docs

3. **SESSION_RUNNER.md updated** — Phase 0 now includes step 8: "Ask which persona for this session — Contributor or Consumer?" Step count updated from 8 to 9.

4. **Memory saved** — `feedback_persona_framework.md` indexed as FOUNDATIONAL in MEMORY.md

**What's next:**
1. **Wait for v3.0.0 GA (April 8).** Do not submit PRs during release freeze.
2. **User action items (non-code):**
   - Email team: request WRITE access for KJ5HST on both repos
   - Email team: ask about Apple Developer account ownership and Windows build toolchain
3. **Next contributor session (after GA + WRITE access):** Phase 2 quick wins — CONTRIBUTING.md, PR template, close stale PR #1 / issue #1, propose branch protection. One session.
4. **Next consumer session (anytime):** Prototype switching build.yml from SourceForge tarball to two-stage GitHub source build. Also: rebuild when v3.0.0 GA drops, add corresponding source tarball to releases (GPL compliance Gap #1).
5. **Phase 6 upstream patches** can be done anytime (no access needed) — CMake 4.x fixes, deployment target, stale URLs.

**Key files:**
- `docs/contributor/MIGRATION_PLAN.md` — THIS SESSION'S PRIMARY OUTPUT. Full CI/CD migration plan.
- `docs/contributor/CONTRIBUTION_PLAN.md` — Clean contributor version of the 6-phase plan
- `docs/contributor/REPO_AUDIT.md` — Clean contributor version of the org audit
- `docs/consumer/CONSUMER_STRATEGY.md` — NEW. Persona framework definition, pipeline impact, cert strategy.
- `docs/consumer/SYMBIOTIC_OPEN_SOURCE.md` — Moved from `docs/`
- `docs/consumer/GPL_COMPLIANCE_GAPS.md` — Moved from `docs/planning/`
- `SESSION_RUNNER.md:Phase 0` — Updated with persona selection step (step 8)
- `CLAUDE.md` — Updated doc references and persona rule
- `BACKLOG.md` — Updated doc references

**Gotchas for next session:**
- v3.0.0 GA is April 8 (5 days). Do NOT submit PRs to WSJTX org repos before then.
- We have READ-only access. Need WRITE before any contributor work on org repos.
- **Persona must be declared at session start.** Contributor sessions produce zero consumer references. Consumer sessions can reference contributor work. No mid-session switching.
- Contributor docs were verified clean (zero matches for rad-con/commercial/Claude/consumer/KJ5HST-LABS/symbiotic). Maintain this standard.
- `.p12` files still in repo root (untracked). Never commit.
- `OUTREACH.md`, `jt9_wisdom.dat`, `timer.out` still untracked.
- `docs/planning/` no longer exists. Plans go to `docs/contributor/` or `docs/consumer/` by persona.

**Self-assessment:**
- (+) Migration plan covers all 5 workstreams with concrete technical details (workflow pseudocode, dependency matrices, timeline)
- (+) Persona reorganization verified clean — grep confirmed zero consumer leakage in contributor docs
- (+) All file references updated across 6 files with no orphaned paths (one methodology template reference left intentionally)
- (+) SESSION_RUNNER.md updated to enforce persona selection during orientation
- (+) Memory saved for cross-session persistence
- (+) Session had two deliverables (migration plan + persona reorg) but they were requested together by the user as a single unit of work
- (-) Session produced two deliverables rather than the strict "1 and done" rule. The persona reorg was a user-directed mid-session pivot, not scope creep — but worth noting.
- (-) The migration plan was written once with mixed content, then had to be rewritten clean for the contributor persona. Could have anticipated the split if the persona framework had been established first.
- Score: 8/10
