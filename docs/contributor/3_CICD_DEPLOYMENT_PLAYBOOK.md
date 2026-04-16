# CI/CD Deployment Playbook

Deploy the WSJT-X GitHub Actions CI/CD pipeline to the official WSJTX organization repos.

**Audience:** Team-internal. Someone with moderate GitHub Actions experience deploying the pipeline to the official org.
**Time estimate:** 1-2 hours for a full deployment, assuming you have all credentials ready.

---

## Table of Contents

1. [Prerequisites](#1-prerequisites)
2. [Architecture Overview](#2-architecture-overview)
3. [Phase 1: Enable GitHub Actions on the Org](#3-phase-1-enable-github-actions-on-the-org)
4. [Phase 2: Adapt Workflow Files](#4-phase-2-adapt-workflow-files)
5. [Phase 3: Create Repository Secrets](#5-phase-3-create-repository-secrets)
6. [Phase 4: Supporting Files](#6-phase-4-supporting-files)
7. [Phase 5: Submit the PR](#7-phase-5-submit-the-pr)
8. [Phase 6: Test the CI Pipeline](#8-phase-6-test-the-ci-pipeline)
9. [Phase 7: Test the Release Pipeline](#9-phase-7-test-the-release-pipeline)
10. [Ongoing Maintenance](#10-ongoing-maintenance)
11. [Troubleshooting](#11-troubleshooting)
12. [Reference: Complete File Inventory](#12-reference-complete-file-inventory)

---

## 1. Prerequisites

Before starting, confirm every item on this list. Missing any one of them will block deployment.

### Access & Permissions

| Requirement | How to Verify | Who Can Grant |
|-------------|---------------|---------------|
| **Org admin** or **repo admin** on `WSJTX/wsjtx-internal` | Go to repo → Settings. If you see "Actions" in the left sidebar, you have admin access. | Org owner (Joe K1JT) |
| **Write access** to `WSJTX/wsjtx` (public repo) | Try `gh api repos/WSJTX/wsjtx --jq .permissions.push` — should return `true` | Org owner |
| **GitHub Actions enabled** at the org level | Org Settings → Actions → General. Must not show "Actions permissions: Disabled" | Org owner |

### Credentials You'll Need

| Credential | Where to Get It | Format |
|------------|-----------------|--------|
| Apple Developer ID Application certificate (.p12) | Apple Developer portal → Certificates | PKCS12 file + password |
| Apple Developer ID Installer certificate (.p12) | Apple Developer portal → Certificates | PKCS12 file + password |
| Apple ID email (for notarization) | The email address of the Apple Developer account | Plain text |
| App-specific password | appleid.apple.com → Sign-In and Security → App-Specific Passwords | 16-char token like `xxxx-xxxx-xxxx-xxxx` |
| Apple Team ID | Apple Developer portal → Membership Details | 10-char alphanumeric like `ABCDE12345` |
| GitHub fine-grained PAT | github.com → Settings → Developer settings → Fine-grained tokens | `github_pat_...` token string |

### Tools

- `gh` ([GitHub CLI](https://cli.github.com/)) authenticated with an account that has admin access to the target repos
- `base64` command (macOS and Linux both have this)
- Git with push access to `WSJTX/wsjtx-internal`

---

## 2. Architecture Overview

Understanding the architecture will help you debug issues during deployment.

### Workflow Structure

```
.github/workflows/
├── ci.yml               ← Orchestrator. Triggers on push/PR to develop.
│                           Calls the three build workflows below.
│
├── build-macos.yml      ← Reusable workflow (workflow_call).
│                           macOS build (arm64 or x86_64, parameterized) + sign + notarize.
│
├── build-linux.yml      ← Reusable workflow (workflow_call).
│                           Linux x86_64 build, unsigned.
│
├── build-windows.yml    ← Reusable workflow (workflow_call).
│                           Windows x86_64 via MSYS2/MinGW64 + Authenticode signing.
│
└── release.yml          ← Triggers on version tags (v*).
                            Calls all four platform builds, creates a GitHub Release
                            with artifacts, syncs source to the public repo.
```

### How It Flows

**On every push to `develop`:**
```
Push to develop
  └─→ ci.yml triggers
       ├─→ build-macos.yml [ARM64]  (parallel)
       ├─→ build-macos.yml [Intel]  (parallel)
       ├─→ build-linux.yml  (parallel)
       └─→ build-windows.yml (parallel)
            └─→ All four upload artifacts
```

**On a version tag (`v*`):**
```
Push tag v3.0.1
  └─→ release.yml triggers
       ├─→ build-macos.yml [ARM64]  (parallel)
       ├─→ build-macos.yml [Intel]  (parallel)
       ├─→ build-linux.yml  (parallel)
       └─→ build-windows.yml (parallel)
       └─→ release job (after all builds)
            ├─→ Download all artifacts
            ├─→ Create GitHub Release with artifacts attached
            └─→ Push source + tag to public repo (WSJTX/wsjtx)
```

### Build Strategy

Each platform build does the same two-stage process:
1. **Build Hamlib 4.7.0** from source (cached after first run)
2. **Build WSJT-X** against the Hamlib install prefix

This matches what developers do locally but doesn't use the superbuild. The superbuild's ExternalProject approach doesn't map well to CI caching. Building Hamlib directly and caching its install prefix gives better cache hits and faster builds.

### What Gets Cached

| Cache | Key | Saves |
|-------|-----|-------|
| Hamlib install (per platform) | `hamlib-{os}-{branch}-{workflow-hash}` | 5-10 min per platform |
| MSYS2 packages | Built-in `cache: true` parameter | 3-5 min on Windows |

Caches invalidate when the Hamlib branch changes or the workflow file changes. This is intentional — if you change build flags, the cache rebuilds.

---

## 3. Phase 1: Enable GitHub Actions on the Org

This is a **one-time setup** that requires org owner access.

### Step 1: Navigate to Org Actions Settings

```
https://github.com/organizations/WSJTX/settings/actions
```

Or: GitHub → WSJTX org → Settings (gear icon) → Actions → General

### Step 2: Set Actions Permissions

Under **Actions permissions**, select one of:
- **"Allow all actions and reusable workflows"** — simplest, allows everything
- **"Allow WSJTX, and select non-WSJTX, actions and reusable workflows"** — more restrictive

If you choose the restrictive option, you must explicitly allow these third-party actions:
- `actions/checkout@v4`
- `actions/cache@v4`
- `actions/upload-artifact@v4`
- `actions/download-artifact@v4`
- `msys2/setup-msys2@v2`

### Step 3: Set Workflow Permissions

Under **Workflow permissions**, select:
- **"Read and write permissions"**

This allows the release workflow to create GitHub Releases and push tags. Without write permissions, the release job will fail with a 403 error.

### Step 4: Verify

```bash
gh api orgs/WSJTX --jq '.has_organization_projects'
# Just verifying API access to the org works

gh api repos/WSJTX/wsjtx-internal/actions/permissions --jq '.enabled'
# Should return: true
```

If `enabled` returns `false`, Actions is still disabled. Double-check the org settings.

---

## 4. Phase 2: Adapt Workflow Files

Copy all five workflow files from the prototype and make the changes below. Every change is listed with the exact file, line, and what to change.

### 4a. Changes to `ci.yml`

**Branch name** (lines 4-7): If the official repo uses `master` instead of `develop`:

```yaml
# BEFORE (prototype):
on:
  push:
    branches: [develop]
  pull_request:
    branches: [develop]

# AFTER (if official repo uses master):
on:
  push:
    branches: [master]
  pull_request:
    branches: [master]
```

If the official repo already uses `develop`, no change needed.

**Version string** (lines 13, 19, 25): Update if the current version is different:

```yaml
# These appear three times — once per platform call:
    with:
      version: "3.0.0"       # ← Update to current version
      hamlib_branch: "4.7.0"  # ← Update if team uses different Hamlib
```

### 4b. Changes to `release.yml`

**Public repo URL** (line 72): This is the most critical change.

Verify this line points at the official public repo:

```yaml
git remote add public https://x-access-token:${TOKEN}@github.com/WSJTX/wsjtx.git || true
```

**Public repo branch** (line 73): If the public repo's default branch is `master`:

```yaml
# BEFORE (prototype pushes to main):
git push public HEAD:main --force

# AFTER (if public repo uses master):
git push public HEAD:master --force
```

**Version string** (lines 13, 19, 25): Same as `ci.yml` — update version and Hamlib branch if needed.

### 4c. Changes to `build-macos.yml`

**No code changes required.** The macOS workflow is fully parameterized:
- Version comes from `inputs.version`
- Hamlib branch comes from `inputs.hamlib_branch`
- Signing identities are discovered from the keychain at runtime
- All secrets are referenced by name (covered in Phase 3)

**One thing to verify:** The `entitlements.plist` file must exist in the repo root. It's referenced on line 285:
```yaml
ENTITLEMENTS="${GITHUB_WORKSPACE}/entitlements.plist"
```

**Also verify:** `Darwin/com.wsjtx.sysctl.plist` must exist. It's copied into the installer package (line 319).

### 4d. Changes to `build-linux.yml`

**No changes required.** The Linux workflow has no org-specific references.

### 4e. Changes to `build-windows.yml`

**No changes required.** The Windows workflow has no org-specific references.

### Summary of All Changes

| File | Line(s) | What to Change | Why |
|------|---------|----------------|-----|
| `ci.yml` | 5, 7 | `develop` → `master` (if applicable) | Match official branch name |
| `ci.yml` | 13, 19, 25 | Version string | Match current release version |
| `release.yml` | 72 | Verify public repo URL is `WSJTX/wsjtx` | Point sync at official public repo |
| `release.yml` | 73 | `HEAD:main` → `HEAD:master` (if applicable) | Match public repo default branch |
| `release.yml` | 13, 19, 25 | Version string | Match current release version |

That's it. Five lines in two files (public repo URL, branch name, and version strings).

---

## 5. Phase 3: Create Repository Secrets

Secrets are stored at the **repository** level on `wsjtx-internal`. They are never exposed in logs — GitHub masks them automatically.

### Navigate to Secrets Settings

```
https://github.com/WSJTX/wsjtx-internal/settings/secrets/actions
```

Or: Repo → Settings → Secrets and variables → Actions → "New repository secret"

### Secret 1: `CROSS_REPO_TOKEN`

**Purpose:** Allows the release workflow to push source code and tags to the public repo (`WSJTX/wsjtx`).

**How to create the PAT:**

1. Go to https://github.com/settings/personal-access-tokens/new
2. Select **"Fine-grained personal access tokens"**
3. Configure:
   - **Token name:** `wsjtx-release-sync` (or similar)
   - **Expiration:** 1 year (maximum). Set a calendar reminder to rotate it before expiry.
   - **Resource owner:** Select the `WSJTX` organization
   - **Repository access:** Select "Only select repositories" → choose `WSJTX/wsjtx`
   - **Permissions:**
     - **Contents:** Read and write (to push code)
     - **Workflows:** Read and write (to push `.github/workflows/` files)
   - All other permissions: leave as "No access"
4. Click "Generate token"
5. **Copy the token immediately** — you cannot view it again.

**Important:** The token must be created by someone who has **admin access to the target repo** (`WSJTX/wsjtx`). A fine-grained token scoped to a repo you don't admin will fail silently.

**Set the secret:**
```bash
# Paste the token when prompted (it won't echo to the terminal):
gh secret set CROSS_REPO_TOKEN --repo WSJTX/wsjtx-internal
```

**Why not a deploy key?** Deploy keys cannot push `.github/workflows/` files. This is a GitHub platform restriction. The error message ("refusing to allow an OAuth App to create or update workflow") is misleading — it applies to any non-PAT credential, including deploy keys over SSH.

### Secrets 2-5: macOS Code Signing Certificates

These four secrets allow the macOS build to sign and package the app with a Developer ID certificate, which is required for macOS Gatekeeper to accept the binary.

#### Who holds the Apple Developer account?

The WSJT-X team's Apple Developer account is currently held by **John G4KLA**. He has produced the team's existing signed, notarized macOS releases using the Developer ID certificates in his own Keychain.

**No transfer of the underlying Apple account is required** to adopt this CI/CD pipeline. The handoff is certificate-level, not account-level:

1. John exports his existing **Developer ID Application** and **Developer ID Installer** certificates from Keychain Access as `.p12` files (see next subsection).
2. John (or a team member John shares the `.p12` files with) base64-encodes them and loads them as GitHub secrets via `gh secret set`.
3. The pipeline uses those secrets on each build to sign and notarize as "Developer ID: [John's team]".
4. John retains sole ownership of the Apple Developer account. Notarization runs under his Apple ID + app-specific password (see `APPLE_ID` / `APPLE_APP_SPECIFIC_PASSWORD` below).

If John ever steps down or the account owner changes, only the four Apple-related secrets need to be re-set — no workflow-file changes.

#### Preparing the .p12 files

You need two certificates from the Apple Developer portal:
- **Developer ID Application** — signs the app binary and dylibs
- **Developer ID Installer** — signs the `.pkg` installer

If you already have `.p12` files exported from Keychain Access (John's existing certificates, for example), skip to the base64 step.

**To export from Keychain Access (on a Mac):**

1. Open Keychain Access
2. In the left sidebar, select "login" keychain
3. Click "My Certificates" tab
4. Find "Developer ID Application: [Team Name]"
5. Right-click → "Export..."
6. Choose format: Personal Information Exchange (.p12)
7. Save as `app.p12`
8. Enter a password when prompted — you'll need this for the secret
9. Repeat for "Developer ID Installer: [Team Name]" → save as `installer.p12`

#### Base64-encode the certificates

GitHub secrets are text, so binary `.p12` files must be base64-encoded:

```bash
# On macOS:
base64 -i app.p12 -o app.p12.b64
base64 -i installer.p12 -o installer.p12.b64

# On Linux:
base64 -w0 app.p12 > app.p12.b64
base64 -w0 installer.p12 > installer.p12.b64
```

#### Set the four secrets

```bash
# Application signing certificate (base64-encoded .p12):
gh secret set DEVELOPER_ID_CERTIFICATE_P12 --repo WSJTX/wsjtx-internal < app.p12.b64

# Password for the application certificate:
gh secret set DEVELOPER_ID_CERTIFICATE_PASSWORD --repo WSJTX/wsjtx-internal
# (paste the password you chose when exporting, press Enter)

# Installer signing certificate (base64-encoded .p12):
gh secret set DEVELOPER_ID_INSTALLER_P12 --repo WSJTX/wsjtx-internal < installer.p12.b64

# Password for the installer certificate:
gh secret set DEVELOPER_ID_INSTALLER_PASSWORD --repo WSJTX/wsjtx-internal
# (paste the password you chose when exporting, press Enter)
```

**After setting secrets, delete the local .p12 and .b64 files.** They contain your signing keys.

```bash
rm app.p12 installer.p12 app.p12.b64 installer.p12.b64
```

### Secrets 6-8: Apple Notarization

Notarization sends the signed binary to Apple's servers for malware scanning. Without it, macOS Gatekeeper shows a scary "unidentified developer" warning.

#### `APPLE_ID`

The email address of the Apple Developer account — **John G4KLA's** Apple ID, since he holds the team's Developer account (see [Who holds the Apple Developer account?](#who-holds-the-apple-developer-account) above).

```bash
gh secret set APPLE_ID --repo WSJTX/wsjtx-internal
# Paste: developer@example.com
```

#### `APPLE_APP_SPECIFIC_PASSWORD`

Apple requires an app-specific password for automated notarization (not your regular Apple ID password).

**To generate one:**

1. Go to https://appleid.apple.com
2. Sign in with the Apple Developer account
3. Go to **Sign-In and Security** → **App-Specific Passwords**
4. Click **"Generate an app-specific password"**
5. Label it `wsjtx-ci-notarize` (or similar)
6. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

```bash
gh secret set APPLE_APP_SPECIFIC_PASSWORD --repo WSJTX/wsjtx-internal
# Paste: xxxx-xxxx-xxxx-xxxx
```

#### `APPLE_TEAM_ID`

Your Apple Developer team identifier:

1. Go to https://developer.apple.com/account
2. Scroll down to **Membership Details**
3. Copy the **Team ID** (10-character alphanumeric string)

```bash
gh secret set APPLE_TEAM_ID --repo WSJTX/wsjtx-internal
# Paste: ABCDE12345
```

### Verification: Confirm All Secrets Are Set

```bash
gh secret list --repo WSJTX/wsjtx-internal
```

You should see exactly these 8 secrets:

```
APPLE_APP_SPECIFIC_PASSWORD     Updated 2026-...
APPLE_ID                        Updated 2026-...
APPLE_TEAM_ID                   Updated 2026-...
CROSS_REPO_TOKEN                Updated 2026-...
DEVELOPER_ID_CERTIFICATE_P12    Updated 2026-...
DEVELOPER_ID_CERTIFICATE_PASSWORD Updated 2026-...
DEVELOPER_ID_INSTALLER_P12      Updated 2026-...
DEVELOPER_ID_INSTALLER_PASSWORD Updated 2026-...
```

If any are missing, the macOS build will fail at the signing step with an empty identity error.

### Secrets 9-10: Windows Authenticode Signing

The team's existing Windows signing certificate is used in CI the same way as macOS — base64-encoded and stored as a repository secret.

#### Preparing the certificate

Export the existing Authenticode certificate as a `.pfx` file (if you don't already have one exported). Base64-encode it, same as the macOS certificates:

```bash
# On macOS:
base64 -i wsjtx-signing.pfx -o wsjtx-signing.pfx.b64

# On Linux:
base64 -w0 wsjtx-signing.pfx > wsjtx-signing.pfx.b64
```

#### Set the secrets

```bash
# Windows signing certificate (base64-encoded .pfx):
gh secret set WINDOWS_SIGNING_CERT_PFX --repo WSJTX/wsjtx-internal < wsjtx-signing.pfx.b64

# Password for the certificate:
gh secret set WINDOWS_SIGNING_CERT_PASSWORD --repo WSJTX/wsjtx-internal
# (paste the password, press Enter)
```

**Delete local files after setting secrets:**
```bash
rm wsjtx-signing.pfx wsjtx-signing.pfx.b64
```

#### Adding the signing step to `build-windows.yml`

Insert this step after the "Build" step and before "Upload build artifacts":

```yaml
    - name: Sign Windows binaries
      shell: pwsh
      env:
        CERT_PFX: ${{ secrets.WINDOWS_SIGNING_CERT_PFX }}
        CERT_PASSWORD: ${{ secrets.WINDOWS_SIGNING_CERT_PASSWORD }}
      run: |
        if (-not $env:CERT_PFX) {
          Write-Warning "WINDOWS_SIGNING_CERT_PFX not set — skipping signing"
          exit 0
        }
        $pfxPath = "$env:RUNNER_TEMP\signing.pfx"
        [IO.File]::WriteAllBytes($pfxPath, [Convert]::FromBase64String($env:CERT_PFX))

        $signtool = Get-ChildItem -Path "C:\Program Files (x86)\Windows Kits" `
          -Recurse -Filter "signtool.exe" | Where-Object {
            $_.FullName -match "x64"
          } | Select-Object -First 1

        if (-not $signtool) { throw "signtool.exe not found" }

        foreach ($exe in @("wsjtx-build\wsjtx.exe", "wsjtx-build\jt9.exe", "wsjtx-build\wsprd.exe")) {
          if (Test-Path $exe) {
            & $signtool.FullName sign /f $pfxPath /p $env:CERT_PASSWORD `
              /tr http://timestamp.digicert.com /td sha256 /fd sha256 $exe
          }
        }
        Remove-Item $pfxPath
```

The step is structured to skip gracefully if the secrets aren't set — the build succeeds unsigned during initial setup while secrets are being configured.

### Linux Signing (Optional)

Linux binary signing is less critical — Linux users don't encounter SmartScreen-style warnings when downloading binaries. However, GPG-signing release tarballs is good practice if the team distributes `.tar.gz` or `.deb` packages. This would require one additional secret (`GPG_SIGNING_KEY`) and a small step in the release workflow.

### Verification: All Secrets

You should see 10 secrets:

```bash
gh secret list --repo WSJTX/wsjtx-internal
```

```
APPLE_APP_SPECIFIC_PASSWORD       Updated 2026-...
APPLE_ID                          Updated 2026-...
APPLE_TEAM_ID                     Updated 2026-...
CROSS_REPO_TOKEN                  Updated 2026-...
DEVELOPER_ID_CERTIFICATE_P12      Updated 2026-...
DEVELOPER_ID_CERTIFICATE_PASSWORD Updated 2026-...
DEVELOPER_ID_INSTALLER_P12        Updated 2026-...
DEVELOPER_ID_INSTALLER_PASSWORD   Updated 2026-...
WINDOWS_SIGNING_CERT_PFX          Updated 2026-...
WINDOWS_SIGNING_CERT_PASSWORD     Updated 2026-...
```

---

## 6. Phase 4: Supporting Files

These files are referenced by the workflows and must exist in the repo.

### `entitlements.plist` (repo root)

The macOS build passes this file to `codesign --entitlements` when signing binaries under `Contents/MacOS` and CLI tools. It must exist at the repo root — the workflow references it unconditionally. The file should contain an **empty dict**:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
</dict>
</plist>
```

WSJT-X does not need any of the permissive hardened-runtime exceptions (`allow-jit`, `allow-unsigned-executable-memory`, `disable-executable-page-protection`). The codebase is plain C++/Fortran with Qt Widgets and FFTW — no JIT, no runtime code generation, no embedded script interpreters, no `PROT_EXEC`/`mprotect`. Earlier revisions of this file inherited those entitlements from an unrelated prototype and were never audited.

**Audit evidence:** Apple's notarization service accepted a signed build using this empty plist in CI run `24476420532` (`Code sign binaries`, `Build installer pkg`, `Notarize pkg`, and `Notarize CLI tools` all succeeded). Notarization fails if hardened-runtime policy is violated, so successful notarization is the authoritative verification. See `KJ5HST-LABS/wsjtx-internal#11`.

If a future feature ever adds true runtime code generation, re-introduce only the minimum required entitlement and document the reason inline.

### `Darwin/com.wsjtx.sysctl.plist`

The macOS installer package copies this into `/Library/LaunchDaemons/` to configure shared memory limits (required for WSJT-X interprocess communication). Check if it exists:

```bash
ls -la Darwin/com.wsjtx.sysctl.plist
```

### `CMakeLists.txt` OmniRig Change (Optional)

The Windows CI passes `-DOMNIRIG_TYPE_LIB=<path>` to CMake. This requires a small change to `CMakeLists.txt` (around line 940) that adds an `if (OMNIRIG_TYPE_LIB)` branch. The change is backward-compatible — existing local builds without `-DOMNIRIG_TYPE_LIB` work exactly as before.

If the official repo doesn't have this change, include it in the PR. The relevant section:

```cmake
if (WIN32)
  find_program (DUMPCPP dumpcpp)
  if (DUMPCPP-NOTFOUND)
    message (FATAL_ERROR "dumpcpp tool not found")
  endif (DUMPCPP-NOTFOUND)

  if (OMNIRIG_TYPE_LIB)
    # CI/headless: type library path provided directly
    file (TO_CMAKE_PATH "${OMNIRIG_TYPE_LIB}" AXSERVERSRCS)
    message (STATUS "Using OmniRig type library: ${AXSERVERSRCS}")
  else ()
    # Normal build: query COM registry for type library location
    execute_process (
      COMMAND ${DUMPCPP} -getfile {4FE359C5-A58F-459D-BE95-CA559FB4F270}
      OUTPUT_VARIABLE AXSERVER
      OUTPUT_STRIP_TRAILING_WHITESPACE
      )
    # ... existing registry-query code ...
  endif ()
```

---

## 7. Phase 5: Submit the PR

### Option A: PR from a Branch

If you have write access to `WSJTX/wsjtx-internal`:

```bash
# Clone the official repo (if you haven't already):
git clone git@github.com:WSJTX/wsjtx-internal.git
cd wsjtx-internal

# Create a feature branch:
git checkout -b ci/github-actions

# Copy workflow files from the prototype:
# (adjust paths to wherever you have the prototype checked out)
cp /path/to/prototype/.github/workflows/*.yml .github/workflows/

# Make the changes from Phase 2 (branch names, repo URL, versions)
# ... edit ci.yml and release.yml ...

# Copy supporting files if needed:
cp /path/to/prototype/entitlements.plist .
cp -r /path/to/prototype/Darwin .

# Commit:
git add .github/workflows/ entitlements.plist Darwin/
git commit -m "feat: add GitHub Actions CI/CD for four-platform builds"

# Push and create PR:
git push -u origin ci/github-actions
gh pr create \
  --title "Add GitHub Actions CI/CD" \
  --body "Four-platform CI (macOS ARM64, macOS Intel x86_64, Linux x86_64, Windows x86_64) with tag-triggered releases."
```

### Option B: PR from a Fork

If you don't have write access:

```bash
# Fork the repo on GitHub first, then:
git clone git@github.com:YOUR_USERNAME/wsjtx-internal.git
cd wsjtx-internal
git remote add upstream git@github.com:WSJTX/wsjtx-internal.git

# Then follow the same steps as Option A, but push to your fork:
git push -u origin ci/github-actions

# Create PR from fork to upstream:
gh pr create \
  --repo WSJTX/wsjtx-internal \
  --title "Add GitHub Actions CI/CD" \
  --body "Four-platform CI (macOS ARM64, macOS Intel x86_64, Linux x86_64, Windows x86_64) with tag-triggered releases."
```

**Important note about forks:** Workflow files in PRs from forks don't run automatically — this is a GitHub security feature. The PR must be merged before the workflows will trigger. This means you can't test the CI from a fork PR. If you need to test before merging, use a branch on the official repo (Option A).

---

## 8. Phase 6: Test the CI Pipeline

After the PR is merged (or if you pushed directly to a test branch), verify CI works.

### Step 1: Trigger a CI Run

Push any small change to the target branch:

```bash
# If testing on a branch:
git checkout develop  # or master
echo "# CI test" >> README.md
git add README.md
git commit -m "test: trigger CI pipeline"
git push
```

### Step 2: Monitor the Run

```bash
# Watch the run in real-time:
gh run watch --repo WSJTX/wsjtx-internal

# Or list recent runs:
gh run list --repo WSJTX/wsjtx-internal --limit 5
```

### Step 3: Check Each Platform

All four builds should complete. Expected times (first run, no cache):

| Platform | First Run | Cached Run |
|----------|-----------|------------|
| macOS ARM64 | ~12-15 min | ~8 min |
| macOS Intel x86_64 | ~15-20 min | ~10 min |
| Linux x86_64 | ~10-12 min | ~7 min |
| Windows x86_64 | ~40-45 min | ~15 min |

Windows is the slowest because MSYS2 package installation is slow on first run.

### Step 4: Inspect Failures

If a job fails:

```bash
# View the failed run's logs:
gh run view <RUN_ID> --repo WSJTX/wsjtx-internal --log-failed
```

Common first-run failures:

| Symptom | Cause | Fix |
|---------|-------|-----|
| "Resource not accessible by integration" | Workflow permissions too restrictive | Org Settings → Actions → Workflow permissions → "Read and write" |
| macOS signing fails with empty identity | Missing signing secrets | Set `DEVELOPER_ID_CERTIFICATE_P12` and related secrets |
| macOS notarization fails | Missing or wrong `APPLE_ID` / password / team ID | Verify all three notarization secrets |
| Windows build timeout (>60 min) | MSYS2 cache miss + slow package install | Re-run — the cache will be populated for next time |
| "refusing to allow an OAuth App to create or update workflow" | This error can appear at PR merge time if the branch contains workflow files and was pushed with a deploy key | Push the branch using a PAT or via the GitHub web UI instead |

### Step 5: Revert the Test Commit

```bash
git revert HEAD
git push
```

---

## 9. Phase 7: Test the Release Pipeline

Only do this after CI is green on all four platforms.

### Step 1: Choose a Test Version

Pick a version number that's clearly a test. Convention: append a patch number to the current version.

```bash
# If current version is 3.0.0:
TEST_TAG="v3.0.0.1-test"
```

### Step 2: Create and Push the Tag

```bash
git tag "$TEST_TAG"
git push origin "$TEST_TAG"
```

### Step 3: Monitor the Release Run

```bash
gh run watch --repo WSJTX/wsjtx-internal
```

The release workflow will:
1. Build all four platforms (same as CI)
2. Create a GitHub Release with downloadable artifacts
3. Push source and the tag to the public repo

### Step 4: Verify the Release

```bash
# Check that the release was created:
gh release view "$TEST_TAG" --repo WSJTX/wsjtx-internal

# Check that the public repo received the code:
gh api repos/WSJTX/wsjtx/tags --jq '.[].name' | head -5

# Check that the public repo received the tag:
gh api repos/WSJTX/wsjtx/git/refs/tags/"$TEST_TAG" --jq '.ref'
```

### Step 5: Verify the Artifacts

Download and inspect at least one artifact:

```bash
gh release download "$TEST_TAG" --repo WSJTX/wsjtx-internal --dir /tmp/release-test
ls -la /tmp/release-test/
```

For the macOS `.pkg`, verify signing:

```bash
pkgutil --check-signature /tmp/release-test/wsjtx-*-arm64-macOS.pkg
# Should show "Developer ID Installer: [Team Name]"
```

### Step 6: Clean Up the Test Release

```bash
# Delete the release:
gh release delete "$TEST_TAG" --repo WSJTX/wsjtx-internal --yes

# Delete the tag from wsjtx-internal:
gh api -X DELETE repos/WSJTX/wsjtx-internal/git/refs/tags/"$TEST_TAG"

# Delete the tag from wsjtx (public):
gh api -X DELETE repos/WSJTX/wsjtx/git/refs/tags/"$TEST_TAG"

# Delete local tag:
git tag -d "$TEST_TAG"
```

---

## 10. Ongoing Maintenance

### Secret Rotation

| Secret | Rotation Schedule | How to Rotate |
|--------|-------------------|---------------|
| `CROSS_REPO_TOKEN` | Before expiry (check token settings at github.com) | Generate new PAT → `gh secret set CROSS_REPO_TOKEN --repo WSJTX/wsjtx-internal` |
| `APPLE_APP_SPECIFIC_PASSWORD` | When Apple revokes it or account password changes | Generate new app-specific password → update secret |
| macOS signing certificates (.p12) | When certificate expires (typically 5 years) | Export new cert from Keychain → base64-encode → update both P12 and PASSWORD secrets |
| Windows signing certificate (.pfx) | When certificate expires (typically 1-3 years for OV) | Obtain renewed cert from CA → base64-encode → update PFX and PASSWORD secrets |

### Version Bumps

When releasing a new version, update the `version` input in both `ci.yml` and `release.yml`. Each file has three places where the version appears (one per platform call):

```bash
# Find all version references:
grep -n 'version:' .github/workflows/ci.yml .github/workflows/release.yml
```

### Hamlib Updates

If the team moves to a new Hamlib version, update `hamlib_branch` in both `ci.yml` and `release.yml`. The Hamlib cache will automatically invalidate because the cache key includes the branch name.

### Cache Management

If builds behave strangely after dependency changes, clear the Actions cache:

```bash
# List caches:
gh api repos/WSJTX/wsjtx-internal/actions/caches --jq '.actions_caches[] | "\(.id) \(.key)"'

# Delete a specific cache:
gh api -X DELETE repos/WSJTX/wsjtx-internal/actions/caches/<CACHE_ID>
```

Or go to: Repo → Actions → Caches (left sidebar)

### Workflow File Updates

When modifying workflow files, keep in mind:
- Changes to `build-*.yml` invalidate the Hamlib cache for that platform (cache key includes the workflow file hash).
- Changes to `ci.yml` or `release.yml` do **not** invalidate caches (they're just orchestrators).
- Reusable workflows (`workflow_call`) cannot be tested from fork PRs — they must be on the same repo.

---

## 11. Troubleshooting

### Problem: "refusing to allow an OAuth App to create or update workflow"

**Context:** This appears when the release workflow tries to push to the public repo.

**Root cause:** The credential being used (deploy key, OAuth token, or any non-PAT) cannot modify `.github/workflows/` files. This is a GitHub platform-level restriction.

**Fix:** Ensure `CROSS_REPO_TOKEN` is a **fine-grained PAT** with **Contents: Read and write** AND **Workflows: Read and write** permissions. Classic PATs need the `workflow` scope.

### Problem: macOS build fails with "no identity found"

**Context:** The signing step can't find a Developer ID certificate in the keychain.

**Root cause:** The `DEVELOPER_ID_CERTIFICATE_P12` secret is empty, not base64-encoded properly, or the password is wrong.

**Diagnosis:**
```bash
# Check that the secret exists:
gh secret list --repo WSJTX/wsjtx-internal | grep DEVELOPER_ID

# Re-encode and re-set:
base64 -i app.p12 -o app.p12.b64
gh secret set DEVELOPER_ID_CERTIFICATE_P12 --repo WSJTX/wsjtx-internal < app.p12.b64
```

### Problem: Notarization fails with "Invalid" status

**Context:** The notarytool submission comes back as "Invalid" instead of "Accepted."

**Diagnosis:** The workflow automatically fetches the notarization log on failure. Look for the log output in the GitHub Actions run. Common issues:

| Log message | Meaning | Fix |
|-------------|---------|-----|
| "The signature of the binary is invalid" | Code signing used wrong identity or missed a binary | Check that all executables and dylibs are signed |
| "The binary uses an SDK older than the 10.9 SDK" | Deployment target too old | Check `CMAKE_OSX_DEPLOYMENT_TARGET` (currently 11.0) |
| "The signature does not include a secure timestamp" | Missing `--timestamp` in codesign | Verify the codesign commands include `--timestamp` |

### Problem: Windows build fails at OmniRig install

**Context:** The PowerShell step that downloads OmniRig fails.

**Root cause:** The download URL (`https://www.dxatlas.com/OmniRig/Files/OmniRig.zip`) may be temporarily unavailable.

**Fix:** Re-run the job. If persistent, download OmniRig manually, add the `.exe` to the repo as a build dependency, and update the workflow to use the local copy.

### Problem: CROSS_REPO_TOKEN sync silently skips

**Context:** The release job succeeds but the public repo doesn't get updated. No error in logs — just a warning: "CROSS_REPO_TOKEN not set — skipping public repo sync."

**Root cause:** The secret is not set, or it's set on the wrong repo, or it's empty.

**Fix:**
```bash
# Verify the secret exists:
gh secret list --repo WSJTX/wsjtx-internal | grep CROSS_REPO

# Re-set it:
gh secret set CROSS_REPO_TOKEN --repo WSJTX/wsjtx-internal
# Paste the token value
```

### Problem: Cache not being used

**Context:** Hamlib builds from source every run even though nothing changed.

**Diagnosis:** Check the cache step output in the workflow run. Look for "Cache not found" vs "Cache restored."

**Common causes:**
- Cache key changed (workflow file was modified)
- Cache was evicted (GitHub evicts caches after 7 days of no access, or when the repo exceeds 10 GB of cache storage)
- The `actions/cache` action version changed behavior

### Problem: Build succeeds but binary crashes

**Context:** The built binary segfaults or behaves differently than a local build.

**Diagnosis:**
- Check compiler versions: `gcc --version` / `gfortran --version` in the workflow output
- Check linked libraries: the macOS build has a verification step that checks for remaining Homebrew paths
- Compare CMake configure output between CI and a local build

---

## 12. Reference: Complete File Inventory

### Files to Include in the PR

| File | Purpose | Changes Needed |
|------|---------|----------------|
| `.github/workflows/ci.yml` | CI orchestrator | Branch name, version string |
| `.github/workflows/release.yml` | Release pipeline | Public repo URL, branch name, version string |
| `.github/workflows/build-macos.yml` | macOS build (parameterized arm64/x86_64) | None |
| `.github/workflows/build-linux.yml` | Linux x86_64 build | None |
| `.github/workflows/build-windows.yml` | Windows x86_64 build | None |
| `entitlements.plist` | macOS app entitlements | None (if not already in repo) |
| `Darwin/com.wsjtx.sysctl.plist` | macOS shared memory config | None (if not already in repo) |
| `CMakeLists.txt` | OmniRig type library variable | Add `OMNIRIG_TYPE_LIB` conditional (optional, can be separate PR) |

### Secrets Required on `wsjtx-internal`

| Secret Name | Used By | Required For | Required? |
|-------------|---------|-------------|-----------|
| `CROSS_REPO_TOKEN` | `release.yml` | Public repo sync | Yes |
| `DEVELOPER_ID_CERTIFICATE_P12` | `build-macos.yml` | macOS app code signing | Yes |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | `build-macos.yml` | macOS app code signing | Yes |
| `DEVELOPER_ID_INSTALLER_P12` | `build-macos.yml` | macOS installer signing | Yes |
| `DEVELOPER_ID_INSTALLER_PASSWORD` | `build-macos.yml` | macOS installer signing | Yes |
| `APPLE_ID` | `build-macos.yml` | macOS notarization | Yes |
| `APPLE_APP_SPECIFIC_PASSWORD` | `build-macos.yml` | macOS notarization | Yes |
| `APPLE_TEAM_ID` | `build-macos.yml` | macOS notarization | Yes |
| `WINDOWS_SIGNING_CERT_PFX` | `build-windows.yml` | Windows Authenticode signing | Yes |
| `WINDOWS_SIGNING_CERT_PASSWORD` | `build-windows.yml` | Windows Authenticode signing | Yes |

### External Dependencies (Downloaded at Build Time)

| Dependency | URL | Used By |
|------------|-----|---------|
| Hamlib 4.7.0 | `https://github.com/Hamlib/Hamlib.git` | All four platforms |
| OmniRig | `https://www.dxatlas.com/OmniRig/Files/OmniRig.zip` | Windows only |

### Build-Time Patches Applied in CI

These are `sed` patches applied during the build, not committed to the repo. They work around upstream issues:

| Patch | File | Platform | Why |
|-------|------|----------|-----|
| Comment out MAP65 | `CMakeLists.txt` | Windows | GCC 15 rejects legacy Fortran in `decode0.f90` |
| Fix FFTW3 threads | `CMake/Modules/FindFFTW3.cmake` | Windows | MSYS2 splits FFTW threads into separate lib |
| Symlink dumpcpp | `/mingw64/bin/` | Windows | MSYS2 ships `dumpcpp-qt5`, CMake expects `dumpcpp` |

These patches are candidates for future upstream PRs but are not required for the CI deployment itself.
