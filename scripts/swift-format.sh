#!/usr/bin/env bash
# Runs swift-format from the selected Xcode toolchain on macOS (DEVELOPER_DIR names the
# baseline, so CI and local runs format alike), or from PATH elsewhere.
set -euo pipefail

if [[ "$(uname -s)" == "Darwin" ]] && xcrun --find swift-format > /dev/null 2>&1; then
  exec xcrun swift-format "$@"
fi
exec swift-format "$@"
