# Backlog

## Current Milestone: WSJT-X Team Onboarding

Full plan: `docs/planning/WSJTX_TEAM_CONTRIBUTION_PLAN.md`
Risk analysis: `docs/planning/GPL_COMPLIANCE_GAPS.md`
Governing principle: `docs/SYMBIOTIC_OPEN_SOURCE.md`

### Blocked
- [ ] Phase 1: Repo audit (wsjtx + wsjtx-internal) — **blocked on GitHub invitation**
  - Find the superbuild (wsjtx-internal?)
  - Resolve Hamlib fork location and status
  - Map branching strategy and release process
  - Identify who owns the Apple Developer account (Gap #9)
  - Check for existing protocol documentation (Gap #2/12)

### Ready (no access needed)
- [ ] Gap 1 fix: Add corresponding source tarball to release workflow
- [ ] Phase 6: Upstream CMake patches (can work locally, post-GA)
- [ ] Rebuild when v3.0.0 GA drops

### Up Next (after Phase 1)
- [ ] Phase 2: GitHub templates and guards
- [ ] Phase 3: CI/CD foundation — macOS (two-stage: Hamlib → WSJT-X)
- [ ] Phase 4: CI/CD expansion — Linux and Windows
- [ ] Phase 5: Release automation

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
