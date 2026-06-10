---
name: Risk-Driven Test Coverage
description:
  Improve coverage for terminal lifecycle, live POSIX I/O, ANSI encoding, and
  cancellation-sensitive code.
status: pending
created: 2026-06-10
updated: 2026-06-10
---

## Progress

- [ ] **Phase 1 — Coverage baseline and reporting**
  - [ ] 1.1 Add a repeatable coverage summary command
  - [ ] 1.2 Document the current baseline and target scope
- [ ] **Phase 2 — Pure Swift low-risk coverage gaps**
  - [ ] 2.1 Complete `AsyncEventBuffer` edge coverage
  - [ ] 2.2 Complete `TerminalSession` edge coverage
  - [ ] 2.3 Add direct `Frame` coverage
  - [ ] 2.4 Cover trivial handle wrappers
- [ ] **Phase 3 — ANSI encoder exhaustiveness**
  - [ ] 3.1 Add exhaustive `ControlSequence` byte tests
  - [ ] 3.2 Add append/composition and escaping regression tests
- [ ] **Phase 4 — Platform I/O fault coverage**
  - [ ] 4.1 Add deterministic POSIX syscall test seams
  - [ ] 4.2 Cover `POSIXSyscalls` errno mapping and writable polling
  - [ ] 4.3 Cover `PlatformIO.flush` failure retention paths
  - [ ] 4.4 Cover additional `POSIXInputLoop` lifecycle/error paths
- [ ] **Phase 5 — Live terminal and resize coverage**
  - [ ] 5.1 Add PTY-backed live terminal test support
  - [ ] 5.2 Cover `TerminalDevice.live(handles:)` raw/alt/size/write behavior
  - [ ] 5.3 Refactor and cover resize stream notifications deterministically
  - [ ] 5.4 Cover cleanup registry saved-termios path
- [ ] **Phase 6 — Final validation and coverage closeout**
  - [ ] 6.1 Run full tests, examples build, lint, and coverage report
  - [ ] 6.2 Record final gaps and intentional exclusions

## Overview

The current production-source coverage is about 65% line coverage, with the largest gaps
in `TesseraTerminalIO`: live terminal integration, SIGWINCH resize handling, POSIX syscall
wrappers, and edge paths around cancellation and failure. This plan improves coverage in
risk order: first pure deterministic tests, then ANSI exhaustiveness, then focused seams
for POSIX failure modes, then PTY-backed live terminal tests. The goal is not to chase
unhelpful coverage for fatal-process behavior, but to automate the paths most likely to
break terminal restoration, input delivery, output flushing, and ANSI wire compatibility.

Baseline from `swift test --enable-code-coverage` on 2026-06-10:

| Scope                   | Line coverage | Function coverage | Region coverage |
| ----------------------- | ------------: | ----------------: | --------------: |
| All project `Sources/`  |        75.68% |            75.70% |          74.97% |
| Production sources only |        65.26% |            65.64% |          70.14% |

Target after this plan: production-source line coverage at or above 85% if practical, with
`TesseraTerminalIO` above 75% and every remaining 0%-covered production file either
covered or explicitly documented as intentionally excluded.

## Phase 1 — Coverage baseline and reporting

**Goal**: Make coverage measurement repeatable and scoped to project production code so
future work can compare like-for-like numbers.

### Step 1.1 — Add a repeatable coverage summary command

- Files: `Justfile` or `scripts/coverage-summary.py` / `scripts/coverage-summary.sh`.
- Add a command that runs or consumes SwiftPM coverage JSON and prints project-only
  totals, excluding `.build/checkouts`, generated test runners, test targets, snapshot
  support, and test support when requested.
- Report at least line/function/region coverage and per-module line coverage.
- Acceptance: `swift test --enable-code-coverage` passes and the new coverage command
  reproduces the current production-source baseline within rounding error.

### Step 1.2 — Document the current baseline and target scope

- Files: `.agents/investigations/` or a short docs note if preferred.
- Record the 2026-06-10 baseline, exclusions, commands used, and target thresholds.
- Include the highest-risk uncovered files: `TerminalDevice+Live.swift`,
  `TerminalResizeRegistry.swift`, `POSIXSyscalls.swift`, `PlatformHandles.swift`, and
  `FileDescriptor.swift`.
- Acceptance: Markdown lint passes for the new/updated note.

## Phase 2 — Pure Swift low-risk coverage gaps

**Goal**: Raise coverage quickly in deterministic code and harden cancellation-sensitive
session behavior before touching POSIX seams.

### Step 2.1 — Complete `AsyncEventBuffer` edge coverage

- Files: `Tests/TesseraTerminalTests/TerminalSessionTests.swift` or new
  `Tests/TesseraTerminalTests/AsyncEventBufferTests.swift`.
- Add tests for FIFO delivery to multiple waiters, buffered values before waiters,
  `finish()` waking waiters with `nil`, idempotent `finish()`, `yield` after finish being
  ignored, `next()` after finish returning `nil`, and cancellation before the waiter is
  appended.
