#!/usr/bin/env python3
"""Starts the built app for the make commands that do more than open it: restart and selftest.

Start:  make restart, make selftest (both hand over the app's path)
Needs:  a built app (make build)
The self test runs as the app itself, so macOS uses the app's Full Disk Access instead of asking
per folder; it prints only counts and sizes, never a name from the disk.
"""

import subprocess
import sys
import tempfile
import time
from pathlib import Path

from checks import console

# MARK: Settings

PROCESS = "SpeicherExplorer"
SECONDS_BETWEEN_QUIT_CHECKS = 0.2


# MARK: Steps


def restart(app: Path) -> None:
    console.heading("Speicher-Explorer · restart", str(app))
    if subprocess.run(["pkill", "-x", PROCESS]).returncode == 0:
        while subprocess.run(["pgrep", "-x", PROCESS], capture_output=True).returncode == 0:
            time.sleep(SECONDS_BETWEEN_QUIT_CHECKS)
    subprocess.run(["open", app], check=True)
    console.frame("Opened", [str(app)], console.SUCCESS)


def selftest(app: Path) -> int:
    console.heading("Speicher-Explorer · self test", "counts and sizes only")
    # The app writes into a file, not into this terminal: it is told when colors fit, and that
    # this heading is already there.
    passed_on = ["--env", "CONSOLE_HEADED=1"]
    if console.USES_COLOR:
        passed_on += ["--env", "FORCE_COLOR=1"]
    with tempfile.TemporaryDirectory() as folder:
        report = Path(folder) / "selftest.txt"
        status = console.wait("Measuring real folders", [
            "open", "-n", "-W", "--stdout", str(report), *passed_on, str(app),
            "--args", "--selftest",
        ])
        console.relay(report.read_text() if report.exists() else "")
    return status


# MARK: Run


def main(arguments: list[str]) -> int:
    match arguments:
        case ["restart", app]:
            restart(Path(app))
            return 0
        case ["selftest", app]:
            return selftest(Path(app))
        case _:
            console.failed("Unknown command", " ".join(arguments))
            console.note("scripts/app.py restart <app> | selftest <app>")
            return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
