---
name: Terminal I/O concurrency review fixes
description:
  Fix the concurrency and isolation findings from a review of TesseraTerminal and
  TesseraTerminalIO: cancellation-safe teardown, serialized terminal output, blocking
  I/O off the cooperative pool, session and stream lifetimes, vouch cleanup, and
  deterministic terminal tests. Also the bug punchlist from the 2026-10-17 and 2026-10-20
  repository review notes: nested view lists in layout containers, the parallel suite,
  error-type conformances, and CI coverage of the Examples package.
status: in-progress
created: 2026-10-21
updated: 2026-10-22
---

<!-- Allowed status values: planning, in-review, pending, in-progress, complete, superseded. -->

## Progress

- [ ] **Phase 1 — Baseline and test seams**
  - [x] 1.1 Record a baseline build and test run at HEAD (satisfied by plan 035 Step 1.1
        and Phase 2; see the step)
  - [x] 1.2 Add package-internal waiter observables for the gates and the buffer
        (`3fb25e9`)
- [ ] **Phase 2 — Cancellation-safe teardown**
  - [ ] 2.1 Regression tests for cancelled and returning bodies
  - [ ] 2.2 Run lifecycle teardown in an uncancelled task
- [ ] **Phase 3 — Serialized terminal output**
  - [ ] 3.1 Regression tests for overlapping flushes and discards
  - [ ] 3.2 Make `PlatformIO.flush` a single drain owner
  - [ ] 3.3 Serialize `draw` with its own gate
- [ ] **Phase 4 — Closed session lifecycle**
  - [ ] 4.1 Use after teardown throws (decided 2026-10-21)
  - [ ] 4.2 Close `ModeLifecycle` after a successful exit
  - [ ] 4.3 Close `TerminalSession` after its scoped teardown
- [ ] **Phase 5 — Blocking I/O off the cooperative pool**
  - [ ] 5.1 Move the POSIX input read off the actor onto a dedicated thread
  - [ ] 5.2 Bound the POSIX write wait by slices that check cancellation
  - [ ] 5.3 Move the Windows input wait off the cooperative pool (unverified platform)
- [ ] **Phase 6 — Stream, observer, and descriptor lifetimes**
  - [ ] 6.1 Stop leaking cancelled waiter IDs in `AsyncEventBuffer`
  - [ ] 6.2 Guard the POSIX cancel descriptor against the actor's close
  - [ ] 6.3 Finish the input pump when the session is gone (skipped: Step 6.4 replaces it)
  - [ ] 6.4 Start the input pump after construction (decided 2026-10-21)
  - [ ] 6.5 Buffering policy for input and size streams (decided 2026-10-21)
  - [ ] 6.6 Create one size subscription and fan it out
  - [ ] 6.7 Fix the Windows input-loop restart race (unverified platform)
- [ ] **Phase 7 — Active probe retry policy**
  - [ ] 7.1 Probe retry policy (decided 2026-10-21)
  - [ ] 7.2 Retry after cancellation or emit failure
- [ ] **Phase 8 — Vouches, invariants, and process globals**
  - [ ] 8.1 Remove the two unneeded `@unchecked Sendable` attributes
  - [ ] 8.2 Document the `ResizeSignalSource` invariant and the SIGWINCH disposition
  - [ ] 8.3 Replace or justify the test-helper vouches
  - [ ] 8.4 Descriptor ownership: borrowed standard descriptors (decided 2026-10-21)
  - [ ] 8.5 Stop freeing retired cleanup states in the C shim (unverified)
- [ ] **Phase 9 — Deterministic terminal tests**
  - [ ] 9.1 Order the queued-setter test on an observable
  - [ ] 9.2 Replace waiter-count spins with a bounded waiting helper
  - [ ] 9.3 Order the lifecycle-serialization tests on the gate
  - [ ] 9.4 Remove the bounded yield loops in the input and resize tests
  - [ ] 9.5 Remove the real 60-second sleep from the probe test
  - [ ] 9.6 Narrow `.serialized` to suites that reach a process global
  - [ ] 9.7 Order the remaining yield-before-cancel tests on observables
  - [ ] 9.8 Exercise the suite in parallel, or drop the promise (decided 2026-10-21)
- [ ] **Phase 10 — Repository review punchlist**
  - [ ] 10.1 Flatten nested view lists into layout containers
  - [ ] 10.2 Give `VirtualTerminalError` the standard error conformances
  - [ ] 10.3 Build the Examples package in CI

## Overview

A concurrency and isolation review of `Sources/TesseraTerminal`,
`Sources/TesseraTerminalIO`, and their tests, run on 2026-10-20 at the current HEAD, found
that the actor design is mostly sound but has real defects. A cancelled session skips
terminal teardown, so raw mode and the alternate screen can stay set while the process
keeps running. Overlapping `flush` calls can send bytes twice and a discard can trap,
`draw` can diff against a stale frame, and blocking `poll` and `write` waits hold a thread
with no cancellation path. The phases below fix the correctness defects first, each behind
a test that fails before the change, then move on to the blocking-I/O redesign, the
lifetime and probe-policy decisions that need owner sign-off, vouch cleanup, and test
determinism. Neither review built or ran the package, so Step 1.1 records the baseline
before anything changes, and every Windows and C-shim step stays unverified until it has
been built or stressed on its platform. The repository's baseline toolchain is Swift 6.3.3
(`.swift-version`, Xcode 26.6) with `swift-tools-version: 6.3`, and Swift 6.4 (Xcode 27.1)
is a second supported lane (plan 035 Phase 2); the compiler checks in the review used
Swift 6.4, so each compiler-dependent step must be rechecked on the baseline toolchain.

