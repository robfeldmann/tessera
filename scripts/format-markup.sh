#!/usr/bin/env bash
# Mutating markup formatter: Prettier for YAML and JSON, rumdl --fix for Markdown.
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

"$prettier" --write .
# rumdl returns 1 when it fixed findings; re-check so unfixable violations are reported.
status=0
rumdl check --fix "$repo_root" || status=$?
if [[ "$status" -gt 1 ]]; then
  exit "$status"
fi
rumdl check "$repo_root"
