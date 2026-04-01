# CI/CD Workflow Reference

Detailed documentation of the GitHub Actions build pipeline in `.github/workflows/build.yml`.

## Overview

The workflow builds WSJT-X from the official source tarball on a macOS Apple Silicon runner, producing three deliverables:

1. **`.pkg` installer** — signed, notarized, installs app + CLI tools + shared memory config
2. **`.tar.gz` archives** — one per CLI tool, each self-contained with bundled libraries

## Triggers

- **Push to `main`** — automatic build and release
- **Manual dispatch** — trigger via GitHub Actions UI with a custom `wsjtx_version` input (defaults to `3.0.0-rc1`)

## Jobs

### `build` (macos-15)

Runs on GitHub's Apple Silicon macOS 15 runner. Steps:

#### 1. Install dependencies

```
brew install cmake gcc fftw boost qt@5 libusb dylibbundler
```

| Package | Role in build |
|---------|---------------|
| `cmake` | Build system for the superbuild and WSJT-X |
| `gcc` | Provides `gfortran` — all signal processing code is Fortran |
| `fftw` | Fast Fourier Transform library |
| `boost` | C++ logging (Boost.Log) |
| `qt@5` | GUI framework; CLI tools only use QtCore for shared memory IPC |
| `libusb` | USB device access, required by hamlib |
| `dylibbundler` | Automates dylib collection and `install_name_tool` rewriting for CLI tools |

#### 2. Locate gfortran

Homebrew installs gfortran with a versioned name (e.g., `gfortran-15`). The superbuild's inner ExternalProject doesn't inherit the shell PATH, so the Fortran compiler must be passed explicitly via `CMAKE_Fortran_COMPILER`.

The step checks `$(brew --prefix gcc)/bin/gfortran` first, then falls back to finding the highest-versioned binary in `/opt/homebrew/bin/`.

#### 3. Fix Qt5 keg-only paths

Homebrew's Qt5 is keg-only — installed under `/opt/homebrew/opt/qt@5/` but not linked into `/opt/homebrew/`. The Qt5 CMake config files compute paths relative to `/opt/homebrew/`, so two directories are missing:

- `/opt/homebrew/mkspecs` → symlinked to Qt5 keg's `mkspecs/`
- `/opt/homebrew/plugins` → symlinked to Qt5 keg's `plugins/`

Without these, CMake fails with errors about missing `mkspecs/macx-clang` or `plugins/platforms/libqcocoa.dylib`.

#### 4. Download and extract source

Downloads the self-contained superbuild tarball from SourceForge. This includes bundled source for both hamlib and WSJT-X — no network access needed during compilation.

We use the tarball rather than git clone because SourceForge git access is unreliable.

#### 5. Patch superbuild

Renames reserved CMake target names (`install` → `wsjtx-do-install`, `package` → `wsjtx-do-package`) for CMake 4.x compatibility. Applied via `sed` on the superbuild `CMakeLists.txt`.

#### 6. Configure

```
cmake -S wsjtx-3.0.0-rc1 -B wsjtx-build \
  -DCMAKE_PREFIX_PATH="qt5;libusb;fftw;boost" \
  -DCMAKE_Fortran_COMPILER=gfortran \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DWSJT_GENERATE_DOCS=OFF \
  -DWSJT_SKIP_MANPAGES=ON
```

Key flags:

