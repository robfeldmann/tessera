#!/usr/bin/env bash
# Usage: matrix.sh <consumer-dir> <scheme>
# Builds and runs the consumer on Swift 6.3.3 (Xcode 26.6) and 6.4 (Xcode 27.1),
# with swift build (native and swiftbuild) and xcodebuild.
set -u
dir=$1; scheme=$2; cd "$dir"
for x in 26.6.0 27.1.0; do
  export DEVELOPER_DIR=/Applications/Xcode-$x.app/Contents/Developer
  for bs in native swiftbuild; do
    rm -rf .build
    if xcrun swift build --build-system $bs >build-$x-$bs.log 2>&1; then
      echo "Xcode $x swift build --build-system $bs: OK -> $(./.build/debug/App | sed -n 2p)"
    else
      echo "Xcode $x swift build --build-system $bs: FAIL -> $(grep -m1 -E 'error:' build-$x-$bs.log | cut -c1-200)"
    fi
  done
  dd=/tmp/ghostty-dist-spike/dd-$(basename "$dir")-$x; rm -rf "$dd"
  if xcodebuild -scheme "$scheme" -destination 'platform=macOS' -derivedDataPath "$dd" build >xcodebuild-$x.log 2>&1; then
    echo "Xcode $x xcodebuild: OK -> $("$dd"/Build/Products/Debug/App | sed -n 2p)"
  else
    echo "Xcode $x xcodebuild: FAIL -> $(grep -E 'error:' xcodebuild-$x.log | grep -v 'couldn’t be opened' | head -1 | cut -c1-200)"
  fi
done
