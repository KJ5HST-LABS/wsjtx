# Production Readiness Plan — CI/CD for WSJT-X

**Status:** DRAFT (Session 62, 2026-04-19)
**Purpose:** Close the gaps between the current sandbox CI/CD proof and a team-owned, commercially-viable release pipeline.
**Audience:** WSJT-X maintainers evaluating adoption of this pipeline.

---

## 1. Scope

This plan addresses the 14 concrete defects identified in the Session 62 audit of the current CI/CD machinery. It does NOT re-litigate whether the sandbox machinery works (it does); it defines the precise path from "works in the sandbox on clean tags" to "safe to cut a real WSJT-X release from the team's repository."

**Sandbox-vs-production policy (per user direction):**

- **Sandbox** = `KJ5HST-LABS/wsjtx-internal`. Proving ground. Shortcuts are acceptable here IF they are documented, bounded, and accompanied by an issue tracking their production-required replacement. Example: per-run ephemeral self-signed Windows certificate is acceptable in the sandbox; it is NOT acceptable in production.
- **Production** = `WSJTX/wsjtx-internal` (and its public release surface `WSJTX/wsjtx`). No shortcuts. Every sandbox compromise must be addressed with precision and intent before the first real release cuts from this pipeline.

Each phase below marks items as `[SANDBOX-OK]`, `[PRODUCTION-REQUIRED]`, or `[BOTH]`.

---

## 2. Audit Baseline

The audit identified 14 findings, referenced below by audit number (A1–A14).

| # | Finding | Current state | Severity |
|---|---------|---------------|----------|
| A0 | Replication gap | `WSJTX/wsjtx-internal` has zero `.github/workflows/` | **BLOCKER** |
| A1 | Public distribution broken | `KJ5HST-LABS/wsjtx` is private, zero releases; download URLs 404 | **BLOCKER** (sandbox consumers) |
| A2 | Unconditional force-push to public main | `release.yml:193` | **HIGH** |
| A3 | Silent-success on missing `CROSS_REPO_TOKEN` | `release.yml:185-188` | **HIGH** |
| A4 | Signature verify suppressed (`|| true`) | `build-windows.yml:223` | **HIGH** (blocked on prod cert) |
| A5 | Security posture disabled | Dependabot, code-scanning, secret-scanning all off on sandbox | **HIGH** |
| A6 | Admin-bypass tolerated | Sandbox `develop` protection has `enforce_admins: false` | **MEDIUM** (sandbox) / **HIGH** (prod) |
| A7 | No commit signing | `required_signatures: false` | **MEDIUM** (prod) |
| A8 | Missing governance artifacts | No `CONTRIBUTING.md`, `SECURITY.md`, `CODEOWNERS` | **MEDIUM** |
| A9 | `linuxdeploy` unpinned | `build-linux.yml:146,148` uses `/releases/download/continuous/…` | **MEDIUM** |
| A10 | End-to-end never run in anger | Gate validated by simulation only; no real tag has exercised the full path | **HIGH** |
| A11 | No post-publish verification | Nothing re-downloads released assets to confirm integrity | **MEDIUM** |
| A12 | Version drift | `ci.yml:14,25,34,41` hard-code `"3.0.0"` instead of reading `CMakeLists.txt:55` | **MEDIUM** |
| A13 | No reproducibility manifest | `release.yml:78-91` produces source tarball but no `SHA256SUMS` or provenance attestation | **MEDIUM** |

Production cert provisioning (Windows + Apple Developer ID team identity) is team-owned and explicitly outside this plan's scope; it is a dependency for Phase 5.

---

## 3. Phased Plan

Each phase = one session-bounded deliverable. Adjacent phases can run in sequence; cross-phase parallelism is discouraged (it is what caused the audit findings).

---

### Phase 1 — Sandbox release-path safety hardening `[SANDBOX-OK → PRODUCTION-REQUIRED]`

**Deliverable:** One PR against `KJ5HST-LABS/wsjtx-internal:develop` closing audit items A2, A3, A9, A12 (all edit-local, no external dependencies).

**Actions:**

