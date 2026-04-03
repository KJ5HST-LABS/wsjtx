# CLAUDE.md

## SESSION PROTOCOL — FOLLOW BEFORE DOING ANYTHING

**Read and follow `SESSION_RUNNER.md` step by step.** It is your operating procedure for every session. It tells you what to read, when to stop, and how to close out.

**Three rules you will be tempted to violate:**
1. **Orient first** — Read SAFEGUARDS.md → SESSION_NOTES.md → run `methodology_dashboard.py` → git status → report findings → WAIT FOR THE USER TO SPEAK
2. **1 and done** — One deliverable per session. When it's complete, close out. Do not start the next thing.
3. **Auto-close** — When done: evaluate previous handoff, self-assess, document learnings, write handoff notes, commit, report, STOP.

`SESSION_RUNNER.md` documents known failure modes and their countermeasures. The protocol compensates for documented tendencies to skip orientation, skip close-out, and continue past the deliverable.

## Project Overview

WSJT-X ARM64 macOS native build project. Produces signed, notarized `.pkg` installers for Apple Silicon Macs.

### Key Context
- **Governing doctrine:** `docs/SYMBIOTIC_OPEN_SOURCE.md` — read before any cross-project decision
- **Contribution plan:** `docs/planning/WSJTX_TEAM_CONTRIBUTION_PLAN.md` — 6-phase plan for WSJT-X team
- **Risk analysis:** `docs/planning/GPL_COMPLIANCE_GAPS.md` — 14-gap compliance/risk analysis
- **Build pipeline:** `.github/workflows/build.yml` — GitHub Actions CI/CD (uses superbuild)

### Architecture
- Two-layer build: superbuild (wsjtx-superbuild) wraps raw source (wsjtx)
- Hybrid integration with rad-con: shared memory for audio input, UDP for decode output
- FT8 15-second cycle creates hard real-time constraint

### Safety
- `.p12` files in repo root are signing certificates — NEVER commit them
- GPL boundary with rad-con is foundational — see symbiotic doctrine before any changes
