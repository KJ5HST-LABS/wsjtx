# CI/CD for WSJT-X — Executive Summary

## What We Built

A fully automated build-and-release pipeline for WSJT-X that compiles the application on three platforms (macOS ARM64, Linux x86_64, Windows x86_64) every time code is pushed, and publishes signed binaries with a single `git tag`.

## Why It Matters

WSJT-X currently has **zero build automation**. Every build is manual, every release requires someone to compile on each platform by hand, and there's no way to know if a code change breaks a platform until someone tries to build it. This pipeline gives the team instant feedback on every commit and eliminates the manual release process.

## How It Works

**On every push to `develop`:**
Code is automatically built on all three platforms in parallel. Green check = compiles everywhere. Red X = something broke. Results appear directly on the commit or pull request in GitHub.

**On a version tag (`v3.0.1`):**
All three platforms build, a GitHub Release is created with downloadable binaries (the macOS package is signed and notarized), and the source is automatically synced to the public repo.

## Proven Results

The pipeline has been prototyped and tested end-to-end in a fork (`KJ5HST-LABS/wsjtx-internal`).

| Platform | Build Time | Signed | Notarized |
|----------|-----------|--------|-----------|
| macOS ARM64 | ~8 min | Yes | Yes |
| Linux x86_64 | ~7 min | — | — |
| Windows x86_64 | ~15 min | — | — |

The release pipeline was validated: tag push triggered three-platform builds, created a GitHub Release with all artifacts, and synced source + tag to the public repo — all automatically.

## What It Takes to Deploy

**Five workflow files** copied to `.github/workflows/` — only two lines need changing (the public repo URL and branch name).

**Eight repository secrets** — Apple signing certificates (4), Apple notarization credentials (3), and a GitHub token for public repo sync (1). These are set once via `gh secret set` and don't touch the codebase.

**One prerequisite** — GitHub Actions must be enabled at the WSJTX org level (an admin setting).

No changes to the build system are required. One optional CMake change (`OMNIRIG_TYPE_LIB` variable) makes the Windows CI cleaner and is backward-compatible with local builds.

## Documentation

| Document | What It Covers |
|----------|---------------|
| [Development Workflow](DEVELOPMENT_WORKFLOW.md) | How team members and external contributors work, how the two repos relate, how CI/CD integrates into daily development, the release process, branch strategy, code review |
| [CI/CD Deployment Playbook](CICD_DEPLOYMENT_PLAYBOOK.md) | Step-by-step instructions to deploy the pipeline to the official WSJTX org — enabling Actions, creating secrets, adapting files, testing, troubleshooting |
| [CI/CD Proof of Concept](../planning/CICD_PROOF_OF_CONCEPT.md) | Technical details of the prototype: platform-specific build strategies, caching, Windows CI findings, patches applied |

## Next Step

Review and send the email draft (`docs/contributor/drafts/email_cicd_proposal.md`) to the team. Once the team is on board, the Deployment Playbook has everything needed to stand it up.
