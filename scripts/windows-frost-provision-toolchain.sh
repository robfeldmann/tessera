#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"
# shellcheck source=scripts/windows-frost-ssh-options.sh
source "$repo_root/scripts/windows-frost-ssh-options.sh"


usage() {
  cat <<'EOF'
usage: scripts/windows-frost-provision-toolchain.sh [--force]

Build a Tessera toolchain golden overlay from the Frost base golden, boot it, run
scripts/setup-windows-frost-vm.ps1 inside the guest, and shut it down.

Options:
  --force   Remove an existing Tessera toolchain golden/vars before provisioning
EOF
}

force=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force=1
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

FW="${FROST_QEMU_SHARE_DIR:-/opt/homebrew/share/qemu}"
: "${TESSERA_FROST_PASS:?Set TESSERA_FROST_PASS in ignored local configuration.}"
PASS="$TESSERA_FROST_PASS"
PUBKEY="${TESSERA_FROST_PUBKEY:-$HOME/.ssh/tessera_windows.pub}"
EXPECTED_SWIFT_VERSION="$(tr -d '[:space:]' < "$repo_root/.swift-version")"
REMOTE_SCRIPT="C:/Windows/Temp/setup-windows-frost-vm.ps1"
REMOTE_TASK_HELPER="C:/Windows/Temp/run-windows-frost-provision-task.ps1"
REMOTE_KEY="C:/Windows/Temp/tessera_frost_authorized_key.pub"
TASK_OPTIONAL_ARGS=""
[[ -n "$TESSERA_FROST_GIT_INSTALLER_URL" ]] && TASK_OPTIONAL_ARGS+=" -GitInstallerUrl $TESSERA_FROST_GIT_INSTALLER_URL"
[[ -n "$TESSERA_FROST_VS_BOOTSTRAPPER_URL" ]] && TASK_OPTIONAL_ARGS+=" -VisualStudioBootstrapperUrl $TESSERA_FROST_VS_BOOTSTRAPPER_URL"
[[ -n "$TESSERA_FROST_SWIFT_INSTALLER_URL" ]] && TASK_OPTIONAL_ARGS+=" -SwiftInstallerUrl $TESSERA_FROST_SWIFT_INSTALLER_URL"

require_file() {
  local label="$1"
  local path="$2"
  if [[ ! -f "$path" ]]; then
    printf '%s not found: %s\n' "$label" "$path" >&2
    exit 1
  fi
}

require_file "base golden" "$TESSERA_FROST_BASE_GOLDEN"
require_file "base UEFI vars" "$TESSERA_FROST_BASE_VARS"
require_file "Frost CLI" "$TESSERA_FROST_CLI"
require_file "Frost vmkit helper" "$TESSERA_FROST_ROOT/bin/_vmkit.sh"
require_file "Windows provisioning script" "$repo_root/scripts/setup-windows-frost-vm.ps1"
require_file "Windows scheduled task helper" "$repo_root/scripts/run-windows-frost-provision-task.ps1"
require_file "SSH public key" "$PUBKEY"

if [[ -e "$TESSERA_FROST_TOOLCHAIN_GOLDEN" || -e "$TESSERA_FROST_TOOLCHAIN_VARS" ]]; then
  if [[ "$force" == "1" ]]; then
    rm -f "$TESSERA_FROST_TOOLCHAIN_GOLDEN" "$TESSERA_FROST_TOOLCHAIN_VARS"
  else
    printf 'toolchain golden already exists: %s\n' "$TESSERA_FROST_TOOLCHAIN_GOLDEN" >&2
    printf 'rerun with --force to rebuild it.\n' >&2
    exit 1
  fi
fi

mkdir -p "$(dirname "$TESSERA_FROST_TOOLCHAIN_GOLDEN")" "$TESSERA_FROST_WORK/run" "$TESSERA_FROST_ROOT/work/disks"

printf '[1/7] create Tessera toolchain overlay\n'
qemu-img create -f qcow2 -b "$TESSERA_FROST_BASE_GOLDEN" -F qcow2 "$TESSERA_FROST_TOOLCHAIN_GOLDEN" > /dev/null
cp "$TESSERA_FROST_BASE_VARS" "$TESSERA_FROST_TOOLCHAIN_VARS"

# shellcheck source=/dev/null
source "$TESSERA_FROST_ROOT/bin/_vmkit.sh"

