# Contributing

Thank you for your interest in contributing to this WSJT-X build project.
This document covers the short version. For the full picture — how this
repository relates to upstream WSJT-X, why certain workflows are structured
the way they are, and the ethics of a downstream build project contributing
back upstream — please read
[`docs/contributor/CONTRIBUTION_PLAN.md`](docs/contributor/CONTRIBUTION_PLAN.md).

## What This Repository Is

This repository is the arm64 macOS build pipeline for WSJT-X. It produces
signed, notarized `.pkg` installers for Apple Silicon and publishes them
to GitHub Releases. The C++/Fortran source it builds lives upstream at
[`WSJTX/wsjtx`](https://github.com/WSJTX/wsjtx) and
[`WSJTX/wsjtx-internal`](https://github.com/WSJTX/wsjtx-internal) — this
repo is a build/packaging layer on top of that source.

**Source changes belong upstream.** If you have a patch to the decoder, UI,
or any `.cpp`/`.f90`/`.ui`/`.py` file, open it against
`WSJTX/wsjtx-internal` directly, not here. This repository's scope is CI,
signing, packaging, release publishing, and the consumer-distribution
mirror.

## What Belongs Here

- Changes to `.github/workflows/*.yml` — CI, release, scheduled jobs.
- Changes to macOS-specific packaging artifacts — `entitlements.plist`,
  notarization / signing helpers, `.pkg` postinstall scripts if any.
- Changes to `docs/contributor/` — planning, audit, and replication docs.
- Build-time patches applied during CI (these are deliberately not
  committed to the source tree; they live inside the workflow files as
  `sed` edits or downloaded patch files — see the playbook).

## How to Propose a Change

1. Fork the repository and create a topic branch off `develop`:
   `git checkout -b feat/<short-description>` or `fix/<short-description>`.
2. Make your change. Keep it focused — one logical change per PR.
3. Run the build equivalent locally if possible. For workflow changes,
   validate YAML syntax at minimum; `act` (https://github.com/nektos/act)
   can run many jobs locally against Docker, but macOS-signed and Windows
   Authenticode jobs will only complete on GitHub-hosted runners.
4. Open a PR against `develop`. Reference any relevant issues in the body.
5. CI runs `ci.yml` — four platform builds plus a `prepare` job that
   extracts the version from `CMakeLists.txt`. All five checks must pass.
6. A code owner (`CODEOWNERS`) will review. Small workflow and docs
   changes typically merge quickly; anything touching `release.yml` or
   the signing path receives closer scrutiny.

## PR Discipline

- **Commit messages** follow
  [Conventional Commits](https://www.conventionalcommits.org/):
  `feat:` / `fix:` / `docs:` / `ci:` / `refactor:` / `test:` / `chore:`.
  A scope is optional but welcome: `feat(ci-windows): cache MSYS2 pacman`.
- **PR title** is a one-line summary in the same format. The body can be
  longer: describe *why*, reference audit items or plan phases if
  applicable, and explain any operational impact (e.g., "this changes a
  `required_status_check` name — branch protection must be updated").
- **Squash-merge** is the default for feature PRs; a merge commit is
  acceptable for long-lived feature branches where individual commits
  carry meaning.

## Security Reports

Do not open public issues for suspected security vulnerabilities. See
[`SECURITY.md`](SECURITY.md) for the private reporting channel.

## Code of Conduct

All interaction in issues, PRs, and comments is governed by
[`.github/CODE_OF_CONDUCT.md`](.github/CODE_OF_CONDUCT.md).

## License

By contributing, you agree that your contributions will be licensed under
the same GNU General Public License v3 that governs the rest of the
project. See [`LICENSE`](LICENSE) for the full text.
