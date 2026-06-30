#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"
# shellcheck source=scripts/windows-frost-ssh-options.sh
source "$repo_root/scripts/windows-frost-ssh-options.sh"
if [[ "${1:-}" == "--" ]]; then
  shift
fi



FW="${FROST_QEMU_SHARE_DIR:-/opt/homebrew/share/qemu}"
REPO_PATH="${TESSERA_FROST_REPO_PATH:-C:/Users/$TESSERA_FROST_USER/tessera}"
REMOTE_TEST_SCRIPT="$REPO_PATH/scripts/run-windows-frost-tests.ps1"
SWIFT_TEST_ARGS_JSON="$(python3 -c 'import json, sys; print(json.dumps(sys.argv[1:]))' "$@")"
SWIFT_TEST_ARGS_B64="$(printf '%s' "$SWIFT_TEST_ARGS_JSON" | base64 | tr -d '\n')"


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
require_file "source sync script" "$repo_root/scripts/windows-frost-sync-source.sh"
require_file "guest test script" "$repo_root/scripts/run-windows-frost-tests.ps1"

mkdir -p "$TESSERA_FROST_WORK/run" "$TESSERA_FROST_ROOT/work/disks"

# shellcheck source=/dev/null
source "$TESSERA_FROST_ROOT/bin/_vmkit.sh"

run="$TESSERA_FROST_WORK/run"
ID="test-$$"
OVERLAY="$run/$ID.qcow2"
CVARS="$run/$ID-vars.fd"
SHORT_RUN="${TMPDIR:-/tmp}/tessera-frost-$ID"
TPMDIR="$SHORT_RUN/tpm"
MON="$SHORT_RUN/mon.sock"
QPID=""
frost_ssh_setup 10
TEST_RC=1

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

run_guest() {
  frost_ssh "$TESSERA_FROST_SSH_PORT" "$TESSERA_FROST_USER@localhost" "$1"
}

printf '[1/7] create disposable test overlay\n'
qemu-img create -f qcow2 -b "$TESSERA_FROST_TOOLCHAIN_GOLDEN" -F qcow2 "$OVERLAY" > /dev/null
cp "$TESSERA_FROST_TOOLCHAIN_VARS" "$CVARS"

printf '[2/7] boot test overlay\n'
rm -rf "$TPMDIR"
mkdir -p "$TPMDIR"
swtpm socket --tpm2 --tpmstate "dir=$TPMDIR" --ctrl "type=unixio,path=$TPMDIR/sock" --daemon --pid "file=$TPMDIR/pid"
qemu_argv QARGV --profile hvf --name "$ID" \
  --code "$FW/edk2-aarch64-code.fd" --vars "$CVARS" --disk "$OVERLAY" \
  --tpm "$TPMDIR/sock" --monitor "$MON" --ssh-port "$TESSERA_FROST_SSH_PORT" \
  --mem 8192 --cpus 4 --vnc 4
"${QARGV[@]}" &
QPID=$!

printf '[3/7] wait for SSH\n'
wait_for_ssh 240 || { printf 'SSH did not come up\n' >&2; exit 1; }

printf '[4/7] sync source\n'
"$repo_root/scripts/windows-frost-sync-source.sh" --dest "$REPO_PATH"

printf '[5/7] run swift tests\n'
set +e
run_guest "powershell -NoProfile -ExecutionPolicy Bypass -File $REMOTE_TEST_SCRIPT -RepoPath $REPO_PATH -SwiftTestArgsBase64 \"$SWIFT_TEST_ARGS_B64\""
TEST_RC=$?
set -e

printf '[6/7] shut down guest\n'
run_guest 'shutdown /s /t 0' || true
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

printf '[7/7] guest test exit code: %s\n' "$TEST_RC"
exit "$TEST_RC"
