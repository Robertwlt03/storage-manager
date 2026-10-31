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

PROCESS_NAME = "StorageManager"
SECONDS_BETWEEN_QUIT_CHECKS = 0.2
# The frame the self test ends with when every check held (Sources/Diagnostics/SelfTest.swift).
# open only tells whether the app started, so this line is the self test's verdict.
SELF_TEST_PASSED = "Self test passed"


# MARK: Steps


def restart(app: Path) -> None:
    console.heading("Storage Manager · restart", str(app))
    if subprocess.run(["pkill", "-x", PROCESS_NAME]).returncode == 0:
        while subprocess.run(["pgrep", "-x", PROCESS_NAME], capture_output=True).returncode == 0:
            time.sleep(SECONDS_BETWEEN_QUIT_CHECKS)
    subprocess.run(["open", app], check=True)
    console.frame("Opened", [str(app)], console.SUCCESS)


def selftest(app: Path) -> int:
    console.heading("Storage Manager · self test", "counts and sizes only")
    # The app writes into a file, not into this terminal: it is told when colors fit, and that
    # this heading is already there.
    environment_options = ["--env", "CONSOLE_HEADED=1"]
    if console.USES_COLOR:
        environment_options += ["--env", "FORCE_COLOR=1"]
    with tempfile.TemporaryDirectory() as folder:
        report = Path(folder) / "selftest.txt"
        status = console.wait("Measuring real folders", [
            "open", "-n", "-W", "--stdout", str(report), *environment_options, str(app),
            "--args", "--selftest",
        ])
        output = report.read_text() if report.exists() else ""
    console.relay(output)
    return status or int(SELF_TEST_PASSED not in output)


# MARK: Run


def main(arguments: list[str]) -> int:
    match arguments:
        case ["restart", app]:
            restart(Path(app))
            return 0
        case ["selftest", app]:
            return selftest(Path(app))
        case _:
            console.heading("Storage Manager · app")
            console.stopped("Unknown command", " ".join(arguments),
                            ("scripts/app.py restart <app> | selftest <app>",))
            return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
