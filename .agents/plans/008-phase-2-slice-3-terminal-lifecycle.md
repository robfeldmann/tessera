---
name: Phase 2 Slice 3 Terminal Lifecycle
description:
  Add scoped terminal sessions, real POSIX platform I/O, lifecycle rollback, emergency
  cleanup, and reset tooling.
status: in-progress
created: 2026-06-07
updated: 2026-06-09
---

## Progress

- [x] **Phase 1 — API shape and test seams**
  - [x] 1.1 Add session/configuration/lifecycle public shape
  - [x] 1.2 Replace dependency-client I/O tests with owned-handle test seams
- [x] **Phase 2 — Mode lifecycle for raw mode and alternate screen**
  - [x] 2.1 Implement ordered all-or-nothing `ModeLifecycle.enter`
  - [x] 2.2 Implement over-cleaning `ModeLifecycle.exit`
  - [x] 2.3 Add rollback and virtual-terminal lifecycle tests
- [ ] **Phase 3 — Buffered output and POSIX handles**
  - [ ] 3.1 Introduce noncopyable `FileDescriptor` and `PlatformHandles`
  - [ ] 3.2 Implement buffered `PlatformIO.write`/`flush`
  - [ ] 3.3 Add buffered-write tests with syscall counting
- [ ] **Phase 4 — Async input and terminal size streams**
  - [ ] 4.1 Implement non-blocking input byte stream with `poll` and self-pipe
        cancellation
  - [ ] 4.2 Implement `size()` and SIGWINCH-driven `sizeChanges`
  - [ ] 4.3 Add focused unit tests for stream lifecycle and size queries
- [ ] **Phase 5 — Emergency cleanup and signal/exit hooks**
  - [ ] 5.1 Add signal-safe cleanup registry
  - [ ] 5.2 Install SIGINT/SIGTERM/SIGHUP/SIGQUIT handlers and `atexit`
  - [ ] 5.3 Document manual signal verification in `CONTRIBUTING.md`
- [ ] **Phase 6 — Scoped `TerminalSession` integration**
  - [ ] 6.1 Implement `TerminalSession.withApplicationTerminal(configuration:)`
  - [ ] 6.2 Route drawing and event reads through owned `PlatformIO`
  - [ ] 6.3 Rewrite walking skeleton callers/tests to use `TerminalSession`
- [ ] **Phase 7 — Recovery docs, demo, and validation**
  - [ ] 7.1 Document terminal recovery fallback
  - [ ] 7.2 Add a small runnable session demo in `Examples/`
  - [ ] 7.3 Run focused validation, markdown lint, and `just lint-changed`

## Review process

Use one draft GitHub PR for the slice, with phase-scoped commits rather than stacked PRs
unless the PR becomes too large to review comfortably. The agent implements one phase,
runs focused validation plus `just lint-changed`, updates this plan, pushes the phase
commits, and posts a PR comment summarizing files changed, validation, review focus, and
known follow-ups. The user reviews that phase on GitHub and discusses requested changes;
the agent addresses review comments in follow-up commits and resolves conversations once
fixed. The agent does not start the next phase until the user explicitly says to proceed.

## Overview

Phase 2 Slice 3 turns the Phase 1 terminal skeleton into a scoped, reliable live-terminal
runtime. The durable user API should be `TerminalSession.withApplicationTerminal`, with
arbitrary byte I/O kept out of public application code. Internally, `ModeLifecycle` owns
mode ordering and rollback, `PlatformIO` owns POSIX handles, buffering, input, and size
streams, and a narrowly-contained cleanup registry handles catastrophic exits. Work is
split so each phase pairs production changes with tests or explicit manual verification.

## Implementation strategy

Start by locking the API and test seams before replacing the current dependency-client
`PlatformIO`. Preserve the current exact byte mappings by routing mode bytes through
`ControlSequence` where possible, with nearby comments naming the control family and wire
form, e.g. DEC private mode 1049 `CSI ? 1049 h/l`. Implement the lifecycle before live
POSIX plumbing so rollback behavior can be reviewed independently with fakes. Put the
signal-safe global logic in one small file (preferably C or a Swift file whose signal
handler entry points are proven not to allocate) and treat it as the only global mutable
state in the slice.

## Durable API shape

Proposed public surface:

