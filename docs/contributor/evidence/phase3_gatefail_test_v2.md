# Phase 3 — Forced-failure test evidence (v2, end-to-end)

Session 71 · 2026-04-20 · Contributor persona

Supersedes `phase3_gatefail_test.md` (S69 partial). The v1 test surfaced
Issue #35 before reaching the gate; v2 re-runs after #35 was resolved by
PR #36 and exercises the all-platforms-ready gate end-to-end.

## Test designed

Per `docs/contributor/4_PRODUCTION_READINESS_PLAN.md §Phase 3`, action (1),
with S69's re-plan note item 2 ("delete the upload step entirely on the
disposable branch"):

> Break `build-windows.yml` so the Windows build finishes success but
> produces no `*-windows-x86_64-installer/*.exe` artifact. Push the tag.
> Expect the all-platforms-ready gate in `release.yml` to fail with
> `::error::MISSING Windows .exe`, `Create GitHub Release` to skip,
> public-mirror push to skip.

## What was done

| Artifact | Value |
|----------|-------|
| Disposable branch | `test/phase3-gatefail-v2` (HEAD `9b7ecbf8b`) |
| Edits (1 commit) | `build-windows.yml` — deleted `Upload installer artifact` step (lines 241-245 of develop HEAD); `CMakeLists.txt:55` — `VERSION 3.0.0.0` → `3.0.1.0` in lockstep so S70's parity check passes |
| Tag pushed | `build/v3.0.1-gatefail-test-v2` |
| Release run | <https://github.com/KJ5HST-LABS/wsjtx-internal/actions/runs/24644904444> |
| Trigger | push tag (`event: push`) |
| Run conclusion | `failure` (by design) |

## What actually happened

| Job | Conclusion | Duration |
|-----|------------|----------|
| `prepare` | success | 10s (parity check PASSED: 3.0.1 == 3.0.1) |
| `macos / build` | success | 7m 55s |
| `macos-intel / build` | success | 12m 33s |
| `linux / build` | success | 7m 37s |
| `windows / build` | success | **42m 13s** (Windows built + signed cleanly — #35 fix confirmed working in a second run) |
| `release` | **failure** | 39s |

The 4 platform builds all finished success. The release job failed at the
gate, exactly as designed.

### Release-job step breakdown

| Step | Conclusion |
|------|-----------|
| Set up job | success |
| Run actions/checkout@v4 | success |
| Download all artifacts | success |
| Build source tarball | success |
| List artifacts | success |
| **Verify installer-grade artifacts (all-platforms-ready gate)** | **failure** |
| Create GitHub Release | skipped |
| Verify release tag format | skipped |
| Push to public repo | skipped |
| Post Run actions/checkout@v4 | success |
| Complete job | success |

### Gate output (verbatim)

```
Installer-grade artifact gate — checking 4 platforms…
  ok  macOS arm64 .pkg     artifacts/wsjtx-3.0.1-gatefail-test-v2-arm64-macOS.pkg/wsjtx-3.0.1-gatefail-test-v2-arm64-macOS.pkg (64802447 bytes)
  ok  macOS x86_64 .pkg    artifacts/wsjtx-3.0.1-gatefail-test-v2-x86_64-macOS.pkg/wsjtx-3.0.1-gatefail-test-v2-x86_64-macOS.pkg (70260082 bytes)
  ok  Linux .AppImage      artifacts/wsjtx-3.0.1-gatefail-test-v2-linux-x86_64-AppImage/wsjtx-3.0.1-gatefail-test-v2-linux-x86_64.AppImage (74365432 bytes)
##[error]MISSING  Windows .exe — no match for artifacts/wsjtx-3.0.1-gatefail-test-v2-windows-x86_64-installer/*.exe
##[error]All-platforms-ready gate FAILED — 1 of 4 platform(s) missing installer-grade artifact.
##[error]Refusing to publish a partial release. Fix the failing build job(s) and retry the tag.
##[error]Process completed with exit code 1.
```

## Evidence gathered

Positive results — all designed outcomes confirmed end-to-end:

1. **S70 parity check (Issue #35 fix, part 2) works on tag push.** `prepare`
   finished success in 10s; CMakeLists.txt `3.0.1.0` matched tag numeric
   base `3.0.1`. Had parity failed, `prepare` would have aborted all 4
   builds before ~70m of CI burn.
2. **S70 cpack override (Issue #35 fix, part 3) works end-to-end.** Windows
   built, packaged, AND signed cleanly — the sign-step glob
   (`wsjtx-3.0.1-gatefail-test-v2-*.exe`) matched the cpack output because
   of the `CPACK_PACKAGE_FILE_NAME` override introduced by PR #36. S69's
   v1 test never got this far; v2 proves the fix covers pre-release-style
   suffixes.
3. **All-platforms-ready gate (Issue #25) fires the intended error.** The
   gate recognized 3 of 4 installer-grade artifacts, reported the Windows
   miss with the exact `::error::MISSING Windows .exe` message, and
   exited 1 to fail the release job.
4. **Job-level refusal-to-publish works.** `Create GitHub Release` did not
   run; `Verify release tag format` did not run; `Push to public repo`
   did not run. Step-level conclusions all read `skipped`.
5. **No release draft created.** `gh release view build/v3.0.1-gatefail-test-v2`
   returns `release not found`.
6. **Public mirror untouched.** `gh api repos/KJ5HST-LABS/wsjtx/commits/main --jq .sha`
   returns `b420e7c6e1c0d0f4b8a67aef7de308365f4db550` (S65-era
   `chore: restore CMakeLists.txt VERSION 3.0.0.0`) — identical to
   S69's pre/post-test SHA.

## What this closes vs. v1

| Outcome | v1 (S69) | v2 (S71) |
|---------|----------|----------|
| `prepare` parity check | — (not yet implemented) | PASS — 10s |
| Windows build success | **FAIL** (sign-step glob mismatch — #35) | success — 42m 13s |
| Gate exercised | no (Windows failed before gate) | **yes — exact `::error::MISSING` path fired** |
| `Create GitHub Release` skipped | yes (via `needs:`) | yes (via `needs:` + gate exit 1) |
| Public mirror untouched | yes | yes |

v1 proved the `needs:` dependency stops bad releases when a platform
build fails. v2 proves the **gate** stops bad releases when a platform
build succeeds but produces no installer-grade artifact — the harder
failure mode the gate was written to catch.

## Forensic evidence retained

Per plan §Phase 3 completion criteria ("both tags still in git history
— do not delete"):

- Branch `test/phase3-gatefail-v2` — **kept on origin** (`9b7ecbf8b`).
- Tag `build/v3.0.1-gatefail-test-v2` — **kept on origin**.
- Failed run 24644904444 — retained (default GHA retention).
- v1 artifacts (`test/phase3-gatefail` branch, `build/v3.0.1-gatefail-test` tag,
  run `24641436818`) — also retained.

## Phase 3 status

- **Part (a) forced-failure: COMPLETE.** Gate behavior proven end-to-end.
- **Part (b) happy-path: remains pending.** Requires `yes push`
  authorization (triggers public-mirror force-push). Suggested tag:
  `build/v3.0.1-rc1` with `CMakeLists.txt:55` bumped to `3.0.1.0`
  already in place on `develop` after part (b) is authorized.
