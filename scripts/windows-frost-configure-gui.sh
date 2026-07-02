#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"
# shellcheck source=scripts/windows-frost-ssh-options.sh
source "$repo_root/scripts/windows-frost-ssh-options.sh"


HOST="${1:-${TESSERA_FROST_UTM_SSH_HOST:-}}"
PORT="${TESSERA_FROST_UTM_SSH_PORT:-22}"
REMOTE_SCRIPT="C:/Windows/Temp/configure-windows-frost-gui-vm.ps1"
frost_ssh_setup 10

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

printf '[gui-config] copy settings script to %s@%s:%s\n' "$TESSERA_FROST_USER" "$HOST" "$REMOTE_SCRIPT"
frost_scp "$PORT" \
  "$repo_root/scripts/configure-windows-frost-gui-vm.ps1" \
  "$TESSERA_FROST_USER@$HOST:$REMOTE_SCRIPT"

printf '[gui-config] run settings script\n'
frost_ssh "$PORT" "$TESSERA_FROST_USER@$HOST" \
  "powershell -NoProfile -ExecutionPolicy Bypass -File $REMOTE_SCRIPT"
