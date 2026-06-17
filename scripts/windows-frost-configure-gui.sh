#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"

HOST="${1:-${TESSERA_FROST_UTM_SSH_HOST:-}}"
PORT="${TESSERA_FROST_UTM_SSH_PORT:-22}"
PASS="${TESSERA_FROST_PASS:-${FROST_SSH_PASS:-Test1234!}}"
REMOTE_SCRIPT="C:/Windows/Temp/configure-windows-frost-gui-vm.ps1"
SSHOPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)

usage() {
  cat <<'EOF'
usage: scripts/windows-frost-configure-gui.sh <host>

Apply GUI-VM quality-of-life settings to the UTM-imported Frost VM:
- Enable Windows Developer Mode for unprivileged symlinks.
- Enable Git symlink checkout support for tester.
- Add PowerShell profiles that start in the user's home directory.
EOF
}

if [[ -z "$HOST" ]]; then
  usage >&2
  exit 2
fi

export SSHPASS="$PASS"
printf '[gui-config] copy settings script to %s@%s:%s\n' "$TESSERA_FROST_USER" "$HOST" "$REMOTE_SCRIPT"
sshpass -e scp "${SSHOPTS[@]}" -P "$PORT" \
  "$repo_root/scripts/configure-windows-frost-gui-vm.ps1" \
  "$TESSERA_FROST_USER@$HOST:$REMOTE_SCRIPT"

printf '[gui-config] run settings script\n'
sshpass -e ssh "${SSHOPTS[@]}" -p "$PORT" "$TESSERA_FROST_USER@$HOST" \
  "powershell -NoProfile -ExecutionPolicy Bypass -File $REMOTE_SCRIPT"
