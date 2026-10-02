import pathlib
import re
import unittest


REPOSITORY = pathlib.Path(__file__).resolve().parents[3]


class LinuxCcachePolicyTests(unittest.TestCase):
    def read(self, relative_path):
        return (REPOSITORY / relative_path).read_text(encoding="utf-8")

    def sanitizer_step(self, name):
        action = self.read(".github/actions/build-linux-sanitizers/action.yml")
        match = re.search(
            rf"^    - name: {re.escape(name)}\n(?P<body>.*?)(?=^    - |\Z)",
            action,
            re.MULTILINE | re.DOTALL,
        )
        self.assertIsNotNone(match, name)
        return match.group("body")

    def assert_cache_tiers(self, text, prefix):
        primary = (
            f"{prefix}${{{{ steps.image.outputs.ccache_compatibility_id }}}}-"
            "${{ steps.image.outputs.generation }}-${{ github.sha }}"
            "${{ steps.ccache-key.outputs.suffix }}"
        )
        generation = (
            f"{prefix}${{{{ steps.image.outputs.ccache_compatibility_id }}}}-"
            "${{ steps.image.outputs.generation }}-"
        )
        compatible = (
            f"{prefix}${{{{ steps.image.outputs.ccache_compatibility_id }}}}-"
        )
        self.assertIn(f"key: {primary}", text)
        generation_index = text.index(f"          {generation}")
        compatible_index = text.index(f"          {compatible}", generation_index + 1)
        self.assertLess(generation_index, compatible_index)

    def test_normal_cache_prefers_current_image_generation(self):
        action = self.read(".github/actions/build-linux-payload/action.yml")
        self.assert_cache_tiers(action, "ccache-linux-${{ inputs.arch }}-")
        self.assertIn(
            'export CCACHE_COMPILERCHECK="${{ steps.image.outputs.ccache_compiler_check }}"',
            action,
        )
        self.assertIn('if: inputs.runtime_base == \'host\'', action)
        self.assertIn('echo "CC=gcc"', action)
        self.assertIn('echo "CXX=g++"', action)
        self.assertIn(
            "if: inputs.save_ccache == 'true' && steps.image.outputs.recipe_match == 'true' && steps.ccache.outputs.cache-hit != 'true'",
            action,
        )

    def test_sanitizer_save_requires_trusted_successful_build(self):
        action = self.read(".github/actions/build-linux-sanitizers/action.yml")
        save = self.sanitizer_step("Save sanitizer objects")
        for condition in (
            "inputs.save_ccache == 'true'",
            "github.ref == 'refs/heads/develop'",
            "steps.image.outputs.recipe_match == 'true'",
            "steps.ccache.outputs.cache-hit != 'true'",
        ):
            self.assertIn(condition, save)
        self.assertNotIn("always()", save)
        self.assertNotIn("!cancelled()", save)
        self.assertIn("key: ${{ steps.ccache.outputs.cache-primary-key }}", save)
        self.assertIn("path: ${{ steps.sanitizer.outputs.ccache_dir }}", save)
        self.assertLess(
            action.index("- name: Require sanitizer tests to pass"),
            action.index("- name: Save sanitizer objects"),
        )

    def test_sanitizer_tests_remain_enabled_by_default(self):
        workflow = self.read(".github/workflows/build-linux-sanitizers.yml")
        action = self.read(".github/actions/build-linux-sanitizers/action.yml")
        self.assertRegex(
            workflow,
            r"      run_tests:\n(?:        .*\n)*?        type: boolean\n        default: true",
        )
        self.assertRegex(
            action,
            r'  run_tests:\n(?:    .*\n)*?    default: "true"',
        )
        self.assertIn("run_tests: ${{ inputs.run_tests }}", workflow)
        self.assertIn("inputs.sanitizer == 'tsan' && 180 || 60", workflow)

    def test_build_only_sanitizer_keeps_test_targets_and_instrumentation(self):
        configure = self.sanitizer_step("Configure sanitizer build")
        self.assertIn("-DWSJT_ENABLE_TESTS=ON", configure)
        self.assertIn("-DWSJT_ENABLE_GUI_SMOKE_TESTS=ON", configure)
        for name in (
            "Configure sanitizer build",
            "Build sanitizer targets",
            "Verify sanitizer instrumentation",
        ):
            self.assertNotIn("inputs.run_tests", self.sanitizer_step(name))
        for name in (
            "Prepare test scratch directory",
            "Run tests",
            "Publish test summary",
            "Upload test results",
            "Require sanitizer tests to pass",
        ):
            with self.subTest(step=name):
                self.assertIn("inputs.run_tests == 'true'", self.sanitizer_step(name))
        enforce = self.sanitizer_step("Require sanitizer tests to pass")
        self.assertIn("always()", enforce)
        self.assertIn('steps.ctest.outcome }}" != "success"', enforce)
        self.assertIn("exit 1", enforce)

    def test_sanitizer_cache_keeps_profile_and_generation(self):
        action = self.read(".github/actions/build-linux-sanitizers/action.yml")
        self.assert_cache_tiers(
            action,
            "ccache-linux-x86_64-${{ steps.sanitizer.outputs.cache_key }}-",
        )
        self.assertIn(
            'export CCACHE_COMPILERCHECK="${{ steps.image.outputs.ccache_compiler_check }}"',
            action,
        )

    def test_armhf_verifies_and_forwards_cache_identity(self):
        workflow = self.read(".github/workflows/build-linux.yml")
        self.assert_cache_tiers(workflow, "ccache-linux-armhf-")
        self.assertIn(
            "verify-armhf-ci-image.sh cross-builder armhf", workflow
        )
        self.assertIn("verify-armhf-ci-image.sh runtime armhf", workflow)
        self.assertIn(
            "CROSS_BUILDER_IMAGE: ${{ needs.resolve-image.outputs.cross_image_reference }}",
            workflow,
        )
        self.assertEqual(
            workflow.count(
                "RUNTIME_IMAGE: ${{ needs.resolve-image.outputs.image_reference }}"
            ),
            2,
        )
        self.assertIn("build-linux-armhf-cross.sh", workflow)
        self.assertIn("validate-linux-armhf-runtime.sh", workflow)
        self.assertIn("HAMLIB_BRANCH: ${{ inputs.hamlib_branch }}", workflow)
        self.assertIn("CCACHE_COMPILERCHECK: ${{ steps.image.outputs.ccache_compiler_check }}", workflow)
        self.assertIn("-e CCACHE_COMPILERCHECK", workflow)
        self.assertIn("-e WSJTX_CI_IMAGE_ALLOW_RECIPE_MISMATCH", workflow)
        self.assertIn("cross_recipe_match", workflow)
        self.assertIn("runtime_recipe_match", workflow)
        self.assertIn(
            "if: inputs.save_ccache && steps.image.outputs.recipe_match == 'true' && steps.ccache.outputs.cache-hit != 'true'",
            workflow,
        )

    def test_release_requires_pinned_armhf_pair_without_stale_recipe_fallback(self):
        workflow = self.read(".github/workflows/release.yml")
        armhf_job = workflow.split("  linux-armhf:\n", 1)[1].split(
            "\n  windows:\n", 1
        )[0]
        self.assertNotIn("allow_stale_image: true", armhf_job)
        self.assertIn("image_source: public-release", armhf_job)
        self.assertIn("image_digest: ${{ needs.prepare.outputs.armhf_digest }}", armhf_job)
        self.assertIn("armhf_cross_image_digest: ${{ needs.prepare.outputs.armhf_cross_digest }}", armhf_job)


if __name__ == "__main__":
    unittest.main()