| Flag | Purpose |
|------|---------|
| `CMAKE_PREFIX_PATH` | Tells CMake where Homebrew keg-only packages live |
| `CMAKE_Fortran_COMPILER` | Explicit path to gfortran (doesn't inherit from PATH in ExternalProject) |
| `CMAKE_OSX_DEPLOYMENT_TARGET=11.0` | arm64 requires macOS 11.0+; upstream defaults to 10.12 |
| `CMAKE_POLICY_VERSION_MINIMUM=3.5` | Allows the older cmake_minimum_required to pass on CMake 4.x |
| `WSJT_GENERATE_DOCS=OFF` | Skips asciidoctor dependency |
| `WSJT_SKIP_MANPAGES=ON` | Skips man page generation |

The superbuild forwards all command-line CMake variables to the inner WSJT-X build via a `get_cmake_property(CACHE_VARIABLES)` loop.

#### 7. Build

```
cmake --build wsjtx-build
```

This builds hamlib first (from bundled source, via autotools `./configure && make`), then configures and builds WSJT-X (via CMake ExternalProject). The full build takes ~10 minutes on the runner.

#### 8. Collect binaries

Copies built artifacts into two directories:

- `stage/` — everything for the installer (app bundle + CLI tools)
- `assets/` — CLI tools only (for individual tar.gz packaging)

#### 9. Bundle dylibs into app (`macdeployqt` + custom)

Two-phase bundling for the `.app` bundle:

**Phase 1: `macdeployqt`** — Qt's official deployment tool. Copies Qt frameworks and plugins into `Contents/Frameworks` and `Contents/PlugIns`, rewrites load paths to `@executable_path/../Frameworks/`.

**Phase 2: Custom bundling** — Handles non-Qt Homebrew dylibs that `macdeployqt` doesn't know about (fftw, boost, gcc runtime, libusb). For each:

1. Resolve the library path (handles both absolute `/opt/homebrew/` and `@rpath/` references)
2. Copy into `Contents/Frameworks/`
3. Rewrite the binary's load command via `install_name_tool -change`
4. Recursively process the library's own dependencies

The `@rpath/` resolution is critical for gcc libraries: `libgfortran.5.dylib` references `libgcc_s.1.1.dylib` and `libquadmath.0.dylib` via `@rpath/`, which resolves to the gcc lib directory.

#### 10. Bundle dylibs into CLI tools (`dylibbundler` + custom)

CLI tools are more complex than the app bundle because there's no standard framework structure. The process:

**`dylibbundler`** is called once with all binaries via multiple `-x` flags:

```
dylibbundler -od -b -x jt9 -x wsprd -x ... -d lib/ -p @loader_path/lib/
```

This collects all dylib dependencies, copies them to `lib/`, and rewrites load commands. Using a single call with all binaries avoids directory conflicts (multiple calls with `-od` would overwrite each other's output).

**Qt framework post-processing** — `dylibbundler` doesn't handle `.framework` bundles. For binaries that reference Qt frameworks (like `jt9` which uses `QtCore` for shared memory):

1. Extract the framework binary (e.g., `QtCore.framework/Versions/5/QtCore` → `lib/QtCore`)
2. Run `dylibbundler` on it to collect its transitive deps (pcre2, zstd, glib, icu, etc.)
3. Rewrite the main binary's load command from the framework path to `@loader_path/lib/QtCore`

**Lib-to-lib path correction** — `dylibbundler` sets all deps to `@loader_path/lib/<name>`. This is correct for binaries (the binary is one level above `lib/`), but wrong for libraries within `lib/` referencing each other. Those need `@loader_path/<name>` since they're already in the same directory. A post-processing loop fixes this.

**Duplicate `LC_RPATH` deduplication** — Qt framework binaries sometimes end up with duplicate `@loader_path/` rpath entries after processing. macOS dyld rejects libraries with duplicate rpaths. The fix deletes and re-adds each duplicate.

#### 11. Import signing certificates

Creates a temporary keychain and imports two `.p12` certificates from GitHub secrets:

- **Developer ID Application** — for signing binaries, frameworks, dylibs
- **Developer ID Installer** — for signing the `.pkg` installer

The keychain is configured with `set-key-partition-list` to allow `apple-tool:` and `apple:` access, which is required for `codesign` and `productbuild` to use the certificates without a GUI prompt.

#### 12. Code sign

All Mach-O objects are signed individually with hardened runtime and timestamps:

1. **App bundle (inside-out):**
   - Individual dylibs in `Contents/Frameworks/`
   - Framework bundles in `Contents/Frameworks/`
   - Plugins in `Contents/PlugIns/`
   - Main executable `Contents/MacOS/wsjtx`
   - Outer `.app` bundle
2. **CLI binaries** in both `stage/` and `assets/`
3. **Bundled dylibs** in `stage/lib/` and `assets/lib/`

Apple notarization requires every Mach-O to be signed individually with `--options runtime --timestamp`. Using just `codesign --deep` is insufficient.

#### 13. Build installer pkg

Creates a macOS installer package:

- **`pkgbuild`** creates a component package with:
  - `/Applications/wsjtx.app`
  - `/usr/local/wsjtx/` (CLI tools + `lib/`)
  - `/Library/LaunchDaemons/com.wsjtx.sysctl.plist`
  - A `postinstall` script that loads the sysctl plist and creates symlinks in `/usr/local/bin`

- **`productbuild`** wraps it in a distribution package with a nicer installer UI, signed with the Developer ID Installer certificate.

The sysctl plist configures shared memory limits (`kern.sysv.shmmax=52428800`, `kern.sysv.shmall=25600`) that WSJT-X requires. Without this, the app shows "Shared memory error" on launch.

#### 14. Notarize

Submits the PKG and CLI tools (as a zip) to Apple's notary service using `xcrun notarytool`. Waits for completion and staples the notarization ticket.

If notarization returns "Invalid", the workflow fetches the detailed Apple log showing which specific binary failed and why, then exits with an error.

#### 16. Package individual binaries

Each CLI tool is packaged as a self-contained `.tar.gz`:

```
jt9.tar.gz
├── jt9/
│   ├── jt9          (the binary)
│   └── lib/
│       ├── libgfortran.5.dylib
│       ├── libgomp.1.dylib
│       ├── QtCore
│       └── ... (26 dylibs total)
```

### `release` (ubuntu-latest)

Creates two GitHub releases:

1. **Versioned** (`v3.0.0-rc1`) — permanent, marked as prerelease for RC versions
2. **Latest** (`latest`) — rolling tag, always updated to the newest build, marked as the GitHub "Latest Release"

Both contain the PKG and all `.tar.gz` archives.

## Lessons learned

These are the issues we encountered and solved, documented for anyone attempting similar macOS arm64 CI builds:

1. **`install_name_tool` silently fails on signed binaries.** Modern Xcode ad-hoc signs all compiled binaries. `install_name_tool` warns but doesn't error — the path change is applied but the signature becomes invalid. Any subsequent `install_name_tool` call on the same file may fail or produce corrupt output. Solution: use `dylibbundler` which handles this correctly, or re-sign with `codesign --force --sign -` after each batch of changes.

2. **`dylibbundler -od` overwrites the destination directory.** When calling `dylibbundler` multiple times with different binaries sharing the same `lib/` output directory, each call with `-od` (overwrite dest) replaces the directory contents. Only the last binary's deps survive. Solution: call `dylibbundler` once with all binaries via multiple `-x` flags.

3. **`dylibbundler` doesn't handle `.framework` bundles.** Qt ships as framework bundles (`QtCore.framework/Versions/5/QtCore`), not flat dylibs. `dylibbundler` skips these. Solution: extract the framework binary manually, run `dylibbundler` on it for transitive deps, and rewrite the load command with `install_name_tool`.

4. **Lib-to-lib `@loader_path` is relative to the lib, not the binary.** `dylibbundler` sets all deps to `@loader_path/lib/<name>`. For a binary at `./jt9` loading `./lib/libfoo.dylib`, this is correct. But for `./lib/libfoo.dylib` loading `./lib/libbar.dylib`, the `@loader_path` resolves to `./lib/`, so the correct reference is `@loader_path/libbar.dylib` (no `lib/` prefix). This requires a post-processing fixup pass.

5. **Duplicate `LC_RPATH` entries crash dyld.** macOS dyld rejects Mach-O files with duplicate rpath entries. This can happen when both the original framework and `dylibbundler` add `@loader_path/`. Solution: detect and deduplicate after all processing.

6. **PKG signing requires a separate certificate.** `productbuild --sign` requires a "Developer ID Installer" certificate, not "Developer ID Application". These are different certificate types from Apple's developer portal.

7. **Notarization requires individual signing.** Apple's notary service checks every Mach-O inside a submission. `codesign --deep` is not sufficient — each framework, dylib, and plugin must be signed individually with `--options runtime --timestamp`.
