#!/usr/bin/env bash

quality_classify_file() {
  local file="$1"

  [[ -f "$file" ]] || return

  if [[ "$file" == *.swift ]]; then
    swift_files+=("$file")
    spelling_files+=("$file")
  fi

  if [[ "$file" == *.md ]]; then
    spelling_files+=("$file")
    if [[ "$file" != *".docc/"* ]]; then
      markdown_files+=("$file")
    fi
  fi

  if [[ "$file" != "package-lock.json" && ( "$file" == *.json || "$file" == *.yaml || "$file" == *.yml || "$file" == *.py ) ]]; then
    spelling_files+=("$file")
  fi

  if [[ "$file" == *".docc/"* ]]; then
    docc_files+=("$file")
  fi
}

quality_require_swift_tools() {
  for tool in swift-format swiftlint; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      echo "Missing $tool. Install the repository quality dependencies first." >&2
      exit 1
    fi
  done

  if [[ ! -f .swift-format || ! -f .swiftlint.yml ]]; then
    echo "Missing .swift-format or .swiftlint.yml in the checked files." >&2
    exit 1
  fi
}

quality_require_docc() {
  if [[ "$(uname)" != "Darwin" ]]; then
    echo "DocC validation requires macOS with Xcode and xcrun docc." >&2
    exit 1
  fi

  if ! command -v just >/dev/null 2>&1 || ! command -v xcrun >/dev/null 2>&1 || ! xcrun --find docc >/dev/null 2>&1; then
    echo "DocC validation requires just and Xcode's xcrun docc toolchain." >&2
    exit 1
  fi
}
