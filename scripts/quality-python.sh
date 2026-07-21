#!/usr/bin/env bash
set -euo pipefail

repo_root="${TESSERA_REPO_ROOT:-$(git rev-parse --show-toplevel)}"
venv_root="$repo_root/.venv"

bootstrap=false
if [[ "${1:-}" == "--bootstrap" ]]; then
  bootstrap=true
  shift

  if [[ ! -x "$venv_root/bin/python" && ! -x "$venv_root/Scripts/python.exe" ]]; then
    for python in python3 python; do
      if command -v "$python" >/dev/null 2>&1; then
        "$python" -m venv "$venv_root"
        break
      fi
    done
  fi
fi

if [[ -x "$venv_root/bin/python" ]]; then
  python="$venv_root/bin/python"
elif [[ -x "$venv_root/Scripts/python.exe" ]]; then
  python="$venv_root/Scripts/python.exe"
else
  echo "Missing .venv. Run 'just setup quality-tools' first." >&2
  exit 1
fi

if [[ "$bootstrap" == true ]]; then
  "$python" -m pip install --disable-pip-version-check --requirement "$repo_root/requirements/codespell.txt"
  exit
fi

exec "$python" "$@"
