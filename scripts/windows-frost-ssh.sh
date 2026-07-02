#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"
# shellcheck source=scripts/windows-frost-ssh-options.sh
source "$repo_root/scripts/windows-frost-ssh-options.sh"


frost_ssh_setup 10
SSHOPTS=(-tt "${FROST_SSH_OPTS[@]}")

ssh_command=(ssh "${SSHOPTS[@]}" -p "$TESSERA_FROST_SSH_PORT" "$TESSERA_FROST_USER@localhost" "$@")
if [[ -t 0 ]]; then
  exec "${ssh_command[@]}"
fi

exec script -q /dev/null "${ssh_command[@]}"
