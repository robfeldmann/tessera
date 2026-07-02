#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"
# shellcheck source=scripts/windows-frost-ssh-options.sh
source "$repo_root/scripts/windows-frost-ssh-options.sh"

usage() {
  cat <<'EOF'
usage: scripts/windows-frost-build-ghostty.sh [--force]

Build the pinned libghostty-vt revision inside the persistent Frost Windows VM
(started with `just windows-frost start`) and cache the artifact on the host at:

  $TESSERA_FROST_WORK/libghostty-vt/<revision>/windows-arm64

`just windows-frost test` provisions test guests from that host cache. Re-run
this after bumping scripts/ghostty-vt-version.txt. Skips the guest build when
the host cache for the pinned revision already exists unless --force is given.
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

revision="$(tr -d '[:space:]' < "$repo_root/scripts/ghostty-vt-version.txt")"
if [[ -z "$revision" ]]; then
  printf 'empty revision in scripts/ghostty-vt-version.txt\n' >&2
  exit 1
fi

host_cache_root="$TESSERA_FROST_WORK/libghostty-vt"
host_artifact="$host_cache_root/$revision/windows-arm64"
if [[ "$force" == "0" ]] && [[ -f "$host_artifact/lib/ghostty-vt-static.lib" ]] && [[ -f "$host_artifact/include/ghostty/vt.h" ]]; then
  printf 'libghostty-vt host cache already populated: %s\n' "$host_artifact"
  exit 0
fi

REPO_PATH="${TESSERA_FROST_REPO_PATH:-C:/Users/$TESSERA_FROST_USER/tessera}"
GUEST_OUTPUT_ROOT="C:/Users/$TESSERA_FROST_USER/AppData/Local/tessera/libghostty-vt"

frost_ssh_setup 10
# Keep the connection alive across the long in-guest Zig build.
FROST_SSH_OPTS+=(-o ServerAliveInterval=30 -o ServerAliveCountMax=10)

run_guest() {
  frost_ssh "$TESSERA_FROST_SSH_PORT" "$TESSERA_FROST_USER@localhost" "$1"
}

printf '[1/4] check persistent VM\n'
if ! run_guest "exit 0" > /dev/null 2>&1; then
  printf 'persistent Frost VM is not reachable; run `just windows-frost start` first.\n' >&2
  exit 1
fi

printf '[2/4] sync source\n'
"$repo_root/scripts/windows-frost-sync-source.sh" --dest "$REPO_PATH"

printf '[3/4] build libghostty-vt in guest (revision %s)\n' "$revision"
force_flag=""
if [[ "$force" == "1" ]]; then
  force_flag=" -Force"
fi
# -File propagates the script's exit code; ServerAliveInterval survives the long build.
run_guest "powershell -NoProfile -ExecutionPolicy Bypass -File $REPO_PATH/scripts/build-libghostty-vt.ps1$force_flag"

printf '[4/4] copy artifact to host cache: %s\n' "$host_artifact"
mkdir -p "$host_cache_root"
rm -rf "$host_cache_root/$revision"
run_guest "tar -C $GUEST_OUTPUT_ROOT -czf - $revision" > "$host_cache_root/artifact-$revision.tgz"
tar -xzf "$host_cache_root/artifact-$revision.tgz" -C "$host_cache_root"
rm -f "$host_cache_root/artifact-$revision.tgz"

for artifact in "$host_artifact/lib/ghostty-vt-static.lib" "$host_artifact/include/ghostty/vt.h" "$host_artifact/bin/ghostty-vt.dll"; do
  if [[ ! -f "$artifact" ]]; then
    printf 'artifact copy incomplete; missing %s\n' "$artifact" >&2
    exit 1
  fi
done

printf 'libghostty-vt host cache ready: %s\n' "$host_artifact"
