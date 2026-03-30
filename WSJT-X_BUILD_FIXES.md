# WSJT-X Build Fixes for CMake 4.x and Apple Silicon

These issues were encountered building WSJT-X 3.0.0-rc1 from the self-contained source tarball on macOS (Darwin 25.3.0, Apple Silicon / arm64) using CMake 4.3.1, Homebrew Qt 5.15.18, and GCC/gfortran 15.2.0.

## 1. Superbuild: Reserved CMake target names (CMake >= 4.0)

**File:** `CMakeLists.txt` (superbuild root, line ~199)

**Problem:** The superbuild defines custom targets named `install` and `package`:

```cmake
add_custom_target (install DEPENDS wsjtx-install)
add_custom_target (package DEPENDS wsjtx-package)
```

CMake 4.0+ rejects these because `install` and `package` are reserved built-in target names:

```
CMake Error at CMakeLists.txt:199 (add_custom_target):
  The target name "install" is reserved or not valid for certain CMake
  features, such as generator expressions, and may result in undefined
  behavior.
```

**Fix:** Rename the targets:

```cmake
add_custom_target (wsjtx-do-install DEPENDS wsjtx-install)
add_custom_target (wsjtx-do-package DEPENDS wsjtx-package)
```

The `build` target on the line above (`add_custom_target (build ALL DEPENDS wsjtx-build)`) is not currently rejected but may also be at risk in future CMake versions.

## 2. Inner WSJT-X: macOS deployment target incompatible with arm64

**File:** `CMakeLists.txt` (inner wsjtx source)

**Problem:** The deployment target is hardcoded to macOS 10.12 (Sierra):

```cmake
set (CMAKE_OSX_DEPLOYMENT_TARGET 10.12 CACHE STRING "Earliest version of macOS supported")
```

Apple Silicon requires macOS 11.0 (Big Sur) as the minimum deployment target. Building for arm64 with a target of 10.12 is invalid — no arm64 Mac ever ran anything earlier than 11.0.

**Workaround:** Override from the command line:

```
cmake -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 ...
```

**Suggested fix:** Conditionally set the deployment target based on architecture:

```cmake
if (CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
  set (CMAKE_OSX_DEPLOYMENT_TARGET 11.0 CACHE STRING "Earliest version of macOS supported")
else ()
  set (CMAKE_OSX_DEPLOYMENT_TARGET 10.12 CACHE STRING "Earliest version of macOS supported")
endif ()
```

## Build environment

- macOS 26.0 (Tahoe), Darwin 25.3.0, arm64
- CMake 4.3.1
- AppleClang 21.0.0
- GCC/gfortran 15.2.0 (Homebrew)
- Qt 5.15.18 (Homebrew, keg-only)
- Boost 1.90.0, FFTW 3.3.10, libusb 1.0.29 (all Homebrew)
- WSJT-X 3.0.0-rc1 self-contained source tarball

## Build command

```bash
brew install cmake gcc fftw boost qt@5 libusb

# Homebrew Qt5 keg-only workaround — CMake configs resolve paths
# relative to /opt/homebrew but keg files live under /opt/homebrew/opt/qt@5
ln -s /opt/homebrew/opt/qt@5/mkspecs /opt/homebrew/mkspecs
ln -s /opt/homebrew/opt/qt@5/plugins /opt/homebrew/plugins

tar xzf wsjtx-3.0.0-rc1.tgz
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
```

The resulting `jt9` binary is at `wsjtx-prefix/src/wsjtx-build/jt9` — native Mach-O arm64.
