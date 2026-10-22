#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
metadata_file="$repo_root/scripts/config/swift-sdks.json"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift is required; install the toolchain named by .swift-version first" >&2
  exit 1
fi

swift_version="$("$repo_root/scripts/linux-sdk-version.sh")"
sdk_bundle_id="$(jq -er --arg version "$swift_version" '.[$version].linuxStaticSDKBundleID' "$metadata_file")"
sdk_id="$(jq -er --arg version "$swift_version" '.[$version].linuxStaticSDKID' "$metadata_file")"
sdk_url="$(jq -er --arg version "$swift_version" '.[$version].linuxStaticSDKURL' "$metadata_file")"
sdk_checksum="$(jq -er --arg version "$swift_version" '.[$version].linuxStaticSDKChecksum' "$metadata_file")"

if swift sdk list 2>/dev/null | grep -qx "$sdk_bundle_id"; then
  echo "✅ Linux SDK already installed: $sdk_bundle_id ($sdk_id)"
  exit 0
fi

echo "Installing Linux SDK for Swift $swift_version: $sdk_bundle_id ($sdk_id)"
swift sdk install "$sdk_url" --checksum "$sdk_checksum"