1. **A2 — Guard public-mirror force-push** (`release.yml:181-194`)
   - Add `if: ${{ github.ref_name == needs.prepare.outputs.expected_ref_name }}` or an explicit branch-name verification step before the `git push public HEAD:main --force`.
   - Add a pre-push step that fetches the current public `main` SHA and logs the SHA about to be overwritten. Human-auditable record.
   - Acceptable sandbox relaxation: continue to use `--force` (history-rewrite tolerated during bring-up). Production-required: replace `--force` with fast-forward-only, AND require a human approval environment (`environment: public-release`) on the job.

2. **A3 — Fail-loud on missing sync token** (`release.yml:185-188`)
   - Change the `if [ -z "$TOKEN" ]; then echo warning; exit 0; fi` to `exit 1`. Or, better: require the secret at job level via `environment:` rules so the job never starts if the token is absent.
   - Rationale: a "successful" release that silently skips the mirror sync is the worst failure mode — it looks green and leaves users unable to download.

3. **A9 — Pin `linuxdeploy`** (`build-linux.yml:143-148`)
   - Replace `/releases/download/continuous/` with a specific tagged release. Pin `linuxdeploy` AND `linuxdeploy-plugin-qt` to the same dated tag.
   - Capture the SHA256 of each `.AppImage` after download; fail the job if the hash drifts. This makes an undetected upstream change impossible.
   - Sandbox-acceptable: manual tag pin. Production-required: SHA256-pinned, verified at download time.

4. **A12 — Single-source-of-truth version** (`ci.yml:14,25,34,41`)
   - Add a `prepare` job to `ci.yml` mirroring the one in `release.yml:14-20`, reading `CMakeLists.txt:55` via `grep -E 'VERSION\s+[0-9]' CMakeLists.txt | head -1` or equivalent, and feeding the derived version as a job output to all four build jobs.
   - Remove the four hard-coded `"3.0.0"` literals.
   - CI and release now agree on version by construction.

**Completion criteria (Phase 1 DONE):**
- PR opens, 4 platform builds pass, merged to `develop`.
- `git grep '"3.0.0"' .github/workflows/` returns zero hits.
- `grep -n 'continuous' .github/workflows/build-linux.yml` returns zero hits.
- `grep -n '|| true' .github/workflows/release.yml` shows only intentional instances (none should remain in release.yml after this phase; `build-windows.yml:223` remains — that is Phase 5).

**Verification:**
```
gh pr view <PR> --json mergedAt,state --jq '.state'     # → "MERGED"
gh run list --workflow=ci.yml --branch=develop --limit=1 # → success
```

**Session boundary:** One PR. One session. Close out when the PR is merged and verified green.

---

### Phase 2 — Sandbox repo security posture + governance `[SANDBOX-OK → PRODUCTION-REQUIRED]`

**Deliverable:** One configuration + docs PR closing audit items A5, A6 (sandbox-tier), A8.

**Actions:**

1. **A5 — Enable repo security features** on `KJ5HST-LABS/wsjtx-internal`:
   - Dependabot security updates.
   - Dependabot version updates (config file committed in `.github/dependabot.yml` — weekly cadence for GitHub Actions ecosystem; quarterly for C++/Python where churn is low).
   - Secret scanning + push protection.
   - Code scanning with CodeQL (C++, Python, Actions YAML).
   - Enable via `gh api` PATCH or GitHub web UI; settings committed as screenshots in `docs/contributor/screenshots/` for audit trail.

2. **A6 — Tighten admin bypass on sandbox `develop`**:
   - Sandbox can continue to allow admin bypass (Terrell is sole admin; workflow requires it for direct pushes during bring-up).
   - But record the current setting explicitly in `docs/contributor/3_CICD_DEPLOYMENT_PLAYBOOK.md` with a production-migration note: "Production must set `enforce_admins: true`."

3. **A8 — Add governance artifacts** (at repo root):
   - `SECURITY.md` — disclosure channel (email or private-vulnerability-report form), 90-day response commitment, supported-versions table.
   - `CONTRIBUTING.md` — lightweight; points to `docs/contributor/CONTRIBUTION_PLAN.md` for depth, covers the basics (PR flow, build-equivalent, how to run CI locally via `act` if applicable).
   - `CODEOWNERS` — declare reviewers per-path. Sandbox-acceptable: single owner (`*  @KJ5HST`). Production-required: team ownership by area (`build-*.yml`, `CMakeLists.txt`, `lib/`, `doc/`).
   - `.github/CODE_OF_CONDUCT.md` — adopt Contributor Covenant v2.1 unless the team has a preference.

