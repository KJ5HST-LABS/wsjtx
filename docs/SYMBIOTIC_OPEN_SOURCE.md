# Symbiotic Open Source

**This document defines the relationship between our commercial work (rad-con) and our open source contributions (WSJT-X). Every decision involving both projects must be evaluated against the principles in this document.**

---

## The Principle

This must be truly symbiotic.

Not "mutually tolerant." Not "carefully coexisting." Not "one side benefits while the other permits it." Symbiotic — where each organism is genuinely stronger because the other exists, and where removing either one diminishes the whole.

WSJT-X is a world-class signal processing platform built by scientists over 25 years. It decodes signals that no human ear can hear, enabling communication at the physical limits of radio. It is open source because its creators believe that advancing science and amateur radio should be a shared endeavor.

rad-con is a commercial platform that puts these tools — and many others — into the hands of operators who might never compile a line of code. It lowers the barrier to entry for digital radio by integrating fragmented pieces into a coherent experience. It is commercial because sustaining that integration work requires a business model.

Neither project is complete without what the other provides. WSJT-X has the signal processing. rad-con has the integration and accessibility. WSJT-X reaches developers and power users. rad-con reaches everyone else. WSJT-X advances the science. rad-con funds the ecosystem.

The symbiosis is the point. Not a side effect. Not a rationalization. The relationship exists because both projects are genuinely better for it, and the moment that stops being true for either side, the relationship must be re-evaluated.

This document defines the boundaries that keep the symbiosis healthy — the legal separation that copyright law requires, the organizational firewall that community trust demands, and the ethical commitments that make the whole thing worth doing.

---

## The Legal Reality

WSJT-X and its components (jt9, wsprd, ft8code, q65code, etc.) are licensed under the **GNU General Public License v3 (GPL-3.0)**. GPL is a copyleft license — any software that incorporates, links, or embeds GPL code must itself be distributed under the GPL.

rad-con is intended to be a **commercial application**. It cannot be GPL. Therefore:

- rad-con **must never** statically or dynamically link GPL code
- rad-con **must never** embed GPL source or compiled objects
- rad-con **must never** include GPL binaries inside its own application bundle
- rad-con **must never** ship GPL code as if it were part of rad-con

These are not guidelines. They are legal requirements. Violating them would either force rad-con to become GPL or constitute copyright infringement.

---

## The Architectural Boundary

The GPL permits a program to **execute** a GPL-licensed binary as a separate process. This is how WSJT-X itself uses jt9 — it launches it as a subprocess and communicates through shared memory. The two programs remain independent works under copyright law.

rad-con follows this same pattern:

1. rad-con **downloads** pre-built WSJT-X binaries from this repository's GitHub Releases
2. rad-con **launches** them as separate subprocesses at runtime
3. Communication happens through well-defined IPC channels (shared memory, stdin/stdout, UDP)
4. The GPL binaries run in their own process space with their own lifecycle

This boundary is not a workaround. It is the correct architectural separation of concerns. Decoders are standalone signal processing tools. rad-con is a radio control and integration platform. They should be separate executables regardless of licensing.

---

## The Two Repositories

### KJ5HST-LABS/WSJT-X-MAC-ARM64 (this repository)

**Purpose:** Build, sign, notarize, and distribute standalone WSJT-X binaries for macOS ARM64.

**Open source value:**
- Native Apple Silicon builds of WSJT-X available to the entire amateur radio community
- Signed and notarized — runs without macOS security warnings
- Individual decoder tools packaged for standalone use
- CI/CD pipeline that proves automated WSJT-X builds are possible

**rad-con value:**
- Stable release URL for downloading known-good decoder binaries
- `latest` tag provides a permanent, version-independent download endpoint
- Self-contained binaries with bundled dylibs — no system dependency conflicts

**This repository must remain independent.** It is not part of the WSJTX organization. It is maintained by KJ5HST-LABS. It serves the open source community AND rad-con, and that dual purpose is by design.

### WSJTX/wsjtx (the team's repository)

**Purpose:** The official WSJT-X source code, maintained by the WSJT Development Team.

**Our contributions there:** CI/CD automation, GitHub infrastructure, upstream patches, documentation — things that help the project regardless of rad-con's existence. If rad-con disappeared tomorrow, every contribution we make to the WSJT-X project should still be valuable.

---

## What The Symbiosis Looks Like

