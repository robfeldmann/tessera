#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"

HOST="${1:-${TESSERA_FROST_UTM_SSH_HOST:-}}"
PORT="${TESSERA_FROST_UTM_SSH_PORT:-22}"

if [[ -z "$HOST" ]]; then
  cat >&2 <<'EOF'
usage: just windows-frost-sync-utm <host>

Pass the IPv4 address shown inside the UTM-imported Frost VM, or set
TESSERA_FROST_UTM_SSH_HOST. The source is synced to TESSERA_FROST_REPO_PATH
(default: C:/Users/tester/tessera).
EOF
  exit 2
fi

printf '[utm-sync] target: %s@%s:%s\n' "$TESSERA_FROST_USER" "$HOST" "$PORT"
printf '[utm-sync] known_hosts collisions are ignored with UserKnownHostsFile=/dev/null;\n'
printf '[utm-sync] remove stale entries manually with: ssh-keygen -R %s\n' "$HOST"

exec "$repo_root/scripts/windows-frost-sync-source.sh" \
  --host "$HOST" \
  --port "$PORT" \
  --dest "$TESSERA_FROST_REPO_PATH"