```swift
public struct TerminalApplicationConfiguration: Equatable, Sendable {
  public var modes: Set<ModeLifecycle.Mode>
  public static var `default`: Self { get }
}

public actor ModeLifecycle {
  public enum Mode: Hashable, Sendable {
    case rawMode
    case altScreen
    case mouseTracking
    case bracketedPaste
    case focusEvents
    case kittyKeyboard
  }

  // See unresolved decision #1 before implementing this initializer publicly.
  package init(io: PlatformIO)

  public func enter(_ modes: Set<Mode>) async throws
  public func exit() async throws
  public var activeModes: Set<Mode> { get async }
}

public actor TerminalSession {
  public static func withApplicationTerminal<R>(
    configuration: TerminalApplicationConfiguration,
    _ body: (isolated TerminalSession) async throws -> sending R
  ) async throws -> sending R

  public func draw<R>(
    _ body: (borrowing Frame) throws -> sending R
  ) async throws -> sending R

  public func nextEvent() async throws -> InputEvent
}
```

Proposed package/internal surface:

```swift
package actor PlatformIO {
  package init(handles: consuming PlatformHandles) throws
  package func write(_ bytes: [UInt8]) async throws
  package func write(_ bytes: ArraySlice<UInt8>) async throws
  package func flush() async throws
  package nonisolated var bytes: AsyncStream<UInt8> { get }
  package func size() async throws -> TerminalSize
  package var sizeChanges: AsyncStream<TerminalSize> { get }
  package func enableRawMode() async throws
  package func disableRawMode() async throws
  package func savedTermios() -> termios?
}
```

## Resolved design decisions

1. **`ModeLifecycle` visibility vs. `PlatformIO` visibility.** Resolved: keep `PlatformIO`
   package-only and make `ModeLifecycle` public for state inspection/control but with a
   package initializer; public users enter through
   `TerminalSession.withApplicationTerminal`.
2. **Signal-safe implementation language.** Resolved: use a tiny dependency-free C shim
   for signal primitives, but split graceful notifications from die-now restoration. For
   graceful paths such as SIGINT/SIGTERM/SIGWINCH, the C handler only `write(2)`s a byte
   to a self-pipe/signalfd-style wakeup and Swift performs cleanup in normal execution
   context. Reserve in-handler `tcsetattr`, teardown-byte `write(2)`,
   `signal(sig, SIG_DFL)`, and `raise(sig)` for fatal/die-now restoration where the
   process cannot get back to the Swift event loop before termination.
3. **Termios restoration order.** Resolved: structured mode lifecycle uses strict LIFO
   nesting for an N-mode acquisition stack, not hardcoded two-mode cleanup. Enter raw
   before alt so echo is off during screen transition; exit alt before raw so echo is not
   re-enabled while the alternate-screen leave sequence is in flight. Structured exit
   writes and flushes escape-sequence teardown before restoring termios, using `TCSADRAIN`
   or `TCSAFLUSH` rather than `TCSANOW` where appropriate. Emergency cleanup shares the
   same restore primitives where possible but fires a flat idempotent reset blob that is
   safe from half-initialized state.
4. **`TerminalSession.draw` frame type.** Resolved: implement minimal session drawing in
   this slice. `TerminalSession.draw` should use the existing full-repaint
   `Renderer.render(_:)` path and a small current/placeholder `Frame` sufficient for tests
   and the demo. Do not pull Slice 4 damage tracking or width-aware renderer work into
   this slice.

## Phase 1 — API shape and test seams

**Goal**: Make the reviewable API and fake I/O boundary explicit before changing runtime
behavior.

### Step 1.1 — Add session/configuration/lifecycle public shape

- Files: `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`,
  `Sources/TesseraTerminal/TerminalSession.swift`,
  `Sources/TesseraTerminalIO/ModeLifecycle.swift`, `Package.swift` if target dependencies
  need adjustment.
- Add the proposed types and method signatures with conservative placeholder behavior.
- Keep arbitrary byte writes off the public `TerminalSession` API.
- Acceptance: `swift test --filter TesseraTerminalIOTests` and
  `swift test --filter TesseraTerminal` build; public `TesseraTerminal` exports the
  session/configuration surface.

### Step 1.2 — Replace dependency-client I/O tests with owned-handle test seams

- Files: `Sources/TesseraTerminalIO/PlatformIO.swift`,
  `Sources/TesseraTerminalIO/TerminalDevice.swift`,
  `Sources/TesseraTerminalTestSupport/InMemoryTerminalDevice.swift`,
  `Tests/TesseraTerminalIOTests/PlatformIOTests.swift`.
