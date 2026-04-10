**Subject:** CI/CD proof of concept — three platforms building, ready for review

Joe, Brian, all,

I prototyped a CI/CD pipeline for WSJT-X in a fork and wanted to share results before proposing anything for the official repos.

## What it does

Push to `develop` → automatic build on three platforms. Tag a version (`v*`) → build all three + create a GitHub Release with downloadable binaries + sync source to the public repo. Green check = compiles. Red X = something broke.

## Results

All three platforms build successfully from the raw WSJT-X source (no superbuild):

| Platform | Runner | Build time | Notes |
|----------|--------|------------|-------|
| macOS ARM64 | macos-15 | ~8 min | Signed + notarized via org secrets |
| Linux x86_64 | ubuntu-24.04 | ~7 min | Unsigned |
| Windows x86_64 | windows-latest + MSYS2 | ~15 min (cached) | MSYS2 MINGW64, unsigned |

Build times include Hamlib. With caching (Hamlib install, MSYS2 packages), repeat builds are faster.

## Architecture

Five workflow files, no duplicated build logic:

```
.github/workflows/
├── build-macos.yml      reusable, called by ci.yml and release.yml
├── build-linux.yml      reusable
├── build-windows.yml    reusable
├── ci.yml               push/PR trigger → calls all three builds
└── release.yml          tag trigger → builds + GitHub Release + public repo sync
```

Each platform build is a two-stage process: build Hamlib 4.7.0 from source, then build WSJT-X against it. This matches what developers do locally but automates the dependency chain. Hamlib installs are cached per-platform.

The release workflow pushes source and tags to the public repo automatically on tagged releases, preserving the current two-repo workflow.

## One CMake fix worth discussing

Windows CI needed a way to tell CMake where the OmniRig type library is when OmniRig isn't installed in the COM registry (which it isn't on a fresh CI runner). I added a `OMNIRIG_TYPE_LIB` CMake variable — when set, `dumpcpp` uses the file path directly instead of querying the registry. When not set, existing behavior is unchanged. This might be worth upstreaming since it makes the build more portable.

## Things I found along the way

- **MAP65** doesn't compile with GCC 15 — `decode0.f90` has legacy Fortran that the new compiler rejects. I skip it in CI for now. Not a WSJT-X issue per se, but worth knowing.
- **Deploy keys can't push workflow files** — GitHub platform restriction. The release workflow uses a fine-grained PAT instead.
- **MSYS2 renames Qt5 tools** with a `-qt5` suffix (`dumpcpp-qt5` instead of `dumpcpp`). Handled with a symlink in CI.
- **The `find_program` check for dumpcpp** in the existing CMake has a bug — `if (DUMPCPP-NOTFOUND)` checks a literal string, never a variable. It works anyway because dumpcpp is always found, but it's a latent issue.

## What I'd propose

If the team is interested, I could submit a PR to `wsjtx-internal` with these workflows. The CI would run on every push to `develop` and every PR, giving everyone immediate feedback on whether their changes compile across platforms. The release workflow could be enabled later when you're ready.

Happy to walk through any of this or adjust the approach. The fork is at `KJ5HST-LABS/wsjtx-internal` if anyone wants to look at the workflow files or build logs directly.

73, Terrell KJ5HST
