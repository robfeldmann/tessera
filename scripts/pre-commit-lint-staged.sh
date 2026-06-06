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

for file in "${staged_files[@]}"; do
  [[ -f "$file" ]] || continue

  case "$file" in
    Package.swift|Examples/Package.swift|Sources/*.swift|Sources/*/*.swift|Sources/*/*/*.swift|Tests/*.swift|Tests/*/*.swift|Tests/*/*/*.swift|Examples/Sources/*.swift|Examples/Sources/*/*.swift|Examples/Sources/*/*/*.swift|Examples/Tests/*.swift|Examples/Tests/*/*.swift|Examples/Tests/*/*/*.swift)
      swift_files+=("$file")
      ;;
    *.md)
      markdown_files+=("$file")
      ;;
  esac
done

if [[ ${#swift_files[@]} -gt 0 ]]; then
  swift-format lint "${swift_files[@]}"
  swiftlint lint --config .swiftlint.yml "${swift_files[@]}"
fi

if [[ ${#markdown_files[@]} -gt 0 ]]; then
  if command -v prettier &> /dev/null; then
    prettier --check "${markdown_files[@]}"
  else
    echo "⚠️  prettier not found — skip markdown linting (pnpm add -g prettier)"
  fi
fi
