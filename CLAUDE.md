# CLAUDE.md

## MISSION — READ BEFORE ANYTHING ELSE

**This is a dual-purpose repo.** Failing to recognize the duality has been the repeated source of drift.

**Primary (consumer):** `KJ5HST-LABS/wsjtx-internal` is rad-con's arm64 macOS build pipeline. It produces signed+notarized `.pkg` installers that rad-con consumes as its WSJT-X dependency. Releases ship from here. This is operational — see `gh release list`.

**Secondary (contributor working area):** This is also where Terrell drafts Phase 1-5 plans (`docs/contributor/`) and iterates the CI/CD workflows that will later be **replicated** to `WSJTX/wsjtx-internal`. Replication is a hand-off to the team — not PRs from the sandbox, not adoption executed by Terrell.

### The two upstream repos (don't conflate)
- `WSJTX/wsjtx-internal` (private) — active dev, default `develop`. This is where the proven machinery gets replicated. Phase 6 patches Terrell authors target here (`develop`).
- `WSJTX/wsjtx` (public) — release-facing, default `master`, stale since Feb 2025. Receives source + tags + GitHub Release artifacts from internal at release time (one-way sync). External contributors fork here.

### Scope of Terrell's work
1. **Sandbox pipeline proof** — finish the 4-platform release workflow so packaging/signing/gate work end-to-end (currently blocked on #22/#23/#24/#25).
2. **Phase 6 upstream patches Terrell authors** — drafted and opened directly against `WSJTX/wsjtx-internal → develop`, not staged in this sandbox.

### NOT Terrell's work (do not put these on any "still to do" list)
- Team's own housekeeping (stale PRs/issues on their repos, typo branches, "IMPROVED" branding)
- Adoption of proven machinery (when/how the team replicates workflows, enables branch protection, adopts CONTRIBUTING.md)
- Release-operational resources on the team side (production Windows code-signing cert, Apple Team ID selection, secret provisioning)
- Superbuild / SourceForge decisions

**Sandbox vs. upstream.** The sandbox has a real consumer (rad-con). "Sandbox has no consumers" is wrong — the arm64 macOS `.pkg` IS shipped. What the sandbox does NOT do is ship releases to the general WSJT-X user base; that's upstream's job after replication.

**Fabricated blockers.** Do not treat team-owned operational resources (production certs) or upstream release policies (all-platforms-ready gate as policy) as sandbox blockers. Sandbox proves the machinery (can the pipeline sign? can the gate evaluate?), not the production resource acquisition.

**"Serve, don't preach"** per `docs/contributor/CONTRIBUTION_PLAN.md:40`. Working infrastructure speaks; a to-do list for the team is preaching.

---

## SESSION PROTOCOL — FOLLOW BEFORE DOING ANYTHING

**Read and follow `SESSION_RUNNER.md` step by step.** It is your operating procedure for every session. It tells you what to read, when to stop, and how to close out.

**Three rules you will be tempted to violate:**
1. **Orient first** — Read SAFEGUARDS.md → SESSION_NOTES.md → run `python3 /Users/terrell/Documents/code/wsjtx-arm/methodology_dashboard.py` (project-local, absolute path — never the portfolio-level script) → git status → report findings → WAIT FOR THE USER TO SPEAK
2. **1 and done** — One deliverable per session. When it's complete, close out. Do not start the next thing.
3. **Auto-close** — When done: evaluate previous handoff, self-assess, document learnings, write handoff notes, commit, report, STOP.

`SESSION_RUNNER.md` documents known failure modes and their countermeasures. The protocol compensates for documented tendencies to skip orientation, skip close-out, and continue past the deliverable.

## Project Overview

WSJT-X ARM64 macOS native build project. Produces signed, notarized `.pkg` installers for Apple Silicon Macs.

### Key Context
- **Contributor docs:** `docs/contributor/` — contribution plan, repo audit, migration plan (never reference consumer context here)
- **Consumer docs:** `docs/consumer/` — symbiotic doctrine, GPL compliance gaps, consumer strategy
- **Persona rule:** Contributor persona never mentions rad-con, consumer agenda, or AI tooling. Consumer can reference contributor work freely.
- **Build pipeline:** `.github/workflows/build.yml` — GitHub Actions CI/CD (uses superbuild)

### Architecture
- Two-layer build: superbuild (wsjtx-superbuild) wraps raw source (wsjtx)
- Hybrid integration with rad-con: shared memory for audio input, UDP for decode output
- FT8 15-second cycle creates hard real-time constraint

### Safety
- `.p12` files in repo root are signing certificates — NEVER commit them
- GPL boundary with rad-con is foundational — see `docs/consumer/SYMBIOTIC_OPEN_SOURCE.md` before any changes

## Backlog & Issues

Use **GitHub Issues** for backlog items, bugs, and cross-project coordination. Do not use BACKLOG.md — it has been migrated to GitHub Issues.

- View issues: `gh issue list`
- Create issue: `gh issue create --title "..." --body "..."`
- Cross-project issues: use the target repo's issue tracker
