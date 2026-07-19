#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"

FORCE=0
TIMEOUT=3600

usage() {
  cat <<'EOF'
usage: scripts/windows-frost-build-base.sh [--force] [--timeout SECONDS]

Build the base Windows 11 ARM64 Frost golden image from user-provided ISO files.
Set these environment variables first:

  TESSERA_FROST_WINDOWS_ISO=/path/to/Win11_ARM64.iso
  TESSERA_FROST_VIRTIO_ISO=/path/to/virtio-win.iso
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      FORCE=1
      shift
      ;;
    --timeout)
      TIMEOUT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

require_file() {
  local label="$1"
  local path="$2"
  if [[ -z "$path" ]]; then
    printf '%s is not set.\n' "$label" >&2
    exit 1
  fi
  if [[ ! -f "$path" ]]; then
    printf '%s not found: %s\n' "$label" "$path" >&2
    exit 1
  fi
}

require_file "TESSERA_FROST_WINDOWS_ISO" "$TESSERA_FROST_WINDOWS_ISO"
require_file "TESSERA_FROST_VIRTIO_ISO" "$TESSERA_FROST_VIRTIO_ISO"
require_file "Frost CLI" "$TESSERA_FROST_CLI"

: "${TESSERA_FROST_PASS:?Set TESSERA_FROST_PASS in ignored local configuration.}"

if [[ -e "$TESSERA_FROST_BASE_GOLDEN" || -e "$TESSERA_FROST_BASE_VARS" ]]; then
  if [[ "$FORCE" == "1" ]]; then
    rm -f "$TESSERA_FROST_BASE_GOLDEN" "$TESSERA_FROST_BASE_VARS"
  else
    printf 'base golden already exists: %s\n' "$TESSERA_FROST_BASE_GOLDEN" >&2
    printf 'rerun with --force to rebuild it.\n' >&2
    exit 1
  fi
fi

mkdir -p "$(dirname "$TESSERA_FROST_BASE_GOLDEN")" "$TESSERA_FROST_ROOT/work/disks"

FROST_SSH_PASS="$TESSERA_FROST_PASS" exec "$TESSERA_FROST_CLI" build \
  --iso "$TESSERA_FROST_WINDOWS_ISO" \
  --virtio "$TESSERA_FROST_VIRTIO_ISO" \
  --out "$TESSERA_FROST_BASE_GOLDEN" \
  --vars-out "$TESSERA_FROST_BASE_VARS" \
  --user "$TESSERA_FROST_USER" \
  --ssh-port "$TESSERA_FROST_SSH_PORT" \
  --timeout "$TIMEOUT"
