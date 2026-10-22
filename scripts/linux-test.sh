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

# Read the whole list before printing: `break`ing early closed the pipe while limactl
# was still writing, and `pipefail` turned that SIGPIPE (exit 141) into a failure.
status="$(
  limactl list --json \
    | python3 -c 'import json, os, sys
name = os.environ["TESSERA_LINUX_VM_NAME"]
entries = [json.loads(line) for line in sys.stdin if line.strip()]
print(next((entry["status"] for entry in entries if entry["name"] == name), ""))'
)"

project_dir="$(
  limactl list --json \
    | python3 -c 'import json, os, sys
name = os.environ["TESSERA_LINUX_VM_NAME"]
entries = [json.loads(line) for line in sys.stdin if line.strip()]
print(next((entry.get("param", {}).get("ProjectDir", "") for entry in entries if entry["name"] == name), ""))'
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

# The guest keeps the baseline toolchain (.swift-version) as its swiftly default;
# TESSERA_LINUX_SWIFT_VERSION selects another release for one run (for example 6.4.1, the
# Swift 6.4 lane), installing it on first use.
swift_version="${TESSERA_LINUX_SWIFT_VERSION:-$(tr -d '[:space:]' < "$repo_root/.swift-version")}"

limactl shell "$linux_vm_name" -- bash -lc '
  set -euo pipefail
  repo_root="$1"
  swift_version="$2"
  shift 2

  source ~/.local/share/swiftly/env.sh
  export PATH=~/.local/bin:$PATH

  if ! swiftly list | grep -q "^Swift $swift_version "; then
    swiftly install "$swift_version" --assume-yes
  fi

  cd "$repo_root"
  rm -rf \
    .build/aarch64-unknown-linux-gnu/debug/ModuleCache* \
    .build/x86_64-unknown-linux-gnu/debug/ModuleCache*

  scripts/build-libghostty-vt.sh
  swiftly run "+$swift_version" swift --version
  swiftly run "+$swift_version" swift test --jobs 2 --no-parallel "$@"
' bash "$repo_root" "$swift_version" "${swift_test_args[@]+"${swift_test_args[@]}"}"
