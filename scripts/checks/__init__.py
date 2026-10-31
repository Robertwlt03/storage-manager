"""The shared code of the project's tools, and the Python they need.

Start:  imported first by every script in scripts/, before any other module of the package
Needs:  Python 3.13 or newer; make picks the newest one it finds (see PYTHON in the Makefile)
The check runs before the rest of the package loads, because the package uses what older Python
cannot read, and it uses only what every Python 3 understands, so even the 3.9 that Xcode brings
says clearly what is missing instead of failing somewhere inside.
"""

import platform
import sys

# MARK: Settings

OLDEST_PYTHON = (3, 13)  # gets security fixes until October 2029 (devguide.python.org/versions)

# MARK: Run

if sys.version_info < OLDEST_PYTHON:
    sys.exit(
        "Python {}.{} or newer is needed; this is {} ({}).\n"
        "make finds a newer one by itself; to install one: brew install python@3.14".format(
            *OLDEST_PYTHON, platform.python_version(), sys.executable
        )
    )
