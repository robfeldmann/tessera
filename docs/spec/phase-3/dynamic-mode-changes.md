---
type: spec
description: "Dynamic mode changes (ModeLifecycle.apply)"
---

# Dynamic mode changes (`ModeLifecycle.apply`)

Phase 2 Slice 3 deliberately made double-`enter` an error and deferred mid-run toggling ("we'll handle that when we get there"). Phase 3 is where we get there, because Phase 4 depends on it: the view layer's `TerminalRequirements` are dynamic — removing the last mouse handler should turn mouse tracking off mid-run, and adding one should turn it on.

The shape: lifecycle/session modes (`rawMode`, `altScreen`) remain session-fixed and are still owned by `enter`/`exit`. Application protocol modes (bracketed paste, focus events, mouse tracking, Kitty keyboard) become reconcilable:

```swift
extension ModeLifecycle {
    /// Reconciles the active application-protocol modes against `target`:
    /// computes the delta, emits only the enable/disable sequences for modes that
    /// changed, and atomically updates the cleanup registry's teardown bytes.
    /// Session modes (rawMode, altScreen) in `target` are a programmer error.
    public func apply(applicationModes target: Set<Mode>) async throws
}
```

Invariants, in order of importance:

1. **The cleanup registry is updated on every successful mode change**, before `apply` returns. If the process dies between two `apply` calls, emergency teardown reflects the modes that are actually active. (`ModeLifecycle` owns the canonical enable and disable ordering internally — the `Set` is a request, not a sequence.)
2. **`apply` is delta-based and idempotent.** Applying the current set is a no-op that emits no bytes. This is what lets the Phase 4 session reconcile `graph.terminalRequirements` after every update without byte spam.
3. **Disable-on-exit still over-cleans.** `exit()` and the emergency path disable every application mode Tessera might ever enable, regardless of what `apply` believes is active.

Implementation notes, grounded in the Phase 2 code:

- `Mode` already declares the four application-protocol cases; the work is removing them from the `unsupportedModes` rejection path in `enable`/`disable`.
- Extend the static `acquisitionOrder` so application modes come after `.altScreen`, e.g. `[.rawMode, .altScreen, .bracketedPaste, .focusEvents, .mouseTracking, .kittyKeyboard]`, and add them to `supportedModes`. `enter(_:)` then enables them after the screen is set up, and `exit()`'s reversed walk disables them first — the teardown ordering each slice asks for falls out of the array, with the Kitty push last among enables and its pop first among disables when `.kittyKeyboard` is the final element.
- Application-mode enable/disable needs no new `TerminalDevice` endpoints. Unlike raw mode (termios/console-mode syscalls) and alt screen, these are pure byte sequences: encode the `ControlSequence`, then `io.write(bytes)` + `io.flush()`.
- `installCleanup()` must grow. Teardown bytes currently cover alt-screen exit and cursor show; every successful `enter`/`apply` recomputes them to include disable sequences for all application modes (over-cleaning is fine — the emergency path may disable modes that were never enabled).
- Build `apply(applicationModes:)` once, after slices 1–4 exist, or as part of wiring slice 6 configuration; the four protocol slices themselves only require `enter`/`exit`/cleanup support. Implement each slice's enable/disable in a shape `apply` can reuse (per-mode enable/disable byte emission plus cleanup-registry refresh), so the reconciler is a delta loop over existing pieces.

Each Phase 3 slice below describes its mode in enable-at-startup terms for simplicity; read those through this section — "enable at startup" means the mode is present in the `TerminalApplicationConfiguration.modes` set handed to `withApplicationTerminal`, or in the initial applied set once requirements-driven reconciliation exists.
