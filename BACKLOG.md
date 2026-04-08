# Backlog

## Current Milestone: WSJT-X Team Onboarding

Contributor plan: `docs/contributor/CONTRIBUTION_PLAN.md`
Migration plan: `docs/contributor/MIGRATION_PLAN.md`
Risk analysis: `docs/consumer/GPL_COMPLIANCE_GAPS.md`
Governing principle: `docs/consumer/SYMBIOTIC_OPEN_SOURCE.md`

### Blocked (until v3.0.0 GA April 8)
- [ ] Phase 2: GitHub templates and guards — REVISED scope:
  - Bug template already exists (skip). Focus on: CONTRIBUTING.md, branch protection, close stale PR #1 / issue #1
  - **WRITE access granted 2026-04-04.** Waiting on GA only.
- [ ] Phase 3: CI/CD foundation — macOS (two-stage: Hamlib from github.com/Hamlib/Hamlib integration branch → WSJT-X)
- [ ] Phase 4: CI/CD expansion — Linux and Windows
- [ ] Phase 5: Release automation (GitHub Releases as new channel alongside SourceForge)

### Ready (no access needed)
- [ ] Gap 1 fix: Add corresponding source tarball to release workflow
- [ ] Phase 6: Upstream CMake patches — REVISED: superbuild patches have no GitHub target (SourceForge-only). WSJT-X source patches can PR to wsjtx-internal.
- [ ] Rebuild when v3.0.0 GA drops (April 8, 2026)

### Action items (non-code)
- [x] Email team: request WRITE access for KJ5HST on both repos — GRANTED 2026-04-04
- [ ] Email team: ask about Apple Developer account ownership (Gap #9, still unresolved)

### Done
- [x] ARM64 macOS native build — proven, working
- [x] GitHub Actions CI/CD for ARM build (this repo)
- [x] Code signing and notarization pipeline
- [x] Strategic contribution plan (6 phases)
- [x] Symbiotic open source doctrine (bi-directional firewall)
- [x] 14-gap compliance/risk analysis
- [x] WSJT-X GitHub org researched; team accounts identified
- [x] Two-layer architecture (superbuild vs raw source) documented
- [x] Hamlib fork situation analyzed
- [x] Hybrid integration architecture defined (shared memory input, UDP output)
- [x] GitHub invitation troubleshooting — instructions sent to Joe K1JT
- [x] Methodology bootstrap (SESSION_RUNNER, SAFEGUARDS, CLAUDE.md, docs/methodology/)
- [x] Phase 1: Repo audit — COMPLETE (Session 3). See `docs/contributor/REPO_AUDIT.md`
  - Superbuild: NOT on GitHub (SourceForge-only)
  - Hamlib: official GitHub repo, `integration` branch
  - Protocol docs: `Network/NetworkMessage.hpp`
  - v3.0.0 GA: April 8, 2026
  - Apple Developer account: unresolved (must ask team)
  - All team GitHub accounts identified
