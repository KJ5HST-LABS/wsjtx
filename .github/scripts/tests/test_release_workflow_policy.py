import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
PUBLIC = (ROOT / ".github/workflows/public-release.yml").read_text()
SIGN = (ROOT / ".github/workflows/sign-windows-release.yml").read_text()


def step(workflow: str, name: str) -> str:
    start = workflow.index(f"      - name: {name}\n")
    following = re.search(r"\n      - ", workflow[start + 1:])
    return workflow[start:start + 1 + following.start()] if following else workflow[start:]


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

    def test_windows_signing_guard_admits_only_rc_and_ga(self):
        guard = step(SIGN, "Require a public RC or GA invocation")
        self.assertIn('test "$(jq -r .channel <<<"$IDENTITY")" = "$CHANNEL"', guard)
        self.assertIn('test "$CHANNEL" = RC || test "$CHANNEL" = GA', guard)
        self.assertLess(SIGN.index(guard), SIGN.index("uses: signpath/github-action-submit-signing-request"))


if __name__ == "__main__":
    unittest.main()