**Completion criteria (Phase 2 DONE):**
- `gh api repos/KJ5HST-LABS/wsjtx-internal --jq .security_and_analysis` shows all four enabled.
- `gh api repos/KJ5HST-LABS/wsjtx-internal/contents/SECURITY.md` returns 200.
- `gh api repos/KJ5HST-LABS/wsjtx-internal/contents/CONTRIBUTING.md` returns 200.
- `gh api repos/KJ5HST-LABS/wsjtx-internal/contents/CODEOWNERS` returns 200.
- First Dependabot PR has opened within 24 h (proof the automation is live).

**Session boundary:** One session. Close out when the settings are on and the governance files are merged.

---

### Phase 3 — Sandbox end-to-end release validation `[SANDBOX-OK]`

**Deliverable:** Exercise the full release path against real tags. Closes audit item A10 and provides empirical ground truth for Phase 4's replication design.

**Actions:**

1. **Forced-failure test tag** (low blast radius — gate is expected to fail before any publish side-effect).
   - On a disposable branch, temporarily break `build-windows.yml`'s upload-artifact step (e.g., rename the artifact to `wsjtx-<ver>-windows-x86_64-broken`).
   - Push `build/v3.0.1-gatefail-test`.
   - Expect: `release.yml`'s all-platforms-ready gate fails with `::error::MISSING Windows .exe`, `Create GitHub Release` never runs, public-mirror push never fires.
   - Revert the artifact name, delete the tag.
   - Document the run ID in `docs/contributor/3_CICD_DEPLOYMENT_PLAYBOOK.md`.

2. **Happy-path test tag** (high blast radius — triggers the public-mirror force-push; see A2 from Phase 1 — this is only safe AFTER Phase 1 lands).
   - Push `build/v3.0.1-rc1` from develop.
   - Observe: all 4 builds green, gate passes, GitHub Release created as `--prerelease`, public-mirror sync step logs the pre-push SHA (per Phase 1 A2) and pushes. Downloadable assets verify.
   - Document run ID, release URL, and the 4 asset SHA256s in the playbook.

**Completion criteria (Phase 3 DONE):**
- One forced-failure run link recorded with `::error::` proof.
- One happy-path run link recorded with all 4 asset SHA256s.
- Both tags still in git history (do not delete — they are forensic evidence).

**Session boundary:** One session covers both tags (they are cohesive end-to-end validation). Close out after both are documented.

---

### Phase 4 — Replication to `WSJTX/wsjtx-internal` `[PRODUCTION-REQUIRED]`

**Deliverable:** Open the first `WSJTX/wsjtx-internal` PR introducing the CI build matrix. This phase splits into **4a (inventory)** and **4b (PR)** as separate sessions — inventory discipline from SESSION_RUNNER applies.

#### Phase 4a — Evidence-based inventory (planning session)

Produce `docs/contributor/REPLICATION_DELTA.md` enumerating every difference between sandbox and production that must be reconciled:

