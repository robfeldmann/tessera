#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"

PASS="${TESSERA_FROST_PASS:-${FROST_SSH_PASS:-Test1234!}}"
DEST="${TESSERA_FROST_REPO_PATH:-C:/Users/$TESSERA_FROST_USER/tessera}"
ARCHIVE="$TESSERA_FROST_WORK/source/tessera-source.tar.gz"
REMOTE_ARCHIVE="C:/Windows/Temp/tessera-source.tar.gz"
REMOTE_SYNC_SCRIPT="C:/Windows/Temp/sync-windows-frost-source.ps1"
SSHOPTS=(-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10)

usage() {
  cat <<'EOF'
usage: scripts/windows-frost-sync-source.sh [--dest C:/path/to/tessera]

Create an archive of the current working tree and sync it into an already-running
Windows Frost guest over SSH.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dest)
      DEST="$2"
      shift 2
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

if git -C "$repo_root" ls-files --deleted --error-unmatch -- ':/*' > /dev/null 2>&1; then
  printf 'deleted tracked files are present; commit/stash or restore before packaging source.\n' >&2
  git -C "$repo_root" ls-files --deleted >&2
  exit 1
fi

mkdir -p "$(dirname "$ARCHIVE")"
rm -f "$ARCHIVE"

printf '[sync] create source archive: %s\n' "$ARCHIVE"
(
  cd "$repo_root"
  git ls-files -z --cached --others --exclude-standard |
    tar --null -czf "$ARCHIVE" -T -
)

printf '[sync] copy archive and extractor to guest\n'
export SSHPASS="$PASS"
sshpass -e scp "${SSHOPTS[@]}" -P "$TESSERA_FROST_SSH_PORT" \
  "$ARCHIVE" \
  "$TESSERA_FROST_USER@localhost:$REMOTE_ARCHIVE"
sshpass -e scp "${SSHOPTS[@]}" -P "$TESSERA_FROST_SSH_PORT" \
  "$repo_root/scripts/sync-windows-frost-source.ps1" \
  "$TESSERA_FROST_USER@localhost:$REMOTE_SYNC_SCRIPT"

printf '[sync] extract source in guest: %s\n' "$DEST"
sshpass -e ssh "${SSHOPTS[@]}" -p "$TESSERA_FROST_SSH_PORT" "$TESSERA_FROST_USER@localhost" \
  "powershell -NoProfile -ExecutionPolicy Bypass -File $REMOTE_SYNC_SCRIPT -ArchivePath $REMOTE_ARCHIVE -Destination $DEST"
