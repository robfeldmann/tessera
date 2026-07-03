#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"
# shellcheck source=scripts/windows-frost-ssh-options.sh
source "$repo_root/scripts/windows-frost-ssh-options.sh"


DEST="${TESSERA_FROST_REPO_PATH:-C:/Users/$TESSERA_FROST_USER/tessera}"
SSH_HOST="${TESSERA_FROST_SSH_HOST:-localhost}"
SSH_PORT="${TESSERA_FROST_SSH_PORT:-2222}"
ARCHIVE="$TESSERA_FROST_WORK/source/tessera-source.tar.gz"
REMOTE_ARCHIVE="C:/Windows/Temp/tessera-source.tar.gz"
REMOTE_SYNC_SCRIPT="C:/Windows/Temp/sync-windows-frost-source.ps1"

frost_ssh_setup 10

usage() {
  cat <<'EOF'
usage: scripts/windows-frost-sync-source.sh [--host HOST] [--port PORT] [--dest C:/path/to/tessera]

Create an archive of the current working tree and sync it into an already-running
Windows Frost guest over SSH.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      SSH_HOST="$2"
      shift 2
      ;;
    --port)
      SSH_PORT="$2"
      shift 2
      ;;
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
  printf 'deleted tracked files are present; stage, commit, stash, or restore before packaging source.\n' >&2
  printf 'The Windows source archive is built from git ls-files; unstaged deletes are still listed by the index.\n' >&2
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
frost_scp "$SSH_PORT" \
  "$ARCHIVE" \
  "$TESSERA_FROST_USER@$SSH_HOST:$REMOTE_ARCHIVE"
frost_scp "$SSH_PORT" \
  "$repo_root/scripts/sync-windows-frost-source.ps1" \
  "$TESSERA_FROST_USER@$SSH_HOST:$REMOTE_SYNC_SCRIPT"

printf '[sync] extract source in guest: %s\n' "$DEST"
frost_ssh "$SSH_PORT" "$TESSERA_FROST_USER@$SSH_HOST" \
  "powershell -NoProfile -ExecutionPolicy Bypass -File $REMOTE_SYNC_SCRIPT -ArchivePath $REMOTE_ARCHIVE -Destination $DEST"