### What WSJT-X gets from us
- GitHub Actions CI/CD — automated multi-platform builds they don't currently have
- GitHub infrastructure — issue templates, PR templates, branch protection, release automation
- Upstream patches — CMake 4.x compatibility, ARM64 deployment target fixes
- Build expertise — deep knowledge of the CMake superbuild, dependency chain, code signing
- Documentation — build guides, contribution guidelines

### What rad-con gets from a healthy WSJT-X project
- Reliable, well-tested decoder binaries
- Active development of new modes and protocols (FT8, Q65, FST4, etc.)
- A community that maintains and improves the signal processing code
- Stable IPC interfaces (shared memory protocol, UDP message format)
- Broad platform support that reduces rad-con's own platform burden

### The feedback loop
Better CI/CD for WSJT-X means faster, more reliable releases. Faster releases mean rad-con can adopt improvements sooner. rad-con adoption puts WSJT-X tools in front of more operators. More operators means more testing, more feedback, more contribution back to WSJT-X.

Neither project is diminished by the other's success. Both are strengthened by it.

---

## The White Room: Organizational Separation

The legal and architectural boundaries above are necessary but not sufficient. The open source community is rightly sensitive to commercial interests influencing open source projects. Even well-intentioned contributions can be perceived as self-serving if the separation isn't clean and visible.

The "white room" principle: **when contributing to WSJT-X, we operate as if rad-con does not exist.**

### What this means in practice

**Separate contexts.** Work on WSJT-X contributions and work on rad-con happen in separate sessions, separate mental frames, separate conversations. We do not sit in a rad-con planning session, identify something that would be convenient for rad-con, and then go contribute it to WSJT-X. The contribution must originate from the needs of the open source project itself.

**The litmus test.** Before making any contribution to WSJT-X, ask: *"Would a contributor with no commercial interest make this same contribution?"* If the answer is yes — because it fixes a real bug, improves the build system, helps all users — then proceed. If the answer is "only if they also had a commercial product that needed it" — stop. That contribution belongs in our own repo or in rad-con, not upstream.

**The firewall is bi-directional.** Information does not leak in either direction:

- **Open source → commercial:** Knowledge gained from WSJT-X internals (unpublished protocol changes, unreleased features in wsjtx-internal) does not flow into rad-con development ahead of public availability. When a new WSJT-X feature is released publicly, rad-con can adopt it. Not before.

- **Commercial → open source:** Proprietary concepts, designs, algorithms, integration patterns, or innovations developed for rad-con do not flow into WSJT-X contributions. Once something is contributed to a GPL project, it is GPL forever — it cannot be retracted. If a novel idea is part of rad-con's commercial value, contributing it upstream surrenders that value irrevocably. This is not theoretical risk — it is the fundamental mechanism of copyleft.

The firewall protects both sides. Open source is protected from commercial influence steering the project. Commercial interests are protected from inadvertent disclosure of proprietary innovation into an irrevocable public license.

**Separate identities in context.** When Terrell contributes to WSJT-X, he is a team member contributing to an open source project. The WSJT-X team knows about rad-con — Terrell was transparent from day one — but contributions are evaluated on their merit to the project, not on their benefit to rad-con. If a contribution discussion ever turns to "but this helps your commercial product," the correct response is to withdraw the contribution and re-evaluate whether it passes the litmus test.

### Why this matters

Open source communities have seen the pattern before: a company contributes heavily to an open source project, steers it toward their commercial needs, and eventually the project serves the company more than the community. The community's immune response to this pattern is strong and justified.

We avoid triggering that response by maintaining genuine separation. Not the appearance of separation — actual separation. The white room isn't a PR strategy. It's an operational discipline.

---

## The Long View: Commercial Funding of Open Source

The healthiest open source ecosystems have sustainable funding. Volunteer labor built the foundation, but long-term maintenance, infrastructure, and development benefit from financial support.

There is an opportunity — not now, but as rad-con matures — for commercial revenue to fund open source development through royalties or sponsorship. This is a well-established model:

- Red Hat built a billion-dollar business on GPL software and contributed massively back
- Qt is dual-licensed — commercial licenses fund the open source edition
- Many companies sponsor open source projects they depend on via GitHub Sponsors, Open Collective, or direct grants

**The vision:** A portion of rad-con's commercial revenue flows back to the open source projects it depends on — WSJT-X, Hamlib, and others. Not as charity. Not as payment for services. As recognition that commercial success built on open source creates an obligation to sustain it.

