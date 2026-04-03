# Compliance, Risk, and Governance Analysis

**Context:** This repository distributes GPL-3.0 licensed binaries and its maintainer participates in the WSJT-X development team while building a commercial product (rad-con). This document analyzes the legal, technical, social, strategic, and operational risks across that boundary.

**Governing doctrine:** `docs/SYMBIOTIC_OPEN_SOURCE.md`

## Summary

| # | Gap | Category | Status | Action Required |
|---|-----|----------|--------|-----------------|
| 1 | GPL Corresponding Source obligation | Legal | Needs implementation | Add source tarball to releases |
| 2 | Shared memory + UDP hybrid architecture | Legal/Technical | Refined | Shared mem input, UDP output. Propose protocol spec to team. |
| 3 | Trademark usage | Legal | Resolved | Follow nominative fair use rules |
| 4 | One-person firewall | Organizational | Resolved | 5 structural mitigations defined |
| 5 | API stability with no SLA | Technical | Resolved | UDP + adapter layer + tests |
| 6 | Apple JIT entitlement fragility | Technical | Monitor | Test Flang periodically; flag to team |
| 7 | Qt5 end of life | Technical | Monitor | Keep CI Qt-version-flexible |
| 8 | Project continuity risk | Strategic | Acknowledged | Architecture already favors resilience |
| 9 | Secret management for org CI/CD | Operational | Phase 1 | Team answers trust questions |
| 10 | Recusal protocol | Governance | Resolved | Disclosure over recusal |
| 11 | CLA risk | Governance | Monitor | Don't sign without legal review |
| 12 | Copyright claim on protocol specs | Legal/IP | Acknowledged | Respect intent; frame spec publication as serving the team |
| 13 | Competition perception | Social | Acknowledged | Lead with infrastructure; credit prominently; deliver funding |
| 14 | v3.0.0 GA release timing | Operational | Monitoring | Timing trigger for build update, audit, and patches |

---

## 1. Corresponding Source (GPL-3.0 Section 6)

### The Obligation

When distributing object code (binaries), GPL-3.0 requires providing access to the "Corresponding Source" — defined as the source code needed to generate, install, and run the object code, including scripts to control those activities (i.e., build scripts), modification installation information, and any patches applied.

### Current State

Our CI/CD pipeline:
1. Downloads `wsjtx-{version}.tgz` from SourceForge
2. Applies a `sed` patch to the superbuild CMakeLists.txt (two target name renames for CMake 4.x compatibility)
3. Passes `CMAKE_OSX_DEPLOYMENT_TARGET=11.0` as a build flag
4. Builds and publishes binaries to GitHub Releases

The SourceForge tarball is publicly available, but our binaries are built from a **modified** version of it. The sed patch changes the source. We distribute binaries without providing the exact source that produced them.

### Compliance Method

GPL-3.0 Section 6a: accompany the object code with the Corresponding Source.

**Resolution:** Add a workflow step that:
1. After patching but before building, creates a tarball of the complete source tree as it exists at build time
2. Attaches this `wsjtx-{version}-arm64-source.tgz` to the GitHub Release alongside the binaries
3. Includes the build.yml workflow itself (it is a "script used to control compilation and installation")

This provides anyone who downloads our binaries the exact source and build instructions needed to reproduce them.

### Implementation

Add to `build.yml` after the patch step, before configure:

```yaml
- name: Package corresponding source
  run: |
    tar czf "wsjtx-${WSJTX_VERSION}-arm64-source.tgz" \
      "wsjtx-${WSJTX_VERSION}/" \
      entitlements.plist
```

And attach to both releases alongside the binaries.

### Status: NEEDS IMPLEMENTATION (Phase 6 or standalone session)

---

## 2. Shared Memory Protocol vs. UDP — Integration Architecture

### The Two Interfaces

WSJT-X exposes two completely different IPC mechanisms:

#### A. Shared Memory (`commons.h` / `dec_data_t` struct)
- **Purpose:** Internal interface between the WSJT-X GUI process and the jt9 decoder subprocess
- **Defined in:** `commons.h` (C struct), `lib/jt9com.f90` (Fortran common block), `lib/shmem.cpp` (Qt wrapper)
- **Implementation:** POSIX/Qt shared memory (`QSharedMemory`), keyed by instance name
- **Nature:** Tightly coupled to Fortran internals. Contains raw audio samples (`d2[]`), spectral data (`ss[]`, `savg[]`), and dozens of decoder parameters that mirror the GUI state. The struct comment says: *"This structure is shared with Fortran code, it MUST be kept in sync with lib/jt9com.f90"*
- **Stability:** Version-specific. v3.0.0 added ~30 new fields vs. v2.x. No backward compatibility mechanism.
- **Designed for:** Internal use only. Not a public API.

