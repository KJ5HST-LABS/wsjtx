# Windows CI Remediation Plan

## Problem Statement

Phase 2 of the CI/CD PoC has been thrashing on Windows for 20+ commits across multiple ghost sessions. The current approach — disabling OmniRig and MAP65, patching CMakeLists.txt with sed/Python regex in the workflow — is wrong. OmniRig should be properly built and included. The session needs to stop disabling features and fix the actual build pipeline.

The latest failure (`24200135962`) is a linker error: `TransceiverFactory.cpp` references `OmniRigTransceiver` symbols that were removed from the build. This confirms that you can't solve this by removing files — the call sites still exist.

## Root Cause Analysis

### OmniRig Build Chain

The OmniRig build has two steps:

1. **Registry query** (`CMakeLists.txt:933-950`):
   ```cmake
   execute_process (COMMAND ${DUMPCPP} -getfile {4FE359C5-A58F-459D-BE95-CA559FB4F270} ...)
   ```
   This asks the Windows COM registry "where is OmniRig's type library?" — fails on CI runners because OmniRig isn't COM-registered.

2. **Code generation** (`CMake/Modules/QtAxMacros.cmake`):
   ```cmake
   wrap_ax_server (GENAXSRCS ${AXSERVERSRCS})
   ```
   This calls `dumpcpp -o <outfile> <infile>` directly on the type library file. It generates `OmniRig.h` and `OmniRig.cpp` — the C++ COM wrappers that `OmniRigTransceiver.cpp` depends on.

**Only step 1 fails.** Step 2 doesn't need COM registration — it just needs the file path. The 10+ ghost session commits were all trying to fix step 1 via registry manipulation when they should have been bypassing it.

### The Fix: Skip the Registry, Provide the File

Download OmniRig in CI, find the `.exe` (which embeds the type library), and set `AXSERVERSRCS` directly. `dumpcpp` can process the type library from the file without COM registration. The CMakeLists.txt `dumpcpp -getfile` block at lines 933-950 is just a file-finder — replace it with the known path.

### MAP65