- Acceptance: `swift test --filter AsyncEventBuffer` or the relevant terminal-session
  filter passes.

### Step 2.2 — Complete `TerminalSession` edge coverage

- Files: `Tests/TesseraTerminalTests/TerminalSessionTests.swift`,
  `Sources/TesseraTerminalTestSupport/InMemoryTerminalDevice.swift` if extra seams are
  needed.
- Add tests for `nextEvent()` throwing `PlatformIOError.inputClosed` when input finishes
  without an event, ignored control bytes followed by input close, draw error propagation
  from `size()`, draw error propagation from `flush()`, and cleanup behavior when
  lifecycle exit fails after a successful body if a deterministic failing device seam is
  available.
- Acceptance: `swift test --filter TerminalSessionTests` passes.

### Step 2.3 — Add direct `Frame` coverage

- Files: `Tests/TesseraTerminalTests/FrameTests.swift` or existing terminal tests.
- Add direct assertions for `Frame.size` and styled writes reaching the backing buffer.
- Prefer direct scalar/API assertions; do not snapshot trivial scalar behavior.
- Acceptance: `swift test --filter FrameTests` or relevant filter passes.

### Step 2.4 — Cover trivial handle wrappers

- Files: `Tests/TesseraTerminalIOTests/PlatformHandlesTests.swift`.
- Add package-internal tests for `FileDescriptor(rawValue:)`, consuming
  `PlatformHandles.init(stdin:stdout:)`, and `PlatformHandles.standard()` returning the
  expected standard descriptor raw values on POSIX.
- Keep these tests small; their value is preventing accidental API/regression changes in
  noncopyable wrappers.
- Acceptance: `swift test --filter PlatformHandlesTests` passes.

## Phase 3 — ANSI encoder exhaustiveness

**Goal**: Make ANSI/VT wire compatibility exhaustive enough that future refactors cannot
silently alter emitted bytes.

### Step 3.1 — Add exhaustive `ControlSequence` byte tests

- Files: `Tests/TesseraTerminalANSITests/ANSIEncoderTests.swift` or new
  `Tests/TesseraTerminalANSITests/ControlSequenceTests.swift`.
- Add parameterized tests covering every `ControlSequence` case, including positive and
  negative/zero movement counts if current API allows them, all boolean toggles, all erase
  modes, all SGR attributes, standard/bright/indexed/RGB colors, raw payloads, text, OSC
  window titles, synchronized output, alternate screen, cursor save/restore, and cursor
  positioning's zero-based to one-based conversion.
- Use direct byte/string assertions for small cases and snapshots only for larger grouped
  tables.
- Acceptance: `swift test --filter TesseraTerminalANSITests` passes and
  `ControlSequence.swift` coverage is no longer a major production gap.

### Step 3.2 — Add append/composition and escaping regression tests

- Files: `Tests/TesseraTerminalANSITests/ControlSequenceTests.swift`.
- Test `encode(into:)` appends without clearing existing bytes, multiple sequences compose
  in order, UTF-8 text is preserved, and OSC title encoding has the current documented
  terminator behavior.
- Add any missing tests for `ANSIByteEncoding` helper boundaries discovered while writing
  exhaustive cases.
- Acceptance: `swift test --filter TesseraTerminalANSITests` passes.

## Phase 4 — Platform I/O fault coverage

**Goal**: Cover POSIX and platform-I/O error paths deterministically without relying on
rare OS timing or real terminal state.

### Step 4.1 — Add deterministic POSIX syscall test seams

- Files: `Sources/TesseraTerminalIO/POSIXSyscalls.swift`,
  `Tests/TesseraTerminalIOTests/POSIXSyscallsTests.swift`.
- Introduce the narrowest package-internal seam needed to inject `write` and `poll`
  behavior in tests. Keep live defaults as direct Darwin/Glibc calls.
- Avoid broad dependency frameworks; a small package-internal struct of `@Sendable`
  closures or helper functions is sufficient.
- Acceptance: existing `swift test --filter TesseraTerminalIOTests` passes with no
  behavior changes.

### Step 4.2 — Cover `POSIXSyscalls` errno mapping and writable polling

- Files: `Tests/TesseraTerminalIOTests/POSIXSyscallsTests.swift`.
- Add tests for successful write, empty write returning zero, `EINTR` ->
  `.writeInterrupted`, `EAGAIN`/`EWOULDBLOCK` -> `.writeWouldBlock`, other errno ->
  `.writeFailed`, `waitUntilWritable` success, `poll` interruption, and `poll` failure.
- Acceptance: `swift test --filter POSIXSyscallsTests` passes.

### Step 4.3 — Cover `PlatformIO.flush` failure retention paths

- Files: `Tests/TesseraTerminalIOTests/PlatformIOTests.swift`.
- Add tests for underlying write returning zero, failure before any bytes are written,
  failure after a partial write removing only flushed bytes, and retry after
  `.writeWouldBlock` / `.writeInterrupted` without losing buffered data.
