**Subject:** CI/CD pipeline for WSJT-X — built and tested, ready for deployment

Joe, Brian, all,

I built a CI/CD pipeline for WSJT-X and have it working end-to-end on all three platforms. Sharing the results and documentation so the team can evaluate whether to adopt it.

## What it does

Push to `develop` → automatic build on macOS ARM64, Linux x86_64, and Windows x86_64. Green check = compiles everywhere. Red X = something broke.

Tag a version (`v*`) → builds all three platforms, creates a GitHub Release with signed binaries, and syncs source + tag to the public repo. The two-repo workflow is preserved.

## Build results

| Platform | Build time (cached) | Signed | Notes |
|----------|-------------------|--------|-------|
| macOS ARM64 | ~8 min | Yes | Developer ID + Apple Notarization, Gatekeeper-ready |
| Linux x86_64 | ~7 min | No | GPG signing can be added |
| Windows x86_64 | ~15 min | Yes | Authenticode via existing certificate |

The release pipeline was validated end-to-end: tag push triggered three-platform builds, created a GitHub Release with all artifacts, and synced source + tag to the public repo automatically.

## What's needed to deploy

Five workflow files copied to `.github/workflows/`. Five lines need changing across two files (public repo URL, branch name, and version strings). Ten repository secrets (Apple signing/notarization credentials, Windows Authenticode certificate, and a GitHub PAT for public repo sync), set once via `gh secret set`. The team's existing macOS and Windows signing credentials are used directly — they just need to be exported as secrets for CI.

One prerequisite: GitHub Actions must be enabled at the WSJTX org level.

No changes to the build system are required. One optional CMake change (`OMNIRIG_TYPE_LIB` variable) makes the Windows build more portable — when set, `dumpcpp` uses a file path instead of querying the COM registry. When not set, existing behavior is unchanged.

## Things found along the way

- **MAP65** doesn't compile with GCC 15 — `decode0.f90` has legacy Fortran that the new compiler rejects. Skipped in CI. Not a WSJT-X issue per se, but worth knowing.
- **Deploy keys can't push workflow files** — GitHub platform restriction. The release workflow uses a fine-grained PAT instead.
- **MSYS2 renames Qt5 tools** with a `-qt5` suffix (`dumpcpp-qt5` instead of `dumpcpp`). Handled with a symlink in CI.
- **The `find_program` check for dumpcpp** in the existing CMake has a bug — `if (DUMPCPP-NOTFOUND)` checks a literal string, never a variable. It works because dumpcpp is always found, but it's a latent issue.

## Documentation

I wrote three documents that cover the full picture:

- **[Executive Summary](../1_CICD_EXECUTIVE_SUMMARY.md)** — two-page overview of what was built, what it produces, and what's needed to deploy
- **[Development Workflow](../2_DEVELOPMENT_WORKFLOW.md)** — how the two-repo model works, how CI/CD integrates into daily development, branch strategy, release process, code review
- **[Deployment Playbook](../3_CICD_DEPLOYMENT_PLAYBOOK.md)** — step-by-step instructions to stand up the pipeline on the official repos, including secrets, troubleshooting, and ongoing maintenance

If the team wants to move forward, I can submit a PR to `wsjtx-internal` with the workflow files. The Deployment Playbook covers the rest.

73, Terrell KJ5HST
