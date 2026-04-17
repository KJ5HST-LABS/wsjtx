# Upstream PR draft — `WSJT_SKIP_MAP65` CMake option

**Target:** `WSJTX/wsjtx` → `master`
**Source commit (internal):** `887194c16` — extracted as a standalone patch
**Status:** DRAFT — awaits fork + push authorization before opening
**Risk:** Low. Additive, opt-in, `OFF` by default. No behavior change for existing users.

---

## Proposed PR title

```
Add WSJT_SKIP_MAP65 option to allow building without MAP65 on GCC 15
```

## Proposed PR body

```markdown
## Problem

On GCC 15, `map65/decode0.f90` fails to compile because `NFFT` is used as a
non-constant array dimension. GCC 14 and earlier accepted this; GCC 15 is
stricter and rejects it. The upstream fix is to make MAP65 GCC-15-clean, but
in the meantime CI and end-user builds on toolchains that ship GCC 15 fail
at the MAP65 subdirectory.

Rather than sed-patching `CMakeLists.txt` in each downstream build script,
this PR adds a CMake option that lets those builds opt out of MAP65 cleanly.

## Change

One new CMake option, `OFF` by default, and one `if()` guard around the
existing `add_subdirectory (map65)` call. No change to the default build.

```cmake
option (WSJT_SKIP_MAP65 "Skip building MAP65 EME decoder (legacy Fortran; fails on GCC 15)." OFF)
...
if (WIN32)
  find_package (Portaudio REQUIRED)
  if (NOT WSJT_SKIP_MAP65)
    add_subdirectory (map65)
  endif ()
endif ()
```

## Default behavior

Unchanged. `WSJT_SKIP_MAP65` defaults to `OFF`, so MAP65 still builds on
Windows for every existing consumer and CI configuration.

## Opt-in usage

```
cmake -DWSJT_SKIP_MAP65=ON ...
```

Downstream packagers and CI pipelines that hit the GCC 15 issue can add the
flag instead of maintaining source-tree patches.

## Rationale for the option name and location

- `WSJT_SKIP_MAP65` follows the existing `WSJT_*` option-naming convention
  (see `WSJT_FOX_OTP`, `WSJT_TRACE_UDP`, `WSJT_BUILD_UTILS`, etc. in
  `CMakeLists.txt`).
- The option is declared in the same block as the other `option()` calls,
  just below `WSJT_FOX_OTP`.
- The guard is placed inline with the `if (WIN32)` block that MAP65
  already lives in — no change to MAP65's existing platform gating.

## Test plan

- Default build (MAP65 included): unchanged, passes as today.
- `-DWSJT_SKIP_MAP65=ON`: build completes without entering `map65/`. Verified
  in our downstream Windows CI on MSYS2 + GCC 15 (see run logs in
  `KJ5HST-LABS/wsjtx-internal`).
- No changes to Linux or macOS code paths; MAP65 only builds on Windows in
  the current tree.

## Scope

This PR is the `WSJT_SKIP_MAP65` change only. A companion `FindFFTW3.cmake`
threads fix (also in our internal `887194c16`) is a separate concern and
will be submitted as its own PR once the upstream-friendly formulation is
settled.
```

## The exact patch

```diff
diff --git a/CMakeLists.txt b/CMakeLists.txt
index 6e62f76ee..1bce9ce9d 100644
--- a/CMakeLists.txt
+++ b/CMakeLists.txt
@@ -160,6 +160,7 @@ option (WSJT_RIG_NONE_CAN_SPLIT "Allow split operation with \"None\" as rig.")
 option (WSJT_TRACE_UDP "Debugging option that turns on UDP message protocol diagnostics.")
 option (WSJT_BUILD_UTILS "Build simulators and code demonstrators." ON)
 option (WSJT_FOX_OTP "Enable Fox OTP Verification Messages." ON)
+option (WSJT_SKIP_MAP65 "Skip building MAP65 EME decoder (legacy Fortran; fails on GCC 15)." OFF)
 CMAKE_DEPENDENT_OPTION (WSJT_QDEBUG_IN_RELEASE "Leave Qt debugging statements in Release configuration." OFF
   "NOT is_debug_build" OFF)
 CMAKE_DEPENDENT_OPTION (WSJT_ENABLE_EXPERIMENTAL_FEATURES "Enable features not fully ready for public releases." ON
@@ -1637,7 +1638,9 @@ endif (${OPENMP_FOUND} OR APPLE)

 if (WIN32)
   find_package (Portaudio REQUIRED)
-  add_subdirectory (map65)
+  if (NOT WSJT_SKIP_MAP65)
+    add_subdirectory (map65)
+  endif ()
 endif ()
   add_subdirectory (qmap)
```

Two hunks, one file, +4/-1 lines.

## Required steps before opening the PR (need user authorization)

1. **Fork** `WSJTX/wsjtx` to a personal namespace (likely `KJ5HST`). This
   establishes a fork on GitHub. One-time setup.
2. **Branch** from `upstream/master` locally: `git checkout -b
   upstream-wsjt-skip-map65 upstream/master`.
3. **Apply** the patch above (cherry-pick the relevant hunks of
   `887194c16` or re-author directly on `CMakeLists.txt`).
4. **Sign-off** with `git commit -s -m "Add WSJT_SKIP_MAP65 option..."` —
   many upstream projects expect DCO sign-offs; confirm WSJTX convention.
5. **Add fork remote**: `git remote add fork git@github.com:KJ5HST/wsjtx.git`.
6. **Push**: `git push fork upstream-wsjt-skip-map65`.
7. **Open PR**: `gh pr create --repo WSJTX/wsjtx --base master --head
   KJ5HST:upstream-wsjt-skip-map65 --title "..." --body-file ...`.

Each of these is shared-state and requires explicit authorization; steps
5-7 publish the change to external systems.

## Notes for the session that executes this

- **Do not bundle** with the `FindFFTW3.cmake` patch, the `OMNIRIG_TYPE_LIB`
  fallback, or the Hamlib INSTALL bump — those are independent Issue #2
  sub-items. Keeping each PR single-purpose maximizes upstream merge
  probability.
- **Verify WSJTX contribution conventions** (CONTRIBUTING.md or README on
  the WSJTX org) before pushing: commit message style, DCO sign-off
  requirement, target branch.
- **Confirm with user** which personal GitHub account should host the fork
  (`KJ5HST` personal vs. a dedicated contributor identity).
