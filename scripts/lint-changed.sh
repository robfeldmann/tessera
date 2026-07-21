#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
source scripts/quality-files.sh

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
spelling_files=()
docc_files=()
for file in "${changed_files[@]}"; do
  quality_classify_file "$file"
done

if [[ ${#swift_files[@]} -gt 0 ]]; then
  echo "▶ Linting changed Swift files"
  quality_require_swift_tools
  swift-format lint --configuration .swift-format "${swift_files[@]}"
  swiftlint lint --strict --config .swiftlint.yml "${swift_files[@]}"
fi

if [[ ${#markdown_files[@]} -gt 0 ]]; then
  echo "▶ Linting changed Markdown files"
  npm run check:markup -- "${markdown_files[@]}"
fi

if [[ ${#spelling_files[@]} -gt 0 ]]; then
  echo "▶ Checking spelling in changed files"
  scripts/quality-python.sh -m codespell_lib --config .codespellrc "${spelling_files[@]}"
fi

if [[ ${#docc_files[@]} -gt 0 ]]; then
  echo "▶ Validating DocC documentation (macOS-only)"
  quality_require_docc
  just docs lint
fi

echo "✅ Changed-file lint passed"
