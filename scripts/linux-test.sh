#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
linux_vm_name="${TESSERA_LINUX_VM_NAME:-tessera-linux}"
export TESSERA_LINUX_VM_NAME="$linux_vm_name"
if [[ "${1:-}" == "--" ]]; then
  shift
fi

swift_test_args=("$@")

if ! command -v limactl &> /dev/null; then
  echo "⚠️  limactl not found — run 'brew bundle install'"
  exit 1
fi

status="$(
  limactl list --json \
    | python3 -c 'import json, os, sys
name = os.environ["TESSERA_LINUX_VM_NAME"]
for line in sys.stdin:
    entry = json.loads(line)
    if entry["name"] == name:
        print(entry["status"])
        break
else:
    print("")'
)"

project_dir="$(
  limactl list --json \
    | python3 -c 'import json, os, sys
name = os.environ["TESSERA_LINUX_VM_NAME"]
for line in sys.stdin:
    entry = json.loads(line)
    if entry["name"] == name:
        print(entry.get("param", {}).get("ProjectDir", ""))
        break
else:
    print("")'
)"

started_vm=0
if [[ -z "$status" ]]; then
  limactl --yes start \
    --name="$linux_vm_name" \
    --mount-only "$repo_root:w" \
    --param ProjectDir="$repo_root" \
    "$repo_root/scripts/config/lima/tessera-linux.yaml"
  started_vm=1
elif [[ "$project_dir" != "$repo_root" && "$status" != "Running" ]]; then
  limactl delete --force "$linux_vm_name"
  limactl --yes start \
    --name="$linux_vm_name" \
    --mount-only "$repo_root:w" \
    --param ProjectDir="$repo_root" \
    "$repo_root/scripts/config/lima/tessera-linux.yaml"
  started_vm=1
elif [[ "$project_dir" != "$repo_root" ]]; then
  echo "⚠️  $linux_vm_name is already running for $project_dir, not $repo_root"
  exit 1
elif [[ "$status" != "Running" ]]; then
  limactl start "$linux_vm_name"
  started_vm=1
fi

cleanup() {
  if [[ "$started_vm" == "1" ]]; then
    limactl stop "$linux_vm_name"
  fi
}
trap cleanup EXIT

limactl shell "$linux_vm_name" -- bash -lc '
  set -euo pipefail
  repo_root="$1"
  shift

  source ~/.local/share/swiftly/env.sh
  export PATH=~/.local/bin:$PATH

  cd "$repo_root"
  rm -rf \
    .build/aarch64-unknown-linux-gnu/debug/ModuleCache* \
    .build/x86_64-unknown-linux-gnu/debug/ModuleCache*

  scripts/build-libghostty-vt.sh
  swift test --jobs 2 --no-parallel "$@"
' bash "$repo_root" "${swift_test_args[@]+"${swift_test_args[@]}"}"
