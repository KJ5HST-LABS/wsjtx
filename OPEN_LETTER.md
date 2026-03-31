# Open Letter to the WSJT-X Development Team

Dear WSJT-X developers,

I'm Terrell Deppe, KJ5HST. I've been running WSJT-X on Apple Silicon Macs since the M1 came out, and like many hams in the same situation, I've been using the official x86_64 build under Rosetta 2. It works, but it's not ideal — especially for CPU-intensive decoding modes like Q65 and FST4 where native ARM performance would make a real difference.

I decided to see what it would take to produce a native arm64 build. The answer: not much. Your build system is well-structured and already architecture-aware. I was able to get WSJT-X 3.0.0-rc1 building natively on Apple Silicon with only two minor build system patches — no changes to any application code.

## What we built

The project is at **https://github.com/KJ5HST-LABS/WSJT-X-MAC-ARM64**

It's a GitHub Actions CI/CD pipeline that:

- Downloads the official WSJT-X source tarball from SourceForge
- Applies two small build system patches (see below)
- Compiles natively on a macOS arm64 runner
- Bundles all dependencies so the output is fully self-contained
- Signs with Developer ID and notarizes with Apple
- Publishes a `.pkg` installer, a `.dmg`, and individual self-contained CLI tool downloads

The full `wsjtx.app` GUI, `jt9`, `wsprd`, and all other tools build and run natively as arm64 Mach-O binaries.

## The two patches

### 1. CMake 4.x reserved target names

**File:** Superbuild `CMakeLists.txt`, line ~199

CMake 4.0 (released 2025) rejects `install` and `package` as custom target names since they're now reserved. Anyone building with CMake 4.x will hit this. The fix is a one-line rename:

```cmake
# Before
add_custom_target (install DEPENDS wsjtx-install)
add_custom_target (package DEPENDS wsjtx-package)

# After
add_custom_target (wsjtx-do-install DEPENDS wsjtx-install)
add_custom_target (wsjtx-do-package DEPENDS wsjtx-package)
```

The `build` target on the line above may also need renaming in a future CMake version.

### 2. macOS deployment target for arm64

**File:** Inner WSJT-X `CMakeLists.txt`

`CMAKE_OSX_DEPLOYMENT_TARGET` is set to 10.12 (Sierra). Apple Silicon requires macOS 11.0 (Big Sur) as the minimum — no arm64 Mac ever ran anything earlier. We override this at configure time:

```
cmake -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 ...
```

A conditional in the CMakeLists would handle this automatically:

```cmake
if (CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
  set (CMAKE_OSX_DEPLOYMENT_TARGET 11.0 CACHE STRING "Earliest macOS for arm64")
else ()
  set (CMAKE_OSX_DEPLOYMENT_TARGET 10.12 CACHE STRING "Earliest macOS for x86_64")
endif ()
```

## Additional build notes for macOS arm64

These aren't bugs — they're environment-specific details that came up during the build:

- **Fortran compiler:** `gfortran` from Homebrew's `gcc` package works perfectly. The compiler needs to be passed explicitly via `-DCMAKE_Fortran_COMPILER` when using the superbuild, since the inner ExternalProject doesn't inherit the PATH.

- **OpenMP:** AppleClang doesn't ship OpenMP for C/C++, but the existing `OR APPLE` codepath in the CMakeLists handles this correctly. Fortran OpenMP via gfortran works fine.

- **Qt5 on Homebrew:** Qt5 is "keg-only" on modern Homebrew (to avoid Qt6 conflicts). The Qt5 CMake config files resolve paths relative to the Homebrew prefix, which causes `mkspecs` and `plugins` directory lookups to fail. Symlinks work around this, but the official macOS build presumably doesn't use Homebrew for Qt.

- **Shared memory:** The `com.wsjtx.sysctl.plist` for configuring `kern.sysv.shmmax` and `kern.sysv.shmall` is already in the source tree under `Darwin/`. Our `.pkg` installer picks it up and installs it automatically.

## What we'd love to see

An official arm64 macOS build alongside the existing x86_64 release — or even a universal binary. The build system is already 99% there. The two patches above are all that's needed to compile. The remaining work is packaging (bundling dylibs, code signing, notarization), which is CI/CD infrastructure rather than code changes.

If it's useful, our entire CI pipeline is open source and MIT-licensed. The GitHub Actions workflow handles everything from download through notarized release in a single file. Feel free to adapt any of it.

## Contact

- **GitHub:** https://github.com/KJ5HST-LABS/WSJT-X-MAC-ARM64
- **Email:** kj5hst@deppe.com
- **Call:** KJ5HST

Thank you for WSJT-X. It's extraordinary software and the reason many of us got into weak signal work. Happy to help in any way with getting native arm64 into the official release.

73 de KJ5HST
