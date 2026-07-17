#!/usr/bin/env bash
set -euo pipefail

repo_root="${TESSERA_REPO_ROOT:-$(git rev-parse --show-toplevel)}"
prettier="$repo_root/node_modules/.bin/prettier"
markdownlint="$repo_root/node_modules/.bin/markdownlint-cli2"

if [[ ! -x "$prettier" || ! -x "$markdownlint" ]]; then
  echo "Missing local markup tools. Run 'npm ci' first." >&2
  exit 1
fi

if [[ $# -eq 0 ]]; then
  "$prettier" --check .
  "$markdownlint" "**/*.md" "!**/*.docc/**/*.md" "!**/.build/**/*.md" "!Packages/**/*.md" "!node_modules/**/*.md"
else
  "$prettier" --check "$@"
  "$markdownlint" "$@"
fi
