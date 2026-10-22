#!/usr/bin/env bash
# Strict markup gate: rumdl for Markdown, Prettier for YAML and JSON.
set -euo pipefail

repo_root="${TESSERA_REPO_ROOT:-$(git rev-parse --show-toplevel)}"
prettier="$repo_root/node_modules/.bin/prettier"

if [[ ! -x "$prettier" ]]; then
  echo "Missing local markup tools. Run 'npm ci' first." >&2
  exit 1
fi

node_runtime="$(cd "$repo_root" && node -p 'process.execPath')"
export PATH="$(dirname "$node_runtime"):$PATH"

# shellcheck source=scripts/rumdl.sh
source "$repo_root/scripts/rumdl.sh"

if [[ $# -eq 0 ]]; then
  "$prettier" --check .
  rumdl check "$repo_root"
else
  "$prettier" --check "$@"
  rumdl check "$@"
fi
