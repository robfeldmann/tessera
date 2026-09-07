#!/usr/bin/env bash
set -euo pipefail

# Developer capture deliberately reuses test support. Keep its test-framework loader
# environment out of the live specimen executable and the user's shell configuration.
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
if [[ $# != 2 || "$1" != layout ]]; then
  echo "Usage: scripts/capture-specimen.sh layout OUTPUT_DIRECTORY" >&2
  exit 2
fi

just core build-libghostty-vt
swift build --package-path Examples --product TesseraCapture
bin_path="$(swift build --package-path Examples --show-bin-path)"

if [[ "$(uname -s)" == Darwin ]]; then
  platform="$(xcrun --sdk macosx --show-sdk-platform-path)"
  export DYLD_FRAMEWORK_PATH="$platform/Developer/Library/Frameworks:$platform/Developer/Library/PrivateFrameworks${DYLD_FRAMEWORK_PATH:+:$DYLD_FRAMEWORK_PATH}"
  export DYLD_LIBRARY_PATH="$platform/Developer/usr/lib${DYLD_LIBRARY_PATH:+:$DYLD_LIBRARY_PATH}"
fi

revision="$(git rev-parse HEAD)"
dirty=clean
if [[ -n "$(git status --porcelain --untracked-files=normal)" ]]; then
  dirty=dirty
fi
# Execute directly: the protected /usr/bin/swift shim strips DYLD variables.
exec "$bin_path/TesseraCapture" "$1" "$2" "$revision" "$dirty"