- Migrate `PlatformIO` off the public `Dependencies`-backed `TerminalDevice` client and
  onto owned package-only terminal capabilities, while preserving deterministic fake
  syscall/handle seams for tests. This is about modeling live terminal ownership:
  noncopyable file descriptors, lifetime-bound cleanup, cancellation pipes/tasks, saved
  termios provenance, buffered writes, and the rule that only the session owns live
  terminal writes.
- Keep production and tests compiling during the transition; remove dependency-client API
  only after replacement seams exist.
- Acceptance: existing `PlatformIOTests` are either updated or marked by equivalent new
  tests; no public API lets users construct platform handles or write arbitrary live
  bytes.

## Phase 2 — Mode lifecycle for raw mode and alternate screen

**Goal**: Implement lifecycle semantics independently from live POSIX details.

### Step 2.1 — Implement ordered all-or-nothing `ModeLifecycle.enter`

- Files: `Sources/TesseraTerminalIO/ModeLifecycle.swift`,
  `Sources/TesseraTerminalIO/PlatformIOError.swift`.
- Enter modes by walking a canonical acquisition order and recording an acquisition stack;
  for this slice, `.rawMode` is acquired before `.altScreen`.
- Treat overlapping second `enter` calls as errors.
- Roll back already-entered modes by unwinding the acquisition stack in reverse if a later
  mode fails.
- Acceptance: focused `ModeLifecycle` tests cover success, unsupported modes, overlapping
  enter, and rollback on second-mode failure.

### Step 2.2 — Implement over-cleaning `ModeLifecycle.exit`

- Files: `Sources/TesseraTerminalIO/ModeLifecycle.swift`.
- Exit by unwinding the acquisition stack in reverse; for this slice, leave alt screen,
  flush, then restore raw mode with a draining/flushing termios restore where supported.
- Emit disable/leave calls for modes believed or requested active.
- Clear active state and cleanup registration even if one cleanup action throws, while
  still surfacing an error to structured callers.
- Acceptance: tests prove `exit` is idempotent, clears state, and attempts both cleanup
  operations when one fails.

### Step 2.3 — Add rollback and virtual-terminal lifecycle tests

- Files: `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`, `Package.swift` if
  `TesseraTerminalSnapshotSupport` test dependency is needed.
- Add direct scalar/API assertions for mode state and call order.
- Add a snapshot or structured virtual-terminal assertion for
  `enter([.rawMode, .altScreen])` followed by `exit()` using exact emitted bytes.
- Acceptance: `swift test --filter ModeLifecycleTests` passes.

## Phase 3 — Buffered output and POSIX handles

**Goal**: Replace immediate stdout writes with owned, buffered platform output.

### Step 3.1 — Introduce noncopyable `FileDescriptor` and `PlatformHandles`

- Files: `Sources/TesseraTerminalIO/FileDescriptor.swift`,
  `Sources/TesseraTerminalIO/PlatformHandles.swift`,
  `Sources/TesseraTerminalIO/PlatformIOError.swift`.
- Add `~Copyable` wrappers for stdin/stdout and a live constructor for standard handles on
  POSIX; Windows throws `.unsupportedPlatform` for this slice.
- Ensure descriptors are not accidentally copied or publicly constructible.
- Acceptance: `swift build --target TesseraTerminalIO` passes on POSIX.

### Step 3.2 — Implement buffered `PlatformIO.write`/`flush`

- Files: `Sources/TesseraTerminalIO/PlatformIO.swift`,
  `Sources/TesseraTerminalIO/POSIXSyscalls.swift` (or equivalent small wrapper).
- `write` appends to an internal buffer; `flush` performs retrying `write(2)` loops and
  clears only bytes actually written.
- Add source comments for concrete mode byte mappings emitted here, if any.
- Acceptance: repeated writes do not reach the underlying descriptor until `flush`.

### Step 3.3 — Add buffered-write tests with syscall counting

- Files: `Tests/TesseraTerminalIOTests/PlatformIOTests.swift`,
  `Sources/TesseraTerminalTestSupport/InMemoryTerminalDevice.swift` or new fake syscall
  support.
- Use a fake syscall/device layer to assert many writes + one flush produces one
  underlying write attempt when the OS accepts all bytes.
- Add partial-write and EINTR retry coverage with direct assertions.
- Acceptance: `swift test --filter PlatformIOTests` passes.

## Phase 4 — Async input and terminal size streams

**Goal**: Provide async-native input bytes and terminal-size notifications on POSIX.

### Step 4.1 — Implement non-blocking input byte stream with `poll` and self-pipe cancellation

