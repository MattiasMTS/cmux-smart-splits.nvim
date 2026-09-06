"""Exercise ZLE and the Lua command runner without moving real cmux panes."""

import json
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT / "shell/cmux-smart-splits.zsh"


class Shell:
    def __init__(self, env):
        self.master, slave = pty.openpty()
        self.process = subprocess.Popen(
            ["zsh", "-d", "-i"], stdin=slave, stdout=slave, stderr=slave,
            env=env, start_new_session=True,
        )
        os.close(slave)
        self.output = b""
        try:
            self.until(lambda: b"CMUX_TEST> " in self.output)
        except Exception:
            self.close()
            raise

    def send(self, data):
        os.write(self.master, data)

    def until(self, predicate, timeout=5):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            if select.select([self.master], [], [], 0.02)[0]:
                self.output += os.read(self.master, 65536)
        raise AssertionError(f"Shell timed out:\n{self.output.decode(errors='replace')}")

    def close(self):
        self.process.terminate()
        try:
            self.process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait(timeout=3)
        os.close(self.master)


class ShellTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="cmux-smart-splits-")
        self.addCleanup(temporary.cleanup)
        self.directory = Path(temporary.name)
        self.state_path = self.directory / "state.json"
        panes = [
            {
                "id": name, "surface_ids": [f"shell-{name}"],
                "focused": name == "left",
                "pixel_frame": {"x": x, "y": 0, "width": 500, "height": 500},
                "cell_width_points": 10, "cell_height_points": 20,
            }
            for name, x in [("left", 0), ("right", 500)]
        ]
        self.state_path.write_text(json.dumps({"panes": panes, "calls": [], "resizes": []}))
        bin_dir = self.directory / "bin"
        bin_dir.mkdir()
        cli = bin_dir / "cmux"
        shutil.copyfile(ROOT / "tests/fixtures/cmux", cli)
        cli.chmod(0o755)
        self.env = os.environ.copy()
        for key in ("SSH_CONNECTION", "TMUX", "ZELLIJ", "CMUX_SMART_SPLITS_ROOT"):
            self.env.pop(key, None)
        self.env.update(
            CMUX_WORKSPACE_ID="test-workspace", CMUX_TEST_STATE=str(self.state_path),
            PATH=f"{bin_dir}:{self.env['PATH']}", TERM="xterm-256color",
        )

    def state(self):
        return json.loads(self.state_path.read_text())

    def focused(self):
        return next(pane["id"] for pane in self.state()["panes"] if pane["focused"])

    def shell(self, surface, configured=True):
        startup = self.directory / surface
        startup.mkdir()
        capture = startup / "buffer"
        rc = (
            "PROMPT='CMUX_TEST> '\nRPROMPT=''\nKEYTIMEOUT=10\nbindkey -v\n"
            f"export PATH={shlex.quote(self.env['PATH'])}\n"
            f'_test_buffer() {{ print -rn -- "$BUFFER" > {shlex.quote(str(capture))}; }}\n'
            "zle -N _test_buffer\nbindkey '^]' _test_buffer\n"
        )
        if configured:
            rc += f"source {shlex.quote(str(HELPER))}\n"
        (startup / ".zshrc").write_text(rc)
        env = dict(self.env, CMUX_SURFACE_ID=surface, ZDOTDIR=str(startup))
        shell = Shell(env)
        self.addCleanup(shell.close)
        return shell, capture

    def test_fresh_shells_navigate_both_ways_and_preserve_command(self):
        left, capture = self.shell("shell-left")
        right, _ = self.shell("shell-right")
        left.send(b"echo unfinished\x0c")
        left.until(lambda: self.focused() == "right")
        left.send(b"\x1d")
        left.until(capture.exists)
        self.assertEqual(capture.read_text(), "echo unfinished")
        right.send(b"\x08")
        right.until(lambda: self.focused() == "left")
        self.assertEqual(sum(args[3] == "focus-pane" for args in self.state()["calls"]), 2)

    def test_alt_key_resizes_through_lua_runner(self):
        shell, _ = self.shell("shell-left")
        shell.send(b"\x1bl")
        shell.until(lambda: len(self.state()["resizes"]) == 1)
        args = self.state()["resizes"][0]
        self.assertEqual(args[args.index("--pane") + 1], "left")
        self.assertEqual(args[args.index("--amount") + 1], "70")
        self.assertIn("-R", args)

    def test_missing_startup_source_does_not_install_bindings(self):
        shell, capture = self.shell("shell-left", configured=False)
        shell.send(b"\x0c\x1d")
        shell.until(capture.exists)
        self.assertEqual(self.state()["calls"], [])
        shell.send(f"source {shlex.quote(str(HELPER))}\r".encode())
        shell.send(b"\x0c")
        shell.until(lambda: self.focused() == "right")

    def test_repeated_source_installs_all_keymaps(self):
        script = r'''
source "$1"
source "$1"
for map in emacs viins vicmd; do
  for key direction in h left j down k up l right; do
    [[ $(bindkey -M "$map" "^${(U)key}") == *"cmux-smart-move-$direction" ]] || exit 1
    [[ $(bindkey -M "$map" "^[$key") == *"cmux-smart-resize-$direction" ]] || exit 1
  done
done
'''
        result = subprocess.run(
            ["zsh", "-dfi", "-c", script, "test", str(HELPER)],
            env=dict(self.env, CMUX_SURFACE_ID="shell-left"),
            capture_output=True, text=True, timeout=5,
        )
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_nested_sessions_keep_shell_bindings(self):
        for key in ("SSH_CONNECTION", "TMUX", "ZELLIJ"):
            with self.subTest(key=key):
                result = subprocess.run(
                    ["zsh", "-dfi", "-c", 'source "$1"; bindkey -M viins "^H"', "test", str(HELPER)],
                    env=dict(self.env, CMUX_SURFACE_ID="shell-left", **{key: "nested"}),
                    capture_output=True, text=True, timeout=5,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertNotIn("cmux-smart", result.stdout)

    @unittest.skipUnless(os.environ.get("CMUX_TEST_INSTALLED_SHELL"), "opt-in installed zsh startup check")
    def test_installed_shell_loads_bindings_without_manual_source(self):
        env = os.environ.copy()
        for key in ("SSH_CONNECTION", "TMUX", "ZELLIJ", "CMUX_SMART_SPLITS_ROOT"):
            env.pop(key, None)
        env.update(CMUX_WORKSPACE_ID="test-workspace", CMUX_SURFACE_ID="shell-left")
        result = subprocess.run(
            ["zsh", "-lic", 'bindkey -M viins "^H"; bindkey -M viins "^[l"'],
            env=env, capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("cmux-smart-move-left", result.stdout)
        self.assertIn("cmux-smart-resize-right", result.stdout)


if __name__ == "__main__":
    unittest.main(verbosity=2)