#### B. UDP Network Protocol (`NetworkMessage.hpp`)
- **Purpose:** External integration interface for third-party applications
- **Defined in:** `Network/NetworkMessage.hpp` — extensively documented with field-level specifications
- **Implementation:** UDP datagrams using QDataStream serialization, schema-negotiated
- **Nature:** Clean message-based protocol. Message types include Heartbeat, Status, Decode, Clear, QSOLogged, Close, Replay, HaltTx, FreeText, WSPRDecode, Location, LoggedADIF, HighlightCallsign, SwitchConfiguration, Configure.
- **Stability:** Explicit backward compatibility rules documented in the header:
  - New message types may be added; unknown types are silently ignored
  - New fields are appended to existing messages; existing fields never change
  - Schema negotiation handles encoding version differences
- **Designed for:** Third-party applications. JTAlert, GridTracker, and many others use this protocol. It is the explicitly intended external integration point.

### GPL Implications

**Shared memory struct:** The `dec_data_t` struct definition lives in `commons.h`, which is GPL source. If rad-con implements a compatible shared memory interface by reading this struct definition, that implementation arguably derives from GPL source. The struct is not a published API — it's an internal implementation detail. Using it would:
- Create tight coupling to a GPL internal interface
- Require tracking every struct change across WSJT-X versions
- Risk the argument that rad-con's shared memory code is a derivative work

**UDP protocol:** The `NetworkMessage.hpp` header is also GPL source, but the protocol it defines is explicitly designed as a public interface for third-party integration. Multiple non-GPL applications (JTAlert is closed-source) already use this protocol. The protocol specification — message types, field definitions, serialization rules — is documented as a wire format. Implementing a UDP client from the protocol specification is the same as implementing an HTTP client from the HTTP RFC. The protocol is the interface; the implementation is independent.

Post-*Oracle v. Google* (2021), the Supreme Court held that reimplementing an API for interoperability is fair use. The UDP protocol is the published, intended, explicitly-documented integration API. The shared memory struct is not.

### Decision

**rad-con must use the UDP Network Protocol, not shared memory.**

This means:
- rad-con communicates with a running WSJT-X instance (or any WSJT-X-compatible application)
- rad-con does NOT launch jt9/wsprd directly as subprocesses
- The integration pattern is: WSJT-X handles decoding and exposes results via UDP; rad-con consumes UDP messages for display, logging, and radio control integration
- rad-con's UDP client is implemented from the protocol specification, not by copying GPL code

**Wait — this changes the dependency chain.** If rad-con talks to WSJT-X via UDP rather than launching decoders directly, then:
- rad-con does not need to distribute GPL binaries at all
- The user runs WSJT-X themselves (their copy, their license)
- rad-con connects to it over UDP like any other third-party application
- This repo's standalone decoder builds serve the amateur radio community, not rad-con specifically

This is actually a **cleaner architecture** than the subprocess model. It eliminates the GPL distribution question entirely for rad-con. rad-con never touches GPL code — not in source, not in binaries, not in distribution. It talks to a user-installed application over a documented network protocol.

