#!/usr/bin/env bash
# Sourced by the `dev:*` mise tasks, which run from the repository root: it builds and runs
# the `tessera` executable of the Examples package.

tessera() {
  swift run --only-use-versions-from-resolved-file --package-path Examples tessera "$@"
}

# Shows what a `dev:*` task that needs an app name says when it is run without one: the
# command's help, then the apps it can be given. It is help, not a failure, so mise does
# not report the task as failed.
tessera_help_with_apps() {
  tessera help "$1"
  echo
  tessera apps --pretty
}
