---
name: Lifecycle Demo Event Cancellation
date: 2026-06-09
status: resolved
---

# Lifecycle Demo Event Cancellation

## Question

Why does `LifecycleModesDemo` stop handling input after the first key event, and what
changes make this class of bug less likely?

## Findings

- `LifecycleModesDemo` raced input and resize by creating a new task group each loop
  iteration. The losing task was canceled every iteration, so long-lived event sources
  were treated as disposable.
- `TerminalSession.nextEvent()` waited on an internal `CheckedContinuation` that was not
  cancellation-aware. Canceling a task suspended in `nextEvent()` left its continuation in
  the waiter queue. A later input event could resume that abandoned waiter and be dropped
  from the application's perspective.
- This made any consumer pattern that races `nextEvent()` with another async source
  fragile, even if the input stream itself remained alive.
- The safer design is to keep stable producer tasks for long-lived input/resize sources
  and feed a single event stream consumed by the main loop.

## Conclusion

The fix has two layers:

1. `LifecycleModesDemo` now creates stable input and resize producer tasks once per
   terminal session and consumes one buffered event stream.
2. `TerminalSession` now uses a cancellation-safe `AsyncEventBuffer`, so canceling a
   pending `nextEvent()` removes/resumes the waiter instead of allowing future input to be
   lost.

Regression coverage was added for canceled pending event reads and the underlying event
buffer cancellation behavior.
