import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
PUBLIC = (ROOT / ".github/workflows/public-release.yml").read_text()
SIGN = (ROOT / ".github/workflows/sign-windows-release.yml").read_text()
PREPARE = (ROOT / ".github/workflows/prepare-release-dependencies.yml").read_text()


def step(workflow: str, name: str) -> str:
    start = workflow.index(f"      - name: {name}\n")
    following = re.search(r"\n      - ", workflow[start + 1:])
    return workflow[start:start + 1 + following.start()] if following else workflow[start:]


def job(workflow: str, name: str) -> str:
    start = workflow.index(f"\n  {name}:\n") + 1
    following = re.search(r"\n  [A-Za-z0-9_-]+:\n", workflow[start:])
    return workflow[start:start + following.start() + 1] if following else workflow[start:]


class ReleaseWorkflowPolicyTests(unittest.TestCase):
    def test_public_release_marks_every_non_ga_channel_prerelease_and_latest_stays_ga_only(self):
        publish = step(PUBLIC, "Publish public GitHub Release")
        self.assertRegex(publish, r'if \[ "\$CHANNEL" != GA \]; then\s+EXPECTED_PRERELEASE=true\s+fi')
        self.assertRegex(publish, r'if \[ "\$CHANNEL" != GA \]; then\s+FLAGS\+=\(--prerelease\)\s+fi')
        self.assertEqual(publish.count("--prerelease"), 1)
        self.assertRegex(
            publish,
            r'LATEST=false\s+if \[ "\$CHANNEL" = GA \] && \[ "\$GA_RELEASE_IS_LATEST" = true \]; then\s+LATEST=true\s+fi',
        )
        self.assertEqual(publish.count("LATEST=true"), 1)
        self.assertIn('FLAGS+=("--latest=$LATEST")', publish)

    def test_publication_environment_and_its_validation_follow_the_channel(self):
        selected = "${{ needs.prepare.outputs.release_channel == 'BETA' && 'beta-release' || 'public-release' }}"
        self.assertIn(f"    environment: {selected}\n", job(PUBLIC, "publish"))
        guard = step(PUBLIC, "Validate final publication environment protection")
        self.assertRegex(
            guard,
            r'ENVIRONMENT=public-release\s+POLICIES=\(\)\s+'
            r'if \[ "\$CHANNEL" = BETA \]; then\s+ENVIRONMENT=beta-release',
        )
        self.assertIn('"repos/$GITHUB_REPOSITORY/environments/$ENVIRONMENT/deployment-branch-policies"', guard)
        self.assertIn('"repos/$GITHUB_REPOSITORY/environments/$ENVIRONMENT"', guard)
        self.assertIn('--channel "$CHANNEL" "${POLICIES[@]}"', guard)
        self.assertLess(PUBLIC.index(guard), PUBLIC.index("\n  macos:\n"))

    def test_betas_publish_validated_macos_packages_with_nothing_replaceable(self):
        identity = step(PUBLIC, "Validate public release tag and source identity")
        self.assertRegex(
            identity,
            r'if \[ "\$CHANNEL" = BETA \]; then\s+echo "macos_sign_mode=validation" >> "\$GITHUB_OUTPUT"',
        )
        self.assertLess(
            identity.index('[ "$CHANNEL" = BETA ]'),
            identity.index('[ "$MACOS_DISTRIBUTION_SIGNING_ENABLED" = true ]'),
        )
        recheck = step(PUBLIC, "Recheck bundle and immutable public tag")
        self.assertRegex(recheck, r'if \[ "\$CHANNEL" = BETA \]; then\s+EXPECTED_MACOS_MODE=unsigned\s+elif')
        publish = step(PUBLIC, "Publish public GitHub Release")
        self.assertIn(".macos_signing.replaceable_assets[]", publish)
        self.assertNotIn("MACOS_MODE", publish)

    def test_a_rerun_compares_every_published_asset_except_the_manifests_replaceable_ones(self):
        publish = step(PUBLIC, "Publish public GitHub Release")
        self.assertIn("mapfile -t REPLACEABLE_NAMES < <(jq -r '.macos_signing.replaceable_assets[]' "
                      "release-bundle/release-manifest.json)", publish)
        preserve = [
            "if printf '%s\\n' \"${REPLACEABLE_NAMES[@]}\" | grep -Fxq \"$name\"; then",
            "if printf '%s\\n' \"${ACTUAL_NAMES[@]}\" | grep -Fxq \"$name\"; then",
            "echo \"Preserving manually replaceable macOS asset: $name\"",
        ]
        self.assertRegex(publish, r"\s+".join(map(re.escape, preserve)))
        self.assertEqual(len(re.findall(r"^\s+continue$", publish, re.M)), 1)
        self.assertEqual(publish.count('cmp "$file"'), 1)

    def test_windows_signing_guard_admits_only_rc_and_ga(self):
        guard = step(SIGN, "Require a public RC or GA invocation")
        self.assertIn('test "$(jq -r .channel <<<"$IDENTITY")" = "$CHANNEL"', guard)
        self.assertIn('test "$CHANNEL" = RC || test "$CHANNEL" = GA', guard)
        self.assertLess(SIGN.index(guard), SIGN.index("uses: signpath/github-action-submit-signing-request"))

    def test_dependency_preparation_fails_unless_develop_and_the_source_branch_are_protected(self):
        prepare = job(PREPARE, "prepare")
        self.assertIn("github.ref == 'refs/heads/develop'", prepare.split("\n    steps:\n", 1)[0])
        self.assertEqual(PREPARE.count("ref_protected"), 1)
        self.assertNotIn("continue-on-error", prepare)
        guard = step(PREPARE, "Require protected develop")
        self.assertNotRegex(guard, r"\n        if:")
        self.assertIn("REF_PROTECTED: ${{ github.ref_protected }}", guard)
        self.assertRegex(guard, r'if \[ "\$REF_PROTECTED" != true \]; then\s+echo "::error::[^"]+"\s+exit 1')
        self.assertLess(prepare.index("Require protected develop"), prepare.index("actions/checkout"))
        source = step(PREPARE, "Resolve protected source branch to an exact commit")
        self.assertRegex(
            source,
            r'if \[ "\$\(jq -r \'\.protected\' <<< "\$branch"\)" != true \]; then\s+echo "::error::[^"]+"\s+exit 1',
        )

    def test_full_artifact_downloads_drop_the_armhf_build_tree(self):
        release = (ROOT / ".github/workflows/release.yml").read_text()
        for workflow, job_name, next_step in ((release, "candidate-ready", "Verify all candidate artifacts"), (PUBLIC, "assemble", "Build corresponding source archive")):
            body = job(workflow, job_name)
            download = body.index("uses: actions/download-artifact@v8\n        with:\n          path: artifacts\n")
            drop = body.index("      - name: Drop the ARMHF build tree\n        run: rm -rf artifacts/armhf-build-tree\n")
            self.assertLess(download, drop, job_name)
            self.assertLess(drop, body.index(f"      - name: {next_step}\n"), job_name)


if __name__ == "__main__":
    unittest.main()
