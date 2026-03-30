# WSJT-X Native ARM Build for macOS

Native arm64 (Apple Silicon) build of the WSJT-X `jt9` decoder for macOS. The official WSJT-X macOS release ships as x86_64 only and runs under Rosetta 2. This project builds it natively.

Based on WSJT-X 3.0.0-rc1 from [SourceForge](https://sourceforge.net/projects/wsjt/files/wsjtx-3.0.0-rc1/).

## Quick start

```bash
./build.sh
```

This installs dependencies via Homebrew, downloads the source, patches it, builds it, and verifies the output. Takes a few minutes. The resulting binary lands at:

```
wsjtx-build/wsjtx-prefix/src/wsjtx-build/jt9
```

## Requirements

- Apple Silicon Mac (M1/M2/M3/M4)
- macOS 11.0+ (Big Sur or later)
- Xcode Command Line Tools (`xcode-select --install`)
- [Homebrew](https://brew.sh)

## What gets installed

The build script installs these via Homebrew:

| Package | Purpose |
|---------|---------|
| cmake | Build system |
| gcc | Provides gfortran for Fortran signal processing code |
| fftw | FFT library |
| boost | C++ logging |
| qt@5 | Shared memory IPC (Qt5 Core only, not the GUI) |
| libusb | USB access (hamlib dependency) |

## What gets built

The superbuild compiles two things:

1. **Hamlib** — radio control library, built from a bundled patched source
2. **WSJT-X** — the full application, including `jt9`, `wsprd`, and the GUI

The primary target is the `jt9` binary, but all targets are built since the superbuild wraps the inner build as a CMake ExternalProject.

## Manual build

If you prefer to run the steps yourself instead of using the script:

```bash
# Dependencies
brew install cmake gcc fftw boost qt@5 libusb

# Qt5 keg-only workaround (see below)
ln -s /opt/homebrew/opt/qt@5/mkspecs /opt/homebrew/mkspecs
ln -s /opt/homebrew/opt/qt@5/plugins /opt/homebrew/plugins

# Download and extract
curl -L -o wsjtx-3.0.0-rc1.tgz \
  "https://sourceforge.net/projects/wsjt/files/wsjtx-3.0.0-rc1/wsjtx-3.0.0-rc1.tgz/download"
tar xzf wsjtx-3.0.0-rc1.tgz

# Patch for CMake 4.x (see Upstream Issues below)
sed -i '' \
  -e 's/^add_custom_target (install DEPENDS/add_custom_target (wsjtx-do-install DEPENDS/' \
  -e 's/^add_custom_target (package DEPENDS/add_custom_target (wsjtx-do-package DEPENDS/' \
  wsjtx-3.0.0-rc1/CMakeLists.txt

# Configure and build
mkdir wsjtx-build && cd wsjtx-build
cmake \
  -DCMAKE_PREFIX_PATH="$(brew --prefix qt@5);$(brew --prefix libusb);$(brew --prefix fftw);$(brew --prefix boost)" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DWSJT_GENERATE_DOCS=OFF \
  -DWSJT_SKIP_MANPAGES=ON \
  -Wno-dev \
  ../wsjtx-3.0.0-rc1
cmake --build .

# Verify
file wsjtx-prefix/src/wsjtx-build/jt9
# Mach-O 64-bit executable arm64
```

## Upstream issues

Two issues in the WSJT-X source require workarounds for this build. These are documented in detail in [WSJT-X_BUILD_FIXES.md](WSJT-X_BUILD_FIXES.md) for potential contribution back to the project.

### CMake 4.x reserved target names

The superbuild defines custom targets named `install` and `package`, which CMake 4.x rejects as reserved. The build script renames them automatically.

### macOS deployment target

The inner WSJT-X CMakeLists.txt sets `CMAKE_OSX_DEPLOYMENT_TARGET` to 10.12 (Sierra). Apple Silicon requires 11.0+ (Big Sur). Overridden at configure time.

## Homebrew Qt5 keg-only workaround

Homebrew installs Qt5 as keg-only (under `/opt/homebrew/opt/qt@5/`) to avoid conflicting with Qt6. The Qt5 CMake config files resolve paths relative to `/opt/homebrew/`, so `mkspecs/` and `plugins/` directories are not found. The build script creates symlinks to bridge this gap.

If you later install Qt6, these symlinks may conflict — remove them with:

```bash
rm /opt/homebrew/mkspecs /opt/homebrew/plugins
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `asciidoctor is required` | Ensure `-DWSJT_GENERATE_DOCS=OFF` is set |
| Qt5 mkspecs/plugins not found | Run the symlink commands from the Qt5 section above |
| OpenMP not found | Normal on macOS. AppleClang has no OpenMP for C/C++. The build uses a special Apple codepath; Fortran OpenMP via gfortran still works |
| Linker warnings about deployment target mismatch | Harmless. Homebrew libs target your current OS; the binary targets 11.0+ |
| Git clone from SourceForge fails | Use the tarball download instead (the build script does this) |

## Files

| File | Description |
|------|-------------|
| `build.sh` | Automated build script |
| `BUILD_GUIDE.md` | Step-by-step manual build walkthrough |
| `WSJT-X_BUILD_FIXES.md` | Upstream bug details for contribution |

## Tested on

- MacBook Pro M5 Max, macOS 26.3.1 (Tahoe)
- AppleClang 21.0.0, CMake 4.3.1, GCC 15.2.0
