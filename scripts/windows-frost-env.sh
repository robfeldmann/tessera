#!/usr/bin/env bash
# Shared defaults for the Frost Windows VM workflow. Source this file from bash scripts.

repo_root="$(git rev-parse --show-toplevel)"

# Machine-local overrides: keep the frost root and ISO paths in a gitignored
# `.windows-frost.env` at the repo root (or point TESSERA_FROST_ENV elsewhere) so the
# workflow runs without env prefixes on every command. That file uses the ${VAR:-…} idiom
# too, so an explicit `env VAR=… just …` still wins; the defaults below fill anything left
# unset.
tessera_frost_env_file="${TESSERA_FROST_ENV:-$repo_root/.windows-frost.env}"
if [[ -f "$tessera_frost_env_file" ]]; then
  # shellcheck source=/dev/null
  source "$tessera_frost_env_file"
fi

export TESSERA_FROST_ROOT="${TESSERA_FROST_ROOT:-$HOME/Developer/frost}"
export TESSERA_FROST_WORK="${TESSERA_FROST_WORK:-${XDG_STATE_HOME:-$HOME/.local/state}/tessera/windows-frost}"
export TESSERA_FROST_SSH_PORT="${TESSERA_FROST_SSH_PORT:-2222}"
export TESSERA_FROST_USER="${TESSERA_FROST_USER:-tester}"
export TESSERA_FROST_WINDOWS_ISO="${TESSERA_FROST_WINDOWS_ISO:-}"
export TESSERA_FROST_VIRTIO_ISO="${TESSERA_FROST_VIRTIO_ISO:-}"
export TESSERA_FROST_GIT_INSTALLER_URL="${TESSERA_FROST_GIT_INSTALLER_URL:-}"
export TESSERA_FROST_VS_BOOTSTRAPPER_URL="${TESSERA_FROST_VS_BOOTSTRAPPER_URL:-}"
export TESSERA_FROST_SWIFT_INSTALLER_URL="${TESSERA_FROST_SWIFT_INSTALLER_URL:-}"
export TESSERA_FROST_PUBKEY="${TESSERA_FROST_PUBKEY:-$HOME/.ssh/tessera_windows.pub}"
export TESSERA_FROST_SSH_KEY="${TESSERA_FROST_SSH_KEY:-$HOME/.ssh/tessera_windows}"
export TESSERA_FROST_WINDOWS_SDK_VERSION="${TESSERA_FROST_WINDOWS_SDK_VERSION:-10.0.26100.0}"
export TESSERA_FROST_REPO_PATH="${TESSERA_FROST_REPO_PATH:-C:/Users/$TESSERA_FROST_USER/tessera}"
export TESSERA_FROST_UTM_SSH_HOST="${TESSERA_FROST_UTM_SSH_HOST:-}"
export TESSERA_FROST_UTM_SSH_PORT="${TESSERA_FROST_UTM_SSH_PORT:-22}"

export TESSERA_FROST_BASE_GOLDEN="${TESSERA_FROST_BASE_GOLDEN:-$TESSERA_FROST_WORK/disks/base-win11.qcow2}"
export TESSERA_FROST_BASE_VARS="${TESSERA_FROST_BASE_VARS:-$TESSERA_FROST_WORK/disks/base-win11-vars.fd}"
export TESSERA_FROST_TOOLCHAIN_GOLDEN="${TESSERA_FROST_TOOLCHAIN_GOLDEN:-$TESSERA_FROST_WORK/disks/tessera-win11.qcow2}"
export TESSERA_FROST_TOOLCHAIN_VARS="${TESSERA_FROST_TOOLCHAIN_VARS:-$TESSERA_FROST_WORK/disks/tessera-win11-vars.fd}"

export TESSERA_FROST_CLI="$TESSERA_FROST_ROOT/bin/frost"
