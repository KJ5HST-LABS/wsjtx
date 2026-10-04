# CI/CD Deployment Playbook

Reference for configuring and operating the WSJT-X GitHub Actions CI/CD pipeline in the official `WSJTX` organization repositories.

**Audience:** Repository administrators and release managers responsible for CI/CD configuration and release credentials.

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
| Apple Developer ID Application certificate (.p12) | Export from the Apple Developer account holder's keychain | PKCS12 file + password |
| Apple Developer ID Installer certificate (.p12) | Export from the Apple Developer account holder's keychain | PKCS12 file + password |
| App Store Connect API key (for notarization) | A team-owned key created by the Apple Developer Account Holder | `.p8` private key, key ID, and issuer ID |
| Apple Team ID | Apple Developer portal → Membership Details | 10-char alphanumeric like `ABCDE12345` |
| GitHub fine-grained PAT | github.com → Settings → Developer settings → Fine-grained tokens | `github_pat_...` token string |

### Tools

- `gh` ([GitHub CLI](https://cli.github.com/)) authenticated with an account that has admin access to the target repos
- `base64` command (macOS and Linux both have this)
- Git with push access to `WSJTX/wsjtx-internal`

---

## 2. Architecture Overview

Understanding the architecture will help you debug issues during deployment.

> **Tag convention.** Internal `build/v*` tags identify immutable candidates. Only manual promotion creates the corresponding public `v*` tag; public distribution builds start from that public tag.

### Workflow Structure

```
.github/workflows/
├── ci.yml                       ← Orchestrator. Triggers on develop and release/**.
│                                    Linux x86_64 is the default path; full-ci or a
│                                    manual run selects broader platform coverage.
│
├── build-macos.yml              ← Reusable workflow (workflow_call).
│                                    macOS arm64 build; Developer ID
│                                    signing and notarization require credentials.
│
├── build-linux.yml              ← Reusable workflow (workflow_call).
│                                    Linux build (x86_64, aarch64, or armhf),
│                                    unsigned.
│
├── build-windows.yml            ← Reusable workflow (workflow_call).
│                                    Windows x86_64 via MSYS2/MinGW64. Installer
│                                    signing per sign_mode input: ephemeral
│                                    self-signed osslsigncode (CI/DEVEL) or
│                                    none (public unsigned mode or SignPath input).
│
├── sign-windows-release.yml     ← Public repo (WSJTX/wsjtx) only; triggered by
│                                    promoted v* tags for both RC and GA.
│                                    Rebuilds the installer from public source,
│                                    SignPath authenticode-signs it, verifies the
│                                    chain and expected signer in signed mode.
│
├── signpath-smoke.yml           ← workflow_dispatch; public repo.
│                                    ~2-minute SignPath round-trip check
│                                    with a trivial PE — no WSJT source built.
│
├── hamlib-upstream-check.yml    ← Scheduled (`cron: '0 12 * * MON'`) + `workflow_dispatch`.
│                                    Weekly poll of Hamlib upstream tags; files a
│                                    GitHub issue when a newer 4.x release is available.
│                                    No platform builds; self-contained.
│
├── release.yml                  ← Internal `build/v*` candidate builds only.
│                                    Uploads validation artifacts; never publishes.
│
└── promote-release.yml          ← Manual candidate validation and public tag promotion.
```

### How It Flows

**On pushes and pull requests to private `develop` or `release/**`:**
```
Push or pull request
  └─→ ci.yml triggers
       ├─→ validate workflow policy and release-state.txt
       └─→ build/test Linux x86_64 by default
            └─→ full-ci or manual selection adds other platforms
```

**For an RC or GA release:**
```
release/X.Y metadata commit
  └─→ Prepare Release Candidate validates/creates build/vX.Y.Z[-rcN]
       └─→ release.yml builds the private candidate
            └─→ release manager validates/promotes that candidate
                 └─→ public vX.Y.Z[-rcN] builds and checks all distributions
                          └─→ assembled bundle summary and final `public-release` approval
                                └─→ verified GitHub Release publication
```

Source promotion makes the reviewed source public. The public workflow builds and verifies the bundle, then waits for final publication approval. See [Public branch history and GA line policy](#public-branch-history-and-ga-line-policy) for branch and tag behavior.

### Build Strategy

Linux candidate and public builds compile WSJT-X from the selected source commit using prepared dependency images. macOS and Windows build native dependency prefixes and reuse them through Actions caches.

### Cache readiness

Native build summaries show dependency cache hits, misses, and rebuild results. Compiler-cache rows distinguish exact and fallback restores from a miss; a forced recompile is reported separately. The dependency warmer also summarizes each selected platform's result. A cache hit alone does not establish that the application build passed.

Use `cold_build=true` on a manually dispatched macOS or Windows build to bypass workflow-managed dependency and compiler-cache restores and saves. Windows also bypasses the MSYS2 package cache. This leaves the runner's preinstalled software in place. `recache` only forces application recompilation and does not make dependencies cold. The macOS build budget is 180 minutes; confirm a cold run completes dependency builds, tests, and packaging within that budget before relying on it for a release.

### Prepared Linux release images

Before creating a candidate, run Prepare Release Dependencies from protected private `develop`, selecting a protected `develop` or `release/X.Y` source branch and an explicit validated image generation. The workflow resolves the selected branch to an exact commit before validating its recipes. Refresh incompatible or missing images through the existing Linux image publisher first.

Preparation verifies all four images against the selected source recipes: x86_64, aarch64, and the ARMHF cross-builder/runtime pair. It copies them to `ghcr.io/wsjtx/wsjtx` without changing their digests and verifies anonymous access. Images contain dependency tooling, not WSJT-X application builds. Review changes to copied scripts and image metadata before public preparation; a digest-preserving copy retains the original OCI labels and build metadata.

The private workflow needs package read access to the internal images and write access to the destination packages through its `GITHUB_TOKEN`. Destination packages must be public. Configure those package permissions separately; the workflow does not change visibility or repository settings. Prepared image retention tags must remain available for release rebuilds.

Download the successful `prepared-release-dependencies` artifact and review `release-linux-images.json`. Commit that file on the private release branch before candidate tagging. It records the validated generation, four public image digests, and their recipe fingerprints. Application-only changes may reuse it; recipe changes require a new preparation. Keep the detailed preparation record with the private workflow artifacts.

Candidate and public builds consume the committed selection and build WSJT-X afresh. They stop on missing images or incompatible recipes instead of resolving `stable` or refreshing images during release. Candidate provenance binds the selection's checksum and digests; source promotion verifies that binding. The public release manifest records the same builder digests.

### What the Release Produces

Each approved public `v*` tag yields one installer and one command-line tools archive per target plus a source tarball on the public GitHub Release:

| Artifact | Produced by | Format |
|----------|-------------|--------|
| `wsjtx-<ver>-arm64-macOS.pkg` | `build-macos.yml` (arm64 leg) | Hosted Developer ID signing, or a validated package for manual replacement |
| `wsjtx-<ver>-linux-x86_64.AppImage` | `build-linux.yml` (x86_64 leg) | Portable AppImage |
| `wsjtx-<ver>-linux-aarch64.AppImage` | `build-linux.yml` (aarch64 leg) | Portable AppImage |
| `wsjtx-<ver>-linux-armhf.AppImage` | `build-linux.yml` (armhf leg) | Portable AppImage |
| Linux x86_64 `.deb` and `.rpm` | `build-linux.yml` (x86_64 leg) | Distribution packages |
| Linux aarch64 `.deb` and `.rpm` | `build-linux.yml` (aarch64 leg) | Distribution packages |
| Linux armhf `.deb` and `.rpm` | `build-linux.yml` (armhf leg) | Distribution packages |
| `wsjtx-<ver>-win64.exe` | `build-windows.yml` | SignPath Foundation Authenticode for both public RC and GA |
| `wsjtx-<ver>-arm64-macOS-tools.tar.gz` | `build-macos.yml` | Command-line programs with their dylibs in `lib/`; ad-hoc signed, not notarized |
| `wsjtx-<ver>-linux-<arch>-tools.tar.gz` | `build-linux.yml` (x86_64, aarch64 and armhf legs) | Command-line programs that link the distribution's libraries; unsigned |
| `wsjtx-<ver>-windows-x86_64-tools.tar.gz` | `build-windows.yml` | Command-line programs with the DLLs they import; not Authenticode-signed |
| `wsjtx-<ver>-src.tar.gz` | Public release workflow | Source tarball from the public tag |

`CMake/Install.cmake` defines the command-line programs in two lists. Every installer carries `wsjt_installed_cli_tools`: the install rules cover it, and the macOS package stages `/usr/local/wsjtx` from the build's `installed-cli-tools.txt`; unless `/usr/local/wsjtx` is a symbolic link, its postinstall removes programs there that the package does not ship, with their `/usr/local/bin` links, and leaves `lib/` alone. Each tools archive carries both lists, read from the build's `cli-tools.txt`. Staging and packaging fail if a listed program is missing; packaging also fails if a Linux program has an RPATH or RUNPATH entry inside the build tree, or if a Windows program imports a DLL found neither in the staged installation nor in the Windows system directory, or `objdump` cannot read it.

The project-created source tarball is assembled from the public tag. GitHub also generates its own zip and tar.gz source archives for that tag; they contain the tagged tree but may have different compressed hashes. `SHA256SUMS` covers immutable payload assets uploaded by the workflow. In manual macOS signing mode it excludes the replaceable `.pkg` file, which the release manifest identifies separately. The manifest also records the tag, source commit, workflow run, and builder provenance. Checksums detect changed bytes; platform signatures establish signer identity and must be verified separately.

### All-Platforms-Ready Gate

Before publishing, the release workflow requires each platform build to produce its expected installer and tools archive artifacts. This prevents a structurally successful build job from creating a partial release.

The gate checks for one installer and one tools archive per platform:

| Platform | Expected artifact pattern |
|----------|---------------------------|
| macOS arm64 | Hosted-signing artifact, or `artifacts/wsjtx-<ver>-arm64-macOS-unsigned.pkg/*.pkg` in manual mode |
| Linux x86_64 | `artifacts/wsjtx-<ver>-linux-x86_64-AppImage/*.AppImage` |
| Linux aarch64 | `artifacts/wsjtx-<ver>-linux-aarch64-AppImage/*.AppImage` |
| Linux armhf | `artifacts/wsjtx-<ver>-linux-armhf-AppImage/*.AppImage` |
| Linux packages | One non-empty `.deb` and `.rpm` under each architecture's artifact directory |
| Windows x86_64 | `artifacts/wsjtx-<ver>-windows-x86_64-installer-signed/*.exe` |
| Tools archives | One non-empty `.tar.gz` in `artifacts/wsjtx-<ver>-<target>-tools/` for each target: `arm64-macOS`, `linux-x86_64`, `linux-aarch64`, `linux-armhf`, `windows-x86_64` |

If any pattern matches zero files, the release job stops before publishing.

Presence alone is insufficient. The publication gate also requires the expected production filenames and reports, and verifies that their hashes, public tag, and source SHA agree. In manual macOS signing mode the reports prove that the unsigned packages came from the expected validation builds; their final signatures are verified after manual replacement. A separate installed-runtime smoke test remains necessary because cryptographic verification does not establish application behavior.

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

If you choose the restrictive option, explicitly allow the third-party actions used by the workflows:
- `actions/checkout@v7`
- `actions/cache/restore@v5` and `actions/cache/save@v5`
- `actions/cache/restore@v6` and `actions/cache/save@v6`
- `actions/upload-artifact@v7`
- `actions/download-artifact@v8`
- `msys2/setup-msys2@v2`

**Important:** GitHub's allowlist must match each workflow `uses:` entry. Re-run the following after any Dependabot bump to stay aligned:

```bash
grep -rE 'uses: (actions/|msys2/)' .github/workflows/ | sort -u
```

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

## 4. Phase 2: Install the Release Workflows

The workflows in this repository are already configured for private trunk `develop`, release branches `release/**`, public branch `master`, and public repository `WSJTX/wsjtx`. Copying an older prototype or changing repository names inside `release.yml` would restore the obsolete behavior where an internal build published and synchronized source in one step.

The release-related files have distinct responsibilities:

| File | Responsibility |
|------|----------------|
| `release-state.txt` | Tracked numeric version, channel, RC number, and archive revision placeholder |
| `release-tag-helper.yml` | Validate the release-branch tip and CI, create an immutable private candidate tag, then call the candidate build |
| `release.yml` | Build private validation artifacts only; never publish or copy source |
| `promote-release.yml` | Validate the candidate run and atomically create its immutable tag and create or fast-forward its public release branch; advance public `master` only for newest-line GA |
| `public-release.yml` | Rebuild from public source, enforce tagged signing policy, verify and summarize the bundle, wait for final approval, and preserve Latest on older-line GA |

`release-state.txt` is the version source of truth. Keep `revision=$Format:%H$` literal in Git; Git expands it in exported archives. The workflows reject a tag whose version/channel does not match the tracked state.

The Hamlib version remains pinned on reusable-workflow calls. To audit all pin sites before changing it:

```bash
rg -n 'hamlib_branch:' .github/workflows
```

---

## 5. Phase 3: Create Repository Secrets

The public `public-release` environment must require one approval from an eligible release manager and allow self-review. The `operation=promote` dispatch approves public source; only the final `publish` job waits for release approval. `CROSS_REPO_TOKEN` is a private repository secret.

### Public Final Publication Approval

Configure WSJTX/wsjtx Settings > Environments > public-release:

1. Turn on Required reviewers and add one or more release managers. Any one may approve.
2. Turn off Prevent self-review so the person who promoted the source can approve the same run.
3. Save. If deployment refs are restricted, allow tags matching `v*`.

The first job reads the environment with `Actions: read` and stops before platform builds if the rule is missing, malformed, unreadable, or blocks self-review. Only the final `publish` job should use this environment.

When migrating a repository secret to a restricted environment, verify the environment copy before deleting the repository-level secret. GitHub can otherwise fall back to a same-named repository secret when a job references `secrets.NAME`, defeating the intended ref restriction. Keep Apple signing credentials environment-only.

### Navigate to Secrets Settings

```
https://github.com/WSJTX/wsjtx-internal/settings/environments
```

Or: Repo → Settings → Environments. A repository administrator can restrict `candidate-tagging` and `source-promotion` to protected `release/*` branches and migrate the promotion token into `source-promotion`.

### 5.1 Secret 1: `CROSS_REPO_TOKEN`

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

### 5.2 macOS Code Signing Environment

Create the `apple-release-signing` environment on `WSJTX/wsjtx`, restrict it to release tags, and grant access only to release maintainers. These four secrets provide the distinct Developer ID identities used for application code and installer packages. Prefer fresh, CI-specific certificates rather than transferring a maintainer's long-lived personal export.

#### Credential responsibilities

The WSJT-X Apple Developer membership is currently held by **John G4KLA**, who is therefore the current Apple Developer Account Holder. The responsibilities below are described by role so that the procedure remains valid if the Account Holder changes.

The Apple Developer account holder exports the signing identities. A repository administrator stores the exported credentials as GitHub Actions secrets. The team must assign responsibility for credential rotation and release-artifact verification.

The workflow uses two identities with different responsibilities:

- **Developer ID Application** signs application executables, frameworks, plug-ins, and the command-line tools the package installs.
- **Developer ID Installer** signs the outer `.pkg` installer.

Notarization uses the App Store Connect API key in §5.3 rather than either certificate password. Rotate a certificate's `.p12` and password together. Rotate the notarization key on the team's schedule, when access changes, or after suspected exposure.

The command-line tools archives are not Developer ID-signed or notarized in either signing mode: their programs and `lib/` dylibs carry the build's ad-hoc signatures, and `SHA256SUMS` and the release manifest bind the archive bytes to the tag and source commit. Browsers mark downloads with the `com.apple.quarantine` attribute, and macOS blocks quarantined programs that are not notarized, so remove the attribute from the archive before extracting it: `xattr -d com.apple.quarantine wsjtx-<ver>-arm64-macOS-tools.tar.gz`.

#### Preparing the .p12 files

You need two signing identities associated with the Apple Developer team:
- **Developer ID Application** — signs the app binary and dylibs
- **Developer ID Installer** — signs the `.pkg` installer

If you already have `.p12` files exported from Keychain Access, skip to the base64 step.

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
gh secret set DEVELOPER_ID_CERTIFICATE_P12 --repo WSJTX/wsjtx --env apple-release-signing < app.p12.b64

# Password for the application certificate:
gh secret set DEVELOPER_ID_CERTIFICATE_PASSWORD --repo WSJTX/wsjtx --env apple-release-signing
# (paste the password you chose when exporting, press Enter)

# Installer signing certificate (base64-encoded .p12):
gh secret set DEVELOPER_ID_INSTALLER_P12 --repo WSJTX/wsjtx --env apple-release-signing < installer.p12.b64

# Password for the installer certificate:
gh secret set DEVELOPER_ID_INSTALLER_PASSWORD --repo WSJTX/wsjtx --env apple-release-signing
# (paste the password you chose when exporting, press Enter)
```

**After setting secrets, delete the local .p12 and .b64 files.** They contain your signing keys.

```bash
rm app.p12 installer.p12 app.p12.b64 installer.p12.b64
```

### 5.3 Apple Notarization API Key

Notarization submits the signed package to Apple's service for automated security checks. An accepted submission is then stapled to the package so the ticket can be validated without contacting Apple. Notarization is distinct from Developer ID signing and does not by itself verify Gatekeeper acceptance or application behavior.

Have the Account Holder create a team-owned App Store Connect API key scoped for notarization. Store its key ID as `APP_STORE_CONNECT_KEY_ID`, issuer ID as `APP_STORE_CONNECT_ISSUER_ID`, and base64-encoded `.p8` as `APP_STORE_CONNECT_PRIVATE_KEY_P8_BASE64`, all as `apple-release-signing` environment secrets.

Configure these non-secret variables in the same environment: `APPLE_TEAM_ID`, `APPLE_APPLICATION_CERTIFICATE_SHA1`, and `APPLE_INSTALLER_CERTIFICATE_SHA1`. The SHA-1 values are the full certificate fingerprints without relying on certificate-name matching. Keeping expected identities separate lets the job reject a valid but unintended certificate.

```bash
gh secret set APP_STORE_CONNECT_KEY_ID --repo WSJTX/wsjtx --env apple-release-signing
gh secret set APP_STORE_CONNECT_ISSUER_ID --repo WSJTX/wsjtx --env apple-release-signing
gh secret set APP_STORE_CONNECT_PRIVATE_KEY_P8_BASE64 --repo WSJTX/wsjtx --env apple-release-signing
gh variable set APPLE_TEAM_ID --repo WSJTX/wsjtx --env apple-release-signing --body '<team-id>'
gh variable set APPLE_APPLICATION_CERTIFICATE_SHA1 --repo WSJTX/wsjtx --env apple-release-signing --body '<40-hex-fingerprint>'
gh variable set APPLE_INSTALLER_CERTIFICATE_SHA1 --repo WSJTX/wsjtx --env apple-release-signing --body '<40-hex-fingerprint>'
```

Do not use a maintainer's Apple ID password or app-specific password. The API key is independently revocable and does not tie unattended releases to one person's login.

### Verification: Confirm All Secrets Are Set

```bash
gh secret list --repo WSJTX/wsjtx --env apple-release-signing
```

The environment inventory must contain both certificate identities and the API-key notarization credential set declared by `build-macos.yml`: `DEVELOPER_ID_CERTIFICATE_P12`, `DEVELOPER_ID_CERTIFICATE_PASSWORD`, `DEVELOPER_ID_INSTALLER_P12`, `DEVELOPER_ID_INSTALLER_PASSWORD`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, and `APP_STORE_CONNECT_PRIVATE_KEY_P8_BASE64`. Separately confirm `CROSS_REPO_TOKEN` in private repository secrets until it is migrated to the restricted `source-promotion` environment.

Also configure the public workflow's non-secret expected Apple Team ID and SHA-1 fingerprints for the Application and Installer certificates. These are identifiers, not private-key material; the distribution job uses them to reject a valid but unintended identity.

Set repository variable `MACOS_DISTRIBUTION_SIGNING_ENABLED=false` until the full environment is configured and tested. In that state the workflow publishes validated unsigned packages under the stable release filenames so a release manager can replace them manually. The manifest identifies that package as replaceable and excludes it from immutable hashes; workflow reruns preserve an existing package by name. Set the variable to `true` only after the package completes signing, notarization, stapling, identity, entitlement, and Gatekeeper verification. Distribution mode fails closed if any credential is absent.

> **About Windows signing.** Public RC and GA installers use SignPath Foundation by default. A tagged release can explicitly select an unsigned installer. No Windows certificate private key exists in GitHub; it remains in SignPath's HSM. Ordinary CI builds may use a per-run ephemeral self-signed certificate.

### 5.4 Windows Authenticode Signing via SignPath Foundation

> **How it works.** SignPath Foundation signs OSS artifacts built from the public repository, so the signature attests public-source provenance as well as identity. A promoted `vX.Y.Z` or `vX.Y.Z-rcN` tag triggers the public build, submits the unsigned installer under the `release-signing` policy, verifies the returned Authenticode signature and timestamp, and makes that verified installer eligible for publication. A failed or rejected request blocks the release. The certificate's private key lives in SignPath's HSM; there is no `.pfx` to export or store in GitHub.

SignPath signs only the installer. The Windows command-line tools archive is not submitted: its programs and DLLs carry no Authenticode signature, and `SHA256SUMS` and the release manifest bind the archive bytes to the tag and source commit.

#### The one secret

Create public environment `windows-release-signing`, restrict it to protected `master` and `v*` release tags, and set the token there (not on `wsjtx-internal`). `master` access permits the explicit smoke-test workflow; production signing still accepts only a public RC or GA tag.

```bash
gh secret set SIGNPATH_API_TOKEN --repo WSJTX/wsjtx --env windows-release-signing
# (paste the SignPath CI user's API token, press Enter)
```

Set `WINDOWS_SIGNER_SUBJECT` and comma-separated `WINDOWS_SIGNER_THUMBPRINTS` as variables in that environment. The thumbprint list permits an explicit certificate rollover window; remove the old value after rollover.

```bash
gh variable set WINDOWS_SIGNER_SUBJECT --repo WSJTX/wsjtx --env windows-release-signing --body '<exact certificate subject>'
gh variable set WINDOWS_SIGNER_THUMBPRINTS --repo WSJTX/wsjtx --env windows-release-signing --body '<thumbprint>[,<rollover-thumbprint>]'
```

The SignPath CI user must be a **submitter** on the signing policies (`release-signing`, `test-signing`). The public workflow consumes its own signed result; the internal promotion token does not need access to SignPath credentials.

#### SignPath dashboard configuration

- **Artifact configuration** — GitHub Actions artifacts are always ZIP-wrapped, so the root element must be `zip-file`:

  ```xml
  <?xml version="1.0" encoding="utf-8" ?>
  <artifact-configuration xmlns="http://signpath.io/artifact-configuration/v1">
    <zip-file>
      <pe-file path="*.exe">
        <authenticode-sign />
      </pe-file>
    </zip-file>
  </artifact-configuration>
  ```

- **Trusted build system** — the predefined *GitHub.com* trusted build system added to the SignPath org and linked to the `wsjtx` project; the [SignPath GitHub App](https://github.com/apps/signpath) installed with access to the public repo (origin verification).

#### Validation

`signpath-smoke.yml` (workflow_dispatch on the public repo) signs a trivial hello-world PE through the complete round trip in ~2 minutes — no WSJT source is built or exposed. Dispatch it against `test-signing` to validate plumbing without consuming a `release-signing` approval. Success: the workflow completes green — the returned exe carries a parseable Authenticode signature (hard-checked); chain status is printed for inspection only, since the test certificate never chains to a trusted root.

#### RC/DEVEL builds

Public RC and GA installers use SignPath `release-signing` by default. An explicit `windows_signing=unsigned` value in the tagged `release-state.txt` selects an unsigned installer when SignPath is unavailable; the public workflow records that mode in the manifest and verifies the installer accordingly.

### 5.5 Linux Signing (Optional)

Linux binary signing is less critical — Linux users don't encounter SmartScreen-style warnings when downloading binaries. However, GPG-signing release tarballs is good practice if the team distributes `.tar.gz` or `.deb` packages. This would require one additional secret (`GPG_SIGNING_KEY`) and a small step in the release workflow.

### Verification: Credential Boundaries

Confirm the current `CROSS_REPO_TOKEN` repository secret is present on the private repository. Apple material belongs only in public environment `apple-release-signing`, and `SIGNPATH_API_TOKEN` belongs only in public environment `windows-release-signing`. Only the final public `publish` job uses the `public-release` approval gate.

---

## 6. Phase 4: Supporting Files

These files are referenced by the workflows and must exist in the repo.

### `entitlements.plist` (repo root)

This file is the source of truth for executable entitlements. The **Code sign binaries** step applies the complete plist to every executable under `wsjtx.app/Contents/MacOS`, re-applies it when signing the app bundle and main executable, and applies it to staged standalone executables. Frameworks, plug-in libraries, and other bundled libraries do not receive this plist. The completed bundle must pass deep signature verification.

The current plist enables:

| Entitlement | Current requirement |
|-------------|---------------------|
| `com.apple.security.cs.disable-library-validation` | Allows loading bundled third-party code that does not satisfy library validation, including ad-hoc CI artifacts. |
| `com.apple.security.device.audio-input` | Allows WSJT-X to capture audio under hardened runtime. `NSMicrophoneUsageDescription` in the app's `Info.plist` supplies the separate TCC permission prompt. |

Both entitlements are currently applied as one set, including to executables that may not exercise every capability. Narrowing that scope is a security-sensitive behavior change and is outside this playbook.

Bundle signing re-signs the main executable, so it must receive the entitlement file again after nested code is signed. `codesign --verify` validates signature integrity but does not prove that required entitlements are present. Inspect the effective entitlements and exercise audio capture and a decoder cycle when validating a release.

### `Darwin/com.wsjtx.sysctl.plist`

The macOS installer package copies this into `/Library/LaunchDaemons/` to configure shared memory limits (required for WSJT-X interprocess communication). Check if it exists:

```bash
ls -la Darwin/com.wsjtx.sysctl.plist
```

### OmniRig type-library input

Windows CI passes `-DOMNIRIG_TYPE_LIB=<path>` to CMake because the workflow
already knows the location of the installed OmniRig executable. The build
supports this input directly. Local Windows builds can omit it and allow
`dumpcpp` to query the registered OmniRig type library instead.

MSYS2 installs the tool as `dumpcpp-qt5`; the build discovers both that name
and the unversioned `dumpcpp` name. Do not create an alias in the workflow.

---

## 7. Phase 5: Submit the PR

### Option A: PR from a Branch

If you have write access to `WSJTX/wsjtx-internal`, create a feature branch from `develop`, commit the workflow and supporting-file changes together, push it, and open a PR. Do not copy older prototype workflows over the current files: the candidate, promotion, signing, and publication boundaries must be reviewed as one system.

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
  --body "Five-platform CI (macOS arm64, Linux x86_64, Linux aarch64, Linux armhf, Windows x86_64) with tag-triggered releases (\`build/v*\`)."
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

### Step 3: Check the Selected Platforms

An ordinary push runs the default Linux x86_64 check. Before a candidate, apply the `full-ci` label to a PR or manually dispatch full CI and confirm all five target builds. Expected times (first run, no cache):

| Platform | First Run | Cached Run |
|----------|-----------|------------|
| macOS arm64 | ~12-15 min | ~8 min |
| Linux x86_64 | ~10-12 min | ~7 min |
| Linux aarch64 | ~10-12 min | ~7 min |
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
| macOS signing fails with empty identity | Application P12 is present, but the credential set is incomplete or invalid | Verify the application P12, its password, and the imported identity |
| macOS notarization fails | Missing, revoked, or mismatched App Store Connect API credential | Verify the API key, key ID, issuer ID, and expected Team ID in `apple-release-signing` |
| Windows build timeout (>60 min) | MSYS2 cache miss + slow package install | Re-run — the cache will be populated for next time |
| "refusing to allow an OAuth App to create or update workflow" | This error can appear at PR merge time if the branch contains workflow files and was pushed with a deploy key | Push the branch using a PAT or via the GitHub web UI instead |

### Step 5: Revert the Test Commit

```bash
git revert HEAD
git push
```

---

## 9. Phase 7: Test the Release Pipeline

Only do this after CI is green on all five targets.

### Step 1: Prepare Release Metadata

On `release/X.Y`, commit the numeric version and matching `DEVEL`, `RC n`, or `GA` state in `release-state.txt`. For `3.3.0-rc1`, use `version=3.3.0`, `channel=RC`, and `prerelease=1`. Leave its `$Format:%H$` revision placeholder intact so Git substitutes the source SHA when exporting an archive. Wait for branch CI before tagging. This metadata commit is required even when GA application source is otherwise identical to the last RC, because it makes builds from GitHub's source archives identify themselves correctly.

### Step 2: Build the Private Candidate

Commit the reviewed [Linux image selection](#prepared-linux-release-images) before creating the candidate.

Run Prepare Release Candidate on `release/X.Y` at the expected SHA. Use `operation=validate` first and review the summary, then use `operation=create`. This creates the immutable `build/v...` tag and private validation artifacts. It does not publish or copy source.

### Step 3: Approve Public Source Promotion

Record the candidate run ID. From the same branch and SHA, run Promote Release Source with `operation=validate`; review the summary, then run it with `operation=promote`. Promotion atomically creates the immutable public tag and creates or fast-forwards `release/X.Y` at the candidate SHA, following the [public branch policy](#public-branch-history-and-ga-line-policy). Conflicting tags and non-fast-forward updates fail without changing refs. If public refs change after validation, validate again.

### Step 4: Review and Approve Final Publication

After the builds finish, review the Verified public release bundle summary before approving. It lists the tag, source SHA, run link, signing modes, assets, and checksums. The summary identifies manually replaceable macOS packages, which are excluded from `SHA256SUMS`. Windows uses SignPath by default; source-pinned unsigned releases do not need SignPath. Hosted macOS packages must be Developer ID-signed, notarized, stapled, and pass Gatekeeper.

Once the bundle is ready, approve the final `publish` job in `public-release`. One listed reviewer is enough. With Prevent self-review off, the person who promoted the source can approve the same run. The job rechecks the bundle and tag before publishing. RCs are prereleases. Only the newest GA version on the newest line gets Latest; other GA releases use `--latest=false`.

### Public branch history and GA line policy

Promotion publishes only the validated candidate SHA. Public tags are immutable; release branches contain only promoted commits and must advance by ancestry.

- RCs advance `release/X.Y` and leave `master` unchanged.
- A GA on the newest line also fast-forwards `master`.
- An older-line GA leaves `master` and GitHub Latest unchanged.

Determine the newest GA line from the highest numeric `X.Y` in public GA tags, ignoring RCs and release dates. Reject a GA below the highest GA tag on its line. Only the newest GA version on the newest line can become Latest. Stop if GA tags are missing or refs are malformed.

The promotion workflow creates a missing `release/X.Y` branch. If that line already has public GA or RC tags, the candidate must descend from its latest tag. Do not seed public release branches manually. Subsequent candidates must descend from the existing branch.

Before a newest-line GA, verify that public `master` is an ancestor of the candidate. If it is not, stop and review the divergent history and tree differences. Reconcile the ancestry on the private release branch through a reviewed manual merge, verify that the resulting tree matches the intended release source, and rerun private CI and candidate validation. Promotion never creates this merge or force-rewrites public history.

After promotion, verify that the public release branch and tag resolve to the candidate SHA. For a newest-line GA, check `master` too. For an older-line GA, confirm that `master` and GitHub Latest did not change. Public release-branch pushes skip the full CI matrix; private release branches and pull requests still run it.

If `MACOS_DISTRIBUTION_SIGNING_ENABLED` is false, after publication download the `.pkg` asset, sign and notarize it outside GitHub, verify its signature and installed behavior, then replace the asset without changing its filename. It is intentionally absent from `SHA256SUMS`; the manifest and assemble summary identify it as manually replaceable. Enable the variable after the `apple-release-signing` environment is fully configured.

### Step 5: Verify the Artifacts

Download the release artifacts to a new directory:

```bash
RELEASE_DIR="$(mktemp -d)"
gh release download "v$VERSION" --repo WSJTX/wsjtx --dir "$RELEASE_DIR"
PKG="$RELEASE_DIR/wsjtx-${VERSION}-arm64-macOS.pkg"
```

Verify the installer signature, stapled notarization ticket, and Gatekeeper policy independently:

```bash
pkgutil --check-signature "$PKG"
xcrun stapler validate "$PKG"
spctl --assess --type install --verbose=2 "$PKG"
```

Success requires a valid Developer ID Installer chain, a valid staple, and an `accepted` Gatekeeper assessment. These checks do not validate nested application signatures, entitlements, or runtime behavior.

Inspect the packaged application rather than the staged build tree:

```bash
EXPANDED="$RELEASE_DIR/expanded"
pkgutil --expand-full "$PKG" "$EXPANDED"
APP="$EXPANDED/wsjtx-component.pkg/Payload/Applications/wsjtx.app"

codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements :- "$APP/Contents/MacOS/wsjtx"
codesign -d --entitlements :- "$APP/Contents/MacOS/jt9"
```

Signature verification must succeed, and both inspected executables must contain the two keys in `entitlements.plist`. The effective-entitlement check detects an outer bundle re-sign that preserved a valid signature but removed the executable entitlements.

Finally, install the package on a disposable or release-test macOS system and launch the installed app through Finder. Confirm that macOS grants audio input after the usage prompt, the receive level responds to live input, and `jt9` completes a decode cycle without a hardened-runtime or dynamic-loader failure. A successful signing or notarization check does not establish these runtime properties.

### Step 6: Recover Safely

Rerun jobs against the immutable tag for transient signing, notarization, or service failures. If source or metadata changes, make a new commit and cut the next RC. Do not clean up a failed attempt by moving or recreating either tag; retaining the original identity preserves the audit trail and prevents an already downloaded release name from silently changing meaning.

---

## 10. Ongoing Maintenance

### Secret Rotation

| Secret | Rotation Schedule | How to Rotate |
|--------|-------------------|---------------|
| `CROSS_REPO_TOKEN` | Before expiry (check token settings at github.com) | Generate new PAT → update the current private repository secret, or migrate it to a restricted `source-promotion` environment |
| App Store Connect API key | On team schedule, personnel change, or suspected exposure | Revoke the old key, create a team-owned replacement, and update `apple-release-signing` |
| macOS signing certificates (.p12) | When certificate expires (typically 5 years) | Export new cert from Keychain → base64-encode → update both P12 and PASSWORD secrets |
| SignPath API token | On SignPath schedule, submitter change, or suspected exposure | Replace the public-repo token; the signing key remains in SignPath's HSM |

### Version Bumps

Before creating an RC or GA candidate, commit the numeric version and matching release channel/RC number in `release-state.txt`. Workflows derive their build inputs from that tracked state and reject a mismatched tag; do not maintain duplicate per-platform version literals.

```bash
# Review the tracked release identity before running Prepare Release Candidate:
git diff HEAD^ -- release-state.txt
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

### Branch, Tag, and Environment Protection

Protect `develop` and `release/*` from force-push and deletion, and apply the team's normal CI/review policy. The two manual helper workflows must be run from the current protected `release/X.Y` tip; they reject any other workflow ref or SHA.

On WSJTX/wsjtx, protect `v*` tags from updates and deletion, and limit creation to the source-promotion identity. Protect `master` and `release/*` from force-pushes and deletion.

Restrict `candidate-tagging` and `source-promotion` to protected private `release/*` branches, `apple-release-signing` to public `v*` tags, and `windows-release-signing` to protected public `master` plus `v*` tags. Configure `public-release` as described in [Public Final Publication Approval](#public-final-publication-approval).

### Dependabot & Auto-merge Policy

**Repo feature — enable everywhere this machinery lives:**

```bash
gh api -X PATCH /repos/<org>/<repo> -f allow_auto_merge=true
```

Enabling the feature only makes auto-merge *available* per-PR; it does not auto-merge anything on its own.

**Usage policy:**

| Posture | Dependabot security updates | Patch bumps (x.y.Z) | Minor/major bumps (x.Y.z / X.y.z) |
|---------|-----------------------------|---------------------|-----------------------------------|
| Sandbox | Auto-merge | Auto-merge | Auto-merge OK — breakage teaches here |
| Production | Auto-merge | Auto-merge | **Human merge click required** |

Rationale: CI cannot catch runtime-behavior regressions in major action-version bumps (output-format, permission-model, default-input changes). A human click is the cheapest way to force a moment of review proportional to the blast radius of a production action upgrade.

**Arming auto-merge on a specific PR:**

```bash
gh pr merge <N> --repo <org>/<repo> --auto --squash --delete-branch
```

Dependabot auto-rebases its PRs when the base branch moves, CI re-runs, and GitHub merges once the branch-protection checks (including "up-to-date with base") pass.

---

## 11. Troubleshooting

### Problem: "refusing to allow an OAuth App to create or update workflow"

**Context:** This appears when the release workflow tries to push to the public repo.

**Root cause:** The credential being used (deploy key, OAuth token, or any non-PAT) cannot modify `.github/workflows/` files. This is a GitHub platform-level restriction.

**Fix:** Ensure `CROSS_REPO_TOKEN` is a **fine-grained PAT** with **Contents: Read and write** AND **Workflows: Read and write** permissions. Classic PATs need the `workflow` scope.

### Problem: macOS build fails with "no identity found"

**Context:** The signing step can't find a Developer ID certificate in the keychain.

**Root cause:** Distribution mode was selected, but the imported file, password, or certificate contents do not yield the expected Developer ID Application identity.

**Diagnosis:**
```bash
# Check that the secret exists:
gh secret list --repo WSJTX/wsjtx --env apple-release-signing | rg DEVELOPER_ID

# Re-encode and re-set:
base64 -i app.p12 -o app.p12.b64
gh secret set DEVELOPER_ID_CERTIFICATE_P12 --repo WSJTX/wsjtx --env apple-release-signing < app.p12.b64
```

### Problem: Notarization fails with "Invalid" status

**Context:** The notarytool submission comes back as "Invalid" instead of "Accepted."

**Diagnosis:** The workflow automatically fetches the notarization log on failure. Look for the log output in the GitHub Actions run. Common issues:

| Log message | Meaning | Fix |
|-------------|---------|-----|
| "The signature of the binary is invalid" | Code signing used wrong identity or missed a binary | Check that all executables and dylibs are signed |
| "The binary uses an SDK older than the 10.9 SDK" | Deployment target too old | Check `CMAKE_OSX_DEPLOYMENT_TARGET` (11.0, the `deployment_target` input of `build-macos.yml`) |
| "The signature does not include a secure timestamp" | Missing `--timestamp` in codesign | Verify the codesign commands include `--timestamp` |

### Problem: Windows build fails at OmniRig install

**Context:** The PowerShell step that downloads OmniRig fails.

**Root cause:** The download URL (`https://www.dxatlas.com/OmniRig/Files/OmniRig.zip`) may be temporarily unavailable.

**Fix:** Re-run the job. If persistent, download OmniRig manually, add the `.exe` to the repo as a build dependency, and update the workflow to use the local copy.

### Problem: Public source promotion reports a missing token

**Context:** Promote Release Source stops before it inspects or creates the public tag.

**Root cause:** The secret is not set, or it's set on the wrong repo, or it's empty.

**Fix:**
```bash
# Verify the secret exists:
gh secret list --repo WSJTX/wsjtx-internal | rg CROSS_REPO

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
| `.github/workflows/ci.yml` | CI orchestrator for `develop` and `release/**` | None |
| `.github/workflows/release.yml` | Reusable private candidate build | None |
| `.github/workflows/release-tag-helper.yml` | Validate/create immutable internal candidates | None |
| `.github/workflows/promote-release.yml` | Validate/promote exact source to the public repo | None |
| `.github/workflows/public-release.yml` | Public policy-checked build, bundle verification, and GitHub Release | None |
| `.github/workflows/sign-windows-release.yml` | Public SignPath build/sign/verification | SignPath project and policy identifiers |
| `.github/workflows/build-macos.yml` | macOS arm64 build | None |
| `.github/workflows/build-linux.yml` | Linux build (parameterized x86_64/aarch64/armhf) | None |
| `.github/workflows/build-windows.yml` | Windows x86_64 build | None |
| `.github/workflows/hamlib-upstream-check.yml` | Scheduled (weekly cron + `workflow_dispatch`) poll of Hamlib upstream tags; files a tracking issue when a newer 4.x release is available. No platform builds; self-contained. | None |
| `entitlements.plist` | macOS app entitlements | None (if not already in repo) |
| `Darwin/com.wsjtx.sysctl.plist` | macOS shared memory config | None (if not already in repo) |
| `release-state.txt` | Tracked version, channel, RC number, and archival revision | Set before each candidate |
| `.github/scripts/release-policy.py` | Release identity, asset, archive, signing-report, manifest, and public ref promotion policy | None |

### Secrets Required on `wsjtx-internal`

Use the canonical inventory and setup procedure in [Phase 3](#5-phase-3-create-repository-secrets). `CROSS_REPO_TOKEN` is currently a private repository secret; Apple material belongs in public environment `apple-release-signing`, and `SIGNPATH_API_TOKEN` belongs in public environment `windows-release-signing`. No SignPath private key is stored in either repository.

### External Dependencies (Downloaded at Build Time)

| Dependency | URL | Used By |
|------------|-----|---------|
| Hamlib 4.7.2 | `https://github.com/Hamlib/Hamlib.git` | All supported platforms |
| OmniRig | `https://www.dxatlas.com/OmniRig/Files/OmniRig.zip` | Windows only |

### Build-Time Source Patches

The current workflows do not patch the WSJT-X source tree during a build.
Windows support for MAP65, the MSYS2 FFTW threads library, and the
`dumpcpp-qt5` executable is implemented in the repository and exercised by CI.
