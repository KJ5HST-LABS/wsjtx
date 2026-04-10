# WSJT-X Process Optimization

Opportunities for the team as the project moves toward GitHub-based project management. Organized by category, with effort estimates. Some of these are five-minute fixes; others are team decisions that need discussion first.

---

## Quick Wins (minutes to hours)

### Repository Cleanup

**Stale PR #1 on wsjtx (public).** Open since Feb 2026. The issue template it proposed was already merged in wsjtx-internal as PRs #2 and #3. Close with a comment referencing the internal merge.

**Stale Issue #1 on wsjtx-internal.** Same issue template request. Close with reference to merged PRs.

**Typo branch `feat_mmty_interface`.** Confirm with K9AN whether it has unique commits vs. `feat_mmtty_interface`, then delete the typo branch.

**"IMPROVED by DG2YCB" branding in INSTALL file.** The official repo shouldn't carry fork branding from Uwe Risse's WSJT-X Improved variant. Clean up the ASCII art and update the version string in README (currently says 2.6.1).

**Dead URLs in source.** Commit messages and source files reference `bitbucket.org/k1jt/wsjtx` and old SourceForge paths. Search and replace with current GitHub URLs.

### Branch Protection

No branch protection rules exist on either repo. At minimum:

- **`develop` on wsjtx-internal:** Require PR reviews (1 approval), require CI status checks to pass, disable force-push.
- **`master` on wsjtx:** Disable force-push, disable direct pushes (only the release pipeline should write here).

This also enforces the "prefer merge commits" convention that's currently guidance-only. Disable squash and rebase in the merge options.

### Templates

**PR template** (`.github/pull_request_template.md`): Checklist for platform tested, description of change, related issues. Prevents reviewers from having to ask "what platform did you test on?" every time.

**Issue templates**: Bug report exists. Add templates for feature requests and refactoring proposals. Use GitHub's issue form YAML format so fields are structured.

### CODEOWNERS

The Development Workflow already documents who should review what. Turn that into a `.github/CODEOWNERS` file:

```
lib/ft8/**        @k1jt @k9an
lib/              @k1jt @k9an @w3sz
*.f90             @k1jt @k9an
CMakeLists.txt    @n9adg @kj5hst
.github/          @kj5hst
```

(Use GitHub usernames, not callsigns — the above are illustrative.) GitHub will auto-request reviewers. External contributors see who owns what.

---

## Communication (team decision required)

### Email to GitHub Discussions

Current state: team coordinates via email for release decisions, feature planning, architecture discussions. This works, but it creates an invisible history — new contributors can't see past decisions, and context gets lost in inboxes.

**Option:** Enable GitHub Discussions on wsjtx-internal. Categories: Announcements, Architecture, Release Planning. Email stays for anything that doesn't fit. No one has to stop using email — Discussions just creates a searchable, linkable record for decisions that affect the codebase.

This is a cultural change, not a technical one. Worth discussing as a team.

### Release Decisions

Currently implicit: "The team agrees (via email) that `develop` is ready for a point release." No documented criteria, no approval process.

Worth documenting even if the process stays informal: who can propose a release, what blocks one (failing CI, unresolved critical issues), how long to wait for feedback before tagging.

---

## Build & CI Gaps

### No Automated Tests in CI

CI currently checks one thing: does it compile? That's a significant improvement over nothing, but it doesn't catch regressions.

Current state: one test file exists (`test_qt_helpers.cpp`). Brian's pFUnit PR (#10) is in draft — it would add Fortran test infrastructure.

Path forward: unblock and merge Brian's pFUnit work, integrate Fortran tests into CI, run `test_qt_helpers` on every build. Even minimal test coverage is a step change from zero.

### No Code Quality Checks

CI doesn't check code style or linting. Not urgent, but as the contributor base grows, style debates in code review become time sinks. A `clang-tidy` step or elevated compiler warnings (`-Wall -Wextra`) would catch issues before review.

### No Documentation Generation

The codebase has good inline documentation (the UDP protocol spec in `NetworkMessage.hpp` is thorough). But it only exists in source files. A Doxygen step in CI, published to GitHub Pages, would make it accessible without reading source.

### Reference Test Data

CONTRIBUTING.md says "test with known `.wav` files" but no test files are in the repo. Adding a `tests/data/` directory with reference audio files for each mode would enable automated decoding tests and give contributors a concrete way to verify changes. May need git-lfs for file size.

---

## Version & Release Management

### Manual Version Bumps

Releasing requires updating version strings in `CMakeLists.txt`, `Versions.cmake`, and the CI workflow files. Multiple files, easy to miss one.

A `scripts/bump-version.sh` that updates all references in one pass would eliminate this. Could also add a CI check that verifies version consistency across files.

### No Automated Release Notes