1. **Secrets** — every `${{ secrets.X }}` referenced in the 6 workflow files. For each, state:
   - Sandbox value provenance.
   - Whether production needs a 1:1 equivalent, a team-owned replacement, or can omit.
   - The scope required (repo-level / environment-level / org-level).
   - Example: `MACOS_CERT_P12_BASE64` (sandbox: Terrell's developer ID) → production: team's developer ID, org secret.

2. **Runners** — every `runs-on:` value. Confirm `macos-15`, `macos-15-intel`, `ubuntu-latest`, and `windows-latest` are all on the team's plan. Escalate if not.

3. **Tokens / permissions** — every `permissions:` block and `GH_TOKEN:` use. Confirm the team's default token permissions allow what's needed (or document the overrides).

4. **External dependencies** — hamlib branch, linuxdeploy pin (post-Phase 1), PFUnit, all upstream tags referenced by SHA or name.

5. **Branch structure** — team repo `default_branch: develop`, confirmed. Team's release-tag convention — confirm `build/v*` vs. any existing team pattern (e.g., `v*`, `release/*`).

6. **Public mirror** — whether the team wants the `KJ5HST-LABS/wsjtx` → `WSJTX/wsjtx` sync preserved (with new token) or dropped entirely in favor of direct publish-to-WSJTX/wsjtx from the internal release job.

**Completion criteria (Phase 4a DONE):**
- Inventory document lives at `docs/contributor/REPLICATION_DELTA.md` with one row per reconciliation item.
- Grep-based evidence: `grep -rE 'secrets\.|runs-on:|permissions:' .github/workflows/` output is pasted into the inventory's appendix.
- Team sign-off on the reconciliation choices (dated, per item).

**Session boundary:** Inventory is the deliverable. No workflow files copied yet.

#### Phase 4b — Replication PR

Open PR on `WSJTX/wsjtx-internal:develop`:

- Copy `ci.yml`, `build-macos.yml`, `build-linux.yml`, `build-windows.yml` (all 4 platforms).
- Copy `hamlib-upstream-check.yml` (cron — low risk, high value).
- **Do NOT copy `release.yml`** in this PR. Release is gated behind Phases 5 + 6.
- Apply every secret/runner/token substitution from the inventory.
- Enable branch protection on `WSJTX/wsjtx-internal:develop` with the 4 status checks required (same pattern as sandbox; `enforce_admins: true` this time).

**Completion criteria (Phase 4b DONE):**
- PR merged to `WSJTX/wsjtx-internal:develop`.
- First CI run succeeds on all 4 platforms on the team repo.
- Branch protection verified: `gh api repos/WSJTX/wsjtx-internal/branches/develop/protection` returns a matching structure.
- Dependabot + secret scanning + CodeQL enabled on `WSJTX/wsjtx-internal` (same as Phase 2 applied here).

**Session boundary:** One session for the replication PR. Settings-change session can follow adjacent.

---

### Phase 5 — Production signature integrity `[PRODUCTION-REQUIRED]`

**Deliverable:** Replace every signing shortcut. Closes audit items A4, A7, and the acknowledged open-ticket production cert work.

**Dependencies:** Blocked on team delivery of:
- Production Windows code-signing certificate (stored in GitHub encrypted secret, ideally via HSM or Azure Key Vault sidecar).
- Apple Developer ID for the team's identity, with the `.p12` and notarization credentials stored as org secrets.

**Actions (once certs are available):**

1. **A4 — Remove `|| true` on osslsigncode verify** (`build-windows.yml:223`).
   - Replace with `osslsigncode verify "$INSTALLER"`. Non-zero exit now fails the build.
   - Remove the explanatory "`|| true` keeps CI green" comment block (lines 224-226).
   - Drop ephemeral self-signed cert generation (the block above line 214); use the production cert loaded from `secrets.WINDOWS_CODESIGN_PFX_BASE64`.

2. **Notarization enforcement**:
   - Confirm the macOS codesign + notarize steps fail the build on any failure (no `|| true` there either — verify current state).
   - Enforce `stapler validate` as a hard check post-notarization.

3. **Commit-signing policy** (A7):
   - Set `required_signatures: true` on production `develop`.
   - Team maintainers configure GPG or SSH signing; automated pipeline commits (e.g., hamlib-upstream-check bump commits) use a signed bot identity.

4. **`enforce_admins: true`** on `WSJTX/wsjtx-internal:develop`.

**Completion criteria (Phase 5 DONE):**
- `grep -rn '|| true' .github/workflows/` returns zero hits (production repo).
- `gh api repos/WSJTX/wsjtx-internal/branches/develop/protection --jq '.required_signatures.enabled,.enforce_admins.enabled'` returns `[true, true]`.
- A test signed installer's `osslsigncode verify` exits 0 with `Signature verification: ok`.
- A test signed `.pkg` passes `spctl -a -vv` AND `stapler validate`.

**Session boundary:** One session per sub-item (4 sessions total in this phase), each gated on cert availability. Do not batch: each change has its own failure surface and must be independently observable.

---

### Phase 6 — Operational readiness `[PRODUCTION-REQUIRED]`

**Deliverable:** The release surface becomes *operable* — the team can cut, verify, and if-necessary roll back a release without tribal knowledge. Closes audit items A1, A11, A13.

**Actions:**

1. **A1 — Public release surface** (must be solved before first production release):
   - Team decision: either (a) flip `WSJTX/wsjtx` public with a clean initial release, OR (b) publish releases directly on `WSJTX/wsjtx-internal` (if that repo becomes public) and deprecate the mirror pattern.
   - If (a): audit `WSJTX/wsjtx` for any historical sensitive content before flipping (secret scanning, git-log grep for `*.p12`, `*.pfx`, `*.key`, `*.pem` across all refs). This audit MUST complete before the visibility flip.
   - Adapt `release.yml`'s mirror-push step to the chosen destination.

2. **A11 — Post-publish verification step** — new `release.yml` job:
   - After `gh release create`, download each uploaded asset.
   - Re-verify signatures (macOS: `spctl + stapler`; Windows: `osslsigncode verify`; Linux AppImage: `gpg --verify` if signed, otherwise SHA256 match).
   - Re-compute SHA256 against the upload manifest; fail on mismatch.
   - Publish the verified manifest as a release asset (`SHA256SUMS`).

3. **A13 — Reproducibility manifest + provenance**:
   - Emit `SHA256SUMS` and `SHA256SUMS.asc` (GPG-signed) per release, covering source tarball + every installer.
   - Add GitHub attestations (`actions/attest-build-provenance@v2`) to each installer. Downstream integrators can then verify `gh attestation verify <installer>`.

4. **Runbook** (`docs/contributor/RELEASE_RUNBOOK.md`):
   - How to cut a release: pre-flight checklist, tag format, expected runtime, rollback triggers, rollback procedure (delete release, re-tag, revert force-push — with commands).
   - How to handle a partial release failure (the gate should catch it; document what to do if it doesn't).
   - How to revoke a release (delete + retract advisory + notify users).

5. **Staging/promotion**:
   - Formalize the pre-release tag pattern (`build/v<ver>-rc<n>`, `build/v<ver>-beta<n>`) vs. stable. Already partially supported in `release.yml:171-174` — document and enforce via release-drafter config.
   - Add a `needs: manual-approval` gate via `environment: stable-release` for non-prerelease tags, so a human must approve the stable cut even when the pipeline is green.

**Completion criteria (Phase 6 DONE):**
- One real `build/v*-rc*` release cut end-to-end against production repo; all assets downloadable and signature-verified post-publish.
- `SHA256SUMS` + `SHA256SUMS.asc` present on the release.
- `gh attestation verify <installer> --owner WSJTX` returns green for each installer.
- `docs/contributor/RELEASE_RUNBOOK.md` merged, with documented verification commands.
- Staging gate confirmed: attempting to push a stable tag (no `-rc`) pauses awaiting human approval.

**Session boundary:** Each sub-item is its own session (5 sessions in this phase). The end-to-end rc cut is Phase 6's capstone — do it last, only after all other Phase 6 items are in.

---

## 4. Dependency graph

```
Phase 1 (sandbox hardening) ──┐
                              ├──→ Phase 3 (sandbox E2E validation) ──→ Phase 4a ──→ Phase 4b ──→ Phase 5 ──→ Phase 6
Phase 2 (sandbox governance) ─┘                                                          ▲
                                                                                         │
                                                                              Team-delivered production certs
```

- Phases 1 and 2 can run in either order (or parallel sessions); both precede Phase 3.
- Phase 4a (inventory) must complete before 4b (PR).
- Phase 5 is gated on external team delivery (production certs); all other phases can proceed without it.
- Phase 6 is gated on Phase 5 complete (you cannot verify signatures you do not yet enforce).

---

## 5. Sandbox shortcuts retained vs. retired

| Shortcut | Sandbox status | Production replacement | Phase |
|----------|----------------|------------------------|-------|
| Ephemeral Windows self-signed cert | RETAINED (documented) | Production cert in encrypted secret | 5 |
| `|| true` on `osslsigncode verify` | RETAINED (explained inline) | Removed — hard fail on verify | 5 |
| Force-push to public mirror main | RETAINED (guarded post-Phase 1) | Fast-forward-only + manual approval env | 6 |
| `CROSS_REPO_TOKEN` optional sync | RETIRED Phase 1 (fail-loud) | Same + environment-scoped secret | Phase 1 / 4b |
| A9a: core `linuxdeploy` `continuous` tag | RETIRED Phase 1 (tag pinned + SHA256 verified) | Same | Phase 1 |
| A9b: `linuxdeploy-plugin-qt` `continuous` tag | BLOCKED on upstream — no dated release since `1-alpha-20250213-1` (Qt5.15 `mediaservice` crash on ubuntu-24.04) | Pin + SHA256 verify when upstream ships a newer dated tag | Phase 6 |
| Hard-coded version `"3.0.0"` in `ci.yml` | RETIRED Phase 1 | Same | Phase 1 |
| `enforce_admins: false` | RETAINED (sandbox bring-up) | `true` on production | Phase 5 |
| `required_signatures: false` | RETAINED | `true` on production | Phase 5 |
| No `SHA256SUMS` manifest | RETAINED | Full manifest + GPG sig | Phase 6 |
| No build provenance attestations | RETAINED | `attest-build-provenance` per installer | Phase 6 |
| No post-publish verification | RETAINED | Verification job in `release.yml` | Phase 6 |
| Missing governance files | RETIRED Phase 2 | Same (with team-ownership `CODEOWNERS`) | Phase 2 / 4b |
| Security scanning off | RETIRED Phase 2 | Same on production | Phase 2 / 4b |

The right-hand column is the contract: if a sandbox shortcut is not addressed in the listed phase before the first production release, that release is NOT authorized.

---

## 6. Risks & assumptions

1. **Assumes team-delivered production certs.** Phase 5 cannot start without them. If cert delivery slips, Phases 1-4 + 6a (public-mirror audit, runbook) can proceed; signature-integrity + stable-release capstone stall.
2. **Assumes team acceptance of the 4-platform matrix.** If the team wants additional targets (e.g., ARM Linux, legacy macOS), Phase 4b adds those workflows.
3. **Assumes `WSJTX/wsjtx-internal` remains the release-canonical repo.** If the team moves to publishing directly from `WSJTX/wsjtx`, Phase 4b's replication target shifts.
4. **Assumes GitHub-hosted runners remain adequate.** Self-hosted runners (for performance or for hardware-key-backed signing) change secret-scoping and network-isolation requirements.
5. **`actions/attest-build-provenance@v2`** (Phase 6) requires a GitHub Enterprise or organization plan; confirm availability on `WSJTX` before promising the feature.

---

## 7. Per-phase session count (estimate)

| Phase | Sessions | Notes |
|-------|----------|-------|
| 1 | 1 | Single cohesive PR |
| 2 | 1-2 | Settings + governance may split if the team wants review rounds |
| 3 | 1 | Both test tags in one session |
| 4a | 1 | Inventory document only |
| 4b | 1-2 | PR + settings-enable may split |
| 5 | 4 | One session per sub-item, each cert-gated |
| 6 | 5 | One per sub-item; E2E rc cut is the capstone |
| **Total** | **14-16** | Assuming no rework |

---

## 8. What this plan does NOT cover

- Production code-signing cert procurement (team-owned, separately ticketed).
- Apple Developer ID team-identity decisions (team-owned).
- Team's release cadence, version-numbering conventions, or backport policy.
- Migration of existing WSJT-X release history into the new tag convention (if desired).
- Cross-repo sync between `WSJTX/wsjtx` and `WSJTX/wsjtx-internal` (one-way mirror strategy — team-owned policy decision).
- Anything in `docs/consumer/` territory.

---

## 9. Verification of this plan

Before authorizing implementation, confirm:

- [ ] Each audit item (A0–A13) is addressed in at least one phase.
- [ ] Each phase has: deliverable, actions with evidence citations, completion criteria, verification commands, session boundary.
- [ ] Each sandbox shortcut is listed in §5 with its production retirement phase.
- [ ] Phase sequencing respects dependencies.
- [ ] Team has sign-off authority at: Phase 4a inventory (secrets/runners), Phase 5 kickoff (certs ready), Phase 6 capstone (first production release).

**Sign-off required before Phase 1 starts:** team agreement on the sandbox-vs-production policy in §1, and on the shortcut table in §5.
