#!/usr/bin/env bash
# Package the command-line programs into one archive per platform, published
# as release downloads beside the installers.
#
#   package-cli-tools.sh --platform macos|linux|windows --version V --arch A \
#       --tools FILE --source DIR --out DIR [--dll-dir DIR --system-dir DIR]
#
# --tools is the build directory's cli-tools.txt, written at configure time
# from the installed and archive-only lists in CMake/Install.cmake. Every
# tool in it must be present under --source, or the script fails naming the
# missing ones.
#
# macos:   --source is the CLI assets directory: the tools plus the deployed
#          lib/ directory of relocated dylibs, which is packaged with them.
# linux:   --source is the CMake build directory. The binaries link the
#          distribution's runtime libraries; an RPATH or RUNPATH entry inside
#          the build tree fails the run.
# windows: --source is the CMake build directory, --dll-dir the staged bin/
#          after DLL fixup and --system-dir the Windows system directory. The
#          .exe files are packaged with the transitive closure of the DLLs
#          they import from --dll-dir; an import found in neither directory
#          fails the run.
set -euo pipefail

PLATFORM=""; VERSION=""; ARCH=""; TOOLS_FILE=""; SOURCE=""; OUT=""; DLL_DIR=""; SYSTEM_DIR=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --platform) PLATFORM="$2"; shift 2 ;;
    --version) VERSION="$2"; shift 2 ;;
    --arch) ARCH="$2"; shift 2 ;;
    --tools) TOOLS_FILE="$2"; shift 2 ;;
    --source) SOURCE="$2"; shift 2 ;;
    --out) OUT="$2"; shift 2 ;;
    --dll-dir) DLL_DIR="$2"; shift 2 ;;
    --system-dir) SYSTEM_DIR="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
for v in PLATFORM VERSION ARCH TOOLS_FILE SOURCE OUT; do
  if [ -z "${!v}" ]; then echo "missing --$(echo "$v" | tr '[:upper:]_' '[:lower:]-')" >&2; exit 2; fi
done
[ -d "$SOURCE" ] || { echo "::error::source directory not found: $SOURCE" >&2; exit 1; }
[ -s "$TOOLS_FILE" ] || { echo "::error::tool list not found or empty: $TOOLS_FILE" >&2; exit 1; }

TOOLS=()
while IFS= read -r tool; do
  tool="${tool%$'\r'}"   # the Windows runner's cli-tools.txt has CRLF endings
  [ -n "$tool" ] && TOOLS+=("$tool")
done < "$TOOLS_FILE"

case "$PLATFORM" in
  macos) NAME="wsjtx-${VERSION}-${ARCH}-macOS-tools"; EXT="" ;;
  linux) NAME="wsjtx-${VERSION}-linux-${ARCH}-tools"; EXT="" ;;
  windows) NAME="wsjtx-${VERSION}-windows-${ARCH}-tools"; EXT=".exe" ;;
  *) echo "unknown platform: $PLATFORM" >&2; exit 2 ;;
esac

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
DEST="${WORK}/${NAME}"
mkdir -p "$DEST" "$OUT"

missing=()
for tool in "${TOOLS[@]}"; do
  if [ -f "${SOURCE}/${tool}${EXT}" ]; then
    cp "${SOURCE}/${tool}${EXT}" "${DEST}/"
  else
    missing+=("${tool}${EXT}")
  fi
done
if [ "${#missing[@]}" -gt 0 ]; then
  echo "::error::tools listed in ${TOOLS_FILE} are missing under ${SOURCE}: ${missing[*]}" >&2
  exit 1
fi

