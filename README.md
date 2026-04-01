# WSJT-X Native ARM Build for macOS

Native arm64 (Apple Silicon) build of WSJT-X for macOS. The official WSJT-X macOS release ships as x86_64 only and runs under Rosetta 2. This project builds the full application and all CLI tools natively for Apple Silicon.

Based on WSJT-X 3.0.0-rc1 from [SourceForge](https://sourceforge.net/projects/wsjt/files/wsjtx-3.0.0-rc1/).

## Downloads

Go to [Releases](https://github.com/KJ5HST-LABS/WSJT-X-MAC-ARM64/releases) or use the stable `latest` URLs:

| Download | Description |
|----------|-------------|
| [Installer (.pkg)](https://github.com/KJ5HST-LABS/WSJT-X-MAC-ARM64/releases/latest) | **Recommended.** Installs app, CLI tools, and shared memory config |
| [jt9.tar.gz](https://github.com/KJ5HST-LABS/WSJT-X-MAC-ARM64/releases/download/latest/jt9.tar.gz) | Self-contained JT9/FT8/FT4/Q65 decoder |
| [wsprd.tar.gz](https://github.com/KJ5HST-LABS/WSJT-X-MAC-ARM64/releases/download/latest/wsprd.tar.gz) | Self-contained WSPR decoder |

All downloads are signed with Developer ID and notarized by Apple. No Homebrew or other dependencies required.

```bash
# Example: download and run jt9 directly
curl -LO https://github.com/KJ5HST-LABS/WSJT-X-MAC-ARM64/releases/download/latest/jt9.tar.gz
tar xzf jt9.tar.gz
./jt9/jt9 --help
```

## What this project does

This repository contains a GitHub Actions CI/CD pipeline that:

1. Downloads the official WSJT-X source tarball from SourceForge
2. Patches it for compatibility with modern CMake and Apple Silicon
3. Compiles everything natively on an arm64 GitHub Actions runner
4. Bundles all dynamic libraries so binaries are fully self-contained
5. Signs everything with a Developer ID certificate
6. Notarizes with Apple so there are no Gatekeeper warnings
7. Publishes versioned releases and a rolling `latest` tag

No source code from WSJT-X is modified or stored in this repository. The patches are limited to build system fixes.

## Why this exists

As of WSJT-X 3.0.0-rc1, the official macOS release is x86_64 only. On Apple Silicon Macs (M1 through M5), it runs under Rosetta 2 translation. While this works, native arm64 execution offers better performance — particularly relevant for CPU-intensive decode operations like FT8, Q65, and FST4.

The WSJT-X build system already supports arm64 — it uses `CMAKE_SYSTEM_PROCESSOR` for architecture detection and has Apple-specific codepaths. Only a few small fixes were needed to get it building and running natively. See [WSJT-X_BUILD_FIXES.md](WSJT-X_BUILD_FIXES.md) for details.

## Build system patches

Two patches are applied to the official source. Neither modifies any WSJT-X application code.

### 1. CMake 4.x compatibility (superbuild)

The superbuild `CMakeLists.txt` defines custom targets named `install` and `package`. CMake 4.0+ rejects these as reserved names. The patch renames them:

```cmake
# Before
add_custom_target (install DEPENDS wsjtx-install)
add_custom_target (package DEPENDS wsjtx-package)

# After
add_custom_target (wsjtx-do-install DEPENDS wsjtx-install)
add_custom_target (wsjtx-do-package DEPENDS wsjtx-package)
```

### 2. macOS deployment target override

The inner WSJT-X `CMakeLists.txt` hardcodes `CMAKE_OSX_DEPLOYMENT_TARGET` to 10.12 (Sierra). Apple Silicon requires macOS 11.0 (Big Sur) as the minimum. Overridden at configure time with `-DCMAKE_OSX_DEPLOYMENT_TARGET=11.0`.

## How the CI/CD pipeline works

The [build workflow](.github/workflows/build.yml) runs on `macos-15` (Apple Silicon runner) and produces three types of artifacts:

### App bundle (PKG)

- Built using the WSJT-X superbuild (hamlib + wsjtx)
- Qt frameworks bundled via `macdeployqt`
- Non-Qt Homebrew dylibs (fftw, boost, gcc/gfortran, libusb) bundled manually into `Contents/Frameworks` with `install_name_tool` path rewriting
- The `.pkg` installer additionally:
  - Installs `wsjtx.app` to `/Applications`
  - Installs CLI tools to `/usr/local/wsjtx` with symlinks in `/usr/local/bin`
  - Installs `com.wsjtx.sysctl.plist` to `/Library/LaunchDaemons` and runs a postinstall script to configure shared memory (`kern.sysv.shmmax=52428800`, `kern.sysv.shmall=25600`), which WSJT-X requires

### Self-contained CLI tools (tar.gz)

Each CLI tool (jt9, wsprd, ft8code, etc.) is packaged as a `.tar.gz` containing the binary and a `lib/` directory with all required dynamic libraries. No external dependencies needed.

The bundling process uses [`dylibbundler`](https://github.com/auriamg/macdylibbundler) to handle dylib collection and `install_name_tool` rewriting, with post-processing for:

- **Qt framework references** — `dylibbundler` doesn't handle `.framework` bundles, so `QtCore` is extracted and relinked manually
- **Lib-to-lib path correction** — `dylibbundler` sets `@loader_path/lib/` for all deps, but libraries within `lib/` referencing each other need `@loader_path/` (no `lib/` prefix since they're already in that directory)
- **Duplicate `LC_RPATH` deduplication** — Qt framework binaries sometimes end up with duplicate rpath entries after processing, which causes dyld to reject the library

### Code signing and notarization

All binaries, frameworks, plugins, and dylibs are signed individually with a Developer ID Application certificate using hardened runtime (`--options runtime`) and secure timestamps (`--timestamp`). The `.pkg` is signed with a Developer ID Installer certificate. Everything is submitted to Apple's notary service and stapled.

Signing secrets are stored as GitHub organization secrets:

| Secret | Purpose |
|--------|---------|
| `DEVELOPER_ID_CERTIFICATE_P12` | Application signing cert (base64) |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | Password for above |
| `DEVELOPER_ID_INSTALLER_P12` | Installer signing cert (base64) |
| `DEVELOPER_ID_INSTALLER_PASSWORD` | Password for above |
| `APPLE_ID` | Apple ID for notarization |
| `APPLE_ID_PASSWORD` | App-specific password for notarization |
| `APPLE_TEAM_ID` | Apple Developer team ID |

## Building locally

### Requirements

- Apple Silicon Mac (M1/M2/M3/M4/M5)
- macOS 11.0+ (Big Sur or later)
- Xcode Command Line Tools (`xcode-select --install`)
- [Homebrew](https://brew.sh)

### Quick start

```bash
./build.sh
```

### Manual build

```bash
brew install cmake gcc fftw boost qt@5 libusb

# Qt5 keg-only workaround
ln -s /opt/homebrew/opt/qt@5/mkspecs /opt/homebrew/mkspecs
ln -s /opt/homebrew/opt/qt@5/plugins /opt/homebrew/plugins

curl -L -o wsjtx-3.0.0-rc1.tgz \
  "https://sourceforge.net/projects/wsjt/files/wsjtx-3.0.0-rc1/wsjtx-3.0.0-rc1.tgz/download"
tar xzf wsjtx-3.0.0-rc1.tgz

# Patch for CMake 4.x
sed -i '' \
  -e 's/^add_custom_target (install DEPENDS/add_custom_target (wsjtx-do-install DEPENDS/' \
  -e 's/^add_custom_target (package DEPENDS/add_custom_target (wsjtx-do-package DEPENDS/' \
  wsjtx-3.0.0-rc1/CMakeLists.txt

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

See [BUILD_GUIDE.md](BUILD_GUIDE.md) for a detailed step-by-step walkthrough including troubleshooting.

## Homebrew Qt5 keg-only workaround

Homebrew installs Qt5 as keg-only under `/opt/homebrew/opt/qt@5/` to avoid conflicts with Qt6. The Qt5 CMake config files resolve paths relative to `/opt/homebrew/`, so `mkspecs/` and `plugins/` are not found. The build creates symlinks to bridge this. If you later install Qt6:

```bash
rm /opt/homebrew/mkspecs /opt/homebrew/plugins
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `asciidoctor is required` | Add `-DWSJT_GENERATE_DOCS=OFF` to cmake |
| Qt5 mkspecs/plugins not found | Create the symlinks from the Qt5 section above |
| OpenMP not found | Normal — AppleClang has no OpenMP for C/C++. Fortran OpenMP via gfortran works. The build handles this |
| Shared memory error on launch | Install the sysctl plist (the .pkg does this automatically) |
| Linker warnings about deployment target | Harmless — Homebrew libs target your OS, binary targets 11.0+ |
| Git clone from SourceForge fails | Use the tarball (build script does this) |
| Gatekeeper "damaged" or "unverified" | Releases from this repo are signed and notarized. For local builds: `xattr -cr wsjtx.app` |

## Files

| File | Description |
|------|-------------|
| `.github/workflows/build.yml` | CI/CD pipeline — build, bundle, sign, notarize, release |
| `build.sh` | Local build script |
| `BUILD_GUIDE.md` | Step-by-step manual build walkthrough |
| `WSJT-X_BUILD_FIXES.md` | Upstream build system fixes for contribution |
| `OPEN_LETTER.md` | Letter to the WSJT-X development team |

## Tested on

- MacBook Pro M5 Max, macOS 26.3.1 (Tahoe)
- GitHub Actions macos-15 runner (Apple Silicon)
- AppleClang 21.0.0, CMake 4.3.1, GCC/gfortran 15.2.0

## License

WSJT-X is licensed under GPLv3. This repository contains no WSJT-X source code — only build scripts, CI configuration, and documentation.
