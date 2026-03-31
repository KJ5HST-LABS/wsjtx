# WSJT-X Build Fixes for CMake 4.x and Apple Silicon

These issues were encountered building WSJT-X 3.0.0-rc1 from the self-contained source tarball on macOS Apple Silicon (arm64). Both are build system issues — no application code changes are needed.

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

**Fix:**

```cmake
add_custom_target (wsjtx-do-install DEPENDS wsjtx-install)
add_custom_target (wsjtx-do-package DEPENDS wsjtx-package)
```

The `build` target on the line above (`add_custom_target (build ALL DEPENDS wsjtx-build)`) is not currently rejected but may also be at risk in future CMake versions.

**Impact:** Affects all platforms, not just macOS. Anyone upgrading to CMake 4.x will hit this.

## 2. Inner WSJT-X: macOS deployment target incompatible with arm64

**File:** `CMakeLists.txt` (inner wsjtx source)

**Problem:** The deployment target is hardcoded to macOS 10.12 (Sierra):

```cmake
set (CMAKE_OSX_DEPLOYMENT_TARGET 10.12 CACHE STRING "Earliest version of macOS supported")
```

Apple Silicon requires macOS 11.0 (Big Sur) as the minimum. No arm64 Mac has ever run anything earlier than 11.0.

**Workaround:** Override from the command line:

```
cmake -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 ...
```

**Suggested fix:**

```cmake
if (CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
  set (CMAKE_OSX_DEPLOYMENT_TARGET 11.0 CACHE STRING "Earliest version of macOS supported")
else ()
  set (CMAKE_OSX_DEPLOYMENT_TARGET 10.12 CACHE STRING "Earliest version of macOS supported")
endif ()
```

## Additional notes for arm64 macOS builds

These are not bugs in WSJT-X. They are environment details relevant to anyone building on Apple Silicon.

### Fortran compiler must be passed explicitly

When using the superbuild, the inner WSJT-X ExternalProject does not inherit the shell PATH. If `gfortran` is installed via Homebrew (the common case on macOS), it must be passed explicitly:

```
cmake -DCMAKE_Fortran_COMPILER=/opt/homebrew/bin/gfortran ...
```

### Homebrew Qt5 keg-only paths

Homebrew's Qt5 is keg-only (not linked into `/opt/homebrew/`). The Qt5 CMake config files compute the `_qt5Core_install_prefix` as three directories up from the config file location, which resolves to `/opt/homebrew/` — but the actual Qt5 files are under `/opt/homebrew/opt/qt@5/`. This causes `mkspecs/` and `plugins/` lookups to fail.

Workaround: create symlinks.

```bash
ln -s /opt/homebrew/opt/qt@5/mkspecs /opt/homebrew/mkspecs
ln -s /opt/homebrew/opt/qt@5/plugins /opt/homebrew/plugins
```

### OpenMP

AppleClang does not include OpenMP for C/C++. The existing `OR APPLE` codepath in the WSJT-X CMakeLists correctly handles this — the Fortran OpenMP library (`libgomp`) from Homebrew's GCC works fine.

## Build environment

- macOS 26.3.1 (Tahoe), Darwin 25.3.0, arm64
- CMake 4.3.1
- AppleClang 21.0.0
- GCC/gfortran 15.2.0 (Homebrew)
- Qt 5.15.18 (Homebrew, keg-only)
- Boost 1.90.0, FFTW 3.3.10, libusb 1.0.29 (all Homebrew)
- WSJT-X 3.0.0-rc1 self-contained source tarball