run="$TESSERA_FROST_WORK/run"
ID="toolchain-$$"
# swtpm uses Unix sockets, whose path length limit is easy to hit under long
# repository paths. Keep runtime sockets in /tmp and VM artifacts in .build.
SHORT_RUN="${TMPDIR:-/tmp}/tessera-frost-$ID"
TPMDIR="$SHORT_RUN/tpm"
MON="$SHORT_RUN/mon.sock"
QPID=""
frost_ssh_setup_password 10

cleanup() {
  if [[ -n "$QPID" ]] && kill -0 "$QPID" 2> /dev/null; then
    kill -9 "$QPID" 2> /dev/null || true
  fi
  if [[ -f "$TPMDIR/pid" ]]; then
    kill -9 "$(cat "$TPMDIR/pid")" 2> /dev/null || true
  fi
  rm -f "$MON"
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

wait_for_ssh_down() {
  local timeout_seconds="$1"
  local elapsed=0
  while [[ "$elapsed" -lt "$timeout_seconds" ]]; do
    if ! (echo "" | nc -w 2 localhost "$TESSERA_FROST_SSH_PORT" 2> /dev/null | head -c 8 | grep -q SSH-2); then
      return 0
    fi
    sleep 5
    elapsed=$((elapsed + 5))
  done
  return 1
}

run_guest() {
  frost_ssh "$TESSERA_FROST_SSH_PORT" "$TESSERA_FROST_USER@localhost" "$1"
}

printf '[2/7] boot Tessera toolchain overlay\n'
rm -rf "$TPMDIR"
mkdir -p "$TPMDIR"
swtpm socket --tpm2 --tpmstate "dir=$TPMDIR" --ctrl "type=unixio,path=$TPMDIR/sock" --daemon --pid "file=$TPMDIR/pid"
qemu_argv QARGV --profile hvf --name "$ID" \
  --code "$FW/edk2-aarch64-code.fd" --vars "$TESSERA_FROST_TOOLCHAIN_VARS" --disk "$TESSERA_FROST_TOOLCHAIN_GOLDEN" \
  --tpm "$TPMDIR/sock" --monitor "$MON" --ssh-port "$TESSERA_FROST_SSH_PORT" \
  --mem 8192 --cpus 4 --vnc 4
"${QARGV[@]}" &
QPID=$!

printf '[3/7] wait for SSH\n'
wait_for_ssh 240 || { printf 'SSH did not come up\n' >&2; exit 1; }

printf '[4/7] copy provisioning materials\n'
frost_scp "$TESSERA_FROST_SSH_PORT" \
  "$repo_root/scripts/setup-windows-frost-vm.ps1" \
  "$TESSERA_FROST_USER@localhost:$REMOTE_SCRIPT"
frost_scp "$TESSERA_FROST_SSH_PORT" \
  "$repo_root/scripts/run-windows-frost-provision-task.ps1" \
  "$TESSERA_FROST_USER@localhost:$REMOTE_TASK_HELPER"
frost_scp "$TESSERA_FROST_SSH_PORT" \
  "$PUBKEY" \
  "$TESSERA_FROST_USER@localhost:$REMOTE_KEY"

printf '[5/7] run provisioning script\n'
attempt=1
while true; do
  printf '  provisioning attempt %s\n' "$attempt"
  set +e
  run_guest "powershell -NoProfile -ExecutionPolicy Bypass -File $REMOTE_TASK_HELPER -ProvisionScript $REMOTE_SCRIPT -ExpectedSwiftVersion $EXPECTED_SWIFT_VERSION -AuthorizedKeyPath $REMOTE_KEY -UserName $TESSERA_FROST_USER -Password $PASS$TASK_OPTIONAL_ARGS"
  rc=$?
  set -e

  if [[ "$rc" == "0" ]]; then
    break
  fi

  if [[ "$rc" == "100" && "$attempt" -lt 5 ]]; then
    printf '  guest requested reboot; rebooting and waiting for SSH\n'
    run_guest 'shutdown /r /t 0' || true
    wait_for_ssh_down 180 || true
    wait_for_ssh 600 || { printf 'SSH did not return after reboot\n' >&2; exit 1; }
    attempt=$((attempt + 1))
    continue
  fi

  printf 'provisioning failed with guest exit code %s\n' "$rc" >&2
  exit "$rc"
done

printf '[6/7] verify toolchain marker\n'
run_guest 'powershell -NoProfile -Command "Get-Content C:\ProgramData\Tessera\FrostProvision\complete.txt"'

printf '[7/7] shut down guest\n'
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

printf 'DONE: Tessera toolchain golden overlay = %s\n' "$TESSERA_FROST_TOOLCHAIN_GOLDEN"
printf 'DONE: Tessera toolchain vars = %s\n' "$TESSERA_FROST_TOOLCHAIN_VARS"
