#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
swift_version="$(tr -d '[:space:]' < "$repo_root/.swift-version")"
metadata_file="$repo_root/scripts/config/swift-sdks.json"

if ! command -v jq >/dev/null 2>&1; then
  echo "error: jq is required; run 'brew bundle install'" >&2
  exit 1
fi

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift is required; install Swift $swift_version first" >&2
  exit 1
fi

sdk_bundle_id="$(jq -er --arg version "$swift_version" '.[$version].linuxStaticSDKBundleID' "$metadata_file")" || {
  echo "error: no Linux SDK metadata for Swift $swift_version in $metadata_file" >&2
  exit 1
}
sdk_id="$(jq -er --arg version "$swift_version" '.[$version].linuxStaticSDKID' "$metadata_file")"
sdk_url="$(jq -er --arg version "$swift_version" '.[$version].linuxStaticSDKURL' "$metadata_file")"
sdk_checksum="$(jq -er --arg version "$swift_version" '.[$version].linuxStaticSDKChecksum' "$metadata_file")"

if swift sdk list 2>/dev/null | grep -qx "$sdk_bundle_id"; then
  echo "✅ Linux SDK already installed: $sdk_bundle_id ($sdk_id)"
  exit 0
fi

echo "Installing Linux SDK for Swift $swift_version: $sdk_bundle_id ($sdk_id)"
swift sdk install "$sdk_url" --checksum "$sdk_checksum"