**However:** If rad-con wants to offer a self-contained experience where the user doesn't need to install WSJT-X separately, the subprocess model with standalone decoders is still valuable. In that case:
- This repo distributes the GPL decoders (with corresponding source per Gap #1)
- rad-con downloads them at runtime as a separate, optional component
- The user explicitly consents to downloading GPL software
- rad-con launches them as subprocesses and communicates via shared memory or command-line arguments
- The shared memory interface would need a clean-room implementation

### Updated Analysis: The Hybrid Architecture (Input/Output Split)

The initial recommendation to use UDP-only was incorrect. FT8's 15-second cycle creates a hard real-time constraint:

```
|-- 15 second cycle --|
| RX (audio capture) | decode | decide + TX |
|     ~12.6s         | ~1-2s  |  remaining  |
```

Every millisecond between "decode complete" and "user sees result" is time stolen from the decision window. The current rad-con implementation has a known performance complaint: by the time decode results arrive and the user decides, they've missed the cycle window.

**The architecture must be a hybrid:**

- **Input (audio → decoder): Shared memory.** Unavoidable. Raw 12kHz audio samples cannot be streamed through UDP with the latency and bandwidth requirements of real-time decoding. This is the same mechanism WSJT-X uses with jt9.

- **Output (decode results → rad-con): UDP.** Ideal. Decode results are small discrete messages. UDP is lowest-latency (no connection overhead). Results can stream as they're produced during the decode window, giving the user maximum decision time before the next TX cycle.

```
rad-con (captures audio from radio/sound card)
  │
  │  shared memory: write audio → d2[], set params, signal via ipc[]
  ▼
jt9 (reads shared memory, decodes signals)
  │
  │  UDP: decode results stream back as produced
  ▼
rad-con (displays results, user decides, triggers TX before cycle ends)
```

### Clean-Room Scope (Revised)

The shared memory interface has three components with different clean-room complexity:

**1. Audio buffer (`d2[]`) — TRIVIAL to clean-room**
A contiguous array of 16-bit signed integers at 12kHz sample rate. The format is defined by physics and DSP convention, not by creative expression in source code. Any audio DSP engineer would define it the same way.

**2. IPC signaling (`ipc[3]`) — STRAIGHTFORWARD to clean-room**
A three-integer signaling mechanism: "new data ready," "decoding in progress," "decode complete." The semantics are observable from runtime behavior (monitor the integers while jt9 runs). The specific integer values and state transitions can be documented empirically.

**3. Decoder parameters (`params` struct) — DIFFICULT**
80+ fields controlling decode behavior: frequency limits (`nfa`, `nfb`), mode (`nmode`), period (`ntrperiod`), depth (`ndepth`), submode (`nsubmode`), plus v3.0.0 additions for threading, sensitivity, and FT8 enhancements. These field names, types, memory offsets, and semantics are defined in GPL source (`commons.h`, `lib/jt9com.f90`). Clean-rooming this requires documenting each parameter's purpose and memory layout from observable behavior or published documentation — not from reading the struct definition.

### Resolution Path: Published Protocol Specification

**The most symbiotic resolution is Option 2 from the original analysis: ask the WSJT-X team to publish the shared memory protocol as a standalone specification.**

This serves the entire ecosystem:
- JTAlert, GridTracker, and other third-party apps face the same GPL interface question
- A published spec enables any application to drive the decoders without GPL entanglement
- It's a legitimate contribution to the project — protocol documentation is universally valuable
- It passes the litmus test cleanly: a contributor with no commercial interest would still want this

**Proposed approach:**
1. During Phase 1 (repo audit), identify if any protocol documentation already exists
2. If not, propose writing a shared memory protocol specification as a contribution to WSJT-X documentation
3. The spec would be published under the project's documentation license (or CC-BY or similar)
4. Implementing from a published spec is the same as implementing HTTP from the RFC — legally clean

**If the team declines to publish a spec:**
- Fall back to clean-room implementation based on observable behavior
- Document the empirical methodology rigorously
- Accept that the parameter struct will require significant reverse-engineering effort

### Status: DECISION REFINED — hybrid architecture (shared memory input, UDP output). Propose protocol spec publication during Phase 1. Clean-room as fallback.

---

## 3. Trademark Usage

### Findings

"WSJT" and "WSJT-X" do **not appear to be registered trademarks** with the USPTO. The project publishes no trademark policy, displays no TM or (R) symbols, and has no usage guidelines. Common-law trademark rights likely exist by virtue of 25 years of use in the amateur radio community, but enforcement risk is negligible.

The GPL-3.0 license grants zero trademark rights (it's a copyright license only). Section 7(e) allows projects to explicitly disclaim trademark grants, but WSJT-X hasn't invoked this.

### Nominative Fair Use

Under *New Kids on the Block v. News America Publishing* (9th Cir., 1992), a third party may use another's mark when:
1. The product can't be identified without the mark — satisfied (no generic term for "WSJT-X decoders")
2. Only as much of the mark is used as necessary — satisfied by descriptive phrasing
3. Nothing suggests endorsement by the mark holder — the critical constraint

### Rules for rad-con

**Safe phrasing:**
- "Compatible with WSJT-X"
- "Supports WSJT-X decoders"
- "Works with WSJT-X digital modes"

**Unsafe phrasing:**
- "Powered by WSJT-X" (implies endorsement)
- "Official WSJT-X companion" (implies affiliation)
- "rad-con for WSJT-X" (incorporates the mark into product identity)
- Any use of WSJT-X logos or stylized marks

**Best practice disclaimer:** Include in documentation and/or About screen:
> "WSJT-X is an open-source project by Joe Taylor, K1JT, and the WSJT Development Team. rad-con is not affiliated with or endorsed by the WSJT-X project."

**Additional consideration:** Since Terrell is now a member of the WSJT-X development team, the line between "not affiliated" and "affiliated" gets complicated. The disclaimer should be factually accurate — Terrell contributes to WSJT-X, but rad-con as a product is independent. Consider: "Terrell Galyon (KJ5HST) contributes to the WSJT-X project independently. rad-con is a separate commercial product not endorsed by the WSJT-X project."

### Status: RESOLVED — follow the rules above. Revisit if the team publishes a trademark policy.

---

## 4. The One-Person Firewall

### The Problem

The white room concept (see `docs/SYMBIOTIC_OPEN_SOURCE.md`) assumes organizational separation — different teams, different buildings, different information access. In practice, Terrell is one person on both sides of the wall:

- He has access to wsjtx-internal (unreleased features, protocol changes, development discussions)
- He is building rad-con (a commercial product that integrates with WSJT-X)
- He cannot unsee what he has seen

Self-imposed discipline is inherently more fragile than structural separation. A single person maintaining a firewall has no one to check their reasoning when a boundary case arises.

### Why This Matters

If rad-con ever ships a feature that appears to anticipate an unreleased WSJT-X change, the open source community will notice. Even if the feature was independently conceived, the perception of information leakage destroys trust — and trust, once lost in open source, is nearly impossible to rebuild.

Conversely, if a rad-con innovation appears in a WSJT-X contribution shortly after rad-con implements it, that looks like commercial IP being donated to undercut competitors or establish market position.

### Structural Mitigations

These are not aspirational — they are operational requirements:

1. **Temporal separation.** WSJT-X contribution work and rad-con development work do not happen in the same session. The methodology already enforces single-deliverable sessions. Extend this: a session is either WSJT-X or rad-con, never both. Context switching between them within a working day is acceptable, but within a single Claude Code session it is not.

2. **Public-only policy for rad-con.** All rad-con architectural decisions, feature planning, and integration design must be based exclusively on publicly available WSJT-X information: the public GitHub repo, the published UDP protocol documentation, the user guide, and released binaries. Information from wsjtx-internal, team emails about unreleased features, or private development discussions is off-limits for rad-con purposes — even if Terrell has already read it.

3. **Documentation trail.** For any rad-con feature that touches WSJT-X integration:
   - Document the public source of the information used (URL, document, release version)
   - Date the decision
   - If the feature could be perceived as deriving from non-public WSJT-X knowledge, document the independent origin explicitly

4. **Proactive disclosure.** If a situation arises where the firewall is strained — where Terrell learns something in a WSJT-X context that would materially benefit rad-con — document the conflict immediately and abstain from using that knowledge in rad-con until it becomes public. The documentation itself is the protection.

5. **The methodology as structural enforcement.** Each project has its own repository, its own SESSION_NOTES.md, its own BACKLOG.md. The Iterative Session Methodology's single-deliverable rule naturally prevents cross-project bleed within sessions. This isn't an accident — it's a feature of the methodology being applied correctly.

### Limitations

No structural mitigation fully solves the one-person problem. Terrell will know things. He will have context from both sides. The mitigations above create a paper trail and enforce temporal separation, but they rely on discipline.

The ultimate protection is the same thing Terrell offered the team from day one: transparency. If someone asks "how did rad-con know about this?" the answer must be traceable to a public source, and the documentation trail must exist to prove it.

### Status: RESOLVED — mitigations defined. Operational discipline required from session 1 forward.

---

## 5. API Stability — No SLA, No Guarantee

### The Problem

rad-con depends on WSJT-X's interfaces — at minimum the UDP protocol, and potentially shared memory or command-line conventions. There is no stability guarantee, no versioned API contract, no SLA.

The UDP protocol header (`NetworkMessage.hpp`) does document backward compatibility rules:
- New message types may be added; unknown types must be silently ignored
- New fields are appended to existing messages; existing fields never change
- Schema negotiation handles encoding version differences

This is better than nothing — it's an explicit compatibility contract for the UDP interface. But it's a convention documented in a source code comment, not a formal API promise. A future developer could break it.

The shared memory interface (`commons.h`) has no such convention. v3.0.0 added ~30 fields to the `dec_data_t` struct. Any version change can restructure it.

### Impact on rad-con

If rad-con uses the UDP protocol (recommended per Gap #2), the risk is moderate:
- The protocol has been stable across many versions
- Multiple third-party apps depend on it (JTAlert, GridTracker, JS8Call interop)
- Breaking it would break the entire ecosystem, not just rad-con
- The backward compatibility rules are respected by the existing developers

If rad-con uses shared memory (not recommended), the risk is high:
- The struct changes with every major version
- No compatibility mechanism exists
- rad-con would need to support multiple struct layouts simultaneously

### Mitigations

1. **Use UDP exclusively.** The backward compatibility rules are explicit and have been honored across multiple versions. This is the safest interface.

2. **Version-aware adapter layer.** rad-con implements a thin adapter that translates between its internal model and the WSJT-X UDP protocol. If the protocol changes, only the adapter needs updating.

3. **Integration test suite.** Automated tests that exercise the UDP protocol against each WSJT-X release. These run as part of rad-con's CI, not WSJT-X's. When a new WSJT-X version breaks a test, we know immediately.

4. **Pin and document.** rad-con's documentation states which WSJT-X versions are tested and supported. Users running untested versions are on their own.

5. **Do not request stability guarantees.** Asking the WSJT-X team to maintain API stability for rad-con's benefit violates the white room. The stability comes from the ecosystem pressure (many third-party apps depend on the same protocol), not from our request.

### Status: RESOLVED — use UDP, build an adapter layer, test against releases.

---

## 6. Apple JIT Entitlement Fragility

### The Problem

The ARM macOS build requires three aggressive entitlements in `entitlements.plist`:

```
com.apple.security.cs.allow-jit
com.apple.security.cs.allow-unsigned-executable-memory
com.apple.security.cs.disable-executable-page-protection
```

These exist because GCC's Fortran runtime (`libgfortran`) uses JIT compilation and dynamic memory execution. Without them, the Fortran-based decoders (jt9, wsprd, all signal processing in `lib/`) crash on ARM macOS due to Apple's hardened runtime enforcement.

### Why This Is Fragile

Apple has been progressively tightening security:
- macOS Catalina (10.15): introduced notarization requirement
- macOS Monterey (12): hardened runtime enforcement expanded
- macOS Ventura (13): stricter library validation
- Each major release restricts what non-App Store apps can do

The entitlements we use are the most permissive available for Developer ID distribution. `allow-unsigned-executable-memory` and `disable-executable-page-protection` are effectively asking Apple to turn off memory protection. Apple tolerates this today but has no obligation to continue.

If Apple:
- Removes these entitlements from Developer ID distribution (App Store only)
- Requires additional review for apps using them
- Changes notarization to reject them

Then WSJT-X cannot run natively on ARM macOS. Period. Not just our builds — John G4KLA's builds too, and the official releases.

### Impact

- **This repo:** Builds stop producing functional ARM binaries
- **WSJT-X project:** macOS ARM support breaks entirely
- **rad-con:** Loses access to ARM-native decoders (would fall back to Rosetta, which still works but with performance penalty)

### Root Cause

The root cause is not Apple's policies — it's the GCC Fortran runtime. `libgfortran`'s use of JIT is a compiler/runtime implementation detail, not a requirement of the Fortran language. Two potential fixes exist:

1. **LLVM/Flang:** The LLVM project's Fortran compiler (`flang`) would produce code that runs under the hardened runtime without JIT entitlements. Flang is maturing but may not yet compile WSJT-X's Fortran codebase (which uses extensive F90/F95 features).

2. **GCC fix:** GCC could be patched to avoid JIT on ARM macOS. This would be a contribution to GCC, not to WSJT-X.

### What We Should Do

1. **Monitor Apple's entitlement policies** with each macOS release. Test the build on beta releases of new macOS versions.
2. **Periodically test with Flang** to see if it can compile the Fortran codebase. When it can, propose the compiler switch to the team.
3. **Flag this to the team** as a long-term risk during Phase 1 or Phase 2 — it affects all macOS ARM builds, not just ours.
4. **Do not panic.** Apple is unlikely to remove these entitlements without a deprecation period, and the amateur radio / scientific computing communities are not the only ones affected — any Fortran-dependent macOS app has the same issue.

### Status: ACKNOWLEDGED — monitor, test alternatives, flag to team. No immediate action required.

---

## 7. Qt5 End of Life

### The Situation

Qt5 reached end of life in May 2025 (commercial support ended; open source LTS ended earlier). WSJT-X is built entirely on Qt5: GUI (Widgets), serial port communication (Qt5SerialPort), audio I/O (Qt5Multimedia), internationalization (Qt5LinguistTools), SQL (Qt5Sql), and network (Qt5Network).

The Qt5 → Qt6 migration is not trivial:
- `QRegExp` removed (replaced by `QRegularExpression`)
- `QTextCodec` removed
- `Qt5Multimedia` completely rewritten — different backends, different API
- Integer type changes (implicit conversions now errors)
- `QList` is now `QVector` under the hood (behavior changes)
- Many deprecated APIs removed
- Build system changes (qmake → CMake preferred, but WSJT-X already uses CMake)

### Impact on Us

**CI/CD:** Our build pipeline uses `brew install qt@5`. Homebrew will eventually remove Qt5 from the main repository (it's already keg-only). When it moves to a tap or is removed entirely, our builds break.

**Upstream:** The team will eventually need to migrate. This is a multi-month effort for a codebase this size — especially `Qt5Multimedia`, which handles all audio I/O for a real-time signal processing application.

### What We Should Do

1. **Do not volunteer to lead the Qt6 migration.** This is a massive architectural change that the team needs to own. We can help, but leading it from the outside risks the white room — the migration decisions affect the entire application architecture.

2. **Keep our CI/CD flexible.** When writing workflows for the org, parameterize the Qt version so the pipeline can be updated when the time comes.

3. **Monitor Homebrew Qt5 availability.** When Qt5 is deprecated from Homebrew, we'll need to either build Qt5 from source in CI or switch to Qt6.

4. **If asked to help with Qt6 migration:** This passes the litmus test — it benefits the open source project entirely on its own merits. Proceed, but as a multi-phase planning-first effort per the methodology.

### Status: ACKNOWLEDGED — future risk. No action now. Keep CI/CD Qt-version-flexible.

---

## 8. Project Continuity — What If WSJT-X Development Slows or Stops

### The Reality

Joe Taylor (K1JT) started the project in ~2000. He is a retired Princeton physics professor and Nobel laureate. The core team is small: six active members, most of whom are not professional programmers. Amateur radio demographics skew older.

This is not a criticism — it's a fact that responsible planning must account for. Volunteer open source projects with small teams and no institutional backing can slow, stall, or stop. Key person dependencies are real.

### Impact on rad-con

If WSJT-X development stops:
- **Existing binaries continue to work.** FT8, FT4, Q65, WSPR protocols don't change just because development stops. The decoders will keep decoding.
- **This repo can continue building from the last release** indefinitely. The source is GPL; we have the right to build and distribute.
- **No new features or bug fixes.** If a new operating system breaks compatibility, or a new digital mode emerges, there's no one to update the code.
- **Security vulnerabilities** would go unpatched.

### Contingency Thinking (Not Action)

This requires no action today but informs architectural decisions:

1. **This repo's independence is load-bearing.** If the upstream project goes dormant, this repo is the distribution mechanism for the last-known-good builds. Its CI/CD pipeline and release automation ensure continuity without depending on upstream infrastructure.

2. **The UDP protocol integration model is more resilient than subprocess launching.** If rad-con talks to WSJT-X over UDP, users can run any WSJT-X version (or a fork). If rad-con launches specific decoder binaries, it's coupled to a specific build.

3. **Forking is legally permissible but operationally heavy.** GPL grants the right to fork, modify, and redistribute. If the project stalls and critical bugs need fixing, we can maintain a fork. But maintaining a Fortran/C++/Qt codebase of this size is a serious commitment — not something to do casually.

4. **Community succession is more likely than abandonment.** WSJT-X is the most widely used digital mode software in amateur radio. If the core team steps back, someone will fork it. Our CI/CD contributions make that succession easier — any fork can use the workflows we build.

5. **Our CI/CD contributions are themselves a continuity investment.** Automated builds, documented processes, and infrastructure reduce the bus factor. Even if key developers leave, the code can still be built and released.

### The Symbiotic Angle

This is another dimension of symbiosis. Our CI/CD contributions don't just help the current team — they help whoever maintains the project next. Building infrastructure that outlasts any individual contributor is a genuine gift to the open source ecosystem, with no commercial strings attached.

### Status: ACKNOWLEDGED — no action required. Architecture decisions already favor resilience (independent repo, UDP integration, CI/CD as continuity investment).

---

## 9. Secret Management for Org CI/CD

### The Problem

Setting up CI/CD for the WSJTX org requires handling sensitive credentials as GitHub Secrets:

- **Apple Developer ID certificates** (Application + Installer) — P12 files and passwords
- **Apple ID credentials** — for notarization (App Store Connect API key or app-specific password)
- **Apple Team ID** — identifies the signing entity

These are not our secrets. They belong to whoever holds the WSJT-X project's Apple Developer account. Misconfiguring them has real consequences: leaked signing certificates allow anyone to sign malware that appears to come from the project.

### Questions That Must Be Answered (Phase 1)

1. **Who owns the Apple Developer account?** Is it Joe's personal account? John G4KLA's (since he does the macOS builds)? A team account? The answer determines the bus factor and the trust model.

2. **Who should have GitHub org admin access?** Org admins can read secrets by modifying workflow files. If only Joe is admin, only Joe can set secrets — but then only Joe can update expired certs. If multiple people are admins, more people can access the secrets.

3. **Whose identity goes on the binaries?** The code signing certificate determines the developer name shown to users. If we use KJ5HST-LABS certs temporarily, the binaries say "KJ5HST-LABS" — which is confusing for WSJT-X users.

4. **Certificate rotation.** Apple Developer certificates expire annually. The pipeline needs a renewal process that doesn't depend on one person being available.

### Principles

1. **We do not set up secrets we don't own.** We can write the workflow, document the secret names and formats, and provide instructions. The team configures the actual values.

2. **Least privilege.** If possible, use a dedicated Apple API key (App Store Connect) rather than a personal Apple ID for notarization. API keys can be scoped and revoked independently.

3. **Document the process, not the values.** The workflow documents which secrets are needed, their format, and how to rotate them. The values are never written anywhere except GitHub Secrets.

4. **Temporary demo with our certs — only with explicit permission.** If the team wants to see the pipeline work before providing their own certs, we can use KJ5HST-LABS certs with a clear understanding that:
   - The binaries will be signed as KJ5HST-LABS, not WSJT-X
   - This is a demo only
   - Our certs will be removed once theirs are configured

5. **Firewall applies.** KJ5HST-LABS signing credentials used in this repo must NOT be the same credentials configured in the WSJTX org repo. Separate identities, separate trust boundaries.

### Status: RESOLVED in principle — questions documented for Phase 1. Execution requires team coordination.

---

## 10. Recusal Protocol — When Team Discussions Affect rad-con

### The Problem

As a WSJT-X team member, Terrell will participate in discussions that may directly affect rad-con's interests. Examples:

- "Should we change the shared memory layout?" (breaks subprocess integration)
- "Should we deprecate the UDP protocol?" (breaks rad-con's primary integration path)
- "Should we change the jt9 command-line interface?" (breaks subprocess invocation)
- "Should we add a commercial licensing exception?" (directly relevant to rad-con)
- "Should we restrict redistribution of individual binaries?" (affects this repo)

Participating in these discussions without disclosure looks like covert influence. Staying silent looks like hiding the conflict. Recusing entirely means valuable technical perspective is lost.

### The Protocol

**Disclosure over recusal.**

When a team discussion directly affects rad-con's interests:

1. **Disclose the conflict.** "This decision affects rad-con because [specific reason]. I want you to know that so you can weigh my input accordingly."

2. **Provide technical input on its merits.** If the proposed change would affect all third-party applications (not just rad-con), say so. If it would only affect rad-con, say that too.

3. **Let the team decide.** After disclosing and providing technical context, the decision belongs to the team. Do not lobby, do not argue from rad-con's interests, do not threaten to withhold contributions.

4. **Accept the outcome.** If the team decides to break the UDP protocol, rad-con adapts. The team's project serves the team's goals.

### When To Recuse Entirely

Full recusal is appropriate when:
- The discussion is about licensing changes that directly benefit or harm rad-con
- The discussion involves revenue, sponsorship, or commercial relationships with rad-con
- Terrell cannot provide a technical opinion that is separable from rad-con's commercial interest

In these cases: "I have a commercial interest in this decision through rad-con. I should sit this one out. Here's the technical context if it helps, but the decision should be yours."

### Documentation

Any disclosure or recusal should be documented in the project memory (not in the WSJT-X repo). The purpose is to maintain the paper trail that demonstrates the firewall is working — that conflicts were identified and handled transparently.

### Status: RESOLVED — disclosure over recusal as default. Full recusal for licensing/commercial discussions.

---

## 11. Contribution Licensing Agreement (CLA) Risk

### The Situation

Currently, the WSJT-X project has no CLA. Contributors submit code; it's implicitly licensed under the project's GPL-3.0. Copyright remains with the contributor.

As the project professionalizes (GitHub migration, CI/CD, new contributors), governance questions may emerge. Some open source projects adopt CLAs that:
- Require contributors to grant the project a broad license (including relicensing rights)
- Require copyright assignment (contributor no longer owns their contribution)
- Grant the project the right to dual-license under commercial terms

### Why This Matters

1. **If WSJT-X adopts a CLA with relicensing rights:** Code Terrell contributes could be relicensed under terms that compete with rad-con. For example, if the project later offers a commercial license, a competitor could license WSJT-X code commercially and build a competing product without GPL restrictions.

2. **If WSJT-X requires copyright assignment:** Terrell would no longer own his contributions. The project could use them in ways he doesn't control.

3. **The irony:** Our contributions (CI/CD, infrastructure) are helping the project professionalize. Professionalization often leads to governance formalization. Governance formalization sometimes produces CLAs. We could be building the mechanism that creates this risk.

### What To Do

1. **Do not sign a CLA without legal review.** If the team ever introduces a CLA, read it carefully before signing. The specific terms matter enormously.

2. **Prefer infrastructure contributions over code contributions.** CI/CD workflows, GitHub configuration, and documentation are less likely to be subject to CLA concerns than application code. A GitHub Actions YAML file is not the same as a Fortran decoder.

3. **Keep copyright on contributions.** Under the current no-CLA arrangement, Terrell retains copyright on his contributions (licensed to the project under GPL-3.0). This is the default under copyright law and does not require any special action.

4. **If a CLA is proposed, evaluate it against the symbiotic doctrine.** A CLA that enables dual-licensing could benefit the project financially (selling commercial licenses to fund development). But it could also harm the ecosystem by allowing proprietary forks. Evaluate on the merits per `docs/SYMBIOTIC_OPEN_SOURCE.md`.

5. **Do not be the one who proposes a CLA.** Even if it might benefit the project, proposing it as the person with commercial interests is a bad look. If governance discussions arise, participate transparently but don't drive them.

### Status: ACKNOWLEDGED — no CLA exists today. Monitor if governance discussions arise. Do not sign without legal review.

---

## 12. Copyright Claim on Protocol Specifications and Algorithms

### The Finding

The WSJT-X About dialog (`widgets/mainwindow.cpp:4651`) and user guide (`doc/common/license.adoc`) contain this notice:

> "The algorithms, source code, look-and-feel of WSJT-X and related programs, and **protocol specifications** for the modes FSK441, FST4, FT8, JT4, JT6M, JT9, JT65, JTMS, QRA64, Q65, MSK144 are Copyright (C) 2001-2021 by [list of authors]"

This explicitly asserts copyright on:
1. **Algorithms** — the mathematical methods for encoding/decoding
2. **Source code** — standard
3. **Look-and-feel** — the UI design
4. **Protocol specifications** — the definitions of the digital modes themselves

### Why This Matters

**For Gap #2 (shared memory protocol specification):** Our proposed resolution — asking the team to publish the shared memory protocol as a standalone specification — is a licensing decision, not just a documentation task. If the protocol specifications are copyrighted (as asserted), publishing them under a permissive license requires the copyright holders to make that choice. We can't assume they'll agree.

**For the digital mode protocols broadly:** If the FT8 protocol specification is copyrighted, then any independent implementation of FT8 (not using the GPL code) would need a license to the specification. This has implications beyond rad-con — it affects the entire amateur radio ecosystem.

### Legal Analysis

Copyright on "algorithms" is legally questionable — algorithms are generally considered mathematical methods and are not copyrightable under US law (*Baker v. Selden*, 1879; *Alice Corp v. CLS Bank*, 2014). They can be patented, but not copyrighted. The assertion may be broader than what copyright law actually supports.

Copyright on "protocol specifications" is more complex. A specification document (the written description) can be copyrighted as a literary work. But the functional aspects of a protocol (field types, byte ordering, timing) may not be copyrightable because they are dictated by function, not creative expression (*Lotus v. Borland*, 1995; *Oracle v. Google*, 2021).

However, the assertion exists regardless of its legal enforceability. It signals intent: the team considers these protocols their intellectual property.

### What To Do

1. **Respect the intent.** Even if the copyright claim is legally questionable, the team clearly considers the protocols their IP. Don't challenge this — work within it.

2. **When proposing protocol documentation (Gap #2):** Frame it as helping the team document what they own, not as extracting IP for external use. "The shared memory protocol is yours. A published specification makes it easier for the community to integrate correctly, which reduces bug reports and confusion."

3. **For rad-con's UDP implementation:** The UDP protocol (`NetworkMessage.hpp`) is documented in GPL source code but is explicitly designed for third-party integration. Multiple closed-source applications use it. The practical reality is that the community treats it as a de facto public interface, regardless of the copyright notice. Implementing a UDP client from the documented behavior is defensible under both fair use and interoperability doctrine.

4. **Do not independently implement FT8 or other digital mode protocols in rad-con.** Even if legally defensible, re-implementing the protocols outside of the GPL code would directly conflict with the copyright assertion and poison the relationship. rad-con uses the GPL decoders; it doesn't reimplement them.

5. **If this ever becomes contentious:** This is a situation for a real IP attorney, not for us to resolve through analysis alone.

### Status: ACKNOWLEDGED — significant context for Gap #2 resolution. Respect the intent. Frame protocol documentation as serving the team's interests.

---

## 13. Competition Perception — rad-con as a Better WSJT-X Frontend

### The Dynamic

WSJT-X is both a signal processing engine (the decoders) and a GUI application. Its GUI is functional but not designed for integration — it's a standalone application built by scientists for their own use.

If rad-con becomes a superior user experience for operating digital modes — more intuitive, better integrated with radio control, smoother workflow — while using WSJT-X's decoders under the hood, a predictable tension arises:

*"We did all the hard scientific work building the decoders. They built a pretty wrapper and charge money for it."*

This perception is legally irrelevant. The GPL explicitly permits this. Red Hat charges for a distribution of entirely GPL software. The model is established and legitimate.

But social legitimacy and legal legitimacy are different things. The WSJT-X team are volunteers who have spent decades on signal processing research. If they feel exploited — regardless of the legal reality — the relationship breaks.

### How This Relates to Symbiosis

This is the ultimate test of whether the symbiosis is genuine. If rad-con succeeds because of WSJT-X's decoders, and the WSJT-X project sees no benefit from rad-con's success, that's parasitism, not symbiosis — even if it's legally permitted parasitism.

The answer is the funding model described in `docs/SYMBIOTIC_OPEN_SOURCE.md`. When rad-con generates revenue, a portion flows back to the open source projects it depends on. Not as a licensing fee. Not as payment for services. As an unconditional acknowledgment that commercial success built on open source creates an obligation to sustain it.

### Practical Mitigations

1. **Lead with infrastructure, not UI.** Our immediate contributions (CI/CD, build automation, release engineering) are things the team cannot easily do themselves and that have nothing to do with competing with their GUI. Establish trust through infrastructure before rad-con's UI competition becomes visible.

2. **Never disparage WSJT-X's UI.** Even if rad-con's interface is objectively better, never position it as "WSJT-X done right" or "what WSJT-X should have been." rad-con solves a different problem (integration) for a different audience (less technical users).

3. **Credit prominently.** rad-con's documentation, About screen, and marketing should prominently credit WSJT-X and the development team. Not buried in a license file — front and center.

4. **Deliver on the funding promise.** When rad-con generates revenue, follow through on the royalty/sponsorship model. Talk is cheap. Money transferred is proof of symbiosis.

5. **Make WSJT-X better too.** Every contribution to the open source project — CI/CD, documentation, patches — is evidence that we're invested in WSJT-X's success, not just extracting value from it.

### Status: ACKNOWLEDGED — ongoing relationship management. Lead with infrastructure, credit prominently, deliver on funding when the time comes.

---

## 14. v3.0.0 GA Release Timing

### The Situation

John G4KLA's email stated: "Look out for the General Release of WSJT-X which will happen very soon." This means v3.0.0 GA is imminent.

### Impact on Our Work

1. **This repo:** Can update the build pipeline from `3.0.0-rc1` to the GA release. The CMake patches should apply identically (or be unnecessary if they've been fixed upstream).

2. **Phase 6 (upstream patches):** Timing matters. If we submit patches before GA, they might be included. If after, they target the next version. Post-GA is likely more appropriate — the team won't want to delay a release for our patches.

3. **Phase 1 (repo audit):** The GA release may change what's in the GitHub repo. Wait for it before auditing, so we're looking at the current state.

4. **Shared memory struct:** v3.0.0 added ~30 fields to `dec_data_t`. The GA release locks this as the baseline for rad-con's integration target.

5. **This repo's releases:** Once GA drops, we should build and release it promptly. This demonstrates our CI/CD pipeline's value — we can produce ARM builds quickly.

### Action

Monitor for the GA release. When it drops:
- Update `WSJTX_VERSION` in the workflow
- Rebuild and release
- Begin Phase 1 audit against the GA codebase
- Submit Phase 6 patches against the GA baseline

### Status: MONITORING — timing trigger for multiple phases.