case "$PLATFORM" in
  macos)
    [ -d "${SOURCE}/lib" ] || { echo "::error::deployed lib/ directory not found under ${SOURCE}" >&2; exit 1; }
    cp -R "${SOURCE}/lib" "${DEST}/lib"
    ;;
  linux)
    # The cache holds the build tree's path as the build saw it; the ARMHF
    # build runs in a container at /work, not at --source.
    build_tree=$(sed -n 's/^CMAKE_CACHEFILE_DIR:INTERNAL=//p' "${SOURCE}/CMakeCache.txt" 2>/dev/null || true)
    [ -n "$build_tree" ] || { echo "::error::no build directory recorded in ${SOURCE}/CMakeCache.txt" >&2; exit 1; }
    runpath_re='\((RUNPATH|RPATH)\).*Library[[:space:]](runpath|rpath):[[:space:]]\[([^]]+)\]'
    leaks=()
    for tool in "${TOOLS[@]}"; do
      dynamic=$(readelf -dW "${DEST}/${tool}")
      while IFS= read -r line; do
        [[ "$line" =~ $runpath_re ]] || continue
        IFS=: read -r -a entries <<< "${BASH_REMATCH[3]}"
        for entry in "${entries[@]}"; do
          case "$entry" in
            "$build_tree"|"$build_tree"/*) leaks+=("${tool}:${entry}") ;;
          esac
        done
      done <<< "$dynamic"
    done
    if [ "${#leaks[@]}" -gt 0 ]; then
      echo "::error::RPATH/RUNPATH entries inside the build tree ${build_tree}: ${leaks[*]}" >&2
      exit 1
    fi
    cat > "${DEST}/README.txt" <<README
WSJT-X ${VERSION} command-line tools for Linux (${ARCH})

These programs link shared libraries of the distribution they were built against; \`ldd <program>\` names any that are missing. The programs the WSJT-X packages install are also inside the AppImage with their libraries bundled (--appimage-extract, then squashfs-root/usr/bin).
README
    ;;
  windows)
    [ -n "$DLL_DIR" ] && [ -d "$DLL_DIR" ] || { echo "::error::--dll-dir is required for windows" >&2; exit 2; }
    [ -n "$SYSTEM_DIR" ] && [ -d "$SYSTEM_DIR" ] || { echo "::error::--system-dir is required for windows" >&2; exit 2; }
    # Plain indexed arrays and lookup files keep this runnable on bash 3.2.
    have="${WORK}/have.tsv"
    : > "$have"
    for dll in "$DLL_DIR"/*.dll "$DLL_DIR"/*.DLL; do
      [ -e "$dll" ] || continue
      printf '%s\t%s\n' "$(basename "$dll" | tr '[:upper:]' '[:lower:]')" "$dll" >> "$have"
    done
    system="${WORK}/system.txt"
    for file in "$SYSTEM_DIR"/*; do
      printf '%s\n' "${file##*/}"
    done | tr '[:upper:]' '[:lower:]' > "$system"
    queue=("${DEST}"/*.exe)
    unresolved=()
    i=0
    while [ "$i" -lt "${#queue[@]}" ]; do
      bin="${queue[$i]}"; i=$((i + 1))
      imports=$(objdump -p "$bin") || { echo "::error::objdump failed on ${bin##*/}" >&2; exit 1; }
      while read -r dep; do
        lower=$(printf '%s' "$dep" | tr '[:upper:]' '[:lower:]')
        src=$(awk -F '\t' -v k="$lower" '$1 == k { print $2; exit }' "$have")
        if [ -z "$src" ]; then
          grep -qxF "$lower" "$system" || unresolved+=("${dep}(${bin##*/})")
          continue
        fi
        target="${DEST}/$(basename "$src")"
        [ -e "$target" ] && continue
        cp "$src" "$target"
        queue+=("$target")
      done < <(awk '/DLL Name:/ {print $3}' <<< "$imports")
    done
    if [ "${#unresolved[@]}" -gt 0 ]; then
      echo "::error::DLL imports found in neither ${DLL_DIR} nor ${SYSTEM_DIR}: ${unresolved[*]}" >&2
      exit 1
    fi
    ;;
esac

tar -czf "${OUT}/${NAME}.tar.gz" -C "$WORK" "$NAME"
echo "packaged ${#TOOLS[@]} tools into ${OUT}/${NAME}.tar.gz:"
printf '  %s\n' "${TOOLS[@]}"
