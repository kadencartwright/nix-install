"""Run with the Python + watchdog environment used by photos-sync-watch."""

import pathlib
import subprocess
import sys
import tempfile
import time


def wait_until(predicate, message, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError(message)


with tempfile.TemporaryDirectory(prefix="photos-watch-test-") as directory:
    base = pathlib.Path(directory)
    photos = base / "Photos"
    photos.mkdir()
    calls = base / "calls"
    hold = base / "hold"
    fake = base / "systemctl"
    fake.write_text(
        f"#!{sys.executable}\n"
        "import pathlib, sys, time\n"
        "assert sys.argv[1:] == ['--user', 'start', 'photos-sync-local.service']\n"
        f"base = pathlib.Path({str(base)!r})\n"
        "with (base / 'calls').open('a') as output:\n"
        "    output.write('sync\\n')\n"
        "while (base / 'hold').exists():\n"
        "    time.sleep(0.05)\n"
        "for path in (base / 'Photos').rglob('*'):\n"
        "    if path.is_file():\n"
        "        path.read_bytes()\n"
    )
    fake.chmod(0o700)
    watcher = pathlib.Path(__file__).resolve().parents[1] / "home/photos-sync-watch.py"
    process = subprocess.Popen(
        [sys.executable, str(watcher), str(photos), str(fake)],
        stdout=subprocess.PIPE,
        text=True,
    )

    def count():
        return len(calls.read_text().splitlines()) if calls.exists() else 0

    try:
        assert "Watching" in process.stdout.readline()
        nested = photos / "new album" / "nested"
        nested.mkdir(parents=True)
        for index in range(5):
            (nested / f"{index}.jpg").write_text("photo")
            time.sleep(0.1)
        time.sleep(1)
        assert count() == 0, "Burst was not debounced"
        wait_until(lambda: count() == 1, "Nested creation did not trigger sync")
        time.sleep(4)
        assert count() == 1, "Read-only sync caused a feedback loop"

        hold.touch()
        (nested / "0.jpg").write_text("first edit")
        wait_until(lambda: count() == 2, "Edit did not trigger sync")
        (nested / "0.jpg").write_text("edit during sync")
        time.sleep(3.5)
        assert count() == 2, "Watcher started overlapping jobs"
        hold.unlink()
        wait_until(lambda: count() == 3, "Change during sync was lost")

        (nested / "1.jpg").rename(nested / "renamed.jpg")
        (nested / "2.jpg").unlink()
        wait_until(lambda: count() == 4, "Rename/deletion did not trigger sync")
        time.sleep(4)
        assert count() == 4, "Unexpected duplicate sync after quiet period"

        photos.rename(base / "moved-photos")
        assert process.wait(timeout=5) == 1, "Root replacement did not request restart"
        print("PASS: debounce, recursive events, edits during sync, no read loop, root replacement")
    finally:
        hold.unlink(missing_ok=True)
        process.terminate()
        process.wait(timeout=5)