Phase 10, Steps 9.7 and 9.8, and additions to Steps 3.2 and 8.3 come from two repository
review notes (2026-10-17 and 2026-10-20), re-checked against `28c34b8` on 2026-10-21; see
[Repository review findings](#repository-review-findings). Plan 035
(`.agents/plans/035-toolchain-conventions-and-plan-consolidation.md`) runs this plan as
its Phase 4, after its full local baseline (Step 1.1) and the Swift 6.4 and Xcode 27
toolchain update (Phase 2).

## Phase 1 — Baseline and test seams

**Goal**: a recorded baseline and the package-internal observables that the later
regression tests need, with no behavior change.

### Step 1.1 — Record a baseline build and test run at HEAD

- File: none (commands only).
- Run `swift build`, then `swift test --filter TesseraTerminalIOTests` and
  `swift test --filter TesseraTerminalTests`, on the baseline toolchain (`.swift-version`,
  6.3.3; Xcode 26.6 on macOS) and on the Swift 6.4 lane (Xcode 27.1). The package needs
  remote dependencies and a prebuilt `CGhosttyVT` library, so the first run may need setup
  beyond the repo defaults.
- Record which tests already fail, so later failures can be attributed.
- When this plan runs inside plan 035, Step 1.1 of plan 035 has already recorded the full
  check matrix, and its Phase 2 has set the toolchain lanes. Then run the two filters
  above on every lane Phase 2 kept, and replace "pinned toolchain" in the steps below with
  "each supported lane".
- Acceptance: both commands complete, and any pre-existing failure is written into this
  step before Phase 2 starts.

#### Done (2026-10-22)

- Satisfied by plan 035 Step 1.1 and Phase 2. The full suite (which contains both filters)
  passes on every lane at plan 035 commit `e314658`: Xcode 26.6 (634 tests), Xcode 27.1
  (634), Lima Swift 6.3.3 and 6.4.1 (627 each), and the Windows guest on Swift 6.3.3 (629,
  Ghostty-backed). No pre-existing test failure; the one pre-existing failure in the wider
  matrix was a DocC link, fixed in plan 035 Step 2.2.

### Step 1.2 — Add package-internal waiter observables

- Files: `Sources/TesseraTerminalIO/ModeLifecycle.swift` (`ModeLifecycleTransitionGate`,
  lines 4-56); `Sources/TesseraTerminal/TerminalSession.swift` (`modeTransitionGate`, line
  117); `Sources/TesseraTerminal/AsyncEventBuffer.swift` (already has `waiterCount`, lines
  20-22).
- Add `package var waiterCount: Int` to `ModeLifecycleTransitionGate`, matching the
  existing `AsyncEventBuffer.waiterCount`. Add a `package` accessor on `TerminalSession`
  that reads the waiter count of `modeTransitionGate`, for tests that must observe a
  queued setter.
- Acceptance: `swift build` passes; the existing tests are unchanged and green.

#### Done (2026-10-22)

- Commit `3fb25e9` on `plan-035`: `ModeLifecycleTransitionGate.waiterCount`,
  `ModeLifecycle.queuedTransitionCount` (async get, for the lifecycle's own gate), and
  `TerminalSession.queuedModeSetterCount` (async get, for the session's gate), all
  `package`. `swift build` clean; the full suite (634 tests) unchanged and green on Xcode
  26.6.

## Phase 2 — Cancellation-safe teardown

**Goal**: the terminal is restored when the body is cancelled, with no public API change.

### Step 2.1 — Regression tests for cancelled and returning bodies

- File: `Tests/TesseraTerminalTests/TerminalSessionTests.swift`, beside the failure-path
  tests at lines 983-1020, using the `LifecycleFailureTerminalDevice` actor (line 2802)
  and its recorded events.
- Test A: the body suspends on a gate, the test cancels the task that runs
  `withApplicationTerminal`, and the body then throws `CancellationError`. Expect the
  device events to include `.exitRawMode` and `.exitAltScreen`.
- Test B: the body calls `withUnsafeCurrentTask { $0?.cancel() }` and then returns
  normally. The success path at line 404 then calls `lifecycle.exit()` in a cancelled
  task. Expect the same teardown events.
- Name the tests as sentences in backticks, per repo convention.
- Acceptance: both tests fail on the current HEAD (no `.exitRawMode` and `.exitAltScreen`
  recorded) and pass after Step 2.2.

#### Done (2026-10-22)

- Commit `c60ab94`. Tests `cancelled body still exits raw mode and the alternate screen`
  and `body that returns after its task is cancelled still exits terminal modes` in
  `TerminalSessionTests.swift`. Fails-before: test A recorded no
  `.exitAltScreen`/`.exitRawMode`; test B failed with `Caught error: CancellationError()`.

### Step 2.2 — Run lifecycle teardown in an uncancelled task

- File: `Sources/TesseraTerminal/TerminalSession.swift`, the success exit at line 404 and
  the `catch` at lines 406-416.
- Add one private helper, for example `runUncancellableTeardown(_:)`, and use it for
  `restoreCursorVisibility()` and `lifecycle.exit()` on both paths. The portable form is
  `try await Task { try await operation() }.value`. Unstructured tasks do not inherit the
  parent's cancellation, and `.value` rethrows, so the success path still propagates an
  exit error, and the `catch` path keeps the body error primary.
- `withTaskCancellationShield` (SE-0504) is the idiomatic form, but the package floor is
  macOS 26 (`Package.swift:13`), and the reviewer's compile against the macOS 27 SDK
  reports that the shield is unavailable below macOS 27. If the shield is adopted, put it
  behind `#available(macOS 27, *)` inside this helper only. Keep the platform branch in
  that one helper, per the repo rule to confine platform divergence to leaf seams.
- Cost/risk: teardown can no longer be cancelled. It is still bounded by the device
  writes, which Phase 5 addresses.
- Acceptance: the tests from Step 2.1 pass; `swift test --filter TerminalSessionTests` is
  green, including the failure-path tests at lines 983-1020.

#### Done (2026-10-22)

- Commit `c60ab94`. `runUncancellableTeardown`
  (`try await Task { try await operation() }.value`) wraps `restoreCursorVisibility()` and
  `lifecycle.exit()` on both exit paths; the body error stays primary on the catch path.
  No `withTaskCancellationShield` (macOS 26 floor). The 2.1 tests and the four
  failure-path tests pass; `swift test --filter TerminalSessionTests` green.

## Phase 3 — Serialized terminal output

**Goal**: each byte is sent once and in order, and overlapping frames diff against the
frame actually on screen.

### Step 3.1 — Regression tests for overlapping flushes and discards

- File: `Tests/TesseraTerminalIOTests/PlatformIOTests.swift`, following the
  `CountingOutputWriter` pattern of the flush tests (lines 52-316). Add a device double
  whose write suspends on a gate and records every chunk it receives.
- Test A: flush 1 suspends mid-write; the test appends `B` with `write` and starts flush
  2; then it releases the gate. Expect each byte written exactly once, in order.
- Test B: a discard issued while a write is suspended, followed by a write that throws
  after an earlier partial write. A trap ends the test process, so run this test alone on
  the current HEAD and expect a crash. After the fix, keep the surviving assertion: no
  trap, and the unwritten bytes are retained.
- Test C: bytes appended during a suspended drain are sent exactly once, after the
  remainder.
- Acceptance: A and C fail on the current HEAD (duplicated bytes); B traps on the current
  HEAD when run alone.

#### Done (2026-10-22)

- Commit `e8054a8`. `GatedOutputWriter` (suspends one write on a gate, records chunks and
  accepted bytes) in `PlatformIOTests.swift`; tests A
  `overlapping flushes write each byte once in order`, B
  `discard during a suspended write keeps later bytes after the write fails`, C
  `bytes appended during a suspended drain follow its remainder once`. Fails-before: A and
  C showed duplicated bytes (A: extra `[1][0]: 65` in writes; C: extra `[4]: 65`
  accepted); B run alone exited with signal 5,
  `Swift/RangeReplaceableCollection.swift:596: Fatal error: Can't remove more items from a collection than it has`.

### Step 3.2 — Make `PlatformIO.flush` a single drain owner

- File: `Sources/TesseraTerminalIO/PlatformIO.swift`, `discardBufferedOutput` (lines
  104-106) and `flush` (lines 109-138).
- Change: (a) serialize drains, so a second `flush` waits for the first to finish and then
  drains whatever was appended; (b) keep the drained bytes addressable by offset, or swap
  them out only while no drain is running; (c) a discard increments a generation, and a
  drain that sees a changed generation stops without calling `removeFirst(offset)`; (d) on
  a write failure, unwritten bytes stay at the front of the buffer.
- Caveat (reading): the swap-based sketch in one report prevents duplication but is not
  safe alone. While the first drain is suspended, a second `flush` that swaps the buffer
  out can send bytes appended later before the first drain's remainder, which reorders
  output. Step (a) is required with any swap.
- (e) The `writeWouldBlock` catch at lines 119-122, whose `Task.yield()` spins: the live
  POSIX device never surfaces that error, because `TerminalDevice+Live.swift:191-192`
  catches it and waits in `waitUntilWritable` (bounded by Step 5.2), so only test doubles
  reach the yield. Decision (owner, 2026-10-21): delete the catch, and state in the
  `TerminalDevice` doc comment that `write` either blocks until it makes progress or
  throws. Two existing tests feed `writeWouldBlock` through `CountingOutputWriter` and
  expect a retry: `flush retries temporarily unavailable writes without dropping bytes`
  (`Tests/TesseraTerminalIOTests/PlatformIOTests.swift:91-102`) and
  `flush retries after transient write errors` (`:316-335`). Rewrite the first to assert
  that `flush` throws `writeWouldBlock` and keeps the unwritten bytes, and drop the
  `writeWouldBlock` case from the second, keeping its other transient errors.
- Cost/risk: a second `flush` waits for the first. Public callers are unchanged. A discard
  cannot recall bytes the terminal has already accepted; it only prevents re-sending them.
- Acceptance: Steps 3.1 A, B, and C pass; `swift test --filter PlatformIOTests` is green,
  including `flush preserves unwritten buffered bytes after errors` (line 236) and
  `flush removes only bytes written before a later failure` (line 272).

#### Done (2026-10-22)

- Commit `e8054a8`. One drain at a time: a second `flush` waits in a first-come queue on
  the actor (`package var queuedFlushCount` is the test seam; the wait is not cancellable
  because the write it waits on is not). A discard bumps a generation; a drain that sees
  it changed stops without trimming. Unwritten bytes stay at the front after a failure.
  (e) done: the `writeWouldBlock` catch is deleted, `TerminalDevice.write`'s doc comment
  says a write blocks until it makes progress or throws,
  `flush retries temporarily unavailable writes without dropping bytes` became
  `flush throws temporarily unavailable writes without dropping bytes`, and
  `flush retries after transient write errors` no longer feeds `writeWouldBlock`. The two
  named existing tests stay green; `swift test --filter TesseraTerminalIOTests` green 25
  runs in a row.

### Step 3.3 — Serialize `draw` with a dedicated gate

- File: `Sources/TesseraTerminal/TerminalSession.swift`: a new gate beside
  `modeTransitionGate` (line 117), and `draw` (lines 593-650).
- Change: hold the gate from `io.size()` (line 596) through `io.flush()` (line 641), and
  keep `lastDrawnBuffer = buffer` after the flush, as it is now.
- Use a separate instance, not `modeTransitionGate`. One report proposed sharing the gate;
  this step does not, because a long mode transition would then stall drawing, and draws
  would stall mode changes. The gate type is named for mode lifecycles, so either reuse it
  under a neutral name or add a small general gate.
- Rejected alternative: commit `lastDrawnBuffer` before `await io.write(bytes)`. The
  review marks it unsafe on its own, because two writes may not reach the output buffer in
  encode order (not tested).
- Cost/risk: concurrent draws queue, which is expected for one terminal stream.
- Acceptance: a new test beside `draw writes rendered frame and flushes once` (line 1315).
  The first draw is suspended mid-flush, and the second draw clears a cell that the first
  drew. Expected bytes equal a sequential run of the same two frames. The test fails on
  the current HEAD, where the second frame diffs against the old base. The draw tests at
  lines 1315, 2286, and 2325 stay green.

#### Done (2026-10-22)

- Commit `c60ab94`. A dedicated `drawGate` (a second `ModeLifecycleTransitionGate`
  instance; `package var queuedDrawCount` is the seam) is held from `io.size()` through
  `io.flush()`; `lastDrawnBuffer` is set after the flush. Test
  `overlapping draws diff against the frame the terminal received`. Fails-before (gate
  bypassed): the wait for a queued draw timed out and the output re-sent `A` instead of
  erasing it (`…\e[1;1HA\e[0m\e[?25l\e[0m\e[?25l\e[1;1HA…` against
  `…\e[1;1HA\e[0m\e[?25l\e[1;1H \e[0m\e[?25l`). The three existing draw tests stay green.

## Phase 4 — Closed session lifecycle

**Goal**: a session that has left its scoped teardown cannot write to the terminal again.

### Step 4.1 — Use after teardown throws (decided 2026-10-21)

- File: none (decision).
- Decision (owner, 2026-10-21): calls on a `TerminalSession` after
  `withApplicationTerminal` returns throw, as proposed. This is a pre-1.0 behavior change;
  the reviews found no in-scope caller that depends on the current behavior. Record it in
  `CHANGELOG.md` when Step 4.3 lands.
- Acceptance: none beyond Steps 4.2 and 4.3.

#### Done (2026-10-22)

- Recorded in `CHANGELOG.md` (Unreleased, Changed) with Step 4.3.

### Step 4.2 — Close `ModeLifecycle` after a successful exit

- File: `Sources/TesseraTerminalIO/ModeLifecycle.swift`: `enter` and `apply` (lines
  313-334), `exit` (lines 337-346), and `performApply` (ends at line 484).
- Change: set a closed flag when `exit()` succeeds. Afterwards, `enter` and `apply` throw
  a new `ModeLifecycleError` case before any write. `exit()` stays callable, because
  `failed exit keeps cleanup belief until a successful retry` (line 817) depends on
  retrying it.
- Acceptance: a new test in `ModeLifecycleTests` shows that `apply` after `exit` throws
  and records no device writes. `exit is idempotent after focus cleanup` (line 893) and
  the retry test at line 817 stay green.

#### Done (2026-10-22)

- Commit `e8054a8`. A successful `exit()` sets `closed`; `enter` and `apply` check it
  right after taking the transition gate and throw the new `ModeLifecycleError.closed`
  before any write; `exit()` stays callable. Test
  `enter and apply after a successful exit throw without writing`. Fails-before: "an error
  was expected but none was thrown" twice, with `.flush(ESC[?1004h)` and `.enableRawMode`
  recorded. `failed exit keeps cleanup belief until a successful retry` and
  `exit is idempotent after focus cleanup` stay green. DocC
  (`Extensions/ModeLifecycle.md`, `Managing-Terminal-Modes.md`) lists the case
  (`426bf29`).

### Step 4.3 — Close `TerminalSession` after its scoped teardown

- File: `Sources/TesseraTerminal/TerminalSession.swift`: `copyToClipboard` (lines
  420-429), `setCursorStyle` (line 485), `setMouseTracking` (line 500), `setFocusEvents`
  (line 508), `setKeyboardProtocol` (line 519), `draw` (line 593), `transmitImage` (line
  684), `deleteImages` (line 690), and `reconcileApplicationModes` (line 705).
- Change: set a closed flag on the scoped exit path after Step 2.2. Each entry point
  throws the error chosen in Step 4.1 before writing anything. Today `draw`,
  `copyToClipboard`, `transmitImage`, and `deleteImages` write after teardown, because
  they have no closed check.
- Acceptance: a new test captures the session from `withApplicationTerminal`, and after it
  returns, `setMouseTracking`, `draw`, and `transmitImage` throw, and the device records
  no new writes.

#### Done (2026-10-22)

- Commit `c60ab94`. New
  `public enum TerminalSessionError: Error, Equatable, Sendable { case closed }` (no
  existing public error fit). The session is closed on both exit paths before teardown;
  all nine entry points check it first, and `reconcileApplicationModes` checks again after
  taking its gate so a setter queued before the close also throws. Test
  `session calls after the scoped teardown throw without writing`. Fails-before (check
  disabled): eight post-close calls threw nothing, `copyToClipboard` returned
  `sent(bytesWritten: 17)`, and the device recorded new writes. DocC lists the error
  (`426bf29`).

## Phase 5 — Blocking I/O off the cooperative pool

**Goal**: no blocking POSIX wait holds the input actor or a cooperative-pool thread
indefinitely, and cancellation takes effect within one wait slice.

### Step 5.1 — Move the POSIX input read off the actor

- File: `Sources/TesseraTerminalIO/POSIXInputLoop.swift`: `InputSource` (lines 6-136) and
  `bytes(fileDescriptor:pollTimeoutMilliseconds:)` (lines 142-169).
- Change: run the `poll` and `read` loop on a dedicated `Thread`, which yields chunks into
  the `AsyncStream` continuation. `cancel` writes the cancel pipe and does not hop onto
  the actor. Keep the 25 ms idle chunk, because empty chunks drive the ESC timeout
  (`PlatformIO.swift`, lines 68-70). Keep the `O_NONBLOCK` save and restore (lines 26-27,
  132-134).
- Cost/risk: one thread per open terminal. The loop must end on the cancel pipe or on EOF.
- Acceptance: the input-loop tests in `PlatformIOInputTests` at lines 39, 96, 107, 118,
  and 159 stay green. A new test with a stub `poll` that blocks until the cancel pipe is
  written shows that `cancel` finishes the stream without waiting for a poll timeout.

#### Done (2026-10-22)

- Commit `ba5f83b`. `POSIXInputLoop.InputSource` is a `package final class` whose
  `poll`/`read` loop runs on its own `Thread` and yields chunks into the stream;
  `cancel()` writes the pipe directly; the loop ends on the cancel pipe, EOF, a poll/read
  error, a stop flag, or a `.terminated` yield. The 25 ms idle chunk and `O_NONBLOCK`
  save/restore are kept, and `waitOutIdleTimeout` sleeps out the remainder when a stub
  `poll` returns early, so the investigation-024 spin cannot recur. Tests
  `input loop cancel wakes a blocked poll before its timeout` and
  `input loop paces idle chunks when poll returns immediately`; the five existing
  input-loop tests stay green. Fails-before was shown by breaking the new code (no pipe
  write: the cancel test hit the stub's 5 s cap; no pacing: three chunks in 0.24 ms),
  because the tests cannot target the old actor shape.

### Step 5.2 — Bound the POSIX write wait by slices

- Files: `Sources/TesseraTerminalIO/POSIXSyscalls.swift`, `waitUntilWritable` (lines
  41-60); `Sources/TesseraTerminalIO/TerminalDevice+Live.swift`, `writeOnce` (lines
  184-197).
- Change: replace `poll(…, -1)` (line 44) with slices of a fixed length, for example 50
  ms. Check `Task.isCancelled` between slices, and throw `CancellationError` when
  cancelled. The unwritten bytes stay in the buffer, which depends on the offset semantics
  of Step 3.2.
- Caveat: slicing fixes cancellation. It does not stop a blocked write from occupying a
  thread for each slice. The reviews did not confirm whether the write closure runs on the
  actor's executor or on the cooperative pool (the review marks this as inference); either
  way, the thread is occupied.
- Acceptance: `wait until writable ignores timeout then succeeds` (`POSIXSyscallsTests`,
  line 62) is updated to the slice contract. A new test with a stub `poll` that always
  returns zero shows that a cancelled flush throws `CancellationError` within one slice.

#### Done (2026-10-22)

- Commit `ba5f83b`. `waitUntilWritable` polls in `writableWaitSliceMilliseconds` (50 ms)
  slices and calls `Task.checkCancellation()` after each timed-out slice; unwritten bytes
  stay with the caller because the error propagates.
  `wait until writable ignores timeout then succeeds` became
  `wait until writable polls in bounded slices until writable`; new
  `cancelled wait until writable throws within one slice` and
  `cancelled device write throws within one slice` (through `TerminalDevice.live`).
  Fails-before on the old `poll(…, -1)`: `timeout → -1` instead of 50, no error thrown,
  the write returned 2.

### Step 5.3 — Move the Windows input wait off the cooperative pool (unverified platform)

- File: `Sources/TesseraTerminalIO/WindowsInputLoop.swift`: `run` (lines 39-94) and the
  `Task.detached` in `startIfNeeded` (line 166).
- Change: `Task.detached` still runs on the cooperative pool, so `WaitForSingleObject`
  (line 47) occupies a pool thread for each 25 ms wait. Run the loop on a dedicated
  thread, as in Step 5.1.
- Acceptance: the Windows build and `WindowsInputLoopTests` pass on a Windows host. This
  is not verifiable on macOS, so the step stays unverified until then.

## Phase 6 — Stream, observer, and descriptor lifetimes

**Goal**: waiters, observers, descriptors, and buffers are released or bounded on every
path.

### Step 6.1 — Stop leaking cancelled waiter IDs

- File: `Sources/TesseraTerminal/AsyncEventBuffer.swift`: `next` (lines 43-71) and
  `cancelWaiter` (lines 95-106).
- Change: track pending waiter IDs, and let `cancelWaiter` record an ID in
  `cancelledWaiterIDs` only while that waiter is pending. The alternative is to drop the
  set and ignore a cancel that finds no waiter, because the waiter already has its
  element. Pick one and note it in the code.
- Add a `package` accessor for the size of `cancelledWaiterIDs`, for tests.
- Acceptance: a test resumes a waiter, then drives the cancel path for its ID through a
  package seam, and asserts that the cancelled set is empty. The natural race is not
  deterministic, so the seam is the acceptance point. The buffer tests at
  `TerminalSessionTests.swift` lines 1928 and 2017 stay green.

#### Done (2026-10-22)

- Commit `c60ab94`. Pending waiter IDs are tracked (the choice is noted on
  `cancelledWaiterIDs`); `cancelWaiter(id:)` is `package` and `cancelledWaiterCount` is
  the seam. Test
  `event buffer ignores a late cancel for a waiter that already received a value`;
  fails-before: count 1 instead of 0. The two buffer tests stay green.

### Step 6.2 — Guard the POSIX cancel descriptor against the actor's close

- File: `Sources/TesseraTerminalIO/POSIXInputLoop.swift`: `signalCancellation` (lines
  48-53), `close` (lines 125-135), and `onCancel` (lines 162-167).
- Change: guard the cancel write end and `isClosed` with one lock. `Mutex` from
  `Synchronization` is available on macOS 26. `signalCancellation` writes only while the
  descriptor is open, and `close` takes the same lock before closing. The alternative is
  to close the write end only in `deinit`, after the reader has exited.
- Cost/risk: small. The lock sits on a path that is not hot.
- Acceptance: a test with a counting `POSIXSystem` stub shows that after `cancel()`,
  `signalCancellation()` issues no write. `PlatformIOInputTests` at line 107 stays green.

#### Done (2026-10-22)

- Commit `ba5f83b`. No lock (the repository rule `swift-prefer-actors-over-locks`, and an
  actor cannot guard a blocking reader thread): the plan's alternative, closing the pipe
  only in `InputSource.deinit` after the reader has exited; the reader thread and
  `onTermination` both hold the source, and `cancel()` is idempotent through an
  `Atomic<Bool>` stop flag. Tests
  `input loop cancel after the input ends issues no write`,
  `input loop cancel writes the cancellation pipe only once`,
  `input loop closes its cancel pipe when the source is released` (counting `write` stub
  via the new `SyscallCallCounter`); fails-before shown by removing the exchange guard
  (first two) and closing at reader exit (third).
  `input loop finishes when cancellation pipe wakes poll` stays green.

### Step 6.3 — Finish the input pump when the session is gone

- File: `Sources/TesseraTerminal/TerminalSession.swift`: `TerminalSessionInputObserver`
  (lines 68-96).
- Change: add `hasInstalled`. Once the session has been installed, a nil `session` returns
  nil immediately instead of parking a continuation. Keep the weak reference, because a
  strong one forms a cycle through the pump and `deinit` would never run.
- Ordering: decide Step 6.4 first. If the observer is removed there, this step is moot.
- Acceptance: a test releases the session, then finishes the input source, and expects the
  `events` stream to terminate. Before the fix the stream never finishes, so run the test
  with a timeout.

#### Done (2026-10-22)

- Skipped: Step 6.4 deleted `TerminalSessionInputObserver`, so there is no observer to
  fix.

### Step 6.4 — Start the input pump after construction (decided 2026-10-21)

- File: `Sources/TesseraTerminal/TerminalSession.swift`: the pump start (lines 276-286),
  the observer (lines 68-96), and `deinit` (lines 879-881).
- Decision (owner, 2026-10-21), as proposed: start the pump from a method that
  `withApplicationTerminal` calls after the session is constructed, capturing
  `[weak self]`, and delete `TerminalSessionInputObserver`. Event order is unchanged,
  because the pump still runs sequentially. Step 6.3 is skipped.
- Acceptance: Step 6.3 is marked skipped with this reason, and the existing
  `TerminalSessionTests` stay green.

#### Done (2026-10-22)

- Commit `c60ab94`. `package func startInputPump()` starts the pump with `[weak self]`;
  `withApplicationTerminal` calls it after construction (tests that build a session
  directly call it too, including `makeProbeSession` in the probe tests).
  `TerminalSessionInputObserver` is deleted. Test
  `running input pump does not keep a released session alive` (failed with a strong
  capture).

### Step 6.5 — Buffering policy for input and size streams (decided 2026-10-21)

- Files: `Sources/TesseraTerminal/TerminalSession.swift` (lines 238-239, the input buffer
  and event stream, both unbounded); `Sources/TesseraTerminalIO/PlatformIO.swift`
  (`events`, lines 52-91).
- Decision (owner, 2026-10-21): input is never dropped and has one consumer path (one
  shared buffer, unbounded as today); size changes keep only the newest value
  (`.bufferingNewest(1)` or equivalent), since only the latest size matters.
- Acceptance: the policy is implemented and written into the doc comments of `events`,
  `inputEvents`, and `sizeChanges`, and a test shows that several size changes queued
  before a read deliver only the last one.

#### Done (2026-10-22)

- Commits `c60ab94` (session) and `e8054a8` (sizes). Input: `events` is now
  `AsyncStream(unfolding:)` over the same `AsyncEventBuffer` that `nextEvent()` reads, so
  there is one unbounded queue and one consumer path (each event goes to whichever reader
  takes it); test `events stream and next event share one input queue`. Sizes: newest-only
  (`PlatformIO`'s fan-out keeps one buffered value per consumer); test
  `size changes queued before a read deliver only the newest size` (fails-before: 80×24,
  90×27 and 100×30 instead of only 100×30). The policy is in the doc comments of `events`,
  `inputEvents`, `nextEvent`, and `sizeChanges` on `TerminalSession` and of `events` and
  `sizeChanges` on `PlatformIO`.

### Step 6.6 — Create one size subscription and fan it out

- Files: `Sources/TesseraTerminalIO/PlatformIO.swift` (`sizeChanges` at line 44 and the
  `events` call at line 47); `Sources/TesseraTerminal/TerminalSession.swift` (the public
  `sizeChanges` at line 160 and its assignment at line 273).
- Change: `terminalDevice.sizeChanges()` is called twice, and each live call registers its
  own SIGWINCH source. The public stream, if never read, grows without bound. Create one
  source, and fan its values out to both consumers under the policy chosen in Step 6.5.
- Acceptance: a test with a `TerminalDevice` whose `sizeChanges` counts its subscriptions
  asserts one subscription per `PlatformIO`.

#### Done (2026-10-22)

- Commit `e8054a8`. `PlatformIO` subscribes to the device's size stream once; a private
  `SizeChangeFanOut` actor forwards each value to the public `sizeChanges` and the
  resize-event feed, each newest-only, and cancels the subscription when both end. Test
  `platform io subscribes to device size changes once`; fails-before:
  `(subscriptionCount → 2) == 1`. `size changes yields terminal size notifications` (which
  expected every size) was replaced.

### Step 6.7 — Fix the Windows input-loop restart race (unverified platform)

- File: `Sources/TesseraTerminalIO/WindowsInputLoop.swift`: `startIfNeeded` (lines
  152-175), `cancelIfUnused` (lines 177-182), and `finishAll` (lines 196-209).
- Change: clear `task` when it is cancelled, and let a run finish only the continuations
  that belong to its generation. A late registrant then gets a fresh loop, and is not
  finished by the old run.
- Acceptance: a test in `WindowsInputLoopTests` cancels, re-registers, and asserts that
  the new stream receives bytes. Unverified until a Windows build exists.

## Phase 7 — Active probe retry policy

**Goal**: a probe that was cancelled or failed to send is not treated as answered.

### Step 7.1 — Probe retry policy (decided 2026-10-21)

- Context: `TerminalSession.swift` lines 516-518 describe the generation as "permanently
  cached". `ActiveCapabilityProbeCoordinator.swift` lines 161-166 resolve the generation
  on any error, including cancellation and an emit failure.
- Decision (owner, 2026-10-21): a timeout stays permanent, as the docs say; a cancelled
  probe or a failed emit returns the generation to idle so a later reconcile retries. Step
  7.2 is confirmed.
- Acceptance: none beyond Step 7.2.

#### Done (2026-10-22)

- Applied in Step 7.2; the `setKeyboardProtocol` and `queryActiveCapabilities` doc
  comments on `TerminalSession` say a timeout stays resolved and a cancelled or failed
  probe retries (`c60ab94`).

### Step 7.2 — Retry after cancellation or emit failure

- File: `Sources/TesseraTerminal/ActiveCapabilityProbeCoordinator.swift`: the `catch` in
  `reconcile` (lines 161-166).
- Change: on `CancellationError` or an emit error, set `generation` to `.idle` and discard
  the partial evidence. On normal completion or timeout, keep `.resolved`.
- Acceptance: new tests in
  `Tests/TesseraTerminalTests/ActiveCapabilityProbeCoordinatorTests.swift`: an emit that
  throws, followed by a second `reconcile` that emits again; and a cancelled `reconcile`,
  followed by a second run. The existing tests at lines 93-159 stay green.

#### Done (2026-10-22)

- Commit `c60ab94`. The `catch` in `reconcile` resets the evidence, sets
  `generation = .idle` and `round = .none`, cancels the waiter, and rethrows;
  `try Task.checkCancellation()` now precedes `generation = .resolved(evidence)`, so a
  cancellation after the last round is not cached. Tests
  `failed emit returns the probe generation to idle so a later reconcile retries` and
  `cancelled probe discards partial evidence and a later reconcile retries`; fails-before:
  `cachedAfterFailure == nil` and `cachedAfterCancel == nil` failed (stale
  `privateModes: [2004: .set]` kept) and each second `reconcile` threw `.alreadyResolved`.
  Existing tests green.

## Phase 8 — Vouches, invariants, and process globals

**Goal**: every `@unchecked` attribute and every process-global side effect is either
removed or stated in writing.

### Step 8.1 — Remove the two unneeded `@unchecked Sendable` attributes

- Files: `Sources/TesseraTerminalIO/CleanupRegistry.swift` (line 5);
  `Sources/TesseraTerminalIO/TerminalResizeRegistry.swift` (line 55). Update the comment
  at `TerminalResizeRegistry.swift` lines 50-54, and the stale "immutable" comment at
  `CleanupRegistry.swift` line 4 (the fields are `package var`).
- Change: delete `@unchecked` from `PlatformCleanupRegistration` and from
  `ResizeSignalSource`, so the compiler checks their fields.
- Caveat: the compile checks used Swift 6.4 on extracted shapes. Typecheck the real files
  on the baseline 6.3.3 toolchain as well as on 6.4.
- Acceptance: `swift build` on both lanes and `swift test --filter TesseraTerminalIOTests`
  pass.

#### Done (2026-10-22)

- Commit `3b3325f`, amended by `a580721`. `@unchecked` is gone from
  `PlatformCleanupRegistration` (its doc now describes a value snapshot copied by the C
  shim at install). `ResizeSignalSource` compiles without the vouch on Apple's Dispatch
  but not on swift-corelibs-libdispatch
  (`error: stored property 'source' of 'Sendable'-conforming class 'ResizeSignalSource' has non-Sendable type 'any DispatchSourceSignal'`,
  Linux 6.3.3 and 6.4.1), so that vouch stays with its invariant (Step 8.2) above it. Both
  lanes build; `TesseraTerminalIOTests` green.

### Step 8.2 — Document the `ResizeSignalSource` invariant and the SIGWINCH disposition

- File: `Sources/TesseraTerminalIO/TerminalResizeRegistry.swift`: the class (lines 50-88)
  and `init` (line 62).
- Change: write the invariant above the class. It is one `resume` and one `cancel`, the
  event handler runs on the Dispatch queue, and the continuation is finished from the
  cancel handler. Document why `signal(SIGWINCH, SIG_IGN)` is set, and note that it is
  process-wide and never restored. Decision (owner, 2026-10-21): document only; restoring
  the previous disposition can race with another source that also sets it.
- Acceptance: the comment is written. No behavior change.

#### Done (2026-10-22)

- Commit `3b3325f`. The invariant (one `resume`, one `cancel`, handler on Dispatch's
  default queue, continuation finished from the cancel handler) and the `SIG_IGN`
  disposition (process-wide, never restored, because restoring can race another source)
  are written above `ResizeSignalSource`. No behavior change.

### Step 8.3 — Replace or justify the test-helper vouches

- Files and lines: `Tests/TesseraTerminalIOTests/PlatformIOTests.swift:429`,
  `TerminalDeviceLiveTests.swift:106`, `CleanupRegistryTests.swift:115`,
  `WindowsInputLoopTests.swift:179`, `WindowsConsoleModeTests.swift:213`,
  `POSIXSyscallsTests.swift:63`, `PlatformIOInputTests.swift:53, 76, 119, 160, 212`,
  `TerminalResizeRegistryTests.swift:11, 40, 67`, and
  `Tests/TesseraLayoutTests/FlexDistributionTests.swift:449` (`MeasurementRecorder`).
- Change: for each class, either use `Mutex`-guarded state, or add a one-line comment
  naming the task that owns the state. Do it file by file.
- Also: add a one-line comment above the `Mutex` in
  `Sources/TesseraTerminalSnapshotSupport/VirtualTerminal+Ghostty.swift:31-32`
  (`GhosttyTerminalState`). The `.pi/prompts/phase-slice-workflow.md` rule prefers actors
  for test-support state (line 62), but `VirtualTerminal`'s closures are synchronous, so
  an actor cannot back them; the comment says so.
- Acceptance: `swift test` is green, each remaining `@unchecked` has a comment naming its
  invariant, and the `Mutex` has its justification.

#### Done (2026-10-22)

- Commits `3b3325f` (the `Mutex` comment in `GhosttyTerminalState`: synchronous closures,
  so no actor) and `14d6475` (tests). `MeasurementRecorder` is a `Sendable` class over
  `Mutex` with the reason (synchronous `sizeThatFits`); the `State` classes in
  `PlatformIOInputTests` and `TerminalResizeRegistryTests` are replaced by
  `SyscallCallCounter` (`Atomic`); `FileDescriptorPipe` and `PTYFixture` compile without
  the vouch and carry an ownership comment. Three `@unchecked` remain, all Windows-only
  (`WindowsOutputState`, `WindowsInputState`, `ConsoleState`), each with a comment naming
  the owning task; unverified on Windows until the guest run below.

### Step 8.4 — Descriptor ownership: borrowed standard descriptors (decided 2026-10-21)

- Files: `Sources/TesseraTerminalIO/FileDescriptor.swift` (lines 2-8);
  `PlatformHandles.swift` (lines 3-10); `TerminalDevice+Live.swift` (lines 37-41).
- The `~Copyable` markers do not stop the raw `CInt` from being copied into `@Sendable`
  closures, where it outlives the wrapper. Decision (owner, 2026-10-21): drop `~Copyable`,
  and document the standard descriptors as borrowed for the process lifetime.
- Acceptance: `~Copyable` is gone from the three files, the borrowing contract is in their
  doc comments, and the live-device tests stay green.

#### Done (2026-10-22)

- Commit `3b3325f`. `~Copyable` and `consuming` are gone from `FileDescriptor`, all three
  `PlatformHandles` variants, and `TerminalDevice.live(handles:)`; the doc comments say
  the standard descriptors are borrowed for the process lifetime.
  `TerminalDeviceLiveTests` green.

### Step 8.5 — Stop freeing retired cleanup states in the C shim (unverified)

- File: `Sources/CTesseraTerminalPlatform/cleanup.c`: `tessera_cleanup_install` (lines
  171-208), `tessera_cleanup_perform` (lines 218-231), and the signal handler (lines
  257-259).
- Change: keep retired states alive, for example in a bounded list freed at clear or exit,
  so a handler that loaded the old pointer cannot read freed memory. The alternative is to
  update a fixed teardown buffer under a process-wide signal mask.
- Cost/risk: a bounded amount of retained memory.
- Acceptance: code review, and the existing `CleanupRegistryTests` stay green. A stress
  test would be needed to prove the window, and the review did not reproduce it.
  Unverified.

#### Done (2026-10-22)

- Commit `3b3325f`. `cleanup.c` keeps replaced states in a 16-slot lock-free ring (atomic
  cursor, atomic exchange per slot) fed by `install` and `clear`; the signal and `atexit`
  path never touches it, and a state is freed only when its slot is reused, so a handler
  would have to stay suspended across 16 replacements to read freed memory (bounded, not
  absolute). The same ring is in the Windows branch. Test
  `cleanup registry performs only the latest state after repeated installs and clears` (40
  installs with interleaved clears). Code-reviewed, not stress-tested.

## Phase 9 — Deterministic terminal tests

**Goal**: tests order work on observables, never on yields, and never on the real clock.

### Step 9.1 — Order the queued-setter test on an observable

- File: `Tests/TesseraTerminalTests/TerminalSessionTests.swift`, the test at lines
  403-434. The `Task.yield()` is at line 421.
- Replace the yield with a wait until the focus setter is queued on `modeTransitionGate`,
  using the accessor from Step 1.2. Then cancel the focus task.
- Acceptance: the test asserts the queued state before it cancels, and passes.

#### Done (2026-10-22)

- Commit `c60ab94`. The queued-setter test waits on `queuedModeSetterCount == 1` (bounded
  `waitUntil` helper) before cancelling.

### Step 9.2 — Replace waiter-count spins with a bounded waiting helper

- File: `Tests/TesseraTerminalTests/TerminalSessionTests.swift`, the `while` statements at
  lines 1934, 1967, 1971, 1990, 2112, and 2119 (each
  `while await buffer.waiterCount … Task.yield()`; the yield is on the next line).
- Add a test helper that waits for a waiter count with a deadline, and records an issue
  when the deadline passes. Model it on `waitForCount` in
  `ActiveCapabilityProbeCoordinatorTests.swift` (line 310), and prefer a signal over
  polling where the buffer can provide one.
- Acceptance: no `Task.yield` remains inside a `while` in these tests. A waiter that never
  registers fails the test instead of hanging it.

#### Done (2026-10-22)

- Commit `c60ab94`. `Tests/TesseraTerminalTests/WaitUntil.swift` adds
  `waitUntil(_:timeout:isolation:sourceLocation:_:)`, which records an issue at its
  deadline; every waiter-count spin uses it. `grep Task.yield Tests/TesseraTerminalTests`
  finds nothing.

### Step 9.3 — Order the lifecycle-serialization tests on the gate

- File: `Tests/TesseraTerminalIOTests/ModeLifecycleTests.swift`:
  `concurrent apply transitions serialize` (lines 839-865; yield at line 851) and
  `cancelled queued transition does not mutate lifecycle state` (lines 868-891; yield at
  line 880).
- Replace each yield with a wait until `transitionGate.waiterCount` is 1 (Step 1.2) before
  asserting the flushes or cancelling. Without this, the first test can pass when the
  second call has not started, so serialization is never exercised.
- Acceptance: both tests pass, and each one asserts that the second call is queued before
  it proceeds.

#### Done (2026-10-22)

- Commit `e8054a8`. Both tests wait until `queuedTransitionCount == 1` and assert it
  before flushing or cancelling, via `Tests/TesseraTerminalIOTests/WaitUntil.swift` (5 s
  deadline, records an issue).

### Step 9.4 — Remove the bounded yield loops in the input and resize tests

- Files: `Tests/TesseraTerminalIOTests/PlatformIOInputTests.swift` (the 20-yield loop at
  lines 177-179, waiting for restored flags);
  `Tests/TesseraTerminalIOTests/TerminalResizeRegistryTests.swift` (the 20-yield loop at
  lines 83-85, waiting for termination).
- Replace each loop with an explicit signal: a continuation that the flag-restoring path
  resumes, or an `onTermination` handler that resumes a continuation.
- Acceptance: both tests pass with no `Task.yield` loop.

#### Done (2026-10-22)

- Commit `ba5f83b`. The `fcntlSet` stub yields each flag change into an `AsyncStream` the
  test awaits; the resize test awaits a signal yielded from `onTermination`. Both carry
  `.timeLimit(.minutes(1))`. No `Task.yield` remains in either file.

### Step 9.5 — Remove the real 60-second sleep from the probe test

- File: `Tests/TesseraTerminalTests/ActiveCapabilityProbeCoordinatorTests.swift`, the test
  at lines 124-159. `timeout: .seconds(60)` is at line 132, and the real `ContinuousClock`
  sleep is at line 134.
- Replace the injected `sleep` with a closure that suspends until its task is cancelled.
  `finishInput()` already resolves the round, so the test never waits on the clock.
- Acceptance: the test passes with no real timer. The injected sleep is the only timer.

#### Done (2026-10-22)

- Commit `c60ab94`. The test injects a `suspendUntilCancelled()` sleep (an `AsyncStream`
  that never yields and ends on cancellation); `finishInput()` resolves the round. The
  suite runs in about 0.01 s.

### Step 9.6 — Narrow `.serialized` to suites that reach a process global

- Files: `Tests/TesseraTerminalIOTests/CleanupRegistryTests.swift` (lines 7 and 174);
  `TerminalDeviceLiveTests.swift` (line 8); `WindowsInputLoopTests.swift` (line 10).
- Change: tests that do not assert the C shim get an injected `CleanupRegistryClient` (the
  `.disabled` client exists, and `PlatformIO` already accepts an injected one). Keep
  `.serialized` only where a `tessera_cleanup_*` global or a PTY is touched, with a
  comment above the attribute naming that global. Tests that call
  `CleanupRegistry.install` directly still need the shim.
- Acceptance: `swift test` is green, and each remaining `.serialized` attribute has a
  comment naming its global or PTY.

#### Done (2026-10-22)

- Commit `14d6475`. `TerminalDeviceLiveTests` keeps `.serialized` with a comment naming
  the PTY (`openpty`, `tcsetattr`, `TIOCSWINSZ`) and injects
  `CleanupRegistryClient.disabled` through a `PTYFixture.io()` helper;
  `CleanupRegistryTests` (both platforms) keeps it, named for the `tessera_cleanup_*` shim
  state, because every test there calls `CleanupRegistry` directly;
  `WindowsInputLoopTests` drops it (task-local stubs, fake handles, disabled cleanup;
  unverified on Windows until the guest run below). `CleanupRegistryTestIsolation` and its
  lock are deleted.

### Step 9.7 — Order the remaining yield-before-cancel tests on observables

- File: `Tests/TesseraTerminalTests/TerminalSessionTests.swift`. C-18 cites these two
  yields, but Steps 9.1 to 9.4 do not cover them.
- `queued runtime mode setters preserve unrelated requests` (lines 370-401; yield at line
  388): wait until the focus setter is queued on `modeTransitionGate` (the Step 1.2
  accessor) before resuming the suspended write.
- `pending event read cancellation preserves the next input` (lines 1899-1925; yield at
  line 1915): wait until the buffer has one waiter (the Step 9.2 helper) before
  cancelling.
- Acceptance: both tests assert their precondition before they proceed, and a search of
  `Tests/` for `Task.yield` finds nothing.

#### Done (2026-10-22)

- Commit `c60ab94`. Both tests wait on their precondition (`queuedModeSetterCount`, then
  the buffer's waiter count) before proceeding; `Tests/` contains no `Task.yield`.

### Step 9.8 — Exercise the suite in parallel, or drop the promise (decided 2026-10-21)

- Context: `CONTRIBUTING.md:219` requires tests to be safe under the full parallel suite,
  but every runner passes `--no-parallel`: `justfiles/core.just:28` and `:32`,
  `justfiles/ci.just:18` and `:23`, `.github/workflows/ci.yml:270`, and the Linux script
  (`CONTRIBUTING.md:242`); `CONTRIBUTING.md:103` labels `just core test` "(non-parallel)".
  Read `.agents/investigations/024-phase-3-full-suite-hang.md` first, in case the flag
  works around that hang.
- Decision (owner, 2026-10-21): read investigation 024 first. If its hang no longer
  reproduces under `swift test --parallel` (macOS and Linux, three runs each), take (a):
  after Step 9.6, add a `just` recipe for a parallel run and a non-required CI job, and
  keep `--no-parallel` only where 024 still requires it. Otherwise take (b): remove the
  promise from `CONTRIBUTING.md` and say why, citing 024.
- Acceptance: the branch taken and its evidence (run counts and results) are recorded
  here. This plan runs before plan 035 Step 5.5 replaces `just` with mise, which ports the
  recipe.

#### Done (2026-10-22)

- Branch (a). Investigation 024's hang does not reproduce after Step 5.1:
  `swift test --parallel` passed 3/3 on macOS (Xcode 26.6, 663 tests, about 1 s each warm)
  and 3/3 in the Lima VM (`swift test --jobs 2 --parallel`, 656 tests).
  `just core test-parallel` is added, a non-required `test (parallel, ubuntu-latest)` job
  (`continue-on-error`) runs `swift test --parallel` in `ci.yml`, and `CONTRIBUTING.md`
  names both. `--no-parallel` stays the default for `just core test`, the Linux script,
  and the required CI legs, as what CI has always run; nothing still requires it.

## Phase 10 — Repository review punchlist

**Goal**: the defects from the repository review notes that are not concurrency findings
are fixed, each behind a test or a CI step that would have caught it.

### Step 10.1 — Flatten nested view lists into layout containers

- Files: `Sources/TesseraCore/Views/StructuralView.swift` (`_visitLayoutChildren`, lines
  77-99), `TupleView.swift` (`_visitChildren`, lines 11-29), `ViewBuilder.swift`
  (`buildBlock`, lines 10-13). Every layout container goes through the same function:
  `Sources/TesseraLayout/Stacks.swift:274`, `:334`, `:379`, `Flex.swift:544`,
  `Layout.swift:111`, `Sources/TesseraWidgets/ScrollView.swift:28`, and
  `SplitView.swift:89`.
- Defect (reproduced 2026-10-21 at `28c34b8` with a throwaway test, then deleted): in a
  20x10 graph, `VStack { header(5x2); ForEach(1...3) { row(3x1) } }` places all three rows
  at (0,2), and `VStack { ForEach(1...3) { row(3x1) } }` places all three at (0,0).
  `_visitLayoutChildren` flattens only a top-level `_ViewList`, and `buildBlock` wraps
  even a single expression in a `TupleView`, so a `ForEach` is always nested and becomes
  one child. The 2026-10-20 note predicted the single-`ForEach` case would work; it does
  not.
- Tests first, in `Tests/TesseraLayoutTests/StackDistributionTests.swift`: a `ForEach`
  beside a sibling, a `ForEach` alone, two adjacent `ForEach`es, and the same in an
  `HStack`. In `Tests/TesseraCoreTests/ReconciliationTests.swift`: a keyed child keeps its
  state when an item is inserted before it inside a stack that also has a fixed sibling.
- Change (owner decision, 2026-10-21): flatten at layout time, not at reconciliation, so
  node identity, keyed reconciliation, and the graph's node tree stay exactly as they are.
  `makeLayoutSubviews` (`Sources/TesseraCore/Runtime/ViewGraph.swift:519-548`) builds one
  subview per child node; make it descend through child nodes whose view is a `_ViewList`
  (`TupleView`, `ForEach`, `ConditionalView`, `Optional`, `EmptyView`) and collect their
  leaf descendants as the layout's subviews. Placement then sets each leaf's frame, and
  each intermediate list node takes the union of its children's frames (an empty list gets
  a zero-size frame at its parent's origin). Do not change `_visitLayoutChildren` or
  `_ViewSlot`.
- Also test a two-view `if` branch inside a stack: `ConditionalView` is a `_ViewList`
  (`ConditionalView.swift:2-4`), so its branch must flatten the same way.
- Acceptance: the new tests fail on the current HEAD and pass after the change;
  `swift test` is green; `ReconciliationTests` snapshots are unchanged; and every changed
  frame in a diagnostics snapshot is one the new tests predict. This step lands before any
  demo is built on stacks (plan 032 Step 8.3, or its successor in plan 035 Phase 6).

#### Done (2026-10-22)

- Commit `f4172e8`. `makeLayoutSubviews` descends through `_ViewList` children
  (`TupleView`, `ForEach`, `ConditionalView`, `Optional`, `EmptyView`) and hands the
  layout one subview per leaf; `placeLayoutChildren` sets each leaf's frame and gives each
  list the union of its children's frames (an empty list: zero size at its parent's
  origin). Lists inside containers are no longer measured (diagnostics show them
  unmeasured). Node identity and reconciliation are untouched; no package hook was needed.
  Tests (`StackDistributionTests`, each for `VStack` and `HStack`):
  `stacks lay out ForEach elements beside a sibling individually`,
  `… a lone ForEach individually`, `… adjacent ForEach views individually`,
  `… a two view conditional branch individually`,
  `an empty view list takes a zero size frame at its parent origin`,
  `custom Layout lays out ForEach elements individually`; `ReconciliationTests`:
  `keyed child keeps its state after an insertion before it beside a fixed sibling`.
  Fails-before: all seven failed (18 issues), e.g.
  `[(0,0,5x2), (0,2,3x1), (0,2,3x1), (0,2,3x1)]`, all rows at `(0,0)`,
  `(0,2,4x1), (0,2,2x1)`, keyed insertion `[(0,0), (0,1), (0,1)]`. Full suite green, no
  existing snapshot changed. Discoveries: `ScrollView` places every subview at one origin,
  so no frame changes there; `SplitView { ForEach }` fails earlier at pane-count
  validation (pre-existing); a pane whose content is a nested multi-view list now places
  the first view and hides the rest, where before all overlapped (both wrong; for the
  merged plan's `SplitView` slice).

### Step 10.2 — Give `VirtualTerminalError` the standard error conformances

- File: `Sources/TesseraTerminalSnapshotSupport/VirtualTerminalError.swift:5`.
- Change: conform to `Error, Equatable, Sendable`, like every other error type in
  `Sources/` (for example `PlatformIOError.swift:37`, `GhosttyKeyEncoder.swift:167`). The
  `ghostty(operation:result:)` payload is a `GhosttyResult` imported from C, which should
  already be `Equatable` and `Sendable` (inference, not compiled).
- Acceptance: `swift build` passes on macOS, Linux, and Windows, where the
  `#if canImport(CGhosttyVT)` case differs.

#### Done (2026-10-22)

- Commit `9f80898`. `VirtualTerminalError: Error, Equatable, Sendable`; `GhosttyResult`
  needed no explicit conformance. Builds on macOS (both lanes), Linux (6.3.3 and 6.4.1),
  and the Windows guest (below). The `canImport` fallback branch is unverified (no build
  setting forces it).

### Step 10.3 — Build the Examples package in CI

- Files: `.github/workflows/ci.yml` (the test matrix, lines 144-270), and
  `justfiles/ci.just` (lines 17-23).
- Context: CI runs root `swift build` (line 256) and `swift test --no-parallel` (line 270)
  only; nothing in `.github` passes `--package-path Examples`, though
  `justfiles/core.just:62` already has `just core examples`. Today that leaves the
  Showcase unguarded; once demos live in `Examples/`, it leaves every demo unguarded.
- Change: add `swift build --package-path Examples` to the macOS, Linux, and Windows
  matrix legs (Windows decided by the owner, 2026-10-21; the demos are meant to be checked
  on Windows) and to the local CI recipe.
- Acceptance: a deliberate compile error in `Examples/` fails the CI run, then is
  reverted.

#### Done (2026-10-22)

- Commit `9f80898`. `Build Examples` (`swift build --package-path Examples`) follows the
  root `Build` step on every `test` leg, and `just ci build-test` runs it. The CI proof (a
  deliberate `Examples/` compile error failing the run, then reverted) is recorded on the
  Progress line.

## Findings

Labels: `reproduced` means a throwaway repro or model ran (not the package build).
`reading` means found by reading only. `unverified` means not compiled or run on its
platform, or its intent not confirmed. Impact ratings are as the reports gave them; where
the two reports differed, both are shown. The source of every finding is a
concurrency/isolation review on 2026-10-20.

Tally: high 2 (C-01, C-03); medium-high 1 (C-02); medium 4 (C-04, C-05, C-12, C-19);
low-medium 4 (C-06, C-07, C-10, C-18); low 8 (C-08, C-09, C-11, C-13, C-14, C-15, C-16,
C-17).

### C-01 — A cancelled body skips the terminal lifecycle teardown (impact: high)

- Evidence: reproduced (model). The success-path gap was found by reading in this review.
- Citations: `ModeLifecycle.swift:12-14` (the gate returns false when `Task.isCancelled`);
  `:348-358` (`beginTransition` throws `CancellationError`); `:337-346` (`exit()`);
  `TerminalSession.swift:404` (success-path exit); `:406-416` (catch: cursor restore at
  `:409`, exit at `:413`); `AsyncEventBuffer.swift:58-70` (`next()` throws
  `CancellationError` on cancel, the usual route into the catch).
- What happens: the gate's cancellation check exists so that queued transitions can be
  dropped. Teardown uses the same check, so when the task is cancelled, `performExit`
  never runs. Only the cursor is restored, and raw mode, the alternate screen, mouse
  tracking, and Kitty keyboard stay set. The `atexit` backstop installed by
  `ModeLifecycle.init` (`ModeLifecycle.swift:137`) restores them only at process exit, not
  while the process keeps running. The success path at line 404 has the same gap: a task
  cancelled after the body returns makes `exit()` throw.
- Proposed change: run cursor restore and `lifecycle.exit()` in an unstructured task that
  does not inherit cancellation, and await its value (Step 2.2). The alternative is to
  acquire the gate in `exit()` without the cancellation check. Use
  `withTaskCancellationShield` only behind `#available(macOS 27, *)`, because the package
  floor is macOS 26 (`Package.swift:13`).
- Cost/risk: teardown can no longer be cancelled; it is bounded only by device writes
  (C-05). No public API change.
- Confidence: high. The source matches the reported path.
- Verified by: the model's cancelled-task run printed that `exit` threw
  `CancellationError` and that teardown did not run. The unstructured form ran teardown.
  The package test does not exist yet; Step 2.1 adds it.

### C-02 — A session stays usable after its scoped teardown (impact: medium-high)

- Evidence: reading. Confidence is medium: the `apply` path is inferred from the guard
  structure, because `performExit`'s effects were read but not run.
- Citations: `TerminalSession.swift:345-417` (scoped API; exit at `:404`); `:500-502`
  (`setMouseTracking`) and `:508-510` (`setFocusEvents`), which guard only on
  `modeLifecycle != nil`; `:705-713` (`reconcileApplicationModes`, same guard);
  `ModeLifecycle.swift:325-335` (`apply` has no closed state). `TerminalSession` is a
  `public actor`, so a reference can escape through the `sending R` result.
- What happens: after `exit()`, the mutators pass the nil check, and `ModeLifecycle.apply`
  runs the normal transition path, which writes application-mode sequences and marks modes
  active again. `draw`, `copyToClipboard`, `transmitImage`, and `deleteImages` have no
  closed check, so they write after teardown as well.
- Proposed change: a closed flag on `TerminalSession`, set on the exit path, and on
  `ModeLifecycle`, set on a successful exit. Reject `enter` and `apply`, but not `exit`,
  which must stay retryable (`ModeLifecycleTests.swift:817`). See Phase 4.
- Cost/risk: a public behavior change: calls after teardown throw instead of writing.
  Pre-1.0. No in-scope caller depending on the current behavior was found.

### C-03 — Overlapping `flush` calls send bytes twice, and a discard can trap (impact: high in one report, medium in the other)

- Evidence: reproduced (two models: duplicate delivery, and the trap). The `flush` control
  flow is quoted from source; the package type was not built.
- Citations: `PlatformIO.swift:109-138` (`flush`: `offset` and the uncleared
  `outputBuffer` stay live across the suspension at `:116`); `:104-106`
  (`discardBufferedOutput`); the catch at `:132-137` (`removeFirst(offset)` at `:134`).
  Interleaving callers: `TerminalSession.swift:420-429` (clipboard, via
  `copyToClipboard`), `:639-641` (draw), `:684-687` (image), `:690-693` (delete),
  `:813-814` (probe emit); `ModeLifecycle.swift:394` (discard in enable failure),
  `:491-497` (performExit), `:562-575`, `:599-616`. Only mode transitions are gated; draw,
  clipboard, image, and probe writes are not.
- What happens: a second `flush` during the first one's suspended write starts at offset 0
  and sends the same unwritten bytes again (model: `["FRAME", "FRAME"]`). A discard during
  a suspended write empties the buffer. If the write then throws after an earlier partial
  write advanced `offset`, `removeFirst(offset)` on the shorter buffer traps (model:
  `Can't remove more items from a collection than it has`). Without a throw, the discard
  is harmless.
- Proposed change: a single drain owner (Step 3.2): serialize drains; a discard bumps a
  generation; a drain that sees a changed generation does not call `removeFirst`; failed
  writes keep unwritten bytes at the front. Caveat (reading): the swap-based sketch
  prevents duplication, but a second flush can then send later bytes before the first
  drain's remainder, so serialization must come with it. Known limit: bytes the terminal
  has already accepted cannot be recalled.
- Cost/risk: small; a second flush waits for the first. Public callers are unchanged.
- Confidence: high. Reproduced in models.

### C-04 — `draw` diffs against a stale frame when two calls overlap (impact: medium)

- Evidence: reproduced (model of the suspension points, from one report). The other report
  read the same path and did not reproduce it at session level.
- Citations: `TerminalSession.swift:596` (`io.size()` suspends); `:600-603` (policy
  snapshot); `:626-634` (`encodeFrame(previous: lastDrawnBuffer, …)`); `:639`
  (`io.write`); `:641` (`io.flush`); `:642` (`lastDrawnBuffer = buffer`, after the flush).
  `Sources/TesseraTerminalRendering/Renderer.swift:48-92` (`encodeFrame` is `mutating` and
  updates cursor, style, and erase state synchronously).
- What happens: the actor suspends at `io.size()`, `io.write`, and `io.flush`. A second
  `draw` that starts during the first flush reads the old `lastDrawnBuffer` as its base,
  so cells that the first frame wrote are not re-emitted when the second frame clears
  them. Model result: intended `"   "`, screen `"h  "`.
- Proposed change: a dedicated draw gate around size, encode, write, and flush (Step 3.3).
  Do not share `modeTransitionGate`. Rejected: committing `lastDrawnBuffer` before the
  write, which is unsafe on its own because the writes may not reach the output buffer in
  encode order.
- Cost/risk: concurrent draws queue, which is expected for one terminal stream.
  Invalidation during a draw stays sound (see Checked and sound).
- Confidence: medium-high for the mechanism. The reproduction is a model.

### C-05 — Blocking `poll` and `write` waits run without a cancellation path (impact: medium)

- Evidence: reading.
- Citations: `POSIXInputLoop.swift:57-123` (`InputSource.next`, an actor method, calls
  `poll` with a 25 ms timeout at `:68-71`; the default is at `:144`; `cancel()` at
  `:44-46` queues behind it). `POSIXSyscalls.swift:41-60` (`waitUntilWritable` calls
  `poll(…, -1)` at `:44`). `TerminalDevice+Live.swift:45-47` and `:184-197` (the `write`
  closure runs `writeOnce`, which loops on `waitUntilWritable`). `TerminalDevice.swift:36`
  (the field is `async`). `WindowsInputLoop.swift:46-47` and `:166` (`WaitForSingleObject`
  inside `Task.detached`).
- What happens: a blocked terminal (flow control, a stopped job) holds the write wait
  indefinitely, and the enclosing `flush` cannot be cancelled. Where the write closure
  runs (the actor's executor or the cooperative pool) is not confirmed; a thread is
  blocked either way. The input actor blocks its own executor for up to 25 ms per call.
  `Task.detached` still runs on the cooperative pool, so the Windows wait also occupies a
  pool thread.
- Proposed change: a dedicated thread for the POSIX input loop that yields into the stream
  (Step 5.1); bounded write slices that check cancellation (Step 5.2); a dedicated thread
  for the Windows input wait (Step 5.3, unverified). One report proposed a dedicated queue
  with a continuation for writes; the other proposed slices. Slices come first because
  they are smaller and testable with the existing `POSIXSystem` stubs.
- Cost/risk: a thread per open terminal for input; slice logic on the write path.
- Confidence: high for the mechanism; medium for user-visible impact, since no stalled
  terminal was reproduced.

### C-06 — The POSIX cancel write can race the actor's close of the same descriptor (impact: low in one report, medium-low in the other)

- Evidence: reading for the race. The callback timing (`onCancel` runs on consumer cancel
  but not on natural finish) was reproduced in a model.
- Citations: `POSIXInputLoop.swift:48-53` (`nonisolated signalCancellation` writes
  `cancelWriteDescriptor`); `:125-135` (`close()` closes both descriptors on the actor);
  `:162-167` (`onCancel` calls `signalCancellation()`, then
  `Task { await source.cancel() }`).
- What happens: if the actor has already closed the descriptor, the one-byte write goes to
  a closed number, or to an unrelated file if the number was reused. The window is narrow:
  cancellation must arrive after EOF or close. Not reproduced.
- Proposed change: one lock around the cancel write end and `isClosed` (Step 6.2), or
  close the write end only in `deinit` after the reader exits.
- Cost/risk: small; lifetimes only.
- Confidence: medium.

### C-07 — Windows: a cancelled input loop can finish a new subscriber's stream (impact: low in one report, low-medium in the other; unverified platform)

- Evidence: reading only. Not compiled, because the code is Windows-only.
- Citations: `WindowsInputLoop.swift:177-182` (`cancelIfUnused` cancels `task` and leaves
  it non-nil); `:152-155` (`startIfNeeded` returns early while `task != nil`); `:196-209`
  (`finishAll` sets `task = nil` and finishes every registered continuation).
- What happens: a subscriber that registers after cancellation but before the old loop
  exits gets no loop, and the old run's `finishAll` then finishes its stream with no input
  and no error. Current callers subscribe once, so the defect is latent.
- Proposed change: clear `task` at cancel time, and finish only the continuations from the
  run's generation (Step 6.7).
- Cost/risk: small; Windows only.
- Confidence: medium. Unverified platform.

### C-08 — A cancelled or failed probe is cached as completed (impact: low; confirm intent)

- Evidence: reading.
- Citations: `ActiveCapabilityProbeCoordinator.swift:161-166` (the catch sets
  `generation = .resolved(evidence)` for any error, including `CancellationError` and an
  emit failure; the success path resolves at `:158`); `TerminalSession.swift:516-518` (the
  doc comment says "permanently cached").
- What happens: partial evidence becomes permanent, and later calls return
  `.alreadyResolved` without retrying.
- Proposed change: resolve only on completion or timeout; on cancellation or an emit
  error, return to `.idle` (Step 7.2), after the owner confirms intent (Step 7.1). The
  docs describe timeouts as permanent, so the intent check is needed before changing the
  cancellation path.
- Cost/risk: changes retry behavior after errors; needs tests.
- Confidence: medium.

### C-09 — `AsyncEventBuffer` leaks a cancelled-waiter ID when cancellation loses the race (impact: low)

- Evidence: reading.
- Citations: `AsyncEventBuffer.swift:54-56` (the `defer` removes the ID when `next()`
  returns); `:66-69` (`onCancel` launches `Task { cancelWaiter }`); `:95-106`
  (`cancelWaiter` inserts the ID when it finds no waiter).
- What happens: if the waiter was resumed normally, the cancel task runs after the
  `defer`, finds no waiter, and inserts the ID. Nothing removes it until `finish()`, so
  the set grows by one per such race.
- Proposed change: track pending IDs, or drop the set and ignore a cancel that finds no
  waiter (Step 6.1).
- Cost/risk: none.
- Confidence: medium.

### C-10 — The session's input observer parks forever once the session is released (impact: low-medium)

- Evidence: reproduced (model of the weak reference and the checked continuation).
- Citations: `TerminalSession.swift:68-96` (`TerminalSessionInputObserver`:
  `installedSession()` waits on a continuation whenever `session` is nil); `:276-286` (the
  pump); `:879-881` (`deinit` cancels the pump).
- What happens: after the session deallocates, an `observe` call that reaches
  `installedSession()` never returns. Cancelling the pump does not resume a checked
  continuation, so the pump stays parked and `events` and `inputEvents` never finish. The
  window is an event delivered to the pump after the session is gone.
- Proposed change: after `install`, a nil session means the session is gone, so return nil
  (Step 6.3). Keep the weak reference.
- Cost/risk: an input event delivered after teardown is dropped, which is the correct
  outcome.
- Confidence: high for the mechanism (model). Superseded if C-11 is adopted.

### C-11 — The input observer exists only because the pump starts in `init` (impact: low; design)

- Evidence: reading.
- Citations: `TerminalSession.swift:68-96`; `:276-286` (the pump starts in `init`;
  `Task { await inputObserver.install(self) }` at `:286`); `:879-881`.
- What happens: `self` is not usable inside `init`, which is why the observer
  back-reference exists. The observer adds an actor hop per event and a waiter list.
- Proposed change: start the pump from a method called by `withApplicationTerminal` after
  construction, capturing `[weak self]`, and delete `TerminalSessionInputObserver` (Step
  6.4).
- Cost/risk: small. Event order is unchanged, because the pump still runs sequentially.
- Confidence: high that the indirection is unnecessary. Decide before Step 6.3.

### C-12 — Input, resize, and public size streams are unbounded, and the size stream is subscribed twice (impact: medium)

- Evidence: reading.
- Citations: `TerminalSession.swift:238-239` (`AsyncEventBuffer(coalescing:)` and
  `AsyncStream<InputEvent>.makeStream()`, both with default buffering); `:276-285` (the
  pump feeds both on every event); `:160` (public `sizeChanges`) and `:273` (assigned from
  `io.sizeChanges`); `PlatformIO.swift:44` and `:47` (`terminalDevice.sizeChanges()`
  called twice; each live call registers a SIGWINCH source).
- What happens: an application that reads only `events` grows `inputEvents` without bound,
  and the reverse. An unread public `sizeChanges` grows too. Each live terminal has two
  SIGWINCH sources.
- Proposed change: one consumer path or one shared buffer for input; a bounded newest-only
  policy for sizes; one size subscription, fanned out (Steps 6.5 and 6.6). Input needs a
  documented drop policy, or no drop, rather than a silent default.
- Cost/risk: a bounded policy drops events. Dropping old resize events is harmless;
  dropping input is not. Public behavior may change.
- Confidence: high for the mechanism; medium for impact, since growth depends on how
  callers consume.

### C-13 — Two `@unchecked Sendable` vouches are unnecessary on the reviewed SDK (impact: low)

- Evidence: reproduced (throwaway compile of extracted shapes with the same fields, Swift
  6.4 SDK, `-swift-version 6`). The real types were not built.
- Citations: `Sources/TesseraTerminalIO/CleanupRegistry.swift:4-5`
  (`PlatformCleanupRegistration: @unchecked Sendable`; its fields are `CInt`, `termios?`,
  and `[UInt8]`, all `package var`, so the "immutable" comment is stale);
  `Sources/TesseraTerminalIO/TerminalResizeRegistry.swift:50-55` (`ResizeSignalSource`;
  its comment says `DispatchSourceSignal` does not conform to `Sendable`).
- What happens: both shapes typecheck and lower to SIL without the attribute. Keeping the
  attribute means a future non-`Sendable` field would not be caught.
- Proposed change: delete both attributes (Step 8.1). One report also asked for a written
  invariant on `ResizeSignalSource`; that stays (Step 8.2), whether or not the attribute
  is removed.
- Cost/risk: none.
- Confidence: high for the shapes; medium for the real files until the baseline toolchain
  builds them.

### C-14 — Sixteen `@unchecked` vouch sites, none with a written invariant (impact: low)

- Evidence: reading (search).
- Citations: `CleanupRegistry.swift:5` and `TerminalResizeRegistry.swift:55` (sources),
  and fourteen test helpers: `PlatformIOTests.swift:429`,
  `TerminalDeviceLiveTests.swift:106`, `CleanupRegistryTests.swift:115`,
  `WindowsInputLoopTests.swift:179`, `WindowsConsoleModeTests.swift:213`,
  `POSIXSyscallsTests.swift:63`, `PlatformIOInputTests.swift:53, 76, 119, 160, 212`,
  `TerminalResizeRegistryTests.swift:11, 40, 67`. A search for the word "SAFETY" finds
  nothing, but the codebase states its invariants without that word.
- What happens: no site records which task owns its state.
- Proposed change: `Mutex`-guarded state, or a one-line invariant per site (Steps 8.2 and
  8.3).
- Cost/risk: mechanical test edits.
- Confidence: high for the inventory; medium for the documentation finding.

### C-15 — `~Copyable` on the descriptor wrappers does not enforce ownership (impact: low)

- Evidence: reading.
- Citations: `FileDescriptor.swift:2-8` (`~Copyable`, no owning `deinit`);
  `PlatformHandles.swift:3-10` (`~Copyable`); `TerminalDevice+Live.swift:37-41` (copies
  `handles.stdin.rawValue` and `handles.stdout.rawValue`, both `CInt`, into `@Sendable`
  closures).
- What happens: the marker stops copies of the wrapper, but not of the raw value, which
  outlives the wrapper inside the closures. The descriptors are the process's standard
  streams, so nothing is closed twice, but the marker claims more than it enforces.
- Proposed change: drop `~Copyable` and document the standard descriptors as borrowed for
  the process lifetime, or keep the owner noncopyable and expose only scoped `borrowing`
  access (Step 8.4).
- Cost/risk: a small API cleanup.
- Confidence: high that the raw value escapes.

### C-16 — The C cleanup shim frees a state that a signal handler may still read (impact: low; unverified)

- Evidence: unverified. Reading only; the window was not stressed.
- Citations: `Sources/CTesseraTerminalPlatform/cleanup.c:171-208` (install exchanges the
  state and frees the previous one at `:203-207`); `:218-231` (`tessera_cleanup_perform`
  loads the pointer at `:219` and dereferences it); `:257-259` (the signal handler).
- What happens: an atomic pointer swap does not protect the object that the old pointer
  names. A handler or `atexit` path that loaded the old pointer before the swap can read
  freed memory. The window is small.
- Proposed change: stop freeing retired states in `install`, keeping them alive until
  clear or exit; or update a fixed teardown buffer under a signal mask (Step 8.5).
- Cost/risk: a bounded amount of retained memory.
- Confidence: low to medium.

### C-17 — `ResizeSignalSource` sets a process-wide `SIG_IGN` for SIGWINCH and never restores it (impact: low)

- Evidence: reading.
- Citations: `TerminalResizeRegistry.swift:62` (`signal(SIGWINCH, SIG_IGN)` in `init`);
  `:76-78` and `:81-83` (cancel does not restore it).
- What happens: the process-wide disposition changes for the process lifetime, and the
  reason is not documented.
- Proposed change: save the previous disposition and restore it on cancel, or document the
  requirement at the call site (Step 8.2).
- Cost/risk: restoring can race with another source that installs `SIG_IGN`. Documenting
  costs nothing.
- Confidence: medium.

### C-18 — Tests order work with bare yields and spin on internal state; one real 60-second sleep remains (impact: low in one report, low-medium for the goal in the other)

- Evidence: reading (pattern search). The `ModeLifecycle` false-green was not run against
  a broken implementation.
- Citations: yields before cancel at `TerminalSessionTests.swift:388`, `:421` (the
  queued-setter test, lines 403-434), and `:1915`; waiter spins at `:1934`, `:1967`,
  `:1971`, `:1990`, `:2112`, and `:2119`; `ModeLifecycleTests.swift:851` and `:880`;
  bounded yield loops at `PlatformIOInputTests.swift:177-179` and
  `TerminalResizeRegistryTests.swift:83-85`; the real sleep at
  `ActiveCapabilityProbeCoordinatorTests.swift:134`. The probe is cancelled by
  `finishInput`, so no assertion waits on that sleep, but the goal forbids real sleeps.
- What happens: the queued-setter test passes whether cancellation lands before or after
  queueing. The `ModeLifecycle` serialization test can pass without serialization if the
  second call has not started. The spin loops hang instead of failing when a waiter never
  registers.
- Proposed change: wait on observables (gate and buffer waiter counts, the recorder's
  `waitForCount`), use bounded helpers that fail instead of hanging, use explicit signals
  instead of yield loops, and inject a sleep that suspends until cancelled (Steps 9.1 to
  9.5).
- Cost/risk: test-only. Each hook is a small seam.
- Confidence: high for the patterns; medium for the false green in the `ModeLifecycle`
  test.

### C-19 — Three suites are `.serialized`, against the stated goal (impact: medium for the goal)

- Evidence: reading.
- Citations: `Tests/TesseraTerminalIOTests/TerminalDeviceLiveTests.swift:8`;
  `CleanupRegistryTests.swift:7` (macOS and Linux) and `:174` (Windows);
  `WindowsInputLoopTests.swift:10`; `CleanupRegistryTests.swift:285-301`
  (`CleanupRegistryTestIsolation`, a custom async lock around the global
  `tessera_cleanup_*` shim).
- What happens: the `CleanupRegistry` unit tests reach the global shim, even where they do
  not need it. The live PTY and Windows suites must stay serialized.
- Proposed change: inject `CleanupRegistryClient` into tests that do not assert the shim,
  and keep `.serialized` only where a global or a PTY is used, with a comment that names
  it (Step 9.6).
- Cost/risk: a moderate test refactor. Tests that call `CleanupRegistry.install` directly
  still need the shim.
- Confidence: medium. Not every test that reaches the shim was confirmed.

### Repository review findings

Two repository review notes (2026-10-17, while mining conventions for Lattice at
`f597ac9`; 2026-10-20, while drafting plan 033 at `31966cc`) listed places where practice
contradicts the written rules. Each item was re-checked against `28c34b8` on 2026-10-21.

- R-01, `Task.yield()` in tests despite `CONTRIBUTING.md:217-219` and `docs/Spec.md:173`,
  `:8403`, `:8737`: confirmed at every cited line. Steps 9.1 to 9.4 and Step 9.7.
- R-02, `Task.yield()` in production at `PlatformIO.swift:120`: confirmed, but reachable
  only from test doubles (see Step 3.2 (e)).
- R-03, the parallel-safety rule is never exercised: confirmed. Step 9.8.
- R-04, undocumented `@unchecked Sendable` in test helpers: confirmed at 16 sites. Step
  8.3, which now also lists `FlexDistributionTests.swift:449` and the `Mutex` in
  `VirtualTerminal+Ghostty.swift`. The note's claim that the two production vouches are
  documented is wrong: C-13 found both comments stale and both vouches unnecessary (Step
  8.1).
- R-05, CHANGELOG entries not concise: every `Unreleased` entry is one physical line, as
  `CONTRIBUTING.md:161` requires; "concise" is a matter of taste. Recorded in Checked and
  sound.
- R-06, line length 90 in `CONTRIBUTING.md:189` but 91 in `.swift-format:3`: confirmed;
  SwiftLint's `line_length` is disabled (`.swiftlint.yml:26`), so the stated 150-character
  hard limit is not enforced either. Routed to plan 035 Step 5.1.
- R-07, `VirtualTerminalError` conforms to `Error` only: confirmed. Step 10.2.
- R-08, silent Ghostty fallback in `VirtualTerminal+Ghostty.swift:24-27`: not a defect.
  Recorded in Checked and sound.
- R-09, `mobile` viewport: natural height or 40x16: partly stale. Text-field, picker,
  multi-picker, and content-unavailable-view now say natural height, and key-legend labels
  its 40x16 frame as screen context. Still contradictory: `design/templates/widget.md:38`,
  plan 032 Step 8.2 (lines 609-610, acceptance line 623), and
  `design/widgets/stepper.md:138`; `design/widgets/list.md:186` is defensible if List is
  screen-filling. Routed to plan 035 Step 6.2.
- R-10, plan 032 amendments that plan 033 depends on: a plan change, not a defect.
  `focusChanges` (`GraphStatistics.swift:51`) is confirmed dead: only
  `GraphDiagnosticsSnapshotting.swift:102` reads it and nothing increments it. Routed to
  plan 035 Step 6.1.
- R-11, CI never builds `Examples`: confirmed. Step 10.3.
- R-12, `ForEach` beside other children is not flattened: confirmed and broader than
  reported. Step 10.1.

### Citation corrections

The reports' citations were re-read against the current source. Corrections:

- Structured report, F6: `TerminalSession.swift:262` (public `sizeChanges`) → `:160`
  (declaration) and `:273` (assignment).
- Structured report, F6: `PlatformIO.swift:43-47` → `:44` and `:47`.
- Structured report, F4: `POSIXInputLoop.swift:79` (`cancel()`) → `:44-46`.
- Structured report, F4: `TerminalDevice+Live.swift:184-196` → `:184-197`.
- Structured report, F10: `PlatformIOInputTests.swift:172-179` → `:177-179`.
- Structured report, F2 and F3: the `Frame` citation is
  `Sources/TesseraTerminalBuffer/Frame.swift:12`, not a session file.
- Vague report, F3: `PlatformIO.swift:109-131` → `:109-138` (the catch is at `:132-137`).
- Vague report, F7: `ActiveCapabilityProbeCoordinator.swift:157-166` → the catch is at
  `:161-166`, and the resolution is at `:163`.
- Vague report, F5 and the cancel-pipe claim in Checked and sound:
  `POSIXInputLoop.swift:39-107` → the cancel pipe and poll set are at `:59-71` (`next`),
  and `:142-169` (`bytes`).
- Vague report, Not covered: `cleanup.c:266-271` → `:261-272`.
- Vague report, settings: the upcoming-feature loop is `Package.swift:597-610`, with the
  feature lines at 603-607. Both confirmed.
- Both reports: the compiler was Swift 6.4, while the repo's baseline is 6.3.3
  (`.swift-version`, since plan 035 Step 2.1; 6.3.2 at review time). This is a toolchain
  caveat, not a citation error.

All other cited lines were re-read and match the current source.

## Checked and sound

- `ModeLifecycleTransitionGate` waiter cancellation (`ModeLifecycle.swift:4-56`):
  continuations are registered and cancelled by ID. Queued and cancelled transitions are
  covered by `ModeLifecycleTests.swift:839` and `:868` (the ordering gap is C-18).
- `reconcileApplicationModes` (`TerminalSession.swift:705-787`) takes `modeTransitionGate`
  before it reads `requestedApplicationModes` (`:711`, then `:716`), and releases the gate
  on both paths.
- The two gates are not redundant. The session gate guards requested-mode state that the
  lifecycle gate does not see. Keep both, and comment the split.
- The `withApplicationTerminal` body is `(isolated TerminalSession)` (`:347`, `:358`), so
  it runs on the actor without a hop.
- The `draw` body is synchronous, `(borrowing Frame) throws -> sending R` (`:593-595`).
  `Frame` is `~Copyable, ~Escapable` (`Sources/TesseraTerminalBuffer/Frame.swift:12`), and
  the body cannot suspend. The invariant comment at `:605-607` holds.
- `invalidateRenderer()` racing an in-flight draw is sound. `eraseBeforeNextRepaint`
  persists until the next `encodeFrame` (`Renderer.swift:87`, `:94-99`), so an
  invalidation during a suspended draw still forces a full repaint. The draw failure path
  invalidates the renderer (`TerminalSession.swift:644-648`).
- `ActiveCapabilityProbeCoordinator` single-flight (`:126-133`, with overlap rejected at
  `ActiveCapabilityProbeCoordinatorTests.swift:142-143`), ID-guarded timeouts
  (`:211-216`), and the cancel handler (`:218-223`). The probe tests observe before they
  wait.
- `AsyncEventBuffer` cancel-before-registration (`:58-70`; tests at
  `TerminalSessionTests.swift:1928` and `:2017`). The leaked ID after completion is C-09.
- `queryActiveCapabilities` handles `inProgress` and `alreadyResolved`
  (`TerminalSession.swift:795-826`).
- The `[io]` capture in the probe emit closure (`:812`) captures the `PlatformIO`, not
  `self`. No retain cycle or isolation leak.
- The `nonisolated let` properties (`TerminalSession.swift:140-160`) are all immutable.
- The stored input pump (`TerminalSession.swift:113`, `:276`, `:879-881`) is cancelled in
  `deinit`. It does not capture `self`, so `deinit` runs. The hang is C-10.
- The POSIX cancel pipe wakes `poll`, so cancellation does not wait for the timeout
  (`POSIXInputLoop.swift:64-71`; tests at `PlatformIOInputTests.swift:39` and `:107`).
- The `WindowsConsoleMode` actor (`WindowsConsoleMode.swift:107-142`) has no suspension
  inside its methods, and its saved-mode guard is correct. Reading only; Windows is not
  compiled.
- `TerminalResizeRegistry.swift:66-73`: the `Task { do … catch {} }` is non-throwing; a
  sweep false positive.
- `POSIXSystem` TaskLocal injection (`POSIXSystem.swift:17`): each task sees its own
  system, so parallel tests do not share injected syscalls.
- `TerminalDevice` (`TerminalDevice.swift:4`) is a struct of `@Sendable` closures with no
  shared mutable state.
- `TerminfoDatabase` is an immutable `Sendable` value after load. Read by sweep only.
- `CleanupRegistryTestIsolation` (`CleanupRegistryTests.swift:285-301`): its lock is
  correct on the cancelled and throwing paths.
- `PlatformIO` cleanup and mode flags are installed and cleared per instance, with no
  shared state beyond the registry.
- Sweeps: no `@MainActor` suites; no `processExitsWith` exit tests; no
  `nonisolated(unsafe)` or `assumeIsolated` vouches in the four directories. No `Mutex` or
  lock in either target (the search that found this was not repeated).
- `TerminalDeviceLiveTests` builds `PlatformIO(handles:)`, which uses the live registry,
  but does not enter `ModeLifecycle`. Reported as sound; not re-checked.
- The Ghostty fallback in `VirtualTerminal+Ghostty.swift:24-27` (R-08) is loud, not
  silent: `reportIssue` fails the running test, and the returned `Self()` is built from
  `unimplemented(...)` closures (`VirtualTerminal.swift:30-64`), each of which reports
  another issue when called. Outside a test it is a runtime warning.
- The `Unreleased` CHANGELOG entries (R-05) are each one physical line, which is the
  checkable part of `CONTRIBUTING.md:161`.

## Not covered

- Build and run: neither review built the package, which needs remote dependencies and a
  prebuilt `CGhosttyVT` library. Every compiler claim came from extracted shapes; every
  runtime claim came from models that copy the control flow. Step 1.1 is the first real
  check.
- Toolchain: the compiler checks used Swift 6.4 (`swiftlang-6.4.0.34.1`). The repo's
  baseline is Swift 6.3.3 (`.swift-version`, Xcode 26.6; 6.3.2 at review time), with
  `swift-tools-version: 6.3` (`Package.swift:1`), and Swift 6.4 (Xcode 27.1) is the second
  lane. The `withTaskCancellationShield` availability claim (macOS 27, SE-0504) comes from
  one reviewer's compile against the macOS 27 SDK. It was rechecked neither here nor on
  the baseline toolchain. Plan 035 Phase 2 settled the toolchain lanes before this plan
  runs.
- Windows: `WindowsInputLoop.swift`, `WindowsConsole.swift`, `WindowsConsoleMode.swift`,
  the Windows branches of `CleanupRegistry.swift` and `TerminalDevice+Live.swift`,
  `WindowsInputLoopTests.swift`, and `WindowsConsoleModeTests.swift` were read only. C-07,
  Step 5.3, and Step 6.7 are unverified.
- Linux: the POSIX branches compile under `#if os(macOS) || os(Linux)`. Only macOS was
  considered.
- Real terminal behavior: stalled output (C-05), mode sequences on a real device, cleanup
  after a crash, and the `atexit` path were not run.
- Costs: actor-hop cost and `draw` throughput were not measured.
- Read only in part, or by sweep hit: `TerminalCapabilityDetector`,
  `TerminalCapabilities`, `TerminalApplicationConfiguration`, `TerminfoDatabase`,
  `PlatformIOError`, `WindowsConsole.swift`, `Renderer.swift` outside lines 44-100, and
  the Windows half of `cleanup.c` (lines 1-137).
- Locks and ownership: the `Mutex` suggestions (C-06, C-14) and the `~Copyable` change
  (C-15) follow from general Swift practice. No written rule set was checked against them.
- Process-global side effects, outside the concurrency scope, for owner review: the
  cleanup handlers for SIGINT, SIGTERM, SIGHUP, and SIGQUIT, plus `atexit`
  (`PlatformIO.swift:141-142` → `CleanupRegistry.swift:151-152` → `cleanup.c:261-272`);
  the SIGWINCH disposition (`TerminalResizeRegistry.swift:62`, C-17); and `O_NONBLOCK` on
  the shared stdin, restored on close (`POSIXInputLoop.swift:26-27`, `:132-134`).
- Upcoming features: `NonisolatedNonsendingByDefault` is enabled (`Package.swift:607`), so
  a plain `nonisolated async` function inherits its caller's isolation. Any new
  `nonisolated` annotation must account for that. No step here relies on
  `nonisolated(nonsending)`.
- The experimental `Lifetimes` feature (`Package.swift:603`) was not evaluated.

## References

- `Package.swift:13` (macOS 26 floor); `Package.swift:1` (tools version 6.3);
  `Package.swift:603-607` (experimental and upcoming features).
- `.swift-version` (6.3.3, the baseline; 6.3.2 at review time).
- Repo conventions in `AGENTS.md`: Swift Testing names in backticks, platform divergence
  confined to leaf seams, and Markdown validation with `pnpx markdownlint-cli`.
- Plan 032, `.agents/plans/032-omp2-reference-gallery-and-phase-4-redesign.md`, for the
  plan shape.
- SE-0504, Task cancellation shields:
  [proposals/0504-task-cancellation-shields.md](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0504-task-cancellation-shields.md)
- A concurrency/isolation review on 2026-10-20, two passes over these sources at the
  current HEAD. The origin of every finding in this plan.
- Repository review notes from 2026-10-17 and 2026-10-20 (personal vault inbox, folded
  here and deleted). The origin of Phase 10, Steps 9.7 and 9.8, and the R findings.
