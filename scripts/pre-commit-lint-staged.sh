#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
tmp="$(mktemp -d "${TMPDIR:-/tmp}/tessera-pre-commit.XXXXXX")"

cleanup() {
  rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

staged_files=()
while IFS= read -r file; do
  staged_files+=("$file")
done < <(git -C "$repo_root" diff --cached --name-only --diff-filter=ACMR)

if [[ ${#staged_files[@]} -eq 0 ]]; then
  exit 0
fi

git -C "$repo_root" checkout-index --prefix="$tmp/" -a
cd "$tmp"

swift_files=()
markdown_files=()
spelling_files=()
for file in "${staged_files[@]}"; do
  [[ -f "$file" ]] || continue

  case "$file" in
    Package.swift|Examples/Package.swift|Sources/*.swift|Sources/*/*.swift|Sources/*/*/*.swift|Tests/*.swift|Tests/*/*.swift|Tests/*/*/*.swift|Examples/Sources/*.swift|Examples/Sources/*/*.swift|Examples/Sources/*/*/*.swift|Examples/Tests/*.swift|Examples/Tests/*/*.swift|Examples/Tests/*/*/*.swift)
      swift_files+=("$file")
      spelling_files+=("$file")
      ;;
    *.md)
      spelling_files+=("$file")
      if [[ "$file" != *".docc/"* ]]; then
        markdown_files+=("$file")
      fi
      ;;
    package-lock.json)
      ;;
    *.json|*.yaml|*.yml|*.py)
      spelling_files+=("$file")
      ;;
  esac
done

if [[ ${#swift_files[@]} -gt 0 ]]; then
  swift-format lint "${swift_files[@]}"
  swiftlint lint --strict --config .swiftlint.yml "${swift_files[@]}"
fi

if [[ ${#markdown_files[@]} -gt 0 ]]; then
  prettier="$repo_root/node_modules/.bin/prettier"
  markdownlint="$repo_root/node_modules/.bin/markdownlint-cli2"

  if [[ ! -x "$prettier" || ! -x "$markdownlint" ]]; then
    echo "Missing local markup tools. Run 'npm ci' first." >&2
    exit 1
  fi

  "$prettier" --check "${markdown_files[@]}"
  "$markdownlint" "${markdown_files[@]}"
fi

if [[ ${#spelling_files[@]} -gt 0 ]]; then
  TESSERA_REPO_ROOT="$repo_root" "$repo_root/scripts/quality-python.sh" -m codespell_lib --config .codespellrc "${spelling_files[@]}"
fi
