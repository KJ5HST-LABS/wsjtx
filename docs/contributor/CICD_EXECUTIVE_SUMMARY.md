# CI/CD for WSJT-X — Executive Summary

## What We Built

A fully automated build-and-release pipeline for WSJT-X that compiles the application on three platforms (macOS ARM64, Linux x86_64, Windows x86_64) every time code is pushed, and publishes release binaries with a single `git tag`.

## Why It Matters

WSJT-X currently has **zero build automation**. Every build is manual, every release requires someone to compile on each platform by hand, and there's no way to know if a code change breaks a platform until someone tries to build it. This pipeline gives the team instant feedback on every commit and eliminates the manual release process.

## How It Works

**On every push to `develop`:**
Code is automatically built on all three platforms in parallel. Green check = compiles everywhere. Red X = something broke. Results appear directly on the commit or pull request in GitHub.

**On a version tag (`v3.0.1`):**
All three platforms build, a GitHub Release is created with downloadable binaries (the macOS package is signed and notarized), and the source is automatically synced to the public repo.

## Proven Results

The pipeline has been prototyped and tested end-to-end in a fork (`KJ5HST-LABS/wsjtx-internal`).

| Platform | Build Time | Signed | Notes |
|----------|-----------|--------|-------|
| macOS ARM64 | ~8 min | Yes (Developer ID + Apple Notarization) | Gatekeeper-ready, no warnings |
| Linux x86_64 | ~7 min | Not yet | GPG signing can be added for package repos |
| Windows x86_64 | ~15 min | Not yet | See "Code Signing Gap" below |

The release pipeline was validated: tag push triggered three-platform builds, created a GitHub Release with all artifacts, and synced source + tag to the public repo — all automatically.

### Code Signing Gap: Windows and Linux

**Windows** is the most critical gap. Unsigned Windows binaries trigger SmartScreen warnings ("Windows protected your PC") that block users from running the application. Depending on the user's security settings, the binary may be silently quarantined by Windows Defender. This is a real barrier to distribution — users must click through multiple warnings to run an unsigned `.exe`.

Adding Windows Authenticode signing to the pipeline requires:

| Item | Details |
|------|---------|
| Code signing certificate | OV (Organization Validation) or EV (Extended Validation) from a CA like DigiCert, Sectigo, or SSL.com. OV typically costs $200-500/year. EV eliminates SmartScreen warnings immediately but requires a hardware token. |
| Signing tool | `signtool.exe` (Windows SDK, available on GitHub Actions runners) or `osslsigncode` (open-source, cross-platform) |
| CI integration | OV certs can be stored as `.pfx` secrets and used directly in CI. EV certs traditionally require a USB hardware token, but cloud-based signing services (DigiCert KeyLocker, SSL.com eSigner, Azure Trusted Signing) now allow EV signing in CI without hardware. |
| Secrets needed | `WINDOWS_SIGNING_CERT_PFX` (base64-encoded .pfx), `WINDOWS_SIGNING_CERT_PASSWORD`, and optionally a timestamp server URL |

The workflow is ready to accept a signing step — it would slot in after the build and before the artifact upload in `build-windows.yml`. The implementation is straightforward once the certificate is obtained.

**Linux** signing is less urgent. Linux users typically install software through package managers (apt, rpm) which have their own trust chains, or they build from source. GPG-signing release tarballs is good practice and simple to add (one secret: a GPG private key), but unsigned Linux binaries don't trigger the same kind of user-facing warnings that macOS and Windows do.

**Recommendation:** Prioritize Windows signing. It has the most direct impact on user experience and is the main reason users encounter warnings when downloading WSJT-X releases. The pipeline infrastructure is in place — the team just needs to decide on a certificate provider and whether OV or EV is appropriate.

## What It Takes to Deploy

**Five workflow files** copied to `.github/workflows/` — only two lines need changing (the public repo URL and branch name).

**Eight repository secrets today** — Apple signing certificates (4), Apple notarization credentials (3), and a GitHub token for public repo sync (1). Adding Windows signing would add 2 more (certificate + password). These are set once via `gh secret set` and don't touch the codebase.

**One prerequisite** — GitHub Actions must be enabled at the WSJTX org level (an admin setting).

No changes to the build system are required. One optional CMake change (`OMNIRIG_TYPE_LIB` variable) makes the Windows CI cleaner and is backward-compatible with local builds.

## Documentation

| Document | What It Covers |
|----------|---------------|
| [Development Workflow](DEVELOPMENT_WORKFLOW.md) | How team members and external contributors work, how the two repos relate, how CI/CD integrates into daily development, the release process, branch strategy, code review |
| [CI/CD Deployment Playbook](CICD_DEPLOYMENT_PLAYBOOK.md) | Step-by-step instructions to deploy the pipeline to the official WSJTX org — enabling Actions, creating secrets, adapting files, testing, troubleshooting |
| [CI/CD Proof of Concept](../planning/CICD_PROOF_OF_CONCEPT.md) | Technical details of the prototype: platform-specific build strategies, caching, Windows CI findings, patches applied |

## Next Steps

1. **Review and send the email draft** (`docs/contributor/drafts/email_cicd_proposal.md`) to the team. Once the team is on board, the Deployment Playbook has everything needed to stand up the current pipeline.
2. **Decide on Windows code signing.** Obtain an Authenticode certificate and add the signing step to the Windows workflow. This is the single highest-impact improvement remaining — it eliminates the SmartScreen warnings that affect every Windows user.
3. **Optionally, add Linux GPG signing** for release tarballs.
