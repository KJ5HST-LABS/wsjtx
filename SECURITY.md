# Security Policy

## Scope

This repository hosts the arm64 macOS build pipeline for WSJT-X. Security reports
fall into two categories:

1. **WSJT-X source defects** (decoder code, Qt UI, network protocols, Hamlib
   integration) — these are upstream issues that apply to every WSJT-X build,
   not just this one. Report them to the upstream project via the
   [WSJT-X Development reflector](https://sourceforge.net/projects/wsjt/lists/wsjt-devel)
   so that every downstream build receives the fix.

2. **Build-pipeline defects** specific to this repository — CI workflows, signing
   or notarization flow, release publishing, the public-mirror sync, dependency
   pinning, or the packaged installer itself. These are in scope here.

If you are unsure which category applies, report here and we will triage.

## How to Report

**Please do not open a public issue for a suspected vulnerability.** Use one of
the following private channels:

- **Preferred:** GitHub Private Vulnerability Reporting —
  [Report a vulnerability](../../security/advisories/new). This creates a
  confidential advisory that only repository admins can read until disclosure.

- **Email:** if Private Vulnerability Reporting is not available to you,
  email the maintainer listed in `CODEOWNERS` at the address on their
  GitHub profile. Use the subject line `[SECURITY] wsjtx-internal: <brief>`.

Please include:
- Affected component (workflow file, binary artifact, endpoint, etc.)
- Reproduction steps or a proof-of-concept if available
- Your assessment of impact (e.g., code execution in the build runner,
  supply-chain injection into the released installer, credential exposure).

## Response Commitment

- **Acknowledgment within 7 days** of receipt.
- **Initial assessment within 30 days** — severity, confirmed/not, remediation
  path.
- **Fix or mitigation within 90 days** for confirmed vulnerabilities, unless a
  shorter window is warranted by severity or an embargo coordinated with other
  affected parties.

If circumstances require a longer window, we will state that explicitly with a
rationale (e.g., upstream coordination, cross-platform reproduction).

## Supported Versions

The project follows WSJT-X's release cadence. Security fixes are applied to the
most recently published release and any release the project is actively
supporting.

| Version        | Supported |
|----------------|-----------|
| 3.0.x          | Yes       |
| 2.7.x and older| Upstream-only (report to `wsjt-devel`) |

The currently-published build artifacts are listed on the
[Releases page](../../releases).

## Scope Exclusions

- Denial-of-service against the decoder itself caused by intentionally malformed
  audio input (FT8/FT4/JT9 are designed to tolerate noise; decoder CPU spikes
  under pathological input are not a vulnerability unless they lead to code
  execution).
- Vulnerabilities in upstream dependencies (Qt, Hamlib, FFTW, boost) that are
  already publicly known and tracked upstream — please link the upstream CVE
  or tracker entry.
- Issues that require privileged local access or a maliciously modified build
  environment (these describe a threat model this project does not defend
  against).

## Third-Party Dependencies

Dependabot is enabled for the GitHub Actions ecosystem. Security advisories for
C++ libraries (Qt, Hamlib, FFTW, boost) are tracked by following upstream
release channels; there is no package manifest inside this repository for
automated scanning of those dependencies.
