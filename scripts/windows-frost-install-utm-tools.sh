#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"

HOST="${1:-${TESSERA_FROST_UTM_SSH_HOST:-}}"
PORT="${TESSERA_FROST_UTM_SSH_PORT:-22}"
PASS="${TESSERA_FROST_PASS:-${FROST_SSH_PASS:-Test1234!}}"
TOOLS_URL="${TESSERA_FROST_UTM_TOOLS_ISO_URL:-https://getutm.app/downloads/utm-guest-tools-latest.iso}"
TOOLS_ISO="$TESSERA_FROST_WORK/utm-tools/utm-guest-tools-latest.iso"
REMOTE_EXE="C:/Windows/Temp/utm-guest-tools.exe"
SSHOPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)
MOUNT_POINT=""

usage() {
  cat <<'EOF'
usage: scripts/windows-frost-install-utm-tools.sh <host>

Download UTM Windows Guest Tools, copy the installer into the running UTM-imported
Frost VM over SSH, and run the installer silently.
EOF
}

cleanup() {
  if [[ -n "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" > /dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [[ -z "$HOST" ]]; then
  usage >&2
  exit 2
fi

mkdir -p "$(dirname "$TOOLS_ISO")"
if [[ ! -f "$TOOLS_ISO" ]]; then
  printf '[utm-tools] download %s\n' "$TOOLS_URL"
  curl -L -o "$TOOLS_ISO" "$TOOLS_URL"
fi

printf '[utm-tools] mount tools ISO\n'
attach_output="$(hdiutil attach -nobrowse -readonly "$TOOLS_ISO")"
MOUNT_POINT="$(printf '%s\n' "$attach_output" | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes/")); exit}')"
if [[ -z "$MOUNT_POINT" ]]; then
  printf 'could not determine tools ISO mount point\n%s\n' "$attach_output" >&2
  exit 1
fi

installer="$(find "$MOUNT_POINT" -maxdepth 1 -iname 'utm-guest-tools-*.exe' | head -1)"
if [[ -z "$installer" ]]; then
  printf 'UTM guest tools installer not found in %s\n' "$MOUNT_POINT" >&2
  exit 1
fi

printf '[utm-tools] copy installer to %s@%s:%s\n' "$TESSERA_FROST_USER" "$HOST" "$REMOTE_EXE"
export SSHPASS="$PASS"
sshpass -e scp "${SSHOPTS[@]}" -P "$PORT" "$installer" "$TESSERA_FROST_USER@$HOST:$REMOTE_EXE"

printf '[utm-tools] run installer silently\n'
sshpass -e ssh "${SSHOPTS[@]}" -p "$PORT" "$TESSERA_FROST_USER@$HOST" \
  "powershell -NoProfile -Command \"Start-Process $REMOTE_EXE -ArgumentList '/S' -Wait -PassThru | Select-Object ExitCode\""

printf '[utm-tools] installed. Reboot the Windows guest, then re-test resize and clipboard.\n'
