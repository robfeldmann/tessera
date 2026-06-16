#!/usr/bin/env bash
# Shared defaults for the Frost Windows VM prototype. Source this file from bash scripts.

repo_root="$(git rev-parse --show-toplevel)"

export TESSERA_FROST_ROOT="${TESSERA_FROST_ROOT:-/Users/rob/Developer/solcreek/frost/main}"
export TESSERA_FROST_WORK="${TESSERA_FROST_WORK:-$repo_root/.build/windows-frost}"
export TESSERA_FROST_SSH_PORT="${TESSERA_FROST_SSH_PORT:-2222}"
export TESSERA_FROST_USER="${TESSERA_FROST_USER:-tester}"
export TESSERA_FROST_WINDOWS_ISO="${TESSERA_FROST_WINDOWS_ISO:-}"
export TESSERA_FROST_VIRTIO_ISO="${TESSERA_FROST_VIRTIO_ISO:-}"

export TESSERA_FROST_BASE_GOLDEN="${TESSERA_FROST_BASE_GOLDEN:-$TESSERA_FROST_WORK/disks/base-win11.qcow2}"
export TESSERA_FROST_BASE_VARS="${TESSERA_FROST_BASE_VARS:-$TESSERA_FROST_WORK/disks/base-win11-vars.fd}"
export TESSERA_FROST_TOOLCHAIN_GOLDEN="${TESSERA_FROST_TOOLCHAIN_GOLDEN:-$TESSERA_FROST_WORK/disks/tessera-win11.qcow2}"
export TESSERA_FROST_TOOLCHAIN_VARS="${TESSERA_FROST_TOOLCHAIN_VARS:-$TESSERA_FROST_WORK/disks/tessera-win11-vars.fd}"

export TESSERA_FROST_CLI="$TESSERA_FROST_ROOT/bin/frost"