**This is aspirational, not operational.** There is nothing to implement today. But the architecture — the clean separation, the subprocess boundaries, the independent repositories — is designed with this future in mind. When the time comes to establish a funding relationship, the white room discipline ensures it is perceived as what it is: a commercial entity supporting the ecosystem it benefits from, with no strings attached.

**The key constraint:** Funding must never come with influence over project direction. The moment financial support is used to steer open source development toward commercial interests, the white room collapses. Sponsorship is unconditional or it is not sponsorship — it is procurement.

---

## Rules That Flow From This

### Never do
1. **Never embed GPL code in rad-con** — not in source, not in binaries, not in the app bundle
2. **Never contribute to WSJT-X with the hidden purpose of serving only rad-con** — if a contribution doesn't stand on its own merit for the open source project, don't make it
3. **Never merge this repository into the WSJTX organization** — it must remain an independent distribution point
4. **Never propose changes to WSJT-X's IPC interfaces solely to benefit rad-con** — propose changes that benefit all consumers, including WSJT-X's own GUI
5. **Never represent rad-con's interests as the community's interests** — be transparent about what benefits whom
6. **Never use knowledge from wsjtx-internal to give rad-con a development advantage** — public releases only
7. **Never contribute proprietary rad-con concepts, designs, or innovations to WSJT-X** — once it's GPL, it's GPL forever. If it has commercial value, it stays in rad-con.
8. **Never let financial support buy influence over project direction** — sponsorship is unconditional or it isn't sponsorship

### Always do
1. **Maintain the subprocess boundary** — decoders are launched, never linked
2. **Contribute upstream first** — if a fix benefits WSJT-X, submit it to their repo, don't just patch our build
3. **Keep this repository's releases useful to the general community** — not just rad-con's needs
4. **Be transparent about the relationship** — the WSJT-X team knows about rad-con's existence and our use of their tools
5. **Test the boundary** — when in doubt about whether something crosses the GPL line, assume it does and find the clean path
6. **Apply the litmus test** — would a contributor with no commercial interest make this same contribution?
7. **Keep contexts separate** — WSJT-X contribution sessions and rad-con development sessions are distinct
8. **Disclose conflicts; recuse when necessary** — when team discussions affect rad-con, disclose and let the team decide. Full recusal for licensing/commercial decisions.
9. **Do not sign a CLA without legal review** — if WSJT-X ever introduces a contribution licensing agreement, the terms determine whether continued contribution is compatible with rad-con

**Detailed risk analysis:** See `docs/planning/GPL_COMPLIANCE_GAPS.md` for the full 11-gap analysis covering legal, technical, social, strategic, and operational dimensions.

---

## The Hamlib Dimension

The same principle applies to Hamlib (LGPL-2.1). LGPL is more permissive — dynamic linking is allowed without requiring the consuming application to be open source. However:

- The WSJT-X superbuild statically links Hamlib (`--disable-shared --enable-static`), which under LGPL requires the consumer to provide the ability to relink. This is fine for GPL'd WSJT-X but would be a concern if rad-con ever statically linked Hamlib.
- rad-con currently consumes Hamlib indirectly (through the jt9/wsprd subprocesses). This is clean.
- If rad-con ever needs direct rig control via Hamlib, it should dynamically link (`--enable-shared`) to stay cleanly within LGPL terms.

---

## Why This Document Exists

Open source licensing is not a technicality to be navigated around. It is a social contract. The developers who wrote WSJT-X chose GPL because they want their work to remain free. We respect that by keeping their code free and keeping our boundary clean.

Building a commercial product that works with open source tools is not exploitative — it is exactly how the ecosystem is designed to work. Linux is GPL. Every commercial cloud provider runs it. The boundary is the API, the process, the protocol.

But legality is the floor, not the ceiling. A relationship that is merely legal is not symbiotic — it is transactional. Symbiosis requires that both sides are invested in the other's success. We contribute to WSJT-X not because we have to, but because a stronger WSJT-X makes the entire amateur radio digital ecosystem stronger — and that ecosystem is where both projects live.

This document exists to hold us to that standard. The boundaries it defines are not walls between adversaries. They are the membranes of a healthy symbiosis — selectively permeable, protecting each organism's integrity while enabling the exchange that makes both thrive.

The moment we catch ourselves asking "how close to the line can we get?" instead of "does this make both projects better?" — we have already failed. Re-read this document from the top.