- Files: `Sources/TesseraTerminalIO/PlatformIO.swift`,
  `Sources/TesseraTerminalIO/POSIXInputLoop.swift`,
  `Sources/TesseraTerminalIO/FileDescriptor.swift`.
- Set stdin non-blocking, poll stdin plus a cancellation pipe, read up to 256 bytes, yield
  individual bytes, finish on EOF, and handle EINTR/EAGAIN defensively.
- Restore file descriptor flags during shutdown when possible.
- Acceptance: tests cover yielded bytes, EOF finish, cancellation wake-up, and no busy
  loop under EAGAIN.

### Step 4.2 — Implement `size()` and SIGWINCH-driven `sizeChanges`

- Files: `Sources/TesseraTerminalIO/PlatformIO.swift`,
  `Sources/TesseraTerminalIO/TerminalResizeRegistry.swift` or C registry if shared with
  cleanup, `Sources/TesseraTerminalCore/TerminalGeometry.swift` if needed.
- Query `TIOCGWINSZ` for `TerminalSize` and expose `sizeChanges` as an `AsyncStream`.
- The SIGWINCH handler should only set an atomic flag or write to a self-pipe; querying
  size happens outside the handler.
- Acceptance: fake tests cover successful size query, unavailable size error, and a
  synthetic resize notification yielding a new size.

### Step 4.3 — Add focused unit tests for stream lifecycle and size queries

- Files: `Tests/TesseraTerminalIOTests/PlatformIOInputTests.swift`,
  `Tests/TesseraTerminalIOTests/PlatformIOSizeTests.swift`.
- Keep tests deterministic with fake descriptors/syscalls rather than real terminal state.
- Acceptance: `swift test --filter TesseraTerminalIOTests` passes.

## Phase 5 — Emergency cleanup and signal/exit hooks

**Goal**: Restore terminal state even when structured Swift cleanup is bypassed.

### Step 5.1 — Add signal-safe cleanup registry

- Files: `Sources/TesseraTerminalIO/CleanupRegistry.swift`, optional new C target such as
  `Sources/CTesseraTerminalPlatform/*`, `Package.swift`.
- Store precomputed idempotent teardown bytes and saved termios in a global atomic pointer
  installed by `ModeLifecycle.enter` and cleared by `exit`.
- Split handlers into graceful wakeup and die-now paths. Graceful handlers only `write(2)`
  a byte to a self-pipe/signalfd-style wakeup; Swift observes the pipe and performs
  structured cleanup. The die-now emergency path may load the pointer, `tcsetattr`, and
  `write(2)` precomputed teardown bytes before re-raising.
- Acceptance: unit tests can install/clear registry state and verify emitted cleanup bytes
  through a fake/safe test entry point; production handler code is isolated and
  documented.

### Step 5.2 — Install SIGINT/SIGTERM/SIGHUP/SIGQUIT handlers and `atexit`

- Files: `Sources/TesseraTerminalIO/CleanupRegistry.swift`, C platform files if added,
  `Sources/TesseraTerminalIO/ModeLifecycle.swift`.
- Install handlers once. Graceful handlers wake Swift through the pipe; fatal/die-now
  handlers restore, reset the default action, and re-raise.
- Register an `atexit` backstop that performs precomputed cleanup without re-raising.
- Acceptance: code review confirms only async-signal-safe operations in handlers; no
  automated subprocess signal test is added.

### Step 5.3 — Document manual signal verification in `CONTRIBUTING.md`

- Files: `CONTRIBUTING.md`.
- Add manual verification steps for `Ctrl-C`, external `SIGTERM`, `SIGHUP`/closed terminal
  where practical, and fallback `reset`/`stty sane` recovery.
- Include the exact fish commands developers should run.
- Acceptance: `pnpx markdownlint-cli CONTRIBUTING.md` passes.

## Phase 6 — Scoped `TerminalSession` integration

**Goal**: Make scoped setup/teardown the public way to run terminal applications.

### Step 6.1 — Implement `TerminalSession.withApplicationTerminal(configuration:)`

- Files: `Sources/TesseraTerminal/TerminalSession.swift`,
  `Sources/TesseraTerminal/TerminalApplicationConfiguration.swift`,
  `Sources/TesseraTerminalIO/PlatformIO.swift`,
  `Sources/TesseraTerminalIO/ModeLifecycle.swift`.
- Construct live handles, create `PlatformIO`, enter configured modes, await the body,
  then perform structured async cleanup before returning/rethrowing.
