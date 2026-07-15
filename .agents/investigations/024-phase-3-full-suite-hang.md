---
name: Phase 3 Full-Suite Hang
date: 2026-07-15
status: resolved
---

# Phase 3 Full-Suite Hang

## Question

Why does the OMP session appear stuck at “Capturing exact full-suite result” after
`swift test`?

## Findings

- Three full-suite commands did not return normal Bash completion records. The session
  recorded an empty `details` object and `isError: true` only after the user interrupted:
  14:05–14:24, 14:31–15:08, and 15:33–15:52 UTC.
- The active process is not idle or merely capturing output: `swiftpm-testing-helper` PID
  80925 remains a child of `swift-test --xunit-output .build/phase3-tests.xml`, is in
  state `R`, has run for more than 14 minutes, and uses about 99% CPU.
- `.build/phase3-tests-swift-testing.xml` contains only its XML prologue and
  `<testsuites>`, so SwiftPM has not completed or flushed a test result.
- A process sample attributes all main-thread samples to `POSIXInputLoop.inputLoop` and
  `hasAnyEvent` at `Sources/TesseraTerminalIO/POSIXInputLoop.swift:85`, `:90`, `:104`, and
  `:121`.
- `POSIXInputLoop.bytes` creates an unstructured `Task` that captures its `AsyncStream`
  continuation. Its `onTermination` closure captures the same task. The test
  `input loop restores descriptor flags on termination` injects a `poll` stub that returns
  immediately with no events. If stream termination is not reached, this creates a tight
  loop yielding empty chunks instead of waiting 25 ms.
- The session's statements that a full suite “completed successfully” or “completed in
  about 5 seconds” were not supported by the recorded tool result. The normal 7-second
  persistence slice did pass, but it did not prove that the full suite exited.

## Conclusion

This is a real test-process hang caused by a CPU-bound POSIX input-loop task, not a
passive full-output capture delay. The UI label is misleading, and interrupting the model
has left the `swift-test` child process alive. Stop the stuck process tree, then reproduce
with `swift test --filter TesseraTerminalIOTests` and repair the input loop's
cancellation/lifetime behavior before attempting another full suite.
