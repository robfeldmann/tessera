#!/usr/bin/env bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"
# shellcheck source=scripts/windows-frost-env.sh
source "$repo_root/scripts/windows-frost-env.sh"

brew_hint="brew install qemu swtpm hudochenkov/sshpass/sshpass"

failures=0

ok() {
  printf '✅ %s\n' "$1"
}

warn() {
  printf '⚠️  %s\n' "$1"
}

info() {
  printf 'ℹ️  %s\n' "$1"
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
print_utm_console_ip_fallback() {
  cat <<'EOF'
Fallback inside the UTM Windows console:
  Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notlike "169.254.*" -and $_.IPAddress -ne "127.0.0.1" } |
    Select-Object -ExpandProperty IPAddress
EOF
}

check_utm_vm_ip() {
  local vm_name="$TESSERA_FROST_UTM_VM_NAME"
  printf 'UTM imported VM name: %s\n' "$vm_name"

  if [[ -n "$TESSERA_FROST_UTM_SSH_HOST" ]]; then
    ok "UTM SSH host override: $TESSERA_FROST_UTM_SSH_HOST:$TESSERA_FROST_UTM_SSH_PORT"
  fi

  if ! command -v utmctl > /dev/null 2>&1; then
    info "utmctl not found; cannot query the UTM VM IP from macOS"
    print_utm_console_ip_fallback
    return
  fi

  local ip_output
  if ip_output="$(utmctl ip-address "$vm_name" 2>&1)" && [[ -n "${ip_output//[[:space:]]/}" ]]; then
    local first_ipv4
    first_ipv4="$(printf '%s\n' "$ip_output" | grep -E '^[0-9]+(\.[0-9]+){3}$' | head -n 1 || true)"

    if [[ -n "$first_ipv4" ]]; then
      ok "UTM VM IPv4 ($vm_name): $first_ipv4"
      info "Sync GUI VM source with: just windows-frost sync-utm $first_ipv4"
    else
      info "utmctl returned no IPv4 address for $vm_name"
      printf '%s\n' "$ip_output"
      print_utm_console_ip_fallback
    fi
  else
    info "UTM VM IP unavailable for $vm_name: $ip_output"
    print_utm_console_ip_fallback
  fi
}

printf 'Frost root: %s\n' "$TESSERA_FROST_ROOT"
printf 'Frost work: %s\n' "$TESSERA_FROST_WORK"
printf 'Frost SSH user/port: %s@localhost:%s\n' "$TESSERA_FROST_USER" "$TESSERA_FROST_SSH_PORT"
check_utm_vm_ip
check_executable "frost CLI" "$TESSERA_FROST_CLI"

check_qemu_command qemu-img
check_qemu_command qemu-system-aarch64
check_command swtpm "$brew_hint"
check_command sshpass "$brew_hint"
check_command swift "install Swift for macOS so Frost can build its vmkit helper"

if [[ -x "$TESSERA_FROST_CLI" ]]; then
  if version_output="$($TESSERA_FROST_CLI version 2>&1)"; then
    ok "$version_output"
  else
    warn "frost version failed: $version_output"
    failures=$((failures + 1))
  fi
fi

if [[ "$failures" -gt 0 ]]; then
  printf '\nFrost host prerequisite check failed with %d issue(s).\n' "$failures" >&2
  printf 'Install missing host tools with:\n  %s\n' "$brew_hint" >&2
  printf 'Set machine-local paths in a gitignored .windows-frost.env at the repo root\n' >&2
  printf '(copy scripts/config/frost/windows-frost.env.example), or pass them per\n' >&2
  printf 'command, e.g.:\n' >&2
  printf '  env TESSERA_FROST_ROOT=/path/to/frost just windows-frost doctor\n' >&2
  exit 1
fi

printf '\n✅ Frost host prerequisites look ready.\n'
