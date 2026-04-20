# Phase 3 — Forced-failure test evidence (partial)

Session 69 · 2026-04-19 · Contributor persona

## Test designed

Per `docs/contributor/4_PRODUCTION_READINESS_PLAN.md §Phase 3`, action (1):

> On a disposable branch, temporarily break `build-windows.yml`'s upload-artifact step (rename the artifact to `…-installer-broken`). Push `build/v3.0.1-gatefail-test`. Expect: `release.yml`'s all-platforms-ready gate fails with `::error::MISSING Windows .exe`, `Create GitHub Release` never runs, public-mirror push never fires.

## What was done

| Artifact | Value |
|----------|-------|
| Disposable branch | `test/phase3-gatefail` (HEAD `a06af4a04`) |
| Edit | `.github/workflows/build-windows.yml:232` — `…-installer` → `…-installer-broken` |
| Tag pushed | `build/v3.0.1-gatefail-test` |
| Release run | <https://github.com/KJ5HST-LABS/wsjtx-internal/actions/runs/24641436818> |
| Trigger | push tag (`event: push`) |
| Conclusion | `failure` |

## What actually happened

| Job | Conclusion | Duration |
|-----|------------|----------|
| `prepare` | success | 2s |
| `linux / build` | success | 8m 26s |
| `macos / build` | success | 7m 26s |
| `macos-intel / build` | success | 11m 49s |
| `windows / build` | **failure** | 41m 49s |
| `release` (gate + publish) | **skipped** | — |

The windows build failed at the **Sign installer with self-signed sandbox cert** step (`build-windows.yml:196-228`), not at the upload step. The planted `-installer-broken` break was never exercised because windows failed earlier.

Failure output (`release.yml` run log):

```
ls: cannot access 'wsjtx-3.0.1-gatefail-test-*.exe': No such file or directory
##[error]Process completed with exit code 2.
```

## Latent bug surfaced (filed as issue #35)

`build-windows.yml:196-228` globs for `wsjtx-${inputs.version}-*.exe` where `inputs.version` is derived from the tag (`3.0.1-gatefail-test`). cpack generates `wsjtx-<CMakeLists-VERSION>-win64.exe` (`wsjtx-3.0.0-win64.exe`) using the VERSION in `CMakeLists.txt:55`. When the tag-derived version disagrees with `CMakeLists.txt`, the sign-step glob matches nothing and the job fails.

Past `build/v3.0.0` release (S65) succeeded because the tag version and CMakeLists.txt version were both `3.0.0` by coincidence. Any future pre-release or test tag with a suffix fails at this step.

Issue: <https://github.com/KJ5HST-LABS/wsjtx-internal/issues/35>

## Evidence gathered (differently than planned)

Negative result has value:

1. **`release.yml` job dependency enforcement works.** The `release` job's `needs: [macos, macos-intel, linux, windows]` caused it to `skip` when windows failed. No gate execution, no `Create GitHub Release`, no public-mirror push.
2. **Public mirror untouched.** `gh api repos/KJ5HST-LABS/wsjtx/commits/main --jq .sha` returned `b420e7c6e1c0d0f4b8a67aef7de308365f4db550` (S65-era `chore: restore CMakeLists.txt VERSION 3.0.0.0`) before and after the run.
3. **Version-drift blast radius quantified.** Any release tag whose version string doesn't exactly match `CMakeLists.txt:55` fails windows before the gate. Issue #35 captures this.

## What was NOT proven

- The all-platforms-ready gate (`release.yml:117-152`) was **not** exercised. Its `::error::MISSING Windows .exe` path remains unverified end-to-end (only by simulation — see S60's #25 work).

## Forensic evidence retained

Per plan §Phase 3 completion criteria ("both tags still in git history — do not delete"):

- Branch `test/phase3-gatefail` — **kept on origin**.
- Tag `build/v3.0.1-gatefail-test` — **kept on origin**.
- Failed run 24641436818 — retained (default GHA retention).

## Re-plan for a future session

1. **Resolve #35 first** — implement option 2 from the issue body (validate tag↔CMakeLists.txt parity in `prepare`), or option 1 (derive sign-step glob from CMake VERSION).
2. **Re-run the forced-failure test** once #35 is fixed. Use the same tag `build/v3.0.1-gatefail-test` if CMakeLists.txt is bumped in lockstep, OR use a different break (e.g., delete the upload step entirely on the disposable branch) to isolate the gate test.
3. **Then run happy-path test** (`build/v3.0.1-rc1`) — blocked on #35 for the same reason.