- Avoid `defer { Task { ... } }` as the primary guarantee.
- Acceptance: tests cover body return value, body error rethrow, and cleanup in both
  cases.

### Step 6.2 — Route drawing and event reads through owned `PlatformIO`

- Files: `Sources/TesseraTerminal/TerminalSession.swift`,
  `Sources/TesseraTerminalRendering/Renderer.swift`,
  `Sources/TesseraTerminalInput/InputParser.swift` as needed.
- `draw` uses the existing renderer/full-repaint behavior and a small current/placeholder
  `Frame` for now, writes to buffered `PlatformIO`, and flushes once per draw.
- `nextEvent` consumes raw bytes through the existing input parser or a minimal bridge if
  the parser is not ready for streaming.
- Acceptance: tests assert draw flushes once and public session code cannot write raw
  bytes directly.

### Step 6.3 — Rewrite walking skeleton callers/tests to use `TerminalSession`

- Files: existing Phase 1 skeleton source/tests as discovered during implementation,
  likely `Sources/TesseraTerminal/TesseraTerminal.swift`, examples, and IO tests.
- Remove direct public `PlatformIO.enterRawMode`/`enterAltScreen` usage from public-facing
  code.
- Acceptance: `swift test --filter TesseraTerminal` and affected target tests pass.

## Phase 7 — Recovery docs, demo, and validation

**Goal**: Document the manual fallback for unrecoverable exits and add a small proof that
the scoped API is usable.

### Step 7.1 — Document terminal recovery fallback

- Files: `README.md`, `CONTRIBUTING.md`.
- Do not add a Tessera-specific reset executable in this slice. The real safety net is the
  in-process emergency handler. For residual cases it cannot catch, such as `SIGKILL`, a
  hard hang, or terminal/emulator failure, document the system recovery commands.
- Tell users that if a Tessera app ever leaves the terminal wedged, they can type `reset`
  and press Enter, even if input is not echoing. Include `stty sane` as a secondary
  recovery command for contributors.
- Acceptance: recovery docs are clear; `pnpx markdownlint-cli README.md CONTRIBUTING.md`
  passes.

### Step 7.2 — Add `LifecycleModesDemo` in `Examples/`

- Files: `Examples/Package.swift`, `Examples/Sources/LifecycleModesDemo/main.swift`.
- Use public `TesseraTerminal`/`Tessera` products and
  `TerminalSession.withApplicationTerminal`.
- Demonstrate three phases:
  1. Cooked primary screen before Tessera: print a short message with normal stdout and
     wait for Enter.
  2. Raw + alternate-screen Tessera session: draw a tiny screen explaining that keystrokes
     are handled immediately, show current terminal size, show the last key/event if
     practical, redraw on resize via `sizeChanges`, and exit on `q`.
  3. Restored primary screen after Tessera: print a short message confirming the primary
     screen is back and typing should echo normally.
- Keep it focused on lifecycle modes, resize, input, and scoped cleanup. Do not preview
  Slice 4 damage tracking, widgets, layout, or width-aware rendering.
- Acceptance: `cd Examples && swift build --target LifecycleModesDemo` passes; manual run
  visibly demonstrates alt-screen restoration, immediate raw-mode key handling, and
  responsive size updates.

### Step 7.3 — Run focused validation, markdown lint, and `just lint-changed`

- Files: no production files unless validation finds issues.
- Run narrow tests first, then broader affected tests:
  - `swift test --filter ModeLifecycleTests`
  - `swift test --filter PlatformIOTests`
  - `swift test --filter TesseraTerminalIOTests`
  - `swift test --filter TesseraTerminal`
  - `cd Examples && swift build --target LifecycleModesDemo`
  - `pnpx markdownlint-cli CONTRIBUTING.md .agents/plans/008-phase-2-slice-3-terminal-lifecycle.md`
  - `just lint-changed`
- Acceptance: all validation commands pass or any failures are documented with follow-up
  plan edits before review.

## References

- `docs/Spec.md`, Phase 2 Slice 3, starting at line 1509.
- Ratatui `ratatui/src/init.rs`: `run`, `try_init`, `try_restore`, and panic hook show
  scoped setup/restoration ordering and failure behavior.
- Ratatui `ratatui-core/src/backend.rs`: backend output, flush, size, and window-size
  contracts.
- Ratatui crossterm backend `ratatui-crossterm/src/lib.rs`: writer-backed backend and
  explicit flush behavior.
- Crossterm `src/terminal.rs`: raw mode APIs and alternate screen DEC private mode 1049
  encoding.
