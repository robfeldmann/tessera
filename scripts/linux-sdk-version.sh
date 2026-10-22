#!/usr/bin/env bash
# Print the Swift version whose Static Linux SDK matches the active compiler.
#
# The SDK must match the compiler that uses it, so the version comes from
# `swift --version` (for example `Apple Swift version 6.3.3` from Xcode 26.6, or
# `Swift version 6.4.1` from a swift.org toolchain). When no compiler is on PATH, or its
# version has no entry in scripts/config/swift-sdks.json, fall back to .swift-version, the
# baseline every lane must pass.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
metadata_file="$repo_root/scripts/config/swift-sdks.json"
baseline_version="$(tr -d '[:space:]' < "$repo_root/.swift-version")"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required; run 'brew bundle install'" >&2
  exit 1
fi

compiler_version=""
if command -v swift >/dev/null 2>&1; then
  compiler_version="$(swift --version 2>/dev/null | sed -nE 's/.*Swift version ([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/p' | head -n 1)"
fi

if [[ -n "$compiler_version" ]] && jq -e --arg version "$compiler_version" '.[$version]' "$metadata_file" >/dev/null; then
  printf '%s\n' "$compiler_version"
elif jq -e --arg version "$baseline_version" '.[$version]' "$metadata_file" >/dev/null; then
  if [[ -n "$compiler_version" && "$compiler_version" != "$baseline_version" ]]; then
    echo "warning: no Linux SDK metadata for the active Swift $compiler_version; using the .swift-version baseline $baseline_version" >&2
  fi
  printf '%s\n' "$baseline_version"
else
  echo "error: no Linux SDK metadata for Swift $baseline_version in $metadata_file" >&2
  exit 1
fi
