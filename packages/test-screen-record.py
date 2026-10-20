"""Backend lifecycle tests, without capturing a real screen or microphone."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

HELPER = Path(__file__).with_name("screen-record.py")


class ScreenRecordTest(unittest.TestCase):
    def run_recording(self, microphone=False, fail_export=False, source="test-microphone"):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            scripts = {
                "xdg-user-dir": "import os; print(os.environ['TEST_ROOT'])",
                "pactl": "import os; print(os.environ['TEST_SOURCE'])",
                "wf-recorder": """
import json, os, pathlib, signal, sys, time
pathlib.Path(os.environ['TEST_ROOT'], 'arguments.json').write_text(json.dumps(sys.argv))
pathlib.Path(sys.argv[sys.argv.index('-f') + 1]).write_bytes(b'fake mp4')
signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
while True: time.sleep(.05)
""",
                "ffmpeg": """
import os, pathlib, shutil, sys
if os.environ.get('FAIL_EXPORT'): sys.exit(1)
shutil.copyfile(sys.argv[sys.argv.index('-i') + 1], sys.argv[-1])
""",
            }
            for name, body in scripts.items():
                script = root / name
                script.write_text(f"#!{sys.executable}\n{body}\n")
                script.chmod(0o755)
            env = dict(os.environ, PATH=f"{root}:{os.environ['PATH']}",
                       XDG_RUNTIME_DIR=directory, TEST_ROOT=directory, TEST_SOURCE=source)
            if fail_export:
                env["FAIL_EXPORT"] = "1"
            result = subprocess.run([sys.executable, str(HELPER), "DP-1"]
                                    + (["--microphone"] if microphone else []),
                                    input="stop\n", capture_output=True, text=True, env=env, timeout=10)
            states = [json.loads(line) for line in result.stdout.splitlines()]
            if source.endswith(".monitor"):
                self.assertEqual(states[-1]["status"], "error")
                self.assertFalse((root / "arguments.json").exists())
                return
            arguments = json.loads((root / "arguments.json").read_text())
            self.assertEqual("--audio=test-microphone" in arguments, microphone)
            self.assertEqual(states[0]["status"], "recording")
            self.assertEqual(states[1]["status"], "exporting")
            if fail_export:
                self.assertEqual(states[-1]["status"], "error")
                self.assertEqual(len(list(root.glob('Screen Recordings/.*.recording.mp4'))), 1)
            else:
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(states[-1]["status"], "saved")
                self.assertTrue(Path(states[-1]["path"]).exists())
                self.assertFalse(list(root.glob('Screen Recordings/.*.mp4')))

    def test_silent(self):
        self.run_recording()

    def test_microphone(self):
        self.run_recording(microphone=True)

    def test_export_failure_preserves_recording(self):
        self.run_recording(fail_export=True)

    def test_monitor_source_is_not_a_microphone(self):
        self.run_recording(microphone=True, source="speaker.monitor")


if __name__ == "__main__":
    unittest.main()
