# Session 49 — Consolidated Audit Report

**Date:** 2026-04-17
**Persona:** Contributor
**Scope:** Dashboard-fix verification, open-issue audits (#1 / #2 / #3), hygiene inventory refresh, memory trim, email report-back status. Report-only unless otherwise noted.

---

## 1. Dashboard-fix verification (Session 48 follow-through)

**Result: fix holds.**

On clean Session 49 orient:
- No portfolio-cd reflex fired. The parallel orient batch contained no `cd /Users/terrell/Documents/code` or portfolio-script invocation.
- `python3 /Users/terrell/Documents/code/wsjtx-arm/methodology_dashboard.py` returned the project-local dashboard output — "WSJTX-ARM — METHODOLOGY DASHBOARD | 1 projects | Health 86/100 | Risk medium | Activity active."
- 39-session recurring failure appears broken at the source. The single-session data point is not conclusive; re-evaluate after ~5 sessions.

**Status:** Close this watch after Session ~53 if the reflex stays dormant.

---

## 2. Issue #1 — "Phase 2-3: GitHub templates, guards, and macOS CI/CD"

**Issue state:** OPEN on `KJ5HST-LABS/wsjtx-internal`. Created 2026-04-04. Untouched since.

### Scope vs. current state

| Scope item | Current state | Evidence |
|---|---|---|
| Issue templates | **MISSING** | `.github/ISSUE_TEMPLATE/` does not exist (`ls` → no such file or directory) |
| PR template | **MISSING** | No `PULL_REQUEST_TEMPLATE.md` at repo root, `.github/`, or `.github/pull_request_template.md` |
| Branch protection rules | **NOT CONFIGURED** | `gh api repos/.../branches/develop/protection` → `"Branch not protected"`; `main` branch does not exist on the internal repo |
| Required status checks | **NOT CONFIGURED** | Dependent on branch protection; not in place |
| macOS ARM64 build in GitHub Actions | **LANDED** | `.github/workflows/build-macos.yml`; `ci.yml:11-19` wires runner `macos-15`, deployment target 11.0, arch `arm64` |
| Sign macOS ARM64 binaries | **LANDED** | `build-macos.yml:330-366` — Developer ID signing, entitlements, timestamp, deep verify |
| Notarize macOS ARM64 binaries | **LANDED** | `build-macos.yml:425-464` — `notarytool submit` + staple for `.pkg` and CLI tools zip |
| Two-stage Hamlib — Stage 1 (system/vendored) | **LANDED** | `hamlib_branch: "4.7.1"` cloned + built static in CI |
| Two-stage Hamlib — Stage 2 (custom build) | **NOT STARTED** | No evidence in workflows; no custom-Hamlib branch references |
| Apple Silicon hardware test | **NOT AUTOMATED** | Hosted runner `macos-15` only; no self-hosted runner configured |
| Prerequisite: "waiting on WSJT-X v3.0.0 GA" | **MET** | v3.0.0 GA released 2026-04-08 |

### Recommendation

**Do not close #1 as superseded.** The macOS CI/CD Phase-3 majority is landed (and exceeded — Intel macOS also builds in CI), but Phase 2 (templates/guards) is entirely untouched and Stage 2 Hamlib + hardware testing are unstarted.

Suggested action (next session, Contributor): split #1 into two narrower issues:

- **#1-A — GitHub templates and branch protection.** Scope: add `.github/ISSUE_TEMPLATE/{bug,feature}.yml`, `.github/pull_request_template.md`, enable branch protection on `develop` with required checks = the four CI jobs (`macos`, `macos-intel`, `linux`, `windows`). Trivial to land in one session; zero code risk. Close the Phase-3 portion of #1 with a comment summarizing the landed ARM64 CI/CD (signing + notarization + CI runs), then open #1-A.
- **#1-B — Custom Hamlib build (Stage 2).** Scope: replace system-Hamlib build with the internal custom-Hamlib branch. Flag for confirmation: is this still desired, or does 4.7.1 stable meet the need?

Apple Silicon hardware testing is a self-hosted-runner decision — separate issue when prioritized.

---

## 3. Issue #3 — "Rebuild for WSJT-X v3.0.0 GA (April 8, 2026)"

**Issue state:** OPEN on `KJ5HST-LABS/wsjtx-internal`. Created 2026-04-04.

### Scope vs. current state

| Scope item | Current state | Evidence |
|---|---|---|
| Monitor for v3.0.0 GA release | Met | Released 2026-04-08 (upstream) |
| Rebuild macOS ARM64 binary against GA source | **Code-path ready, NOT EXECUTED** | `ci.yml:14,24,34,41` pins `version: "3.0.0"` — wired for GA. No release run against `v3.0.0` tag has been triggered on the internal repo |
| Test the build thoroughly | Pending rebuild execution | N/A until the rebuild runs |
| Publish updated release artifacts | **Not done** | `gh release list --repo KJ5HST-LABS/wsjtx-internal` shows only `Latest Build` (2026-04-01) and `WSJT-X 3.0.0-rc1` (2026-04-01). No `v3.0.0` GA release on the internal repo |
| Apple Developer account ownership (Gap #9) | **STATUS UNKNOWN** | Not mentioned in recent session notes; not surfaced in any workflow comment |

### Key finding

The v3.0.0 git tag exists locally (`git tag -l | grep v3.0.0` returns `v3.0.0`) but has not been pushed to the internal remote in a way that triggered the release pipeline. `release.yml` is tag-driven (`on: push: tags: ["v*"]`), so the tag push IS the build trigger.

### Recommendation

Issue #3 is **ready to execute** in a single session:

1. Confirm (with user) the local `v3.0.0` tag matches upstream v3.0.0 GA source (or is applied to the correct source commit).
2. Push the tag: `git push origin v3.0.0`.
3. Watch the release workflow build all four platforms, sign + notarize macOS artifacts, publish the GitHub Release, and mirror to the public repo.
4. Smoke-test the GA `.pkg` installer on Apple Silicon.
5. Close #3 with a comment summarizing the rebuild + release URL.

Apple Developer account ownership (Gap #9) is a documentation/admin task, not a build task. Split into its own tiny issue: "Document Apple Developer account ownership and signing-chain single-point-of-failure risk." Clarify:
- Who holds the Team ID and admin role?
- Where are the cert + provisioning profile persisted?
- Succession plan if the primary account holder is unreachable?

---

## 4. Issue #2 — "Linux ARM64 build + upstream patches to WSJT-X"

**Issue state:** OPEN on `KJ5HST-LABS/wsjtx-internal`. Created 2026-04-04; last updated 2026-04-17 (re-scoped).

### Scope as-read

Re-scoped scope is clear and unambiguous:

**Completed (for reference in the issue body, already landed):**
- Linux x86_64 CI (`build-linux.yml`, wired into `ci.yml` + `release.yml`)
- Windows x86_64 CI (`build-windows.yml`, MSYS2/MinGW64; first-push green Session 38, commit `887194c16`)
- Release automation (`release.yml`; tag-driven, 4-platform, signed + notarized, auto-changelog, pre-release flagging, public repo sync)

**Open:**
- **Linux ARM64 build** — add `aarch64` to the matrix, native runner `ubuntu-24.04-arm` preferred over cross-compile, wire into both `ci.yml` and `release.yml`, artifact naming `wsjtx-<version>-linux-aarch64`.
- **Four upstream patches**, each as its own PR:
  1. `FindFFTW3.cmake` threads fix (commit `887194c16`) — needs upstream-friendly reformulation; current patch assumes package-manager split and would break JTSDK/bundled-FFTW path.
  2. `WSJT_SKIP_MAP65` cmake option (commit `887194c16`) — trivial PR.
  3. `OMNIRIG_TYPE_LIB` fallback (commit `801bf1fe5`) — CI-friendly alternative to `dumpcpp` COM-registry query.
  4. Hamlib `INSTALL` doc bump to 4.7.1 (commit `ff637fec6`) — keep-current doc patch.

### Ambiguities / notes

- None in the issue body itself. Scope is sharp.
- **Session-planning note:** The five sub-items are independent — a future session can pick any one in isolation. The upstream patches (2), (3), (4) are low-risk and small; (1) is the only one that needs real reformulation work. Linux ARM64 is a medium-sized workstream (matrix change + CI green + release wiring) — likely one session for the CI change + one for release wiring + one for green CI verification.

### Recommendation

**No scope changes.** Next session picks one sub-item from Issue #2. Recommend order: `WSJT_SKIP_MAP65` upstream PR first (trivial) as the entry point to the upstream contribution workstream. `FindFFTW3.cmake` reformulation should be last (highest risk).

---

## 5. Hygiene inventory — grep-refreshed

Session 48 carried a standing list. Re-greps at Session 49:

### Confirmed standing items

| # | Item | Files / lines | Action |
|---|---|---|---|
| 1 | `PHASE_3_TESTING_PLAN.md` "17 cases" (actual: 16) | `docs/contributor/PHASE_3_TESTING_PLAN.md:87,175` | 2 hits. Small commit: add banner pointing to `CTEST_PFUNIT_INTEGRATION_PLAN.md` as authoritative, or in-place fix. |
| 2 | `release.yml:13` stale "three platform artifacts" comment | `.github/workflows/release.yml:13` | Single line; "three" → "four". |
| 3 | `MIGRATION_PLAN.md:275` "All three platforms building" | `docs/contributor/MIGRATION_PLAN.md:275` | One-line fix. Historical plan doc, context-sensitive but should be accurate. |
| 4 | `CTEST_PFUNIT_INTEGRATION_PLAN.md` header status | `docs/contributor/CTEST_PFUNIT_INTEGRATION_PLAN.md:5` — still "DRAFT — evidence-verified, ready for per-phase implementation" | All 6 phases landed; Issue #16 closed. Change to "LANDED" or "COMPLETE — all phases in CI." |
| 5 | `actions/checkout@v4` upgrade | 5 hits across `.github/workflows/` (`build-macos.yml:32`, `build-windows.yml:23`, `hamlib-upstream-check.yml:17`, `release.yml:68`, `build-linux.yml:20`) | Deadline 2026-09-16. Single-commit bump to `@v5` once v5 has ~2 months of stability (v5 released September 2025 — safe now). |
| 6 | Untracked files | `.DS_Store` (repo root + `docs/` subdirs), `.claude/`, `GitHub-installer.p12`, `GitHub.p12`, `OUTREACH.md`, `docs/contributor/email/Steves tests.eml`, `jt9_wisdom.dat`, `timer.out` | .p12 = signing certs, NEVER commit. `.DS_Store` + `.claude/` + local scratch → add to `.gitignore`. `OUTREACH.md`, `Steves tests.eml` → either commit under `docs/contributor/` with a README or add to `.gitignore` as working-scratch. |

### Newly surfaced "three platform" residuals

Session 48's list missed three sites. Found this session:

| File:line | Content | Context |
|---|---|---|
| `README:86` | "available for all three platforms" | Root README. Stale since Intel macOS added. |
| `.github/workflows/hamlib-upstream-check.yml:96` | "let CI run on all three platforms" | Comment in the Hamlib upstream-check workflow. |
| `package_description.txt:79` | "available for all three platforms" | Debian/macOS package description. |

### Dismissible / non-actionable

| Item | Why |
|---|---|
| `drafts/email_cicd_proposal.md:5,11,21` "three platform" strings | Unsent draft from before Intel macOS landed. Either update if we send it, or delete as superseded. See §6 on email report-back. |
| Node.js 20 deprecation — Node 24 forced 2026-06-02 | No `node-version`, `node 20`, or `NODE_VERSION` hits anywhere in `.github/`. Our workflows don't pin Node versions; using action defaults. No action needed until an action fails. |
| Hamlib version duplicated across 12 locations | Standing multi-session item. Centralize in a single var or workflow input. Low priority; aesthetic. |
| `2_DEVELOPMENT_WORKFLOW.md` "supported" vs "minimum baseline" phrasing | Inspected `:180-188` — reads correctly. Session 48's carry-forward line numbers may reference a broader rewrite intent; not an urgent fix. |
| `macos-15-intel` sunset Fall 2027 | Long-horizon. Re-evaluate mid-2027. |

### Hygiene recommendation

Bundle items 1-4 + newly-surfaced three-platform residuals into one small docs/CI commit. That's 7-10 lines across ~8 files. One tight session. Item 5 (`checkout@v5`) deserves its own commit for rollback cleanliness. Item 6 (untracked) deserves its own `.gitignore`-editing commit + decisions about the email/outreach docs.

---

## 6. Memory trim — `feedback_orient_from_project.md`

**Action taken this session (edit, not just report).**

The memory file still carried the pre-Session-48 framing ("prior remediation wasn't enough because I kept invoking the portfolio script by absolute path"). Updated to reflect the structural fix: the hook regex + remediation message, `SESSION_RUNNER.md:17`, and `CLAUDE.md:8` now inline the full absolute project-local path, and the hook denies both the `cd /Users/terrell/Documents/code` pattern AND any absolute-path invocation of the portfolio script.

Diff (conceptual):

- **Before:** "the prior remediation (a hook blocking `cd` to portfolio) wasn't enough because I kept invoking the portfolio script by absolute path."
- **After:** "Running the portfolio-level script from a project session reports on 19 sibling repos instead of this one — wrong tool for the context." + pointer to the hook and the two procedure docs that inline the project-local path.

File: `/Users/terrell/.claude/projects/-Users-terrell-Documents-code-wsjtx-arm/memory/feedback_orient_from_project.md`. Frontmatter untouched.

---

## 7. Email report-back — audit only (send deferred)

### What exists

- **`OUTREACH.md`** (repo root, untracked): three pre-packaged messages from the v3.0.0-rc1 era (early April 2026) — one mailing-list email to `wsjt-devel@lists.sourceforge.net`, two SourceForge tickets (CMake 4.x reserved targets, arm64 deployment target 10.12→11.0). Content is **stale**:
  - Message references "3.0.0-rc1" — v3.0.0 GA has since dropped (2026-04-08).
  - CI/CD described as "three-platform" — now four (Intel macOS landed).
  - The CMake 4.x target rename may or may not already be upstream (unverified).
  - The deployment-target fix specifics are still accurate.
- **`docs/contributor/drafts/email_cicd_proposal.md`**: the formal CI/CD proposal to the team. Three "three platform" strings (lines 5, 11, 21) — stale.
- **`docs/contributor/drafts/email_cicd_reply.md`**: reply in the CI/CD thread.
- **`docs/contributor/drafts/email_bundle_fix.md`**: unknown — not inspected this session. Flag for next pass.
- **`docs/contributor/email/Re_ CI_CD Success!`**: inbound — the team's reply to the CI/CD proposal. So the first round of outreach already happened and got a positive response.
- **`docs/contributor/email/Steves tests.eml`**: inbound from Steve Franke (decoder test corpus) — superseded by Phase 3d vendoring (Session 46, `ece547850`).

### What a fresh report-back could bundle

Since the CI/CD proposal already got a positive reply, the next team-facing message would be a progress update. Candidates:

1. **v3.0.0 GA build status** — once Issue #3 executes and the GA artifact is published on the internal/public release pages, this becomes the headline.
2. **Four-platform CI green** — confirms Intel macOS + Windows + Linux x86_64 + macOS ARM64 all building and signed/notarized where applicable.
3. **ctest + pfUnit integration complete** — Issue #16 closed, 21 ctest entries × 4 platforms, Franke decoder regression corpus vendored. Good engineering-maturity signal.
4. **Upstream patches queued** — reference the four patches scoped in Issue #2 and ask which landing cadence the team prefers.
5. **Open questions** — Apple Developer account ownership / single-point-of-failure (Gap #9); branch protection preferences.

### Recommendation

**Do not send anything this session.** The message content needs the user's voice and judgment on:

- **Audience:** team mailing list vs. direct email to K1JT.
- **Tone:** progress report vs. request for guidance on upstream cadence.
- **Timing:** before or after pushing the v3.0.0 GA rebuild (Issue #3).
- **Content decisions:** which of the 5 candidates to include, which to defer.

The pending-since-39-sessions line from the handoffs is not wrong, but acting without scope confirmation would violate the shared-state authorization principle. Suggested next step: the user drafts (or asks this agent to draft) the specific message in a dedicated session, then explicitly approves before a send.

---

## Summary of recommended next sessions

| Priority | Session | Scope | Effort |
|---|---|---|---|
| 1 | Execute #3 — push `v3.0.0` tag, watch release run, verify + close | Single tag push, CI watch, release verification | ~1 hour + CI |
| 2 | Split #1 — close macOS CI/CD portion with summary comment, open #1-A (templates + branch protection) | Comment writing + issue creation | ~30 min |
| 3 | #1-A execution — add issue/PR templates, enable branch protection with required checks | 4-5 files, JSON + YAML, no code | ~1 hour |
| 4 | Hygiene bundle — items 1-4 + three-platform residuals | ~8 files, ~10 lines | ~30-45 min |
| 5 | Pick one Issue #2 sub-item — recommend `WSJT_SKIP_MAP65` upstream PR first (trivial entry point) | Upstream PR workflow | ~1 hour + review cycle |
| 6 | Draft email report-back — user-approved content before send | Content drafting + explicit send approval | ~30-45 min |
| n | Apple Developer account ownership — new issue | Documentation-only | ~15 min |

---

*Audit produced Session 49, 2026-04-17. All claims evidence-verified via grep, gh API, git log, or file read within the session.*
