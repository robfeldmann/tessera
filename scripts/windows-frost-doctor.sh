#!/usr/bin/env bash
set -euo pipefail

frost_root="${TESSERA_FROST_ROOT:-/Users/rob/Developer/solcreek/frost/main}"
brew_hint="brew install qemu swtpm hudochenkov/sshpass/sshpass"

failures=0

ok() {
  printf '✅ %s\n' "$1"
}

warn() {
  printf '⚠️  %s\n' "$1"
}

check_executable() {
  local label="$1"
  local path="$2"

  if [[ -x "$path" ]]; then
    ok "$label: $path"
  else
    warn "$label not found or not executable: $path"
    failures=$((failures + 1))
  fi
}

check_command() {
  local command_name="$1"
  local hint="${2:-}"

  if command -v "$command_name" > /dev/null 2>&1; then
    ok "$command_name: $(command -v "$command_name")"
  else
    if [[ -n "$hint" ]]; then
      warn "$command_name not found — $hint"
    else
      warn "$command_name not found"
    fi
    failures=$((failures + 1))
  fi
}

check_qemu_command() {
  local command_name="$1"
  local env_dir="${FROST_QEMU_BIN_DIR:-}"

  if command -v "$command_name" > /dev/null 2>&1; then
    ok "$command_name: $(command -v "$command_name")"
  elif [[ -n "$env_dir" && -x "$env_dir/$command_name" ]]; then
    ok "$command_name: $env_dir/$command_name"
  elif [[ -x "/opt/homebrew/bin/$command_name" ]]; then
    ok "$command_name: /opt/homebrew/bin/$command_name"
  else
    warn "$command_name not found — $brew_hint"
    failures=$((failures + 1))
  fi
}

printf 'Frost root: %s\n' "$frost_root"
check_executable "frost CLI" "$frost_root/bin/frost"

check_qemu_command qemu-img
check_qemu_command qemu-system-aarch64
check_command swtpm "$brew_hint"
check_command sshpass "$brew_hint"
check_command swift "install Swift for macOS so Frost can build its vmkit helper"

if [[ -x "$frost_root/bin/frost" ]]; then
  if version_output="$($frost_root/bin/frost version 2>&1)"; then
    ok "$version_output"
  else
    warn "frost version failed: $version_output"
    failures=$((failures + 1))
  fi
fi

if [[ "$failures" -gt 0 ]]; then
  printf '\nFrost host prerequisite check failed with %d issue(s).\n' "$failures" >&2
  printf 'Install missing host tools with:\n  %s\n' "$brew_hint" >&2
  printf 'If Frost lives elsewhere, pass TESSERA_FROST_ROOT for one command, e.g.:\n' >&2
  printf '  env TESSERA_FROST_ROOT=/path/to/frost just windows-frost-doctor\n' >&2
  exit 1
fi

printf '\n✅ Frost host prerequisites look ready.\n'
