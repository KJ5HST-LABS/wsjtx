**Subject:** CI/CD for WSJT-X — where I'm headed next

Joe, Brian, all,

Now that 3.0.0 is out and settling in, I'd like to turn my attention to build automation.

## Current state

- `wsjtx-internal` has no CI/CD — every build is manual
- I have a working macOS ARM64 pipeline that builds WSJT-X from source using a two-stage approach (Hamlib from GitHub, then WSJT-X via CMake, no superbuild). It produces signed, notarized binaries on every run.

## Plan

I'm going to set up GitHub Actions workflows on `wsjtx-internal` that build on every push/PR to `develop`. Green check = compiles. Red X = something broke. The public repo stays untouched — it keeps receiving tagged releases the same way it does now.

**Phase 1 — macOS** (ready to go, proven approach)
**Phase 2 — Linux** (straightforward, all deps in apt)
**Phase 3 — Windows** (will need a pointer to the current build steps)

Down the road this could extend to tag-triggered release builds, but that's a separate conversation.

## What I need

- Write access on wsjtx-internal (or I'll fork and PR)
- GitHub Actions enabled at the org level (admin setting)
- For Windows: any notes on the current toolchain (MSYS2/MinGW? Visual Studio?)

I'll prototype in a fork first and submit a PR when it's working.

73, Terrell KJ5HST
