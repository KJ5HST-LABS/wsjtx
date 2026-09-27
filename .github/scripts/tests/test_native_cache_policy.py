import importlib.util
import pathlib
import os
import subprocess
import sys
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[3]
SPEC = importlib.util.spec_from_file_location(
    "summary", ROOT / ".github/scripts/summarize-native-caches.py")
summary = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(summary)


class NativeCachePolicyTests(unittest.TestCase):
    def test_compiler_only_command(self):
        result = subprocess.run(
            [sys.executable, str(SPEC.origin), "--compiler"],
            env={**os.environ, "CACHE_STEPS": "{}", "COLD_BUILD": "true"},
            capture_output=True, text=True, check=True)
        self.assertIn("| Compiler objects | bypassed (cold build) | not run |", result.stdout)

    def test_unknown_dependency_is_rejected(self):
        result = subprocess.run(
            [sys.executable, str(SPEC.origin), "unknown"],
            env={**os.environ, "CACHE_STEPS": "{}"},
            capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("unknown dependency: unknown", result.stderr)

    def test_restore_outcomes(self):
        cases = [
            ({}, "not run"),
            ({"outcome": "failure"}, "failure"),
            ({"outcome": "cancelled"}, "cancelled"),
            ({"outcome": "success", "outputs": {"cache-hit": "true"}}, "exact hit"),
            ({"outcome": "success", "outputs": {"cache-hit": "false", "cache-matched-key": "older"}}, "fallback restore"),
            ({"outcome": "success", "outputs": {"cache-hit": ""}}, "miss"),
        ]
        for step, expected in cases:
            with self.subTest(expected=expected):
                self.assertEqual(summary.restore_status(step, False), expected)
        self.assertEqual(summary.restore_status({}, True), "bypassed (cold build)")

    def test_failed_rebuild_and_forced_recompilation_are_distinct(self):
        report = summary.render({
            "qt-cache": {"outcome": "success"},
            "qt-build": {"outcome": "failure"},
            "ccache": {"outcome": "success", "outputs": {"cache-hit": "true"}},
            "compile": {"outcome": "skipped"},
        }, ["qt"], recache=True, compiler=True)
        self.assertIn("| Qt | miss | failure |", report)
        self.assertIn("| Compiler objects | exact hit | not run; forced recompilation requested |", report)

    def test_cold_build_blocks_every_workflow_cache_restore_and_save(self):
        for platform in ["macos", "windows"]:
            text = (ROOT / f".github/workflows/build-{platform}.yml").read_text()
            self.assertEqual(len(re.findall(r"^      cold_build:", text, re.M)), 2)
            for step in re.split(r"^      - ", text, flags=re.M)[1:]:
                if "uses: actions/cache/" in step:
                    self.assertIn("!inputs.cold_build", step)
            self.assertIn("CCACHE_DIR=$(mktemp -d", text)
            self.assertIn("id: compile", text)
        windows = (ROOT / ".github/workflows/build-windows.yml").read_text()
        self.assertIn("cache: ${{ !inputs.cold_build }}", windows)
        self.assertIn("cold_build: ${{ inputs.cold_build }}", windows)
        action = (ROOT / ".github/actions/build-windows-deps/action.yml").read_text()
        for step in re.split(r"^    - ", action, flags=re.M)[1:]:
            if "uses: actions/cache/" in step:
                self.assertIn("inputs.cold_build != 'true'", step)

    def test_summaries_run_after_failures(self):
        paths = [".github/workflows/build-macos.yml", ".github/workflows/build-windows.yml",
                 ".github/actions/warm-macos-deps/action.yml", ".github/actions/build-windows-deps/action.yml"]
        for path in paths:
            text = (ROOT / path).read_text()
            for step in re.split(r"^\s+- name: ", text, flags=re.M)[1:]:
                if step.startswith("Summarize"):
                    self.assertIn("if: always()", step)
        warmer = (ROOT / ".github/workflows/warm-dependency-caches.yml").read_text()
        self.assertIn("  summary:\n    if: always()", warmer)


if __name__ == "__main__":
    unittest.main()