- Acceptance: `swift test --filter PlatformIOTests` passes.

### Step 4.4 — Cover additional `POSIXInputLoop` lifecycle/error paths

- Files: `Sources/TesseraTerminalIO/POSIXInputLoop.swift`,
  `Tests/TesseraTerminalIOTests/PlatformIOInputTests.swift`.
- If needed, add a narrow package-internal seam for pipe/poll/read/write/close/fcntl so
  tests can deterministically drive setup failure, poll timeout, poll `EINTR`, poll fatal
  error, cancellation-pipe wakeup, read `EINTR`, read `EAGAIN`, read fatal error, and flag
  restoration on termination.
- Keep existing pipe-based integration tests for the happy path and EOF.
- Acceptance: `swift test --filter PlatformIOInputTests` passes and no test relies on
  sleeps or real keyboard input.

## Phase 5 — Live terminal and resize coverage

**Goal**: Cover the live terminal paths that currently sit at 0% while keeping tests safe
for developer machines and CI.

### Step 5.1 — Add PTY-backed live terminal test support

- Files: `Sources/TesseraTerminalTestSupport/` or
  `Tests/TesseraTerminalIOTests/PTYTestSupport.swift`.
- Add a POSIX-only helper around `openpty`/`close` that creates master/slave descriptors,
  supports reading bytes from the master, setting terminal window size, and safely closing
  all descriptors.
- Prefer local test support if the helper is only useful for IO tests.
- Acceptance: a small helper self-test or first live-terminal test passes on macOS.

### Step 5.2 — Cover `TerminalDevice.live(handles:)` raw/alt/size/write behavior

- Files: `Tests/TesseraTerminalIOTests/TerminalDeviceLiveTests.swift`, optionally
  `Sources/TesseraTerminalIO/TerminalDevice+Live.swift` only if a minor seam is necessary.
- Using the PTY helper, test entering/exiting alternate screen emits exact DEC private
  mode 1049 bytes, raw mode disables canonical/echo and restores original termios, size
  reads the configured PTY winsize, and write writes bytes to the PTY master side.
- Add a focused test for unsupported or invalid descriptors if deterministic.
- Acceptance: `swift test --filter TerminalDeviceLiveTests` passes on POSIX and skips or
  compiles out cleanly elsewhere.

### Step 5.3 — Refactor and cover resize stream notifications deterministically

- Files: `Sources/TesseraTerminalIO/TerminalResizeRegistry.swift`,
  `Tests/TesseraTerminalIOTests/PlatformIOSizeTests.swift` or new
  `TerminalResizeRegistryTests.swift`.
- Refactor the registry so tests can trigger resize notifications without sending real
  process-wide signals. Keep the live implementation backed by `DispatchSource` for
  `SIGWINCH`.
- Cover successful yields, ignored size-query failures followed by later success, stream
  termination canceling the source, and no repeated creation/cancellation of the same
  producer in test helper code.
- Acceptance: `swift test --filter TerminalResizeRegistryTests` and
  `swift test --filter PlatformIOSizeTests` pass.

### Step 5.4 — Cover cleanup registry saved-termios path

- Files: `Tests/TesseraTerminalIOTests/CleanupRegistryTests.swift`.
- Add tests that install cleanup with non-`nil` saved termios and verify the C shim stores
  enough observable state to prove the saved-termios branch was used. If the C shim does
  not expose this safely, add a package-internal test-only query function in
  `CTesseraTerminalPlatform`.
- Do not attempt to automate true fatal signal delivery beyond existing safe testing
  hooks.
- Acceptance: `swift test --filter CleanupRegistryTests` passes.

## Phase 6 — Final validation and coverage closeout

**Goal**: Prove the added tests are stable, document remaining intentional gaps, and leave
clear follow-up guidance.

### Step 6.1 — Run full tests, examples build, lint, and coverage report

- Commands:
  - `swift test --enable-code-coverage`
  - `swift build --package-path Examples`
  - `just lint-changed`
  - coverage summary command from Phase 1
- If Markdown changed, also run `pnpx markdownlint-cli <path>`.
- Acceptance: all commands pass and the coverage summary shows improvement over the
  baseline.

### Step 6.2 — Record final gaps and intentional exclusions

- Files: `.agents/investigations/` or the baseline note from Phase 1.
- Record final production coverage, per-module coverage, files still below target, and why
  any remaining low-coverage paths are intentionally untested or require manual
  verification.
- Include recommended next steps only for gaps that are still materially risky.
- Acceptance: final note is lint-clean and this plan can be marked completed.

## References

- `.agents/plans/008-phase-2-slice-3-terminal-lifecycle.md`
- `.agents/investigations/004-lifecycle-demo-event-cancellation.md`
- Current coverage command: `swift test --enable-code-coverage`
- Coverage JSON path command: `swift test --show-codecov-path`
