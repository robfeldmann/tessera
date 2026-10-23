#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/package-libghostty-vt-bundle.sh [--variant <name>] [--library <path>]
                                              [--bundle <dir>] [--license <path>]

Copy a libghostty-vt static library built by scripts/build-libghostty-vt.sh (or
.ps1) into an SE-0482 static-library artifact bundle, then rewrite the bundle's
info.json from every variant the bundle holds. Run it once per variant to merge
several variants into one bundle.

Variants and the triples they declare:
  macos-arm64        arm64-apple-macosx
  macos-x86_64       x86_64-apple-macosx
  macos-universal    arm64-apple-macosx, x86_64-apple-macosx
  linux-arm64        aarch64-unknown-linux-gnu
  linux-x86_64       x86_64-unknown-linux-gnu
  linux-musl-arm64   aarch64-swift-linux-musl
  linux-musl-x86_64  x86_64-swift-linux-musl
  windows-arm64      aarch64-unknown-windows-msvc
  windows-x86_64     x86_64-unknown-windows-msvc

Options:
  --variant NAME   Variant to add (default: the host's, e.g. macos-arm64)
  --library PATH   Static library to copy (default: the pinned build's
                   <output root>/<revision>/<variant>/lib/libghostty-vt.a)
  --bundle DIR     Bundle directory (default: .build/ghostty-vt/GhosttyVTLibrary.artifactbundle,
                   which TESSERA_GHOSTTY_VT_BUNDLE=local selects in Package.swift)
  --license PATH   Ghostty LICENSE to place at the bundle root (default: the pinned
                   source checkout's LICENSE, when present)

Environment:
  GHOSTTY_VT_REVISION_FILE  Revision file path
  GHOSTTY_VT_OUTPUT_DIR     Output root (default: ${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt)
USAGE
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

variant=""
library=""
bundle="$repo_root/.build/ghostty-vt/GhosttyVTLibrary.artifactbundle"
license=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --variant|--library|--bundle|--license)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "error: $1 needs a value" >&2
        exit 2
      fi
      case "$1" in
        --variant) variant="$2" ;;
        --library) library="$2" ;;
        --bundle) bundle="$2" ;;
        --license) license="$2" ;;
      esac
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# The one table of variants: name, then the triples SwiftPM matches against.
variant_triples() {
  case "$1" in
    macos-arm64) echo "arm64-apple-macosx" ;;
    macos-x86_64) echo "x86_64-apple-macosx" ;;
    macos-universal) echo "arm64-apple-macosx x86_64-apple-macosx" ;;
    linux-arm64) echo "aarch64-unknown-linux-gnu" ;;
    linux-x86_64) echo "x86_64-unknown-linux-gnu" ;;
    linux-musl-arm64) echo "aarch64-swift-linux-musl" ;;
    linux-musl-x86_64) echo "x86_64-swift-linux-musl" ;;
    windows-arm64) echo "aarch64-unknown-windows-msvc" ;;
    windows-x86_64) echo "x86_64-unknown-windows-msvc" ;;
    *) return 1 ;;
  esac
}

variant_library_name() {
  case "$1" in
    windows-*) echo "ghostty-vt-static.lib" ;;
    *) echo "libghostty-vt.a" ;;
  esac
}

revision_file="${GHOSTTY_VT_REVISION_FILE:-$repo_root/scripts/ghostty-vt-version.txt}"
revision="$(tr -d '[:space:]' < "$revision_file")"
output_root="${GHOSTTY_VT_OUTPUT_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/tessera/libghostty-vt}"

if [[ -z "$variant" ]]; then
  case "$(uname -s)" in
    Darwin) variant="macos" ;;
    Linux) variant="linux" ;;
    *)
      echo "error: unsupported host $(uname -s); pass --variant" >&2
      exit 2
      ;;
  esac
  case "$(uname -m)" in
    arm64|aarch64) variant="$variant-arm64" ;;
    x86_64|amd64) variant="$variant-x86_64" ;;
    *)
      echo "error: unsupported architecture $(uname -m); pass --variant" >&2
      exit 2
      ;;
  esac
fi
if ! variant_triples "$variant" >/dev/null; then
  echo "error: unknown variant: $variant" >&2
  exit 2
fi

library_name="$(variant_library_name "$variant")"
if [[ -z "$library" ]]; then
  library="$output_root/$revision/$variant/lib/$library_name"
fi
if [[ ! -f "$library" ]]; then
  echo "error: library not found: $library (run scripts/build-libghostty-vt.sh first)" >&2
  exit 1
fi
if [[ -z "$license" && -f "$output_root/source/$revision/LICENSE" ]]; then
  license="$output_root/source/$revision/LICENSE"
fi

mkdir -p "$bundle/$variant"
rm -f "$bundle/$variant"/*
cp "$library" "$bundle/$variant/$library_name"
if [[ -n "$license" ]]; then
  cp "$license" "$bundle/LICENSE"
fi

# Rewrite info.json from the variant directories present, so repeated runs merge.
variants_json=""
for directory in "$bundle"/*/; do
  name="$(basename "$directory")"
  triples="$(variant_triples "$name")" || continue
  file="$(variant_library_name "$name")"
  [[ -f "$directory/$file" ]] || continue
  triples_json=""
  for triple in $triples; do
    triples_json+="${triples_json:+, }\"$triple\""
  done
  variants_json+="${variants_json:+,
}        {
          \"path\": \"$name/$file\",
          \"supportedTriples\": [$triples_json],
          \"staticLibraryMetadata\": { \"headerPaths\": [] }
        }"
done

cat > "$bundle/info.json" <<EOF
{
  "schemaVersion": "1.0",
  "artifacts": {
    "GhosttyVTLibrary": {
      "type": "staticLibrary",
      "version": "${revision:0:12}",
      "variants": [
$variants_json
      ]
    }
  }
}
EOF

echo "Packaged $variant into $bundle"
