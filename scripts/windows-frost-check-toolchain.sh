#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"

FW="${FROST_QEMU_SHARE_DIR:-/opt/homebrew/share/qemu}"
PASS="${TESSERA_FROST_PASS:-${FROST_SSH_PASS:-REMOVED_FROST_CREDENTIAL}}"
SSH_KEY="${TESSERA_FROST_SSH_KEY:-$HOME/.ssh/tessera_windows}"
EXPECTED_SWIFT_VERSION="$(tr -d '[:space:]' < "$repo_root/.swift-version")"
EXPECTED_WINDOWS_SDK="${TESSERA_FROST_WINDOWS_SDK_VERSION:-10.0.26100.0}"
REMOTE_CHECK="C:/Windows/Temp/check-windows-frost-toolchain.ps1"

require_file() {
  local label="$1"
  local path="$2"
  if [[ ! -f "$path" ]]; then
    printf '%s not found: %s\n' "$label" "$path" >&2
    exit 1
  fi
}

require_file "toolchain golden" "$TESSERA_FROST_TOOLCHAIN_GOLDEN"
require_file "toolchain UEFI vars" "$TESSERA_FROST_TOOLCHAIN_VARS"
require_file "Frost vmkit helper" "$TESSERA_FROST_ROOT/bin/_vmkit.sh"
require_file "toolchain check script" "$repo_root/scripts/check-windows-frost-toolchain.ps1"
require_file "SSH private key" "$SSH_KEY"

mkdir -p "$TESSERA_FROST_WORK/run" "$TESSERA_FROST_ROOT/work/disks"

# shellcheck source=/dev/null
source "$TESSERA_FROST_ROOT/bin/_vmkit.sh"

run="$TESSERA_FROST_WORK/run"
ID="check-toolchain-$$"
OVERLAY="$run/$ID.qcow2"
CVARS="$run/$ID-vars.fd"
SHORT_RUN="${TMPDIR:-/tmp}/tessera-frost-$ID"
TPMDIR="$SHORT_RUN/tpm"
MON="$SHORT_RUN/mon.sock"
QPID=""
SSHOPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)

cleanup() {
  if [[ -n "$QPID" ]] && kill -0 "$QPID" 2> /dev/null; then
    kill -9 "$QPID" 2> /dev/null || true
  fi
  if [[ -f "$TPMDIR/pid" ]]; then
    kill -9 "$(cat "$TPMDIR/pid")" 2> /dev/null || true
  fi
  rm -f "$OVERLAY" "$CVARS" "$MON"
  rm -rf "$SHORT_RUN"
}
trap cleanup EXIT

wait_for_ssh() {
  local timeout_seconds="$1"
  local elapsed=0
  while [[ "$elapsed" -lt "$timeout_seconds" ]]; do
    if (echo "" | nc -w 4 localhost "$TESSERA_FROST_SSH_PORT" 2> /dev/null | head -c 8 | grep -q SSH-2); then
      return 0
    fi
    sleep 10
    elapsed=$((elapsed + 10))
  done
  return 1
}

run_guest_password() {
  export SSHPASS="$PASS"
  sshpass -e ssh "${SSHOPTS[@]}" -p "$TESSERA_FROST_SSH_PORT" "$TESSERA_FROST_USER@localhost" "$1"
}

printf '[1/6] create disposable check overlay\n'
qemu-img create -f qcow2 -b "$TESSERA_FROST_TOOLCHAIN_GOLDEN" -F qcow2 "$OVERLAY" > /dev/null
cp "$TESSERA_FROST_TOOLCHAIN_VARS" "$CVARS"

printf '[2/6] boot toolchain check overlay\n'
rm -rf "$TPMDIR"
mkdir -p "$TPMDIR"
swtpm socket --tpm2 --tpmstate "dir=$TPMDIR" --ctrl "type=unixio,path=$TPMDIR/sock" --daemon --pid "file=$TPMDIR/pid"
qemu_argv QARGV --profile hvf --name "$ID" \
  --code "$FW/edk2-aarch64-code.fd" --vars "$CVARS" --disk "$OVERLAY" \
  --tpm "$TPMDIR/sock" --monitor "$MON" --ssh-port "$TESSERA_FROST_SSH_PORT" \
  --mem 8192 --cpus 4 --vnc 4
"${QARGV[@]}" &
QPID=$!

printf '[3/6] wait for SSH\n'
wait_for_ssh 240 || { printf 'SSH did not come up\n' >&2; exit 1; }

printf '[4/6] verify password SSH and toolchain\n'
export SSHPASS="$PASS"
sshpass -e scp "${SSHOPTS[@]}" -P "$TESSERA_FROST_SSH_PORT" \
  "$repo_root/scripts/check-windows-frost-toolchain.ps1" \
  "$TESSERA_FROST_USER@localhost:$REMOTE_CHECK"
run_guest_password "powershell -NoProfile -ExecutionPolicy Bypass -File $REMOTE_CHECK -ExpectedSwiftVersion $EXPECTED_SWIFT_VERSION -ExpectedWindowsSDK $EXPECTED_WINDOWS_SDK"

printf '[5/6] verify SSH key auth\n'
ssh "${SSHOPTS[@]}" -i "$SSH_KEY" -o BatchMode=yes -p "$TESSERA_FROST_SSH_PORT" "$TESSERA_FROST_USER@localhost" whoami

printf '[6/6] shut down guest\n'
run_guest_password 'shutdown /s /t 0' || true
for _ in $(seq 1 60); do
  if ! kill -0 "$QPID" 2> /dev/null; then
    QPID=""
    break
  fi
  sleep 3
done

if [[ -n "$QPID" ]]; then
  printf 'guest did not power off cleanly\n' >&2
  exit 1
fi

printf '✅ Frost Windows toolchain golden verified.\n'
