#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
swift_version="$(tr -d '[:space:]' < "$repo_root/.swift-version")"
metadata_file="$repo_root/scripts/config/swift-sdks.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required; run 'brew bundle install'" >&2
  exit 1
fi

sdk_id="$(jq -er --arg version "$swift_version" '.[$version].linuxStaticSDKID' "$metadata_file")" || {
  echo "error: no Linux SDK metadata for Swift $swift_version in $metadata_file" >&2
  exit 1
}

printf '%s\n' "$sdk_id"
