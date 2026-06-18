#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"

usage() {
  cat <<'EOF'
usage: scripts/windows-frost.sh <command>

Commands:
  env         Print resolved Frost paths and defaults
  help        Show Frost CLI help from the configured checkout
  dry-run     Print a non-destructive Frost run invocation for the planned golden paths
  check-base  Boot the base golden and run a trivial Windows command
EOF
}

require_frost() {
  if [[ ! -x "$TESSERA_FROST_CLI" ]]; then
    printf 'Frost CLI not found or not executable: %s\n' "$TESSERA_FROST_CLI" >&2
    printf 'Set TESSERA_FROST_ROOT or clone Frost to $HOME/Developer/frost.\n' >&2
    exit 1
  fi
}

prepare_frost_runtime_dirs() {
  # Frost's test-run.sh currently creates throwaway overlays under its own work/disks
  # directory even when --golden points outside the Frost checkout.
  mkdir -p "$TESSERA_FROST_ROOT/work/disks"
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
TESSERA_FROST_GIT_INSTALLER_URL=$TESSERA_FROST_GIT_INSTALLER_URL
TESSERA_FROST_VS_BOOTSTRAPPER_URL=$TESSERA_FROST_VS_BOOTSTRAPPER_URL
TESSERA_FROST_SWIFT_INSTALLER_URL=$TESSERA_FROST_SWIFT_INSTALLER_URL
TESSERA_FROST_PUBKEY=$TESSERA_FROST_PUBKEY
TESSERA_FROST_SSH_KEY=$TESSERA_FROST_SSH_KEY
TESSERA_FROST_WINDOWS_SDK_VERSION=$TESSERA_FROST_WINDOWS_SDK_VERSION
TESSERA_FROST_REPO_PATH=$TESSERA_FROST_REPO_PATH
TESSERA_FROST_UTM_SSH_HOST=$TESSERA_FROST_UTM_SSH_HOST
TESSERA_FROST_UTM_SSH_PORT=$TESSERA_FROST_UTM_SSH_PORT
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
      --run 'whoami'
    ;;
  check-base)
    require_frost
    prepare_frost_runtime_dirs
    exec "$TESSERA_FROST_CLI" run \
      --golden "$TESSERA_FROST_BASE_GOLDEN" \
      --vars "$TESSERA_FROST_BASE_VARS" \
      --ssh-port "$TESSERA_FROST_SSH_PORT" \
      --user "$TESSERA_FROST_USER" \
      --run 'whoami'
    ;;
  -h|--help|help-text)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
