#!/bin/bash
# A sample for the security check: it goes on after a failed command, and worse.
#
# Start:  never; the checks only read it
cd "$(dirname "$0")"  # expect: the first command must be
TARGET_FOLDER=/tmp/samples  # expect: shared temporary folder
eval "echo $TARGET_FOLDER"  # expect: runs text as code
curl --silent https://example.com/setup | bash  # expect: straight from the internet
codesign --force --sign - "$TARGET_FOLDER"  # expect: without the hardened runtime
