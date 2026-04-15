# CI/CD for WSJT-X — Executive Summary

## What We Built

A fully automated build-and-release pipeline for WSJT-X that compiles the application on three platforms (macOS ARM64, Linux x86_64, Windows x86_64) every time code is pushed, and publishes signed release binaries with a single `git tag`.

## Current State

WSJT-X has no build automation. Builds are manual, releases require compiling on each platform by hand, and there's no automated way to know if a change breaks a platform. This pipeline provides per-commit build verification across all three platforms and automates the release process.

## How It Works

**On every push to `develop`:**
Code is automatically built on all three platforms in parallel. Green check = compiles everywhere. Red X = something broke. Results appear directly on the commit or pull request in GitHub.

**On a version tag (`v3.0.1`):**
All three platforms build, a GitHub Release is created with signed, downloadable binaries, and the source is automatically synced to the public repo.

## Test Results

The pipeline has been prototyped and tested end-to-end in a private fork.

| Platform | Build Time | Signed | Notes |
|----------|-----------|--------|-------|
| macOS ARM64 | ~8 min | Yes | Developer ID + Apple Notarization, Gatekeeper-ready |
| Linux x86_64 | ~7 min | No | GPG signing can be added for package repos |
| Windows x86_64 | ~15 min | Yes | Authenticode via existing certificate |

The release pipeline was validated: tag push triggered three-platform builds, created a GitHub Release with all artifacts, and synced source + tag to the public repo — all automatically.

### Code Signing in CI

The pipeline integrates the team's existing macOS and Windows signing credentials. Both are stored as repository secrets and used automatically during builds — no manual signing step required.

**macOS:** The build signs the application binary and dylibs with the Developer ID Application certificate, signs the `.pkg` installer with the Developer ID Installer certificate, and submits the package to Apple for notarization. The resulting `.pkg` passes Gatekeeper without warnings.

**Windows:** The build signs executables (`wsjtx.exe`, `jt9.exe`, `wsprd.exe`) with the team's Authenticode certificate via `signtool.exe`. The signing step is structured to skip gracefully if the secrets aren't configured, so CI builds still succeed unsigned during initial setup.

**Linux:** Unsigned for now. Linux users don't encounter the same install-time warnings as macOS and Windows. GPG-signing release tarballs is straightforward to add if the team wants it — one additional secret (GPG private key) and a small step in the release workflow.

The Deployment Playbook covers how to export the existing certificates as CI secrets.

## What It Takes to Deploy

**Five workflow files** copied to `.github/workflows/` — five lines need changing across two files (the public repo URL, branch name, and version strings).

**Ten repository secrets** — Apple signing certificates (4), Apple notarization credentials (3), Windows Authenticode certificate and password (2), and a GitHub token for public repo sync (1). The team's existing signing credentials are used directly — they just need to be exported as base64-encoded secrets. Set once via `gh secret set`.

The Apple Developer account is currently held by **John G4KLA**, who produces the team's existing signed/notarized macOS releases. Adopting this pipeline does not require transferring the account — John exports his existing Developer ID certificates as `.p12` files and they become CI secrets. See the [Deployment Playbook](3_CICD_DEPLOYMENT_PLAYBOOK.md#secrets-2-5-macos-code-signing-certificates) for the handoff workflow.

**One prerequisite** — GitHub Actions must be enabled at the WSJTX org level (an admin setting).

No changes to the build system are required. One optional CMake change (`OMNIRIG_TYPE_LIB` variable) makes the Windows CI cleaner and is backward-compatible with local builds.

## Documentation

| Document | What It Covers |
|----------|---------------|
| [Development Workflow](2_DEVELOPMENT_WORKFLOW.md) | How team members and external contributors work, how the two repos relate, how CI/CD integrates into daily development, the release process, branch strategy, code review |
| [CI/CD Deployment Playbook](3_CICD_DEPLOYMENT_PLAYBOOK.md) | Step-by-step instructions to deploy the pipeline to the official WSJTX org — enabling Actions, creating secrets, adapting files, testing, troubleshooting |
| Workflow files (included in PR) | Platform-specific build strategies, caching, Windows CI findings, patches applied |

## Next Steps

1. **Send the proposal email** to the team. Once the team is on board, the Deployment Playbook has everything needed to stand up the pipeline.
2. **Export existing signing credentials as CI secrets.** The Deployment Playbook has step-by-step instructions for both macOS and Windows certificates.
3. **Optionally, add Linux GPG signing** for release tarballs.
