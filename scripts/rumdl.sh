#!/usr/bin/env bash
# Defines `rumdl`: the binary on PATH, or the mise-pinned one (mise.toml) when mise is
# installed but not activated in this shell.
# shellcheck shell=bash

rumdl() {
  if type -P rumdl > /dev/null 2>&1; then
    command rumdl "$@"
  elif type -P mise > /dev/null 2>&1; then
    mise exec -- rumdl "$@"
  else
    echo "rumdl not found: run 'mise install' (see mise.toml) or install rumdl" >&2
    return 127
  fi
}
