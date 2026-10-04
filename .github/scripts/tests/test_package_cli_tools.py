import os
import pathlib
import subprocess
import tarfile
import tempfile
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[3]
SCRIPT = ROOT / ".github/scripts/package-cli-tools.sh"
BUILD_MACOS = ROOT / ".github/workflows/build-macos.yml"


class PackageCliToolsTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = pathlib.Path(temporary.name)
        self.bin = self.root / "bin"
        self.source = self.root / "build"
        self.out = self.root / "out"
        self.bin.mkdir()
        self.source.mkdir()

    def stub(self, command, outputs, failing=()):
        body = "#!/bin/sh\ncase \"$*\" in\n"
        body += "".join(f"  */{name}) exit 1 ;;\n" for name in failing)
        for name, lines in outputs.items():
            body += f"  */{name})\n" + "".join(f"    printf '%s\\n' '{line}'\n" for line in lines) + "    ;;\n"
        (self.bin / command).write_text(body + "esac\n", encoding="utf-8")
        (self.bin / command).chmod(0o755)

    def files(self, directory, names):
        directory.mkdir(exist_ok=True)
        for name in names:
            (directory / name).write_text(name, encoding="utf-8")

    def package(self, platform, tools, *arguments):
        tools_file = self.root / "cli-tools.txt"
        tools_file.write_text("".join(f"{tool}\n" for tool in tools), encoding="utf-8")
        return subprocess.run(
            [
                "bash", str(SCRIPT), "--platform", platform, "--version", "9.9.9", "--arch", "x86_64",
                "--tools", str(tools_file), "--source", str(self.source), "--out", str(self.out), *arguments,
            ],
            env=dict(os.environ, PATH=f"{self.bin}:{os.environ['PATH']}", TMPDIR=str(self.root)),
            text=True,
            capture_output=True,
            check=False,
        )

    def members(self, name):
        with tarfile.open(self.out / f"{name}.tar.gz") as archive:
            return sorted(member.name.split("/", 1)[1] for member in archive.getmembers() if member.isfile())

    def linux_build(self, runpaths):
        (self.source / "CMakeCache.txt").write_text(
            "CMAKE_CACHEFILE_DIR:INTERNAL=/work/wsjtx-build\n", encoding="utf-8"
        )
        self.files(self.source, ["jt9", "wsprd", "encode77", "wsjtx"])
        self.stub("readelf", {
            tool: [f" 0x000000000000001d (RUNPATH)            Library runpath: [{runpath}]"]
            for tool, runpath in runpaths.items()
        })

    def test_linux_archive_holds_exactly_the_listed_tools(self):
        self.linux_build({"jt9": "$ORIGIN/lib:/opt/hamlib/lib"})
        result = self.package("linux", ["jt9", "wsprd", "encode77"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.members("wsjtx-9.9.9-linux-x86_64-tools"), ["README.txt", "encode77", "jt9", "wsprd"]
        )

    def test_missing_tool_fails_naming_it(self):
        self.linux_build({})
        (self.source / "encode77").unlink()
        result = self.package("linux", ["jt9", "wsprd", "encode77"])
        self.assertEqual(result.returncode, 1)
        self.assertIn("missing under", result.stderr)
        self.assertIn("encode77", result.stderr)
        self.assertFalse(self.out.joinpath("wsjtx-9.9.9-linux-x86_64-tools.tar.gz").exists())

    def test_linux_build_tree_runpath_fails(self):
        self.linux_build({"wsprd": "$ORIGIN:/work/wsjtx-build/lib"})
        result = self.package("linux", ["jt9", "wsprd"])
        self.assertEqual(result.returncode, 1)
        self.assertIn("wsprd:/work/wsjtx-build/lib", result.stderr)
        self.assertFalse(self.out.joinpath("wsjtx-9.9.9-linux-x86_64-tools.tar.gz").exists())

    def windows_build(self, system_dlls, failing=()):
        self.files(self.source, ["jt9.exe", "encode77.exe", "wsjtx.exe"])
        self.files(self.root / "dlls", ["libfoo.dll", "libbar.dll", "unused.dll"])
        self.files(self.root / "system", system_dlls)
        self.stub("objdump", {
            "jt9.exe": ["\tDLL Name: libfoo.dll", "\tDLL Name: KERNEL32.dll"],
            "libfoo.dll": ["\tDLL Name: LIBBAR.DLL"],
            "libbar.dll": ["\tDLL Name: KERNEL32.dll"],
            "encode77.exe": ["\tDLL Name: msvcrt.dll"],
        }, failing)
        return self.package(
            "windows", ["jt9", "encode77"],
            "--dll-dir", str(self.root / "dlls"), "--system-dir", str(self.root / "system"),
        )

    def test_windows_archive_holds_tools_and_their_dll_closure(self):
        result = self.windows_build(["KERNEL32.dll", "msvcrt.dll"])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            self.members("wsjtx-9.9.9-windows-x86_64-tools"),
            ["encode77.exe", "jt9.exe", "libbar.dll", "libfoo.dll"],
        )

    def test_windows_import_outside_dll_and_system_dirs_fails(self):
        result = self.windows_build(["KERNEL32.dll"])
        self.assertEqual(result.returncode, 1)
        self.assertIn("msvcrt.dll(encode77.exe)", result.stderr)
        self.assertFalse(self.out.joinpath("wsjtx-9.9.9-windows-x86_64-tools.tar.gz").exists())

    def test_windows_objdump_failure_fails_naming_the_file(self):
        result = self.windows_build(["KERNEL32.dll", "msvcrt.dll"], failing=["libfoo.dll"])
        self.assertEqual(result.returncode, 1)
        self.assertIn("objdump failed on libfoo.dll", result.stderr)
        self.assertFalse(self.out.joinpath("wsjtx-9.9.9-windows-x86_64-tools.tar.gz").exists())


class MacosPostinstallTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.root = pathlib.Path(temporary.name) / "volume"
        self.scripts = pathlib.Path(temporary.name) / "scripts"
        self.scripts.mkdir()
        lines = BUILD_MACOS.read_text(encoding="utf-8").splitlines()
        start = next(i for i, line in enumerate(lines) if line.strip() == 'cat > "${SCRIPTS}/postinstall" << \'SCRIPT\'')
        indent = len(lines[start]) - len(lines[start].lstrip())
        end = next(i for i in range(start + 1, len(lines)) if lines[i] == " " * indent + "SCRIPT")
        body = [line[indent:] for line in lines[start + 1:end]]
        body = [":" if line.startswith(("/bin/launchctl", "/usr/sbin/sysctl")) else line for line in body]
        self.assertTrue(any(line.startswith('root="${3%/}"') for line in body))
        for line in body:
            for prefix in line.split("/usr/local")[:-1]:
                self.assertTrue(prefix.endswith(("$root", '"$root"')), line)
        self.postinstall = self.scripts / "postinstall"
        self.postinstall.write_text("\n".join(body) + "\n", encoding="utf-8")
        (self.scripts / "installed-cli-tools.txt").write_text("jt9\nwsprd\n", encoding="utf-8")

    def executable(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("#!/bin/sh\n", encoding="utf-8")
        path.chmod(0o755)

    def run_postinstall(self):
        return subprocess.run(
            ["bash", str(self.postinstall), "pkg", "/", str(self.root), "/"],
            stdin=subprocess.DEVNULL, text=True, capture_output=True, check=False,
        )

    def test_upgrade_removes_unshipped_programs_and_their_links(self):
        programs = self.root / "usr/local/wsjtx"
        links = self.root / "usr/local/bin"
        for name in ("jt9", "wsprd", "wsprcode"):
            self.executable(programs / name)
        links.mkdir(parents=True)
        (links / "wsprcode").symlink_to(programs / "wsprcode")
        result = self.run_postinstall()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(sorted(path.name for path in programs.iterdir()), ["jt9", "wsprd"])
        self.assertEqual(sorted(path.name for path in links.iterdir()), ["jt9", "wsprd"])

    def test_symlinked_program_directory_is_not_cleaned(self):
        elsewhere = self.root / "Users/someone/bin"
        for name in ("jt9", "backup.sh"):
            self.executable(elsewhere / name)
        (self.root / "usr/local").mkdir(parents=True)
        (self.root / "usr/local/wsjtx").symlink_to(elsewhere)
        result = self.run_postinstall()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((elsewhere / "backup.sh").exists())

    def test_trailing_non_executable_entry_does_not_fail_the_install(self):
        programs = self.root / "usr/local/wsjtx"
        self.executable(programs / "jt9")
        (programs / "zz-notes.txt").write_text("notes", encoding="utf-8")
        result = self.run_postinstall()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((self.root / "usr/local/bin/jt9").is_symlink())


if __name__ == "__main__":
    unittest.main()
