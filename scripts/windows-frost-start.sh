#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"

FW="${FROST_QEMU_SHARE_DIR:-/opt/homebrew/share/qemu}"
PERSIST_DIR="$TESSERA_FROST_WORK/persistent"
PERSIST_DISK="$PERSIST_DIR/dev.qcow2"
PERSIST_VARS="$PERSIST_DIR/dev-vars.fd"
PERSIST_TPM_STATE="$PERSIST_DIR/tpm-state"
RUN_DIR="$TESSERA_FROST_WORK/run/persistent"
PID_FILE="$RUN_DIR/qemu.pid"
SWTPM_PID_FILE="$RUN_DIR/swtpm.pid"
LOG_FILE="$RUN_DIR/qemu.log"
SHORT_RUN="${TMPDIR:-/tmp}/tessera-frost-persistent"
TPM_SOCKET="$SHORT_RUN/tpm.sock"
MON="$SHORT_RUN/mon.sock"
RESET=0

usage() {
  cat <<'EOF'
usage: scripts/windows-frost-start.sh [--reset]

Start a persistent Frost Windows dev overlay for interactive SSH/ConPTY work.

Options:
  --reset   Delete and recreate the persistent overlay from the toolchain golden
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset)
      RESET=1
      shift
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
  if [[ ! -f "$path" ]]; then
    printf '%s not found: %s\n' "$label" "$path" >&2
    exit 1
  fi
}

if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2> /dev/null; then
  printf 'Frost persistent VM already running (pid %s).\n' "$(cat "$PID_FILE")"
  exit 0
fi

require_file "toolchain golden" "$TESSERA_FROST_TOOLCHAIN_GOLDEN"
require_file "toolchain UEFI vars" "$TESSERA_FROST_TOOLCHAIN_VARS"
require_file "Frost vmkit helper" "$TESSERA_FROST_ROOT/bin/_vmkit.sh"

mkdir -p "$PERSIST_DIR" "$PERSIST_TPM_STATE" "$RUN_DIR" "$SHORT_RUN" "$TESSERA_FROST_ROOT/work/disks"

if [[ "$RESET" == "1" ]]; then
  rm -f "$PERSIST_DISK" "$PERSIST_VARS"
  rm -rf "$PERSIST_TPM_STATE"
  mkdir -p "$PERSIST_TPM_STATE"
fi

if [[ ! -f "$PERSIST_DISK" ]]; then
  printf '[start] create persistent overlay: %s\n' "$PERSIST_DISK"
  qemu-img create -f qcow2 -b "$TESSERA_FROST_TOOLCHAIN_GOLDEN" -F qcow2 "$PERSIST_DISK" > /dev/null
fi
if [[ ! -f "$PERSIST_VARS" ]]; then
  cp "$TESSERA_FROST_TOOLCHAIN_VARS" "$PERSIST_VARS"
fi

rm -f "$TPM_SOCKET" "$MON" "$PID_FILE" "$SWTPM_PID_FILE"
swtpm socket --tpm2 --tpmstate "dir=$PERSIST_TPM_STATE" --ctrl "type=unixio,path=$TPM_SOCKET" --daemon --pid "file=$SWTPM_PID_FILE"

# shellcheck source=/dev/null
source "$TESSERA_FROST_ROOT/bin/_vmkit.sh"
qemu_argv QARGV --profile hvf --name tessera-frost-dev \
  --code "$FW/edk2-aarch64-code.fd" --vars "$PERSIST_VARS" --disk "$PERSIST_DISK" \
  --tpm "$TPM_SOCKET" --monitor "$MON" --ssh-port "$TESSERA_FROST_SSH_PORT" \
  --mem 8192 --cpus 4 --vnc 5

printf '[start] boot persistent Frost VM; log: %s\n' "$LOG_FILE"
nohup "${QARGV[@]}" > "$LOG_FILE" 2>&1 &
echo $! > "$PID_FILE"

printf '[start] qemu pid: %s\n' "$(cat "$PID_FILE")"
printf '[start] SSH will be available at %s@localhost:%s\n' "$TESSERA_FROST_USER" "$TESSERA_FROST_SSH_PORT"
printf '[start] Try: just windows-frost-ssh\n'
