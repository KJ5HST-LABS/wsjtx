Everyone,

Thanks for the thoughtful responses — this is exactly the kind of feedback I was hoping for, and a couple of reads are making me realize I owe a clarification.

John and Charlie: when I wrote "where do you guys want to draw that line?" I meant that as a genuine question to the group, but the "I'm just saying…" sentence that followed turned it into a proposal, and the docs themselves — which say "macOS ARM64 / Linux x86_64 / Windows x86_64" everywhere — reinforced that reading. That's on me. I'm here to build what the team wants, not to set platform policy, and the docs need to reflect the team's decisions, not mine. **The pipeline will retain the platforms WSJT-X supports today — Intel Macs, Qt5, Windows 7, all of it.** I'll add an Intel macOS build job (macos-13 runner, target 10.13) and revise the docs so they read as "current sandbox state + intended additions," not as a platform manifesto.

**v3.0.1** — Joe, my honest recommendation is to hand-build v3.0.1 the traditional way. The pipeline is a proof-of-concept running in my sandbox org; it's not deployed to the official WSJTX repos yet, and trying to rush the deployment for a hotfix would add risk exactly where you don't want it. Let's target the pipeline for v3.0.2+. You're also right about the branch basis — v3.0.1 should be tagged on `v3.0.0_test` rather than `develop`. My workflow doc currently says to tag on develop; I'll fix that.

**John, on the Apple Developer account:** nothing changes. You continue to own it. Your existing Developer ID certs get exported as `.p12` files, base64-encoded, and loaded as GitHub secrets; the pipeline reads them automatically on every build. No handoff required unless you want one.

**On the `allow-unsigned-executable-memory` entitlement:** you're right to flag it. I inherited the entitlements plist from an earlier prototype and never audited whether WSJT-X actually needs those runtime exceptions. I'll test a signed + notarized build with them removed and report back.

**Quick answers on the rest:**

- **RC tags** (Joe): they already go through the pipeline; I'll add a rule that flags `v*-rc*` as pre-releases, and write up the branch-cut process.
- **Roger's MAP65 + Qt6 tarballs**: yes please, very much want to see them — strict-flag CI is exactly what would catch the MAP65 issues going forward.
- **Brian**: docs 2 and 4 are the public-facing ones (4 becomes `CONTRIBUTING.md`); I'll introduce `gh` on first use; a scheduled Hamlib check and a source tarball are both easy adds; full test integration (ctest + pfUnit) is a bigger next workstream.

I'll revise the docs with everything above and circulate v2 for another pass.

73,
Terrell
