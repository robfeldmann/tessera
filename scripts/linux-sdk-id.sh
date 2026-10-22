#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
metadata_file="$repo_root/scripts/config/swift-sdks.json"

swift_version="$("$repo_root/scripts/linux-sdk-version.sh")"
jq -er --arg version "$swift_version" '.[$version].linuxStaticSDKID' "$metadata_file"
