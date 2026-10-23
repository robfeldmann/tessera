#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage: scripts/build-libghostty-vt.sh [--force] [--target <zig-target>] [--update-headers]

Build Ghostty's libghostty-vt from the pinned revision in
scripts/ghostty-vt-version.txt and install it under:

  ${GHOSTTY_VT_OUTPUT_DIR:-${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt}/<revision>/<variant>/

where <variant> is <platform>-<arch> (macos-arm64, linux-x86_64, ...), or
linux-musl-<arch> for a musl target. The script also updates this diagnostic
symlink:

  ${GHOSTTY_VT_OUTPUT_DIR:-${XDG_CACHE_HOME:-~/.cache}/tessera/libghostty-vt}/current -> <revision>/<variant>

The Ghostty headers are committed under Sources/CGhosttyVT/include/ghostty/. The
script fails when they differ from the pinned build's headers and names the files;
after bumping the pin, pass --update-headers to re-vendor them.

Options:
  --force           Rebuild even when the pinned variant is already installed
  --target TARGET   Zig target to cross-compile for, for example x86_64-macos,
                    x86_64-linux-gnu.2.31, or aarch64-linux-musl (default: host)
  --update-headers  Copy the pinned build's headers over the committed ones

Prerequisites:
  - Zig 0.17.x on PATH (`mise install` provides it)
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
update_headers=0
zig_target=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force)
      force=1
      shift
      ;;
    --target)
      if [[ $# -lt 2 || -z "$2" ]]; then
        echo "error: --target needs a Zig target" >&2
        exit 2
      fi
      zig_target="$2"
      shift 2
      ;;
    --update-headers)
      update_headers=1
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

variant="$platform-$arch"
zig_build_flags=()
if [[ -n "$zig_target" ]]; then
  IFS=- read -r target_arch target_os target_abi <<<"$zig_target"
  case "$target_arch" in
    aarch64) arch="arm64" ;;
    x86_64) arch="x86_64" ;;
    *)
      echo "error: unsupported target architecture in $zig_target" >&2
      exit 2
      ;;
  esac
  case "$target_os" in
    macos)
      if [[ "$platform" != "macos" ]]; then
        echo "error: $zig_target needs a macOS host" >&2
        exit 2
      fi
      variant="macos-$arch"
      ;;
    linux)
      platform="linux"
      case "${target_abi%%.*}" in
        gnu) variant="linux-$arch" ;;
        musl) variant="linux-musl-$arch" ;;
        *)
          echo "error: $zig_target must name a gnu or musl ABI" >&2
          exit 2
          ;;
      esac
      ;;
    *)
      echo "error: unsupported target OS in $zig_target (Windows uses build-libghostty-vt.ps1)" >&2
      exit 2
      ;;
  esac
  zig_build_flags+=("-Dtarget=$zig_target")
fi
if [[ "$platform" == "linux" ]]; then
  # GitHub-hosted runners may build or run on a different x86_64 CPU model. A baseline
  # library stays portable instead of trapping on native-only instructions.
  zig_build_flags+=("-Dcpu=baseline")
fi
zig_build_flags_text="${zig_build_flags[*]-}"

output_root="${GHOSTTY_VT_OUTPUT_DIR:-$(default_output_root)}"
install_dir="$output_root/$revision/$variant"
source_dir="${GHOSTTY_VT_SOURCE_DIR:-$output_root/source/$revision}"
build_dir="${GHOSTTY_VT_BUILD_DIR:-$output_root/cmake/$revision/$variant}"
build_mode="${GHOSTTY_VT_BUILD_MODE:-Release}"
expected_zig="${GHOSTTY_VT_ZIG_VERSION:-0.17}"

update_current_symlink() {
  local current_link="$output_root/current"
  if [[ -e "$current_link" && ! -L "$current_link" ]]; then
    echo "error: $current_link exists and is not a symlink" >&2
    exit 1
  fi
  ln -sfn "$revision/$variant" "$current_link"
}

check_committed_headers() {
  local pinned="$install_dir/include/ghostty"
  local committed="$repo_root/Sources/CGhosttyVT/include/ghostty"
  if [[ "$update_headers" == "1" ]]; then
    rm -rf "$committed"
    mkdir -p "$(dirname "$committed")"
    cp -R "$pinned" "$committed"
    echo "Updated the committed Ghostty headers: $committed"
    return
  fi
  local differences
  if ! differences="$(diff -rq "$pinned" "$committed" 2>&1)"; then
    echo "error: the committed Ghostty headers differ from revision $revision:" >&2
    printf '%s\n' "$differences" >&2
    echo "Re-vendor them with: scripts/build-libghostty-vt.sh --update-headers" >&2
    exit 1
  fi
}

installed_flags() {
  sed -n 's/^zig_build_flags=//p' "$install_dir/build-metadata.txt" 2>/dev/null || true
}

if [[ "$force" == "0" ]] \
  && [[ -f "$install_dir/include/ghostty/vt.h" ]] \
  && [[ -f "$install_dir/lib/libghostty-vt.a" ]] \
  && [[ "$(installed_flags)" == "$zig_build_flags_text" ]]; then
  update_current_symlink
  check_committed_headers
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
if [[ -z "$zig_executable" || ! -x "$zig_executable" ]]; then
  echo "error: required tool not found: zig $expected_zig.x (run \`mise install\`)" >&2
  exit 1
fi
export PATH="$(dirname "$zig_executable"):$PATH"

zig_version="$($zig_executable version)"
if [[ "$zig_version" != "$expected_zig"* ]]; then
  echo "warning: expected Zig $expected_zig.x, found $zig_version" >&2
fi

if [[ "$platform" == "macos" && -z "${SDKROOT:-}" ]]; then
  # Without SDKROOT, the compiler can fall back to the Command Line Tools SDK even when
  # DEVELOPER_DIR selects an Xcode, and an older Xcode's linker rejects a newer CLT SDK
  # ("tapi error: malformed file"), failing CMake's compiler check.
  export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"
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

# CMake takes a list, so the flags are joined with semicolons.
cmake_zig_flags="$(IFS=';'; printf '%s' "${zig_build_flags[*]-}")"
cmake \
  -S "$source_dir" \
  -B "$build_dir" \
  -G Ninja \
  -DCMAKE_BUILD_TYPE="$build_mode" \
  -DCMAKE_INSTALL_PREFIX="$install_dir" \
  -DGHOSTTY_ZIG_BUILD_FLAGS="$cmake_zig_flags"
cmake --build "$build_dir" --target zig_build_lib_vt
cmake --install "$build_dir"

cat > "$install_dir/build-metadata.txt" <<EOF
revision=$revision
variant=$variant
platform=$platform
arch=$arch
build_mode=$build_mode
zig_version=$zig_version
zig_build_flags=$zig_build_flags_text
cmake_version=$(cmake --version | head -n 1)
ninja_version=$(ninja --version)
source_dir=$source_dir
build_dir=$build_dir
EOF

update_current_symlink
check_committed_headers

echo "Built libghostty-vt: $install_dir"
