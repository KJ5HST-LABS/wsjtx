# Session Notes

## ACTIVE TASK
**Task:** Accept WSJT-X org invitation; monitor for v3.0.0 GA release; begin Phase 1 repo audit when access arrives
**Status:** Blocked — waiting on GitHub invitation (instructions sent to Joe K1JT)
**Session:** 1 complete
**Started:** 2026-04-02

---

### What Session 1 Did
**Deliverable:** Strategic contribution plan + compliance/risk analysis — COMPLETE
**Started:** 2026-04-02
**Status:** All documents written and committed.

**What was produced:**

1. `docs/planning/WSJTX_TEAM_CONTRIBUTION_PLAN.md` — 6-phase plan for contributing to WSJT-X team. Includes two-layer architecture analysis, Hamlib fork situation, dependency chain, team GitHub accounts, and all technical findings.

2. `docs/SYMBIOTIC_OPEN_SOURCE.md` — Foundational doctrine governing the relationship between rad-con (commercial) and WSJT-X (GPL). Covers legal boundary (GPL copyleft), architectural boundary (subprocess IPC), white room discipline (bi-directional firewall), recusal protocol, and long-term funding vision. **This document must be read before any cross-project decision.**

3. `docs/planning/GPL_COMPLIANCE_GAPS.md` — 14-gap analysis across legal, technical, social, strategic, and operational dimensions:
   - Gap 1: GPL Corresponding Source — must ship patched source with binaries (NEEDS IMPLEMENTATION)
   - Gap 2: Hybrid architecture — shared memory for audio input, UDP for decode output (REFINED)
   - Gap 3: Trademark — nominative fair use rules for referencing WSJT-X (RESOLVED)
   - Gap 4: One-person firewall — 5 structural mitigations (RESOLVED)
   - Gap 5: API stability — UDP + adapter layer + integration tests (RESOLVED)
   - Gap 6: Apple JIT entitlements — existential risk to ARM builds, Flang as future fix (MONITOR)
   - Gap 7: Qt5 EOL — keep CI flexible, help if asked (MONITOR)
   - Gap 8: Project continuity — architecture already favors resilience (ACKNOWLEDGED)
   - Gap 9: Secret management — team answers trust questions in Phase 1 (PHASE 1)
   - Gap 10: Recusal protocol — disclosure over recusal (RESOLVED)
   - Gap 11: CLA risk — don't sign without legal review (MONITOR)
   - Gap 12: Copyright on protocol specs — team asserts copyright on specs AND algorithms (ACKNOWLEDGED)
   - Gap 13: Competition perception — lead with infrastructure, credit, fund (ACKNOWLEDGED)
   - Gap 14: v3.0.0 GA timing — imminent release triggers build update and Phase 1 (MONITORING)

4. `SESSION_NOTES.md` + `BACKLOG.md` — methodology bootstrapped for this project

5. Memory entries: team membership, GitHub org state, user profile, symbiotic doctrine pointer

**Key discoveries:**
- GitHub repo is raw source (not superbuild) — changes all CI/CD planning
- Superbuild still points to BitBucket/SourceForge — stale URLs
- Hamlib fork (Bill Somerville, G4WJS) is the central dependency management challenge
- John G4KLA already does ARM builds — our value is automation, not binaries
- FT8 15-second cycle creates hard real-time constraint requiring shared memory for audio input
- Team asserts copyright on protocol specifications, not just code
- Hybrid architecture (shared memory input, UDP output) driven by physics, not preference

**What's next:**
1. Accept GitHub invitation when it arrives
2. Monitor for v3.0.0 GA release — rebuild when it drops
3. **Phase 1: Repo audit** — requires org access
4. **Phase 6: Upstream patches** — can start locally (no access needed)
5. **Gap 1 fix** — add corresponding source tarball to release workflow

**Key files (MUST READ before next session):**
- `docs/SYMBIOTIC_OPEN_SOURCE.md` — foundational doctrine
- `docs/planning/WSJTX_TEAM_CONTRIBUTION_PLAN.md` — contribution plan
- `docs/planning/GPL_COMPLIANCE_GAPS.md` — 14-gap risk analysis
- `.github/workflows/build.yml` — proven CI/CD pipeline (uses superbuild, not raw source)
- `wsjtx-3.0.0-rc1/CMakeLists.txt:69` — BitBucket URL (stale)
- `wsjtx-build/wsjtx-prefix/src/wsjtx/commons.h` — shared memory struct (80+ fields)
- `wsjtx-build/wsjtx-prefix/src/wsjtx/Network/NetworkMessage.hpp` — UDP protocol (documented, stable)

**Gotchas for next session:**
- The contribution plan was revised mid-session after discovering the two-layer architecture. Read the CURRENT version, not from memory.
- Gap #2 evolved significantly: started as "use UDP only," then "hybrid after audio constraint," then complicated by Gap #12 (copyright on protocol specs). Read the full chain.
- The `.p12` files in the repo root are signing certificates. NEVER commit them.
- v3.0.0 GA is imminent. Check if it's been released before starting any phase.

**Self-assessment:**
- (+) Extraordinarily thorough risk analysis — 14 gaps across every dimension
- (+) Symbiotic doctrine is strong and principled, with bi-directional firewall
- (+) Key technical discoveries (two-layer architecture, shared memory struct, copyright on specs) fundamentally shape the approach
- (+) Hybrid architecture decision driven by real physics (FT8 timing), not theory
- (+) Each gap has a clear status and resolution path
- (-) Session scope expanded well beyond original deliverable (plan → plan + doctrine + 14-gap analysis). Justified by the significance of the work, but the methodology says one deliverable. Counter-argument: the user directed each expansion.
- (-) Gap #2 went through three revisions as understanding deepened. The document is correct now but the revision history shows initial analysis was incomplete.
- Score: 9/10

**Previous session handoff evaluation:** N/A — this is Session 1.
