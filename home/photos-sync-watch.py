"""Trigger the shared sync service after a quiet period of local writes."""

import pathlib
import subprocess
import sys
import threading
import time

from watchdog.events import FileSystemEventHandler
from watchdog.observers.inotify import InotifyObserver


class Changes(FileSystemEventHandler):
    def __init__(self):
        self.condition = threading.Condition()
        self.last_change = None
        self.root_changed = False

    def on_any_event(self, event):
        # Reading photos during sync must not trigger another sync.
        if event.event_type not in {"created", "modified", "closed", "deleted", "moved"}:
            return
        if event.is_directory and event.event_type == "modified":
            return
        with self.condition:
            self.last_change = time.monotonic()
            self.condition.notify()

    def wait_for_batch(self, debounce):
        with self.condition:
            while not self.root_changed:
                if self.last_change is None:
                    self.condition.wait()
                    continue
                remaining = self.last_change + debounce - time.monotonic()
                if remaining > 0:
                    self.condition.wait(remaining)
                    continue
                self.last_change = None
                return True
            return False


class RootChanges(FileSystemEventHandler):
    def __init__(self, root, changes):
        self.root = str(root)
        self.changes = changes

    def on_any_event(self, event):
        if event.event_type not in {"created", "deleted", "moved"}:
            return
        if self.root in (event.src_path, getattr(event, "dest_path", None)):
            with self.changes.condition:
                self.changes.root_changed = True
                self.changes.condition.notify()


def main():
    root = pathlib.Path(sys.argv[1]).absolute()
    systemctl = sys.argv[2]
    changes = Changes()
    observer = InotifyObserver()
    observer.schedule(changes, str(root), recursive=True)
    # Rebuild recursive watches if ~/Photos itself is moved/replaced.
    observer.schedule(RootChanges(root, changes), str(root.parent), recursive=False)
    observer.start()
    print(f"Watching {root}; syncing after 3 seconds without changes", flush=True)
    try:
        while changes.wait_for_batch(3):
            # A separate job queues behind the polling job's file lock instead
            # of joining its potentially outdated snapshot. Events arriving
            # during this blocking call remain pending for a follow-up run.
            result = subprocess.run([systemctl, "--user", "start", "photos-sync-local.service"])
            if result.returncode:
                print("Photo sync failed; the remote timer will retry", file=sys.stderr, flush=True)
    finally:
        observer.stop()
        observer.join()
    # systemd restarts us with new watches, or waits for the path to reappear.
    return 1


if __name__ == "__main__":
    sys.exit(main())
