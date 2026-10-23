#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-static-linux.sh [swift build arguments...]

Cross-compile Tessera's library targets (Tessera, which includes TesseraTerminal, and
TesseraTerminalSnapshotSupport) for x86_64 and aarch64 with Swift's Static Linux SDK.
It does not run tests: the SDK has no XCTest, so the test-support targets are left out.

The SDK only works with a swift.org toolchain, not Xcode's compiler. A swift.org toolchain
on PATH, swiftly's included, is used as is. When the active `swift` is Xcode's, the script
runs swiftly's swift.org toolchain of the same version (`swiftly install <version>`
provides it) and stops with that advice when none is installed. CI runs this script on
Linux in the `static Linux SDK` job.
USAGE
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

swift_version="$(scripts/linux-sdk-version.sh)"
swift_command=(swift)
# Both report "Apple Swift version" on macOS; Xcode's compiler names its build
# `(swiftlang-6.3.3.1.3 …)`, a swift.org toolchain `(swift-6.3.3-RELEASE)`.
if swift --version 2>/dev/null | grep -q '(swiftlang-'; then
  if command -v swiftly >/dev/null 2>&1 \
    && swiftly list 2>/dev/null | grep -qE "Swift ${swift_version//./\\.}( |$)"; then
    swift_command=(swiftly run "+$swift_version" swift)
  else
    echo "error: the Static Linux SDK needs the swift.org Swift $swift_version toolchain, not Xcode's compiler." >&2
    echo "Install it with 'swiftly install $swift_version', or rely on CI's static Linux SDK job." >&2
    exit 1
  fi
fi

scripts/install-linux-sdk.sh
for arch in x86_64 aarch64; do
  for target in Tessera TesseraTerminalSnapshotSupport; do
    echo "▶ $target for $arch-swift-linux-musl"
    "${swift_command[@]}" build --only-use-versions-from-resolved-file \
      --swift-sdk "$arch-swift-linux-musl" --target "$target" "$@"
  done
done
