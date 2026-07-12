#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

mode="${1:-}"

changed_files=()
case "$mode" in
  "")
    while IFS= read -r file; do
      changed_files+=("$file")
    done < <(git diff --name-only --diff-filter=ACMR HEAD --)
    while IFS= read -r file; do
      changed_files+=("$file")
    done < <(git ls-files --others --exclude-standard)
    ;;
  --staged)
    while IFS= read -r file; do
      changed_files+=("$file")
    done < <(git diff --cached --name-only --diff-filter=ACMR)
    ;;
  *)
    echo "usage: scripts/lint-changed.sh [--staged]" >&2
    exit 2
    ;;
esac

if [[ ${#changed_files[@]} -eq 0 ]]; then
  echo "✅ No changed files to lint"
  exit 0
fi

unique_files=()
while IFS= read -r file; do
  unique_files+=("$file")
done < <(printf "%s\n" "${changed_files[@]}" | sort -u)
changed_files=("${unique_files[@]}")

swift_files=()
markdown_files=()
docc_files=()

for file in "${changed_files[@]}"; do
  [[ -f "$file" ]] || continue

  if [[ "$file" == "Package.swift" || "$file" == "Examples/Package.swift" || "$file" =~ ^(Sources|Tests|Examples/Sources|Examples/Tests)/.*\.swift$ ]]; then
    swift_files+=("$file")
  fi

  if [[ "$file" == *.md ]]; then
    markdown_files+=("$file")
  fi

  if [[ "$file" =~ ^Sources/.+\.docc/ ]]; then
    docc_files+=("$file")
  fi
done

if [[ ${#swift_files[@]} -gt 0 ]]; then
  echo "▶ Linting changed Swift files"
  swift-format lint "${swift_files[@]}"
  swiftlint lint --strict --config .swiftlint.yml "${swift_files[@]}"
fi

if [[ ${#markdown_files[@]} -gt 0 ]]; then
  echo "▶ Linting changed Markdown files"
  if command -v prettier &> /dev/null; then
    prettier --check "${markdown_files[@]}"
  else
    echo "⚠️  prettier not found — skip markdown formatting check"
  fi

  if command -v pnpx &> /dev/null; then
    pnpx markdownlint-cli "${markdown_files[@]}"
  else
    echo "⚠️  pnpx not found — skip markdownlint check"
  fi
fi

if [[ ${#docc_files[@]} -gt 0 ]]; then
  echo "▶ Validating DocC documentation"
  just docs lint
fi

echo "✅ Changed-file lint passed"
