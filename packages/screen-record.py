"""Record one Wayland output; a stdin line (or bar shutdown) stops safely."""
import argparse
import datetime
import fcntl
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import tempfile
import time


def emit(**state):
    try:
        print(json.dumps(state), flush=True)
    except BrokenPipeError:
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("output")
    parser.add_argument("--microphone", action="store_true")
    args = parser.parse_args()
    runtime = Path(os.environ["XDG_RUNTIME_DIR"])
    with (runtime / "quickshell-screen-record.lock").open("w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("A screen recording is already running")
        videos = subprocess.check_output(["xdg-user-dir", "VIDEOS"], text=True).strip()
        folder = Path(videos or Path.home() / "Videos") / "Screen Recordings"
        folder.mkdir(parents=True, exist_ok=True)
        stamp = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S-%f")
        target = folder / f"Screen-{stamp}.mp4"
        raw = folder / f".Screen-{stamp}.recording.mp4"
        exported = folder / f".Screen-{stamp}.export.mp4"
        command = ["wf-recorder", "-o", args.output, "-r", "30", "-c", "libx264",
                   "-p", "crf=23", "-p", "preset=veryfast", "-x", "yuv420p", "-f", str(raw)]
        if args.microphone:
            source = subprocess.check_output(["pactl", "get-default-source"], text=True).strip()
            if not source or source.endswith(".monitor"):
                raise RuntimeError("Select a microphone as the default input in Audio first")
            command += [f"--audio={source}", "-C", "aac"]
        stopping = False

        def stop_requested(*_):
            nonlocal stopping
            stopping = True

        signal.signal(signal.SIGTERM, stop_requested)
        signal.signal(signal.SIGINT, stop_requested)
        with tempfile.TemporaryFile(mode="w+") as log:
            recorder = subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=log, stderr=log)
            try:
                # Allow immediate startup errors to surface before showing the timer.
                time.sleep(0.4)
                if recorder.poll() is None:
                    emit(status="recording")
                while recorder.poll() is None and not stopping:
                    if select.select([sys.stdin], [], [], 0.2)[0]:
                        sys.stdin.readline()
                        stopping = True
            finally:
                if recorder.poll() is None:
                    recorder.send_signal(signal.SIGINT)
                    try:
                        recorder.wait(timeout=20)
                    except subprocess.TimeoutExpired:
                        recorder.kill()
                        recorder.wait()
                        raise RuntimeError(f"Recorder did not stop; recovery file: {raw}")
            if recorder.returncode not in (0, -signal.SIGINT) or not raw.exists() or raw.stat().st_size == 0:
                log.seek(0)
                raise RuntimeError(f"Recording failed: {log.read()[-1500:]}\nRecovery file: {raw}")
        emit(status="exporting")
        # Video is already H.264 CRF 23; remux without another lossy encode.
        result = subprocess.run(["ffmpeg", "-nostdin", "-v", "error", "-i", str(raw),
                                 "-c", "copy", "-movflags", "+faststart", str(exported)],
                                capture_output=True, text=True)
        if result.returncode:
            exported.unlink(missing_ok=True)
            raise RuntimeError(f"MP4 export failed: {result.stderr[-1000:]}\nRecovery file: {raw}")
        exported.rename(target)
        raw.unlink()
        emit(status="saved", path=str(target))


if __name__ == "__main__":
    try:
        main()
    except Exception as error:
        emit(status="error", error=str(error))
        sys.exit(1)
