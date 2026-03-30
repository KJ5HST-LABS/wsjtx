#!/usr/bin/env bash
set -euo pipefail

# Build WSJT-X jt9 natively on Apple Silicon macOS
# Usage: ./build.sh
# See BUILD_GUIDE.md for details and troubleshooting.

WSJTX_VERSION="3.0.0-rc1"
WSJTX_TARBALL="wsjtx-${WSJTX_VERSION}.tgz"
WSJTX_URL="https://sourceforge.net/projects/wsjt/files/wsjtx-${WSJTX_VERSION}/${WSJTX_TARBALL}/download"
WSJTX_SRC="wsjtx-${WSJTX_VERSION}"
BUILD_DIR="wsjtx-build"

# --- Preflight checks ---

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "Error: This script is for Apple Silicon (arm64) Macs." >&2
  exit 1
fi

if ! command -v brew &>/dev/null; then
  echo "Error: Homebrew is required. Install from https://brew.sh" >&2
  exit 1
fi

# --- Install dependencies ---

echo "==> Installing dependencies..."
brew install cmake gcc fftw boost qt@5 libusb

# --- Fix Homebrew Qt5 keg-only paths ---

QT5_PREFIX="$(brew --prefix qt@5)"

if [[ ! -e /opt/homebrew/mkspecs ]]; then
  echo "==> Symlinking Qt5 mkspecs..."
  ln -s "${QT5_PREFIX}/mkspecs" /opt/homebrew/mkspecs
fi

if [[ ! -e /opt/homebrew/plugins ]]; then
  echo "==> Symlinking Qt5 plugins..."
  ln -s "${QT5_PREFIX}/plugins" /opt/homebrew/plugins
fi

# --- Download source ---

if [[ ! -f "${WSJTX_TARBALL}" ]]; then
  echo "==> Downloading ${WSJTX_TARBALL}..."
  curl -L -o "${WSJTX_TARBALL}" "${WSJTX_URL}"
fi

# --- Extract ---

if [[ ! -d "${WSJTX_SRC}" ]]; then
  echo "==> Extracting..."
  tar xzf "${WSJTX_TARBALL}"
fi

# --- Patch superbuild for CMake 4.x ---

echo "==> Patching superbuild CMakeLists.txt for CMake 4.x..."
sed -i '' \
  -e 's/^add_custom_target (install DEPENDS/add_custom_target (wsjtx-do-install DEPENDS/' \
  -e 's/^add_custom_target (package DEPENDS/add_custom_target (wsjtx-do-package DEPENDS/' \
  "${WSJTX_SRC}/CMakeLists.txt"

# --- Configure ---

echo "==> Configuring..."
rm -rf "${BUILD_DIR}"
mkdir "${BUILD_DIR}"
cmake -S "${WSJTX_SRC}" -B "${BUILD_DIR}" \
  -DCMAKE_PREFIX_PATH="$(brew --prefix qt@5);$(brew --prefix libusb);$(brew --prefix fftw);$(brew --prefix boost)" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
  -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DWSJT_GENERATE_DOCS=OFF \
  -DWSJT_SKIP_MANPAGES=ON \
  -Wno-dev

# --- Build ---

echo "==> Building (this will take a few minutes)..."
cmake --build "${BUILD_DIR}"

# --- Verify ---

JT9="${BUILD_DIR}/wsjtx-prefix/src/wsjtx-build/jt9"

if [[ ! -f "${JT9}" ]]; then
  echo "Error: jt9 binary not found at ${JT9}" >&2
  exit 1
fi

ARCH="$(lipo -archs "${JT9}")"
if [[ "${ARCH}" != "arm64" ]]; then
  echo "Error: jt9 is ${ARCH}, expected arm64" >&2
  exit 1
fi

echo ""
echo "==> Build successful!"
echo "    Binary: ${JT9}"
echo "    Arch:   $(lipo -archs "${JT9}")"
echo "    Size:   $(du -h "${JT9}" | cut -f1)"
echo ""
echo "    To install: cp ${JT9} /usr/local/bin/"