MAP65 is a standalone EME application. GCC 15 (MSYS2's current compiler) rejects its legacy Fortran array dimension syntax. The `-fallow-argument-mismatch -std=legacy` flags don't fully resolve it. Skipping MAP65 on Windows CI is acceptable — it's not core WSJT-X, and it builds fine on macOS/Linux. This should be done cleanly in CMakeLists.txt, not sed-patched in the workflow.

## Inventory: Files to Change

### OmniRig references (for context — these should NOT be modified)
```
Transceiver/TransceiverFactory.cpp:12      #include "OmniRigTransceiver.hpp"
Transceiver/TransceiverFactory.cpp:32-33   OmniRigOneId, OmniRigTwoId enum values
Transceiver/TransceiverFactory.cpp:46-47   OmniRigTransceiver::register_transceivers()
Transceiver/TransceiverFactory.cpp:164-200 case OmniRigOneId / OmniRigTwoId
Transceiver/OmniRigTransceiver.cpp         full implementation
Transceiver/OmniRigTransceiver.hpp:13      #include "OmniRig.h" (the generated header)
Configuration.cpp:3056,4011                string comparisons (UI only)
widgets/mainwindow.cpp:12943               string comparison (UI only)
```
These are correct upstream code. Do NOT add `#ifdef` guards or remove files. The goal is to make the build produce the `OmniRig.h` that these files expect.

### Files to change
```
.github/workflows/build-windows.yml:75-122   Replace entire patch block with OmniRig download + path setup
CMakeLists.txt:933-950                        Make dumpcpp -getfile fallback to OMNIRIG_TYPE_LIB if set
```

## The Fix: Step by Step

### Step 1: Modify CMakeLists.txt (lines 933-950)

Replace the hard-fail registry query with a fallback:

```cmake
if (WIN32)
  # generate the OmniRig COM interface source
  find_program (DUMPCPP dumpcpp)
  if (DUMPCPP-NOTFOUND)
    message (FATAL_ERROR "dumpcpp tool not found")
  endif (DUMPCPP-NOTFOUND)

  if (OMNIRIG_TYPE_LIB)
    # CI/headless: type library path provided directly (COM registration not available)
    file (TO_CMAKE_PATH "${OMNIRIG_TYPE_LIB}" AXSERVERSRCS)
    message (STATUS "Using OmniRig type library: ${AXSERVERSRCS}")
  else ()
    # Normal build: query COM registry for type library location
    execute_process (
      COMMAND ${DUMPCPP} -getfile {4FE359C5-A58F-459D-BE95-CA559FB4F270}
      OUTPUT_VARIABLE AXSERVER
      OUTPUT_STRIP_TRAILING_WHITESPACE
      )
    string (STRIP "${AXSERVER}" AXSERVER)
    if (NOT AXSERVER)
      message (FATAL_ERROR "You need to install OmniRig on this computer, or pass -DOMNIRIG_TYPE_LIB=<path>")
    endif ()
    string (REPLACE "\"" "" AXSERVER ${AXSERVER})
    file (TO_CMAKE_PATH ${AXSERVER} AXSERVERSRCS)
  endif ()
endif ()
```

This is backward-compatible: local builds with OmniRig installed work exactly as before. CI passes `-DOMNIRIG_TYPE_LIB=<path>` to skip the registry query.

### Step 2: Simplify build-windows.yml

Replace the entire "Patch Windows build for CI" step (lines 75-122) with:

```yaml
- name: Install OmniRig
  shell: pwsh
  run: |
    # Download and silently install OmniRig (provides COM type library for dumpcpp)
    Invoke-WebRequest -Uri "https://www.dxatlas.com/OmniRig/OR2Install.exe" -OutFile OmniRig-setup.exe
    Start-Process -FilePath .\OmniRig-setup.exe -ArgumentList '/VERYSILENT','/NORESTART' -Wait
    # Locate the installed type library
    $omnirig = Get-ChildItem -Path "C:\Program Files*\Afreet\OmniRig" -Filter "OmniRig.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $omnirig) { throw "OmniRig install failed — OmniRig.exe not found" }
    echo "OMNIRIG_PATH=$($omnirig.FullName)" >> $env:GITHUB_ENV

- name: Patch MAP65 for GCC 15
  run: |
    # MAP65 is a standalone EME app. GCC 15 rejects its legacy Fortran.
    # Skip it on Windows CI — it builds on macOS/Linux.
    sed -i 's/add_subdirectory (map65)/# add_subdirectory (map65)/' CMakeLists.txt
```

Update the Configure step to pass the OmniRig path:

```yaml
- name: Configure
  run: |
    WORKSPACE=$(cygpath "${GITHUB_WORKSPACE}")
    OMNIRIG=$(cygpath "${OMNIRIG_PATH}")
    sed -i 's/if (NOT WIN32 AND _use_threads)/if (_use_threads)/' CMake/Modules/FindFFTW3.cmake
    cmake -G "MSYS Makefiles" -S . -B wsjtx-build \
      -DCMAKE_PREFIX_PATH="${WORKSPACE}/hamlib-prefix" \
      -DOMNIRIG_TYPE_LIB="${OMNIRIG}" \
      -DCMAKE_Fortran_FLAGS="-fallow-argument-mismatch -std=legacy" \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -DWSJT_GENERATE_DOCS=OFF \
      -DWSJT_SKIP_MANPAGES=ON \
      -Wno-dev
```

### Step 3: Remove all workaround cruft

Delete from the workflow:
- The Python regex patching block
- The stub `OmniRig.h` creation
- The `OmniRigTransceiver.cpp` sed removal
- All `WSJT_SKIP_OMNIRIG` references

### Risk: dumpcpp + LoadTypeLib on CI

`dumpcpp -o <outfile> <file>` internally calls `LoadTypeLib()` on the input file. This is a Windows API that loads the type library from disk — it does NOT require COM registration. It should work on CI runners because it's just file I/O, not a COM server call.

**If `dumpcpp` against the file still fails**: the fallback is to generate `OmniRig.h` and `OmniRig.cpp` once on a real Windows machine, commit them to `ci/generated/`, and copy them into the build directory in CI. This is less clean but still includes full OmniRig support — the generated files are a stable interface that hasn't changed in years.

## Verification

After commit + push:
1. `gh run list --repo KJ5HST-LABS/wsjtx-internal --limit 1` — wait for CI
2. All 3 platforms green
3. Windows build log should show: `Using OmniRig type library: <path>` and `OmniRig.h` / `OmniRig.cpp` generated by `dumpcpp`
4. `wsjtx.exe` artifact exists
5. No `WSJT_SKIP_OMNIRIG` anywhere in the build

## What's NOT in scope

- MAP65 Fortran modernization (upstream's job)
- NSIS installer packaging (Phase 3)
- Release workflow (separate session after Phase 2 green)
- Squashing the 20 thrash commits (optional cleanup, separate session)

## Session Boundary

This is ONE session. Deliverable: CMakeLists.txt change + workflow rewrite. Push, verify CI green, close out.

If `dumpcpp` against the file fails on CI, fall back to pre-generated files (see Risk section). Do NOT revert to disabling OmniRig — that path has been rejected.
