# Consumer Strategy — WSJTX-ARM Pipeline & rad-con Integration

**Status:** Active
**Scope:** How the WSJT-X project's GitHub migration and CI/CD buildout affect our consumer pipeline and rad-con integration

---

## Persona Framework

This repository operates under two distinct personas:

### Open Source Contributor
- Works on WSJTX org repos (`WSJTX/wsjtx`, `WSJTX/wsjtx-internal`)
- Never mentions rad-con, consumer agenda, or AI tooling in documentation, commits, or messaging
- All documentation lives in `docs/contributor/`
- Motivation framed exclusively as helping the open source project

### Open Source Consumer
- Works in this repo (`KJ5HST-LABS/WSJT-X-MAC-ARM64`) and local directories
- Can reference contributor knowledge freely (it's public open source work)
- All documentation lives in `docs/consumer/`
- Manages the commercial/integration relationship

### Information Flow Rule
**Contributor → Consumer: OPEN.** Consumer docs can reference contributor work, audit findings, CI/CD plans.
**Consumer → Contributor: NEVER.** Contributor docs, commits, PRs, and communications must never reference rad-con, this repo's commercial purpose, consumer strategy, or AI tooling.

---

## How the Migration Affects Our Pipeline

### Current State
Our `build.yml` downloads the SourceForge superbuild tarball, patches it for CMake 4.x, builds, signs, notarizes, and publishes. This works but depends on SourceForge hosting.

### When Org CI/CD Exists
Once CI/CD is running on the WSJTX org repos (see `docs/contributor/MIGRATION_PLAN.md`), several things change for us:

1. **Source availability:** We can switch from SourceForge tarballs to GitHub source. This eliminates the SourceForge dependency and gives us access to the latest code via git.

2. **Build approach:** Our pipeline currently uses the superbuild. The org's CI/CD will use the two-stage approach (Hamlib → WSJT-X). We should align our pipeline with the same approach so there's one proven build method, not two.

3. **Official releases on GitHub:** If the team adopts GitHub Releases, the official project may produce signed macOS builds. Our repo's role shifts from "the only ARM macOS build" to "an independent distribution with our own signing identity." This is fine — our repo was always meant to be independent per the symbiotic doctrine.

4. **Version tracking:** With GitHub Releases on the org, we can automate version detection. A workflow_dispatch or schedule trigger can check for new tags and rebuild.

### Pipeline Updates Needed

| Trigger | What to Update | Priority |
|---------|---------------|----------|
| v3.0.0 GA drops (April 8) | Update `WSJTX_VERSION` in build.yml, rebuild and release | High |
| Org CI/CD workflow merged | Align our build approach with the org's two-stage method | Medium |
| Superbuild moves to GitHub | Switch source download from SourceForge to GitHub | Medium |
| Team publishes GitHub Releases | Evaluate whether our releases are still needed | Low |
| Qt5 removed from Homebrew | Build Qt5 from source or switch to Qt6 | Future |

---

## KJ5HST-LABS Signing Credentials

### Current Setup
This repo uses KJ5HST-LABS Apple Developer ID certificates:
- `DEVELOPER_ID_CERTIFICATE_P12` — Application signing
- `DEVELOPER_ID_INSTALLER_P12` — Installer signing
- `APPLE_ID` / `APPLE_ID_PASSWORD` / `APPLE_TEAM_ID` — Notarization

### Relationship to Org CI/CD
The contributor migration plan proposes CI/CD for the org repos. Code signing in the org requires the team's own credentials, not ours. The separation:

| Context | Signing Identity | Managed By |
|---------|-----------------|------------|
| This repo (KJ5HST-LABS) | KJ5HST-LABS Developer ID | Us |
| WSJTX org repos | Team's Developer ID (TBD) | Team |

**Rule:** KJ5HST-LABS credentials are never configured in the WSJTX org repos. The org gets its own identity. We document the secret names and formats in the contributor workflow; the team configures the actual values.

**Demo option:** If the team wants to see the pipeline work before providing their own certs, we can temporarily use KJ5HST-LABS certs with explicit understanding that binaries will be signed as "KJ5HST-LABS" and our certs will be removed once theirs are configured. This requires team permission.

---

## rad-con Integration Implications

### Architecture Decision (from GPL_COMPLIANCE_GAPS.md)
rad-con uses a hybrid integration architecture:
- **Input (audio → decoder):** Shared memory — required by FT8's 15-second real-time constraint
- **Output (decode results → rad-con):** UDP — lowest latency, clean protocol boundary

### How the Migration Affects rad-con

1. **Decoder binaries:** rad-con downloads pre-built decoders from this repo's GitHub Releases. This dependency is unaffected by the org migration — our repo remains independent.

2. **UDP protocol stability:** The org migration doesn't change the UDP protocol. The protocol is documented in `NetworkMessage.hpp` and has explicit backward compatibility rules. Multiple third-party apps depend on it.

3. **Shared memory interface:** If the team publishes a standalone shared memory protocol spec (proposed in GPL_COMPLIANCE_GAPS.md Gap #2), that benefits rad-con's clean-room implementation. But this is a contributor-side proposal that must pass the litmus test — it benefits all third-party integrators, not just rad-con.

4. **Version compatibility:** When v3.0.0 GA drops, the shared memory struct (`dec_data_t`) is locked as the baseline. rad-con integration work targets this version.

### Public-Only Policy
rad-con architectural decisions, feature planning, and integration design are based exclusively on:
- The public GitHub repo (`WSJTX/wsjtx`)
- The published UDP protocol documentation (`NetworkMessage.hpp`)
- The user guide
- Released binaries

Information from wsjtx-internal, team emails about unreleased features, or private development discussions is off-limits for rad-con purposes.

---

## Consumer-Side Action Items

### Immediate (Now → April 8)
- [ ] Prototype switching build.yml from SourceForge tarball to two-stage GitHub source build
- [ ] Prepare to rebuild when v3.0.0 GA drops

### Post-GA (April 8+)
- [ ] Update `WSJTX_VERSION` and rebuild
- [ ] Add corresponding source tarball to releases (GPL compliance, Gap #1)
- [ ] Evaluate whether CMake 4.x patches are still needed in GA

### Medium-term
- [ ] Align our build approach with the org's CI/CD method (when it exists)
- [ ] Monitor Qt5 availability in Homebrew
- [ ] Test Flang as alternative Fortran compiler (Gap #6)

### Ongoing
- [ ] Maintain temporal separation between contributor and consumer sessions
- [ ] Document public source for any rad-con feature touching WSJT-X integration
- [ ] Keep KJ5HST-LABS credentials separate from any org credentials

---

## Key Consumer Documents

| Document | Purpose |
|----------|---------|
| `docs/consumer/SYMBIOTIC_OPEN_SOURCE.md` | GPL boundary doctrine, white room principle, legal/ethical framework |
| `docs/consumer/GPL_COMPLIANCE_GAPS.md` | 14-gap risk analysis (legal, technical, social, strategic, operational) |
| `docs/consumer/CONSUMER_STRATEGY.md` | This document — pipeline impact, cert strategy, integration implications |
| `.github/workflows/build.yml` | The working consumer pipeline |
| `entitlements.plist` | JIT entitlements for Fortran runtime (Gap #6) |
