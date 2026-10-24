#!/usr/bin/env bash
# Sourced by the `dev:*` mise tasks, which run from the repository root: it builds the
# `tessera` executable of the Examples package once and runs the binary it built.

# Where the built executable is, once `tessera` has built it.
tessera_binary=""

# Builds `tessera`, quietly: a build that succeeds prints nothing and one that fails still
# prints its errors. The flags are the ones every SwiftPM command here passes
# (docs/architecture/toolchain-lanes.md).
tessera_build() {
  local flags=(--only-use-versions-from-resolved-file --package-path Examples)
  swift build --quiet "${flags[@]}" --product tessera
  tessera_binary="$(swift build --show-bin-path "${flags[@]}")/tessera"
}

# Runs `tessera` with the given arguments, building it first the first time. A task that
# runs it twice builds once, and the binary keeps the task's terminal, as `launch` needs.
tessera() {
  if [[ -z "$tessera_binary" ]]; then
    tessera_build
  fi
  "$tessera_binary" "$@"
}

# Shows what a `dev:*` task that needs an app name says when it is run without one: the
# command's help, then the apps it can be given. It is help, not a failure, so mise does
# not report the task as failed.
tessera_help_with_apps() {
  tessera help "$1"
  echo
  tessera apps --pretty
}
