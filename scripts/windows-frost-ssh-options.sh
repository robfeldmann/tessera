#!/usr/bin/env bash
# Shared SSH authentication policy for Frost Windows workflows.
# Source after scripts/windows-frost-env.sh.

FROST_SSH_KEY="${TESSERA_FROST_SSH_KEY:-$HOME/.ssh/tessera_windows}"
FROST_SSH_USES_PASSWORD=1
FROST_SSH_OPTS=()

frost_ssh_common_options() {
  local timeout_seconds="${1:-10}"
  FROST_SSH_COMMON_OPTS=(
    -o StrictHostKeyChecking=no
    -o UserKnownHostsFile=/dev/null
    -o ConnectTimeout="$timeout_seconds"
  )
}

frost_ssh_password_options() {
  FROST_SSH_USES_PASSWORD=1
  FROST_SSH_AUTH_OPTS=(
    -o PreferredAuthentications=password
    -o PubkeyAuthentication=no
    -o NumberOfPasswordPrompts=1
  )
}

frost_ssh_key_options() {
  FROST_SSH_USES_PASSWORD=0
  FROST_SSH_AUTH_OPTS=(
    -i "$FROST_SSH_KEY"
    -o IdentitiesOnly=yes
    -o BatchMode=yes
    -o PreferredAuthentications=publickey
  )
}

frost_ssh_setup() {
  frost_ssh_common_options "${1:-10}"
  if [[ -f "$FROST_SSH_KEY" ]]; then
    frost_ssh_key_options
  else
    frost_ssh_password_options
  fi
  FROST_SSH_OPTS=("${FROST_SSH_COMMON_OPTS[@]}" "${FROST_SSH_AUTH_OPTS[@]}")
}

frost_ssh_setup_password() {
  frost_ssh_common_options "${1:-10}"
  frost_ssh_password_options
  FROST_SSH_OPTS=("${FROST_SSH_COMMON_OPTS[@]}" "${FROST_SSH_AUTH_OPTS[@]}")
}

frost_ssh_export_password() {
  : "${TESSERA_FROST_PASS:?Set TESSERA_FROST_PASS in ignored local configuration.}"
  export SSHPASS="$TESSERA_FROST_PASS"
}

frost_ssh() {
  local port="$1"
  local target="$2"
  shift 2

  if [[ "$FROST_SSH_USES_PASSWORD" == "1" ]]; then
    frost_ssh_export_password
    sshpass -e ssh "${FROST_SSH_OPTS[@]}" -p "$port" "$target" "$@"
  else
    ssh "${FROST_SSH_OPTS[@]}" -p "$port" "$target" "$@"
  fi
}

frost_scp() {
  local port="$1"
  local source="$2"
  local destination="$3"

  if [[ "$FROST_SSH_USES_PASSWORD" == "1" ]]; then
    frost_ssh_export_password
    sshpass -e scp "${FROST_SSH_OPTS[@]}" -P "$port" "$source" "$destination"
  else
    scp "${FROST_SSH_OPTS[@]}" -P "$port" "$source" "$destination"
  fi
}
