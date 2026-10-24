#!/usr/bin/env bash
# Prints the registered app names, one per line, for tab completion of the `dev:*` mise tasks.
#
# Completion runs on every Tab and has to answer at once, so this asks the `tessera` binary a
# `dev:*` run already built and never builds one: with no binary it prints nothing.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tessera="$repo_root/Examples/.build/debug/tessera"

if [[ ! -x "$tessera" ]]; then
  exit 0
fi

# `apps --json` is the stable listing: {"apps": [{"minimum", "name", "viewports"}], ...}.
"$tessera" apps --json 2>/dev/null | grep -o '"name":"[^"]*"' | cut -d'"' -f4 || true
