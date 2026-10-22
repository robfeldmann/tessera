---
name: Windows Frost SwiftPM Dependency Cache
date: 2026-07-04
status: resolved
---

# Windows Frost SwiftPM Dependency Cache

## Question

Why does `just windows-frost test` fetch Swift package dependencies from GitHub on every
run, and can the downloads be cached across disposable Frost overlays?

## Findings

- `scripts/windows-frost-test.sh` creates a new qcow2 overlay from the toolchain golden
  for each test run and deletes that overlay during cleanup.
- `scripts/windows-frost-sync-source.sh` replaces `C:\Users\tester\tessera` in the guest
  on each run, so package-local `.build` state from the previous run is not available.
- `scripts/run-windows-frost-tests.ps1` invokes `swift test --no-parallel` without a
  custom SwiftPM cache path, so the shared dependency cache lives inside the disposable
  guest state.
- `swift test --help` on Windows reports `--cache-path <cache-path>` and
  `--enable-dependency-cache` support. An explicit cache path lets the workflow control
  where SwiftPM stores fetched dependency repositories.

## Conclusion

Persist SwiftPM's shared dependency cache outside the disposable overlay by archiving a
guest cache directory back to the host after each run, restoring it into the next overlay
before `swift test`, and invoking SwiftPM with `--enable-dependency-cache --cache-path`.
This avoids repeated GitHub fetches while keeping build products inside the disposable
checkout.