Release notes are manual. GitHub can auto-generate them from PR titles grouped by label (features, fixes, docs). Alternatively, a `CHANGELOG.md` that's updated as part of the release workflow.

### Release Candidate Process

The branch naming convention includes `v*_test` for release candidates, but the workflow isn't documented. When to cut an RC branch, testing criteria, how RCs become final releases — worth writing down.

### SourceForge Distribution

Current process: after a GitHub Release, someone manually uploads artifacts to SourceForge. Two options:

1. Automate the SourceForge upload in the release workflow (rsync or API).
2. Retire SourceForge and point users to GitHub Releases.

Either way, decide and document it. Having two distribution channels with manual sync is a maintenance burden.

---

## CMake & Build System

### CMake 4.0 Compatibility

`add_custom_target(install ...)` and `add_custom_target(package ...)` use reserved names in CMake 4.0+. Rename to `wsjtx-do-install` and `wsjtx-do-package`. Small fix, prevents future breakage.

### macOS Deployment Target

Hardcoded to 10.12 (Sierra), but ARM64 requires macOS 11.0+ (Big Sur). Should be 11.0 for ARM64 builds.

### `dumpcpp` find_program Bug

`if (DUMPCPP-NOTFOUND)` checks a literal string, not the variable. Works because dumpcpp is always found, but will fail silently if it's ever missing. Fix: `if (NOT DUMPCPP_FOUND)`.

### MAP65 / GCC 15

`decode0.f90` has legacy Fortran that GCC 15 rejects. Currently skipped in CI. Worth filing an issue to fix the Fortran so MAP65 builds with modern compilers.

---

## External Contributor Experience

### Two-Repo Integration Friction

External PRs on the public repo must be manually cherry-picked by a team member and re-opened on wsjtx-internal. This is inherent to the two-repo model and can't be fully automated, but a GitHub Action could automate the cherry-pick step when a team member labels an external PR as "accepted."

### No Response Time Guidance

CONTRIBUTING.md says "be patient" — which is honest but vague. A concrete statement like "first response within two weeks; the team is volunteer" sets expectations without creating obligations. A GitHub Action could auto-label PRs as "awaiting-review" after N days.

### No README on the Public Repo

The first thing anyone sees when visiting `github.com/WSJTX/wsjtx` is... no README, or an outdated one (currently says version 2.6.1). A minimal README with a one-line description, download link, build instructions link, and license would help.

---

## Documentation

### GOVERNANCE.md

Roles and authority are implied but not documented. Who can merge PRs, who can tag releases, who holds signing certificates, how disagreements are resolved. Doesn't need to be formal — a half-page that says "Joe makes final calls, maintainers can merge with one approval, signing certs are held by [names]" is enough.

### Signing Certificate Ownership

Currently a knowledge silo. If the person holding the signing credentials is unavailable, releases can't be signed. Document who holds what, where certificates are stored, and the rotation schedule. The Deployment Playbook covers how to export them as CI secrets — that also serves as a backup.

### Superbuild Status

The superbuild is not on GitHub. It's distributed only via SourceForge tarballs. CI doesn't use it (the pipeline builds Hamlib directly). The team should decide: move it to GitHub (`WSJTX/wsjtx-superbuild`), document it as a legacy developer convenience, or deprecate it in favor of the CI-style two-stage build.

### Protocol Documentation

The UDP protocol spec lives in `NetworkMessage.hpp` source comments. It's thorough but only accessible to people reading C++ headers. Extracting it to `docs/PROTOCOL.md` (or generating it with Doxygen) would help external tool developers.

---

## Security & Maintenance

### Secret Rotation

The Deployment Playbook documents how to set secrets but not when to rotate them. GitHub PATs expire (1 year max). Apple certificates expire (5 years). Windows certificates expire (1-3 years). A simple table in a SECURITY.md or MAINTENANCE.md with "what expires when" and "who rotates it" prevents surprise build failures.

### Dependency Monitoring

Qt5, Hamlib, Boost — all pinned or semi-pinned. No automated monitoring for security updates. GitHub's Dependabot doesn't work well with CMake projects, but a scheduled GitHub Action that checks upstream release feeds would catch critical updates.

### Qt5 End of Life

Qt5 is approaching EOL. Not urgent, but a Qt6 migration will be significant work. Worth tracking as a long-term issue so the team can plan rather than react.

---

## Summary by Effort

**Minutes:** Close stale issues/PRs, delete typo branch, clean up branding.

**Hours:** Add PR/issue templates, CODEOWNERS, branch protection rules, README, fix CMake bugs.

**Days:** Deploy CI/CD pipeline, create GOVERNANCE.md, automate release notes, version bump script, extract protocol docs.

**Team decisions required:** GitHub Discussions adoption, SourceForge future, superbuild future, Qt6 migration timeline, release approval process.
