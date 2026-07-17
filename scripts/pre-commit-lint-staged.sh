#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
source "$repo_root/scripts/quality-files.sh"

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
docc_files=()
for file in "${staged_files[@]}"; do
  quality_classify_file "$file"
done

if [[ ${#swift_files[@]} -gt 0 ]]; then
  quality_require_swift_tools
  swift-format lint --configuration .swift-format "${swift_files[@]}"
  swiftlint lint --strict --config .swiftlint.yml "${swift_files[@]}"
fi

if [[ ${#markdown_files[@]} -gt 0 ]]; then
  TESSERA_REPO_ROOT="$repo_root" "$repo_root/scripts/check-markup.sh" "${markdown_files[@]}"
fi

if [[ ${#spelling_files[@]} -gt 0 ]]; then
  TESSERA_REPO_ROOT="$repo_root" "$repo_root/scripts/quality-python.sh" -m codespell_lib --config .codespellrc "${spelling_files[@]}"
fi

if [[ ${#docc_files[@]} -gt 0 ]]; then
  quality_require_docc
  just --justfile "$tmp/Justfile" docs lint
fi
