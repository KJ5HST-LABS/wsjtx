# Building WSJT-X jt9 natively on Apple Silicon macOS

This guide documents how to build the `jt9` decoder binary from WSJT-X 3.0.0-rc1 as a native arm64 binary on Apple Silicon Macs. The official WSJT-X macOS release ships as x86_64 and runs under Rosetta 2. This build produces a native binary.

## Prerequisites

- Apple Silicon Mac (M1/M2/M3/M4/M5)
- macOS 11.0 (Big Sur) or later
- Xcode Command Line Tools (`xcode-select --install`)
- Homebrew (`https://brew.sh`)

## Step 1: Install dependencies

```bash
brew install cmake gcc fftw boost qt@5 libusb
```

| Package | Why |
|---------|-----|
| cmake | Build system |
| gcc | Provides `gfortran` — WSJT-X signal processing code is Fortran |
| fftw | FFT library used by the decoders |
| boost | C++ libraries (logging) |
| qt@5 | Qt5 Core — used by jt9 for shared memory IPC with the GUI |
| libusb | USB device access (hamlib dependency) |

## Step 2: Fix Homebrew Qt5 keg-only paths

Homebrew installs Qt5 as "keg-only" (not linked into `/opt/homebrew`) to avoid conflicts with Qt6. However, Qt5's CMake config files resolve paths relative to `/opt/homebrew`, so two directories are missing. Create symlinks:

```bash
ln -s /opt/homebrew/opt/qt@5/mkspecs /opt/homebrew/mkspecs
ln -s /opt/homebrew/opt/qt@5/plugins /opt/homebrew/plugins
```

Without these, CMake will fail with errors about missing `mkspecs/macx-clang` or `plugins/platforms/libqcocoa.dylib`.

**Note:** If you later install Qt6 via Homebrew, these symlinks may conflict. Remove them if needed.

## Step 3: Download and extract the source

```bash
curl -L -o wsjtx-3.0.0-rc1.tgz \
  "https://sourceforge.net/projects/wsjt/files/wsjtx-3.0.0-rc1/wsjtx-3.0.0-rc1.tgz/download"
tar xzf wsjtx-3.0.0-rc1.tgz
```

This is the self-contained "superbuild" tarball. It includes bundled source for both hamlib and WSJT-X, so no network access is needed during the build.

Git cloning from SourceForge (`git clone https://git.code.sf.net/p/wsjt/wsjtx`) can be unreliable. The tarball is the more dependable path.

## Step 4: Patch the superbuild CMakeLists.txt

CMake 4.x rejects reserved target names. Edit `wsjtx-3.0.0-rc1/CMakeLists.txt` and find these lines (around line 199):

```cmake
add_custom_target (install DEPENDS wsjtx-install)
add_custom_target (package DEPENDS wsjtx-package)
```

Change them to:

```cmake
add_custom_target (wsjtx-do-install DEPENDS wsjtx-install)
add_custom_target (wsjtx-do-package DEPENDS wsjtx-package)
```

If you're using CMake 3.x, this patch is not required.

## Step 5: Configure

```bash
mkdir wsjtx-build && cd wsjtx-build

cmake \
  -DCMAKE_PREFIX_PATH="$(brew --prefix qt@5);$(brew --prefix libusb);$(brew --prefix fftw);$(brew --prefix boost)" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DWSJT_GENERATE_DOCS=OFF \
  -DWSJT_SKIP_MANPAGES=ON \
  -Wno-dev \
  ../wsjtx-3.0.0-rc1
```

Key flags explained:

| Flag | Purpose |
|------|---------|
| `CMAKE_PREFIX_PATH` | Tells CMake where to find Homebrew keg-only packages |
| `CMAKE_OSX_DEPLOYMENT_TARGET=11.0` | arm64 requires macOS 11.0+; the upstream default of 10.12 is invalid for Apple Silicon |
| `CMAKE_POLICY_VERSION_MINIMUM=3.5` | Allows the older CMake minimum version in the project to pass on CMake 4.x |
| `WSJT_GENERATE_DOCS=OFF` | Skips documentation build (requires `asciidoctor`, which is not needed for jt9) |
| `WSJT_SKIP_MANPAGES=ON` | Skips man page generation |

## Step 6: Build

```bash
cmake --build .
```

This builds hamlib first (from the bundled source), then configures and builds all of WSJT-X. The full build takes several minutes. If you only need `jt9`, you can let the full build complete — there is no way to build only the `jt9` target from the superbuild level since it wraps the inner build as an ExternalProject.

## Step 7: Verify

```bash
file wsjtx-prefix/src/wsjtx-build/jt9
# Expected: Mach-O 64-bit executable arm64

lipo -archs wsjtx-prefix/src/wsjtx-build/jt9
# Expected: arm64

wsjtx-prefix/src/wsjtx-build/jt9 --help
```

## Step 8: Install

Copy the binary wherever you need it:

```bash
cp wsjtx-prefix/src/wsjtx-build/jt9 /usr/local/bin/
```

Other useful binaries from the same build directory:

```
wsjtx-prefix/src/wsjtx-build/jt9
wsjtx-prefix/src/wsjtx-build/wsprd
wsjtx-prefix/src/wsjtx-build/wsjtx      (full GUI app bundle)
```

## Troubleshooting

### "The source directory does not appear to contain CMakeLists.txt"
You're pointing CMake at the wrong directory. Use the extracted `wsjtx-3.0.0-rc1/` directory, not a subdirectory.

### Qt5::Core or Qt5::Gui file not found errors
The Homebrew Qt5 symlinks from Step 2 are missing. Verify:
```bash
ls /opt/homebrew/mkspecs/macx-clang
ls /opt/homebrew/plugins/platforms/libqcocoa.dylib
```

### "asciidoctor is required to build the documentation"
Add `-DWSJT_GENERATE_DOCS=OFF` to your cmake command.

### OpenMP not found
Expected on macOS. AppleClang does not ship OpenMP for C/C++. The WSJT-X build handles this with a special Apple codepath (`OR APPLE` in the CMakeLists.txt) — Fortran OpenMP via gfortran still works. No action needed.

### Linker warnings about deployment target mismatch
```
ld: warning: building for macOS-11.0, but linking with dylib ... built for newer version 26.0
```
Harmless. Homebrew libraries are built for your current OS version, but the binary targets macOS 11.0+. It will run fine.

## Tested environment

- Mac mini M4, macOS 26.0 (Tahoe)
- Xcode CLT / AppleClang 21.0.0
- CMake 4.3.1
- GCC/gfortran 15.2.0 (Homebrew)
- Qt 5.15.18 (Homebrew)
- Boost 1.90.0, FFTW 3.3.10, libusb 1.0.29 (Homebrew)
- WSJT-X 3.0.0-rc1 source tarball (37.5 MB)
