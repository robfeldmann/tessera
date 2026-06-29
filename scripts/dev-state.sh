#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

status_icon() {
  if [[ -e "$1" ]]; then
    printf 'present'
  else
    printf 'missing'
  fi
}

default_cache_home() {
  if [[ -n "${XDG_CACHE_HOME:-}" ]]; then
    printf '%s\n' "$XDG_CACHE_HOME"
  elif [[ -n "${HOME:-}" ]]; then
    printf '%s/.cache\n' "$HOME"
  else
    printf '%s/.build\n' "$repo_root"
  fi
}

ghostty_platform() {
  case "$(uname -s | tr '[:upper:]' '[:lower:]')" in
    darwin) printf 'macos\n' ;;
    linux) printf 'linux\n' ;;
    *) printf 'unsupported\n' ;;
  esac
}

ghostty_arch() {
  case "$(uname -m)" in
    arm64|aarch64) printf 'arm64\n' ;;
    x86_64|amd64) printf 'x86_64\n' ;;
    *) printf 'unsupported\n' ;;
  esac
}

print_ghostty_state() {
  local revision_file="$repo_root/scripts/ghostty-vt-version.txt"
  local revision="unknown"
  if [[ -f "$revision_file" ]]; then
    revision="$(tr -d '[:space:]' < "$revision_file")"
  fi
  local output_root="${GHOSTTY_VT_OUTPUT_DIR:-$(default_cache_home)/tessera/libghostty-vt}"
  local install_dir="$output_root/$revision/$(ghostty_platform)-$(ghostty_arch)"

  printf 'Ghostty VT\n'
  printf '  revision: %s\n' "$revision"
  printf '  output root: %s\n' "$output_root"
  printf '  install dir: %s (%s)\n' "$install_dir" "$(status_icon "$install_dir")"
  printf '  source cache: %s (%s)\n' "$output_root/source/$revision" "$(status_icon "$output_root/source/$revision")"
  printf '  build cache: %s (%s)\n' "$output_root/cmake/$revision/$(ghostty_platform)-$(ghostty_arch)" "$(status_icon "$output_root/cmake/$revision/$(ghostty_platform)-$(ghostty_arch)")"
}

print_linux_state() {
  local vm_name="${TESSERA_LINUX_VM_NAME:-tessera-linux}"
  printf '\nLinux\n'
  printf '  Lima VM name: %s\n' "$vm_name"

  if command -v limactl >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    local vm_summary
    vm_summary="$(limactl list --json 2>/dev/null | python3 -c 'import json, os, sys
name = os.environ["TESSERA_DEV_STATE_VM"]
for line in sys.stdin:
    item = json.loads(line)
    if item.get("name") == name:
        print("{} project={}".format(item.get("status", ""), item.get("param", {}).get("ProjectDir", "")))
        break
' 2>/dev/null || true)"
    if [[ -n "$vm_summary" ]]; then
      printf '  Lima VM status: %s\n' "$vm_summary"
    else
      printf '  Lima VM status: not created\n'
    fi
  else
    printf '  Lima VM status: unknown (limactl or python3 missing)\n'
  fi

  if [[ -f "$repo_root/.swift-version" ]]; then
    printf '  Swift version pin: %s\n' "$(tr -d '[:space:]' < "$repo_root/.swift-version")"
  fi
  if command -v swift >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    local swift_version sdk_bundle_id sdk_id
    swift_version="$(tr -d '[:space:]' < "$repo_root/.swift-version")"
    sdk_bundle_id="$(jq -er --arg version "$swift_version" '.[$version].linuxStaticSDKBundleID' "$repo_root/scripts/config/swift-sdks.json" 2>/dev/null || true)"
    sdk_id="$(jq -er --arg version "$swift_version" '.[$version].linuxStaticSDKID' "$repo_root/scripts/config/swift-sdks.json" 2>/dev/null || true)"
    if [[ -n "$sdk_bundle_id" && -n "$sdk_id" ]]; then
      if swift sdk list 2>/dev/null | grep -qx "$sdk_bundle_id"; then
        printf '  Static Linux SDK: %s / %s (installed)\n' "$sdk_bundle_id" "$sdk_id"
      else
        printf '  Static Linux SDK: %s / %s (missing)\n' "$sdk_bundle_id" "$sdk_id"
      fi
    fi
  fi
}

print_windows_frost_state() {
  # shellcheck source=scripts/windows-frost-env.sh
  source "$repo_root/scripts/windows-frost-env.sh"

  printf '\nWindows Frost\n'
  printf '  Frost checkout: %s (%s)\n' "$TESSERA_FROST_ROOT" "$(status_icon "$TESSERA_FROST_ROOT")"
  printf '  Frost state root: %s (%s)\n' "$TESSERA_FROST_WORK" "$(status_icon "$TESSERA_FROST_WORK")"
  printf '  base golden: %s (%s)\n' "$TESSERA_FROST_BASE_GOLDEN" "$(status_icon "$TESSERA_FROST_BASE_GOLDEN")"
  printf '  toolchain golden: %s (%s)\n' "$TESSERA_FROST_TOOLCHAIN_GOLDEN" "$(status_icon "$TESSERA_FROST_TOOLCHAIN_GOLDEN")"
  printf '  source archive: %s (%s)\n' "$TESSERA_FROST_WORK/source/tessera-source.tar.gz" "$(status_icon "$TESSERA_FROST_WORK/source/tessera-source.tar.gz")"
}

TESSERA_DEV_STATE_VM="${TESSERA_LINUX_VM_NAME:-tessera-linux}"
export TESSERA_DEV_STATE_VM

printf 'Tessera local development state\n'
printf 'repo: %s\n\n' "$repo_root"
print_ghostty_state
print_linux_state
print_windows_frost_state
