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

# Ends a `dev:*` task that was run without what it needs, after the command's help has been
# printed. A person at a terminal asked a question and got the answer, so the task succeeds
# and mise reports no failure. In a pipe or a script nothing ran, which is `tessera`'s own
# usage error, so the task exits 2 and an unset variable cannot pass for success.
tessera_end_with_help() {
  if [[ -t 1 ]]; then
    exit 0
  fi
  exit 2
}

# Prints the help of `tessera COMMAND`, then ends the task.
tessera_exit_with_help() {
  tessera help "$1"
  tessera_end_with_help
}

# Prints the help of `tessera COMMAND` and the apps it can be given, then ends the task.
tessera_exit_with_help_and_apps() {
  tessera help "$1"
  echo
  tessera apps --pretty
  tessera_end_with_help
}
