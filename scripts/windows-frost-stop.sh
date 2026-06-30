#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"
# shellcheck source=scripts/windows-frost-ssh-options.sh
source "$repo_root/scripts/windows-frost-ssh-options.sh"


RUN_DIR="$TESSERA_FROST_WORK/run/persistent"
PID_FILE="$RUN_DIR/qemu.pid"
SWTPM_PID_FILE="$RUN_DIR/swtpm.pid"
SHORT_RUN="${TMPDIR:-/tmp}/tessera-frost-persistent"
MON="$SHORT_RUN/mon.sock"
frost_ssh_setup 5

if [[ ! -f "$PID_FILE" ]]; then
  printf 'Frost persistent VM is not running (no pid file).\n'
  exit 0
fi

QPID="$(cat "$PID_FILE")"
if ! kill -0 "$QPID" 2> /dev/null; then
  printf 'Frost persistent VM pid is stale: %s\n' "$QPID"
  rm -f "$PID_FILE"
  exit 0
fi

printf '[stop] request guest shutdown\n'
if [[ "$FROST_SSH_USES_PASSWORD" != "1" ]] || command -v sshpass > /dev/null 2>&1; then
  frost_ssh "$TESSERA_FROST_SSH_PORT" "$TESSERA_FROST_USER@localhost" 'shutdown /s /t 0' || true
fi

for _ in $(seq 1 60); do
  if ! kill -0 "$QPID" 2> /dev/null; then
    QPID=""
    break
  fi
  sleep 3
done

if [[ -n "$QPID" && -S "$MON" ]]; then
  printf '[stop] SSH shutdown did not finish; sending QEMU system_powerdown\n'
  echo system_powerdown | nc -U "$MON" > /dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    if ! kill -0 "$QPID" 2> /dev/null; then
      QPID=""
      break
    fi
    sleep 3
  done
fi

if [[ -n "$QPID" ]]; then
  printf '[stop] force-killing qemu pid %s\n' "$QPID"
  kill -9 "$QPID" 2> /dev/null || true
fi

if [[ -f "$SWTPM_PID_FILE" ]]; then
  kill -9 "$(cat "$SWTPM_PID_FILE")" 2> /dev/null || true
fi

rm -f "$PID_FILE" "$SWTPM_PID_FILE" "$MON" "$SHORT_RUN/tpm.sock"
printf '[stop] persistent Frost VM stopped.\n'
