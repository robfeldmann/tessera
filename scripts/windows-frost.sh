#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"

usage() {
  cat <<'EOF'
usage: scripts/windows-frost.sh <command>

Commands:
  env       Print resolved Frost prototype paths and defaults
  help      Show Frost CLI help from the configured checkout
  dry-run   Print a non-destructive Frost run invocation for the planned golden paths
EOF
}

require_frost() {
  if [[ ! -x "$TESSERA_FROST_CLI" ]]; then
    printf 'Frost CLI not found or not executable: %s\n' "$TESSERA_FROST_CLI" >&2
    printf 'Set TESSERA_FROST_ROOT or clone Frost to /Users/rob/Developer/solcreek/frost/main.\n' >&2
    exit 1
  fi
}

command="${1:-}"
case "$command" in
  env)
    cat <<EOF
TESSERA_FROST_ROOT=$TESSERA_FROST_ROOT
TESSERA_FROST_WORK=$TESSERA_FROST_WORK
TESSERA_FROST_SSH_PORT=$TESSERA_FROST_SSH_PORT
TESSERA_FROST_USER=$TESSERA_FROST_USER
TESSERA_FROST_WINDOWS_ISO=$TESSERA_FROST_WINDOWS_ISO
TESSERA_FROST_VIRTIO_ISO=$TESSERA_FROST_VIRTIO_ISO
TESSERA_FROST_BASE_GOLDEN=$TESSERA_FROST_BASE_GOLDEN
TESSERA_FROST_BASE_VARS=$TESSERA_FROST_BASE_VARS
TESSERA_FROST_TOOLCHAIN_GOLDEN=$TESSERA_FROST_TOOLCHAIN_GOLDEN
TESSERA_FROST_TOOLCHAIN_VARS=$TESSERA_FROST_TOOLCHAIN_VARS
TESSERA_FROST_CLI=$TESSERA_FROST_CLI
EOF
    ;;
  help)
    require_frost
    exec "$TESSERA_FROST_CLI" help
    ;;
  dry-run)
    require_frost
    exec "$TESSERA_FROST_CLI" run --dry-run \
      --golden "$TESSERA_FROST_TOOLCHAIN_GOLDEN" \
      --vars "$TESSERA_FROST_TOOLCHAIN_VARS" \
      --ssh-port "$TESSERA_FROST_SSH_PORT" \
      --user "$TESSERA_FROST_USER" \
      --run 'cmd /c ver'
    ;;
  -h|--help|help-text)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
