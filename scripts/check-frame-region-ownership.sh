#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fixture="Tests/CompileFailFixtures/FrameRegionEscape.swift"
expected="requires that 'FrameRegion' conform to 'Escapable'"

shopt -s nullglob
module_dirs=()
for candidate in .build/*/debug/Modules; do
  if [[ -e "$candidate/TesseraTerminalBuffer.swiftmodule" ]]; then
    module_dirs+=("$candidate")
  fi
done
if [[ ${#module_dirs[@]} -eq 0 ]]; then
  echo "FrameRegion ownership probe requires the current debug build products." >&2
  exit 1
fi

for module_dir in "${module_dirs[@]}"; do
  if diagnostic="$(swiftc -typecheck -enable-experimental-feature Lifetimes -I "$module_dir" "$fixture" 2>&1)"; then
    echo "Expected FrameRegion escape fixture to fail type checking." >&2
    exit 1
  fi

  if [[ "$diagnostic" == *"$expected"* ]]; then
    echo "FrameRegion ownership probe passed"
    exit 0
  fi

  if [[ "$diagnostic" == *"cannot be imported by the"* ]] ||
    [[ "$diagnostic" == *"was created for incompatible target"* ]] ||
    [[ "$diagnostic" == *"could not find module"* ]]; then
    continue
  fi

  echo "FrameRegion escape fixture failed with an unexpected diagnostic:" >&2
  echo "$diagnostic" >&2
  exit 1
done

echo "FrameRegion ownership probe requires compatible current-host debug build products." >&2
exit 1
