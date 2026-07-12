#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-libghostty-vt.sh [--force]

Build Ghostty's libghostty-vt from the pinned revision in
scripts/ghostty-vt-version.txt and install it under:

  ${GHOSTTY_VT_OUTPUT_DIR:-${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt}/<revision>/<platform>-<arch>/

The script also updates this diagnostic symlink:

  ${GHOSTTY_VT_OUTPUT_DIR:-${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt}/current -> <revision>/<platform>-<arch>

and materializes the generated headers into the workspace (gitignored):

  Sources/CGhosttyVT/include/ghostty/

Prerequisites:
  - Zig 0.15.x on PATH
  - CMake
  - Ninja
  - git
  - a C compiler/toolchain
  - Linux: build-essential, pkg-config, libgtk-4-dev, libadwaita-1-dev,
    gettext, blueprint-compiler, libxml2-utils

Environment:
  GHOSTTY_VT_REVISION_FILE  Revision file path
  GHOSTTY_VT_OUTPUT_DIR     Output root (default: ${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt)
  GHOSTTY_VT_SOURCE_DIR     Source checkout path
  GHOSTTY_VT_BUILD_DIR      CMake build path
  GHOSTTY_VT_BUILD_MODE     Debug or Release (default: Release)
  GHOSTTY_VT_ZIG_VERSION    Expected Zig version prefix for diagnostics/cache keys
  ZIG_EXECUTABLE            Zig executable path when `zig` is not on PATH
USAGE
}

force=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force=1
      shift
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

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

default_output_root() {
  local cache_home="${XDG_CACHE_HOME:-}"
  if [[ -z "$cache_home" ]]; then
    if [[ -n "${HOME:-}" ]]; then
      cache_home="$HOME/.cache"
    else
      cache_home="$repo_root/.build"
    fi
  fi
  printf '%s/tessera/libghostty-vt\n' "$cache_home"
}
revision_file="${GHOSTTY_VT_REVISION_FILE:-$repo_root/scripts/ghostty-vt-version.txt}"
revision="$(tr -d '[:space:]' < "$revision_file")"
if [[ -z "$revision" ]]; then
  echo "error: empty Ghostty revision in $revision_file" >&2
  exit 1
fi

platform="$(uname -s | tr '[:upper:]' '[:lower:]')"
case "$platform" in
  darwin) platform="macos" ;;
  linux) platform="linux" ;;
  *)
    echo "error: unsupported platform: $(uname -s)" >&2
    exit 1
    ;;
esac

arch="$(uname -m)"
case "$arch" in
  arm64|aarch64) arch="arm64" ;;
  x86_64|amd64) arch="x86_64" ;;
  *)
    echo "error: unsupported architecture: $(uname -m)" >&2
    exit 1
    ;;
esac

output_root="${GHOSTTY_VT_OUTPUT_DIR:-$(default_output_root)}"
install_dir="$output_root/$revision/$platform-$arch"
source_dir="${GHOSTTY_VT_SOURCE_DIR:-$output_root/source/$revision}"
build_dir="${GHOSTTY_VT_BUILD_DIR:-$output_root/cmake/$revision/$platform-$arch}"
build_mode="${GHOSTTY_VT_BUILD_MODE:-Release}"
expected_zig="${GHOSTTY_VT_ZIG_VERSION:-0.15}"
zig_build_flags=""
if [[ "$platform" == "linux" ]]; then
  # GitHub-hosted runners may restore this cache on a different x86_64 CPU model.
  # A baseline library stays portable across runners instead of trapping on native-only
  # instructions.
  zig_build_flags="-Dcpu=baseline"
fi

case "$platform" in
  macos) shared_glob="libghostty-vt*.dylib" ;;
  linux) shared_glob="libghostty-vt*.so*" ;;
esac

update_current_symlink() {
  local current_link="$output_root/current"
  if [[ -e "$current_link" && ! -L "$current_link" ]]; then
    echo "error: $current_link exists and is not a symlink" >&2
    exit 1
  fi
  ln -sfn "$revision/$platform-$arch" "$current_link"
}

materialize_header_bridge() {
  local bridge_dir="$repo_root/Sources/CGhosttyVT/include/ghostty"
  rm -rf "$bridge_dir"
  mkdir -p "$(dirname "$bridge_dir")"
  cp -R "$install_dir/include/ghostty" "$bridge_dir"
}

if [[ "$force" == "0" ]] && [[ -f "$install_dir/include/ghostty/vt.h" ]] && compgen -G "$install_dir/lib/$shared_glob" >/dev/null; then
  update_current_symlink
  materialize_header_bridge
  echo "libghostty-vt already built: $install_dir"
  exit 0
fi

for tool in git cmake ninja; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "error: required tool not found on PATH: $tool" >&2
    exit 1
  fi
done

zig_executable="${ZIG_EXECUTABLE:-}"
if [[ -z "$zig_executable" ]] && command -v zig >/dev/null 2>&1; then
  zig_executable="$(command -v zig)"
fi
if [[ -z "$zig_executable" ]] && command -v brew >/dev/null 2>&1; then
  brew_zig_prefix="$(brew --prefix zig@0.15 2>/dev/null || true)"
  if [[ -n "$brew_zig_prefix" && -x "$brew_zig_prefix/bin/zig" ]]; then
    zig_executable="$brew_zig_prefix/bin/zig"
  fi
fi
if [[ -z "$zig_executable" || ! -x "$zig_executable" ]]; then
  echo "error: required tool not found: zig 0.15.x" >&2
  exit 1
fi
export PATH="$(dirname "$zig_executable"):$PATH"

zig_version="$($zig_executable version)"
if [[ "$zig_version" != "$expected_zig"* ]]; then
  echo "warning: expected Zig $expected_zig.x, found $zig_version" >&2
fi

mkdir -p "$output_root/source" "$build_dir"
if [[ ! -d "$source_dir/.git" ]]; then
  rm -rf "$source_dir"
  git clone --filter=blob:none https://github.com/ghostty-org/ghostty.git "$source_dir"
fi

git -C "$source_dir" fetch --depth 1 origin "$revision"
git -C "$source_dir" checkout --detach FETCH_HEAD
actual_revision="$(git -C "$source_dir" rev-parse HEAD)"
if [[ "$actual_revision" != "$revision" ]]; then
  echo "error: checked out $actual_revision, expected $revision" >&2
  exit 1
fi

cmake \
  -S "$source_dir" \
  -B "$build_dir" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE="$build_mode" \
  -DCMAKE_INSTALL_PREFIX="$install_dir" \
  -DGHOSTTY_ZIG_BUILD_FLAGS="$zig_build_flags"
cmake --build "$build_dir" --target zig_build_lib_vt
cmake --install "$build_dir"

cat > "$install_dir/build-metadata.txt" <<EOF
revision=$revision
platform=$platform
arch=$arch
build_mode=$build_mode
zig_version=$zig_version
zig_build_flags=$zig_build_flags
cmake_version=$(cmake --version | head -n 1)
ninja_version=$(ninja --version)
source_dir=$source_dir
build_dir=$build_dir
EOF

update_current_symlink
materialize_header_bridge

echo "Built libghostty-vt: $install_dir"
