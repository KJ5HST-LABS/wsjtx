# CLAUDE.md

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
