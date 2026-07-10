---
name: Phase 3 runtime configurability
date: 2026-07-09
status: resolved
---

# Phase 3 runtime configurability

## Question

Which Phase 3 application configuration values can change during a live `TerminalSession`,
which remain startup-only, and which missing runtime controls are useful candidates before
the view layer?

## Findings

`TerminalApplicationConfiguration` is resolved once by
`TerminalSession.withApplicationTerminal`. Mutating the caller's configuration value after
startup has no effect. Current session state falls into four groups.

### Runtime-adjustable policy or mode

| Configuration        | Current runtime behavior                                                                                                                                                                 |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `underlineRendering` | `setUnderlineRendering(_:)` mutates actor-isolated state and invalidates the renderer so the next draw repaints.                                                                         |
| `cursorStyling`      | The enable/disable policy is fixed, but `setCursorStyle(_:)` changes or clears the active style when startup policy is enabled. `ModeLifecycle.apply` preserves other application modes. |

### Runtime operation behind a fixed policy

| Configuration or protocol | Current runtime behavior                                                                                                                                                                                  |
| ------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `clipboardWriting`        | The policy and `ClipboardWritePolicy` limits are immutable, but `copyToClipboard` is an immediate policy-gated operation.                                                                                 |
| Kitty Graphics            | No application configuration policy exists. Query, transmit, and delete are already immediate session APIs; teardown deletes images.                                                                      |
| Capability queries        | `queryActiveCapabilities`, `queryKittyKeyboardSupport`, `queryPrivateModeStatuses`, and `queryKittyGraphicsSupport` emit queries at runtime, but do not mutate `TerminalCapabilities` or reconcile modes. |

### Startup-only output policy

| Configuration        | Missing runtime behavior                                                                            | Required implementation seam                                                                                                |
| -------------------- | --------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| `colorCapability`    | Effective renderer color depth is frozen in `capabilities.color`; override provenance is discarded. | Keep detected metadata separate from actor-isolated effective rendering color. Changing it must invalidate and repaint.     |
| `hyperlinkRendering` | Immutable `TerminalSession` value passed to every draw.                                             | Actor-isolated setter plus renderer invalidation/repaint so existing terminal cells lose or gain OSC 8 metadata.            |
| `synchronizedOutput` | Immutable per-frame wrapper choice.                                                                 | Actor-isolated setter; no renderer invalidation is required because it changes future transaction wrappers, not cell state. |

### Startup-only terminal modes

| Configuration          | Current state                                                                                                    |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `enableBracketedPaste` | Resolved into `.bracketedPaste`; no public session setter.                                                       |
| `enableFocusEvents`    | Resolved into `.focusEvents`; no public session setter.                                                          |
| `mouseTracking`        | Resolved into disabled/button/any-event mode; no public session setter. The demo's `m` key changes logging only. |
| `keyboardProtocol`     | Resolved into legacy/conditional/required startup intent; no public session setter.                              |
| `modes`                | Exact application mode set is entered once. Raw mode and alternate screen are fixed for the scoped session.      |

The internal `ModeLifecycle.apply(applicationModes:)` already reconciles cursor style,
bracketed paste, focus events, mouse tracking, and Kitty keyboard after startup. It
disables in reverse order, enables in canonical order, updates emergency cleanup, and
rejects raw mode or alternate-screen mutation. It is package-only and
`TerminalSession.enabledProtocolModes` is currently an immutable startup snapshot, so
there is no authoritative public runtime mode state.

### Startup-only by design

- `capabilityDetection` resolves environment hints and decides whether initial probes are
  sent before the application body. Public query methods can send probes later, but the
  detected `TerminalCapabilities` value remains advisory and immutable.
- Raw mode and alternate screen define the scoped session boundary and should not become
  ordinary runtime toggles.
- Clipboard policy mutation is possible between writes but is security-sensitive and has
  less user-visible value than rendering or mode controls.

### Probe reconciliation gap

With `capabilityDetection: .active` and `keyboardProtocol: .kittyIfAvailable`, resolution
marks Kitty keyboard as `.probing`, so the initial mode set does not enable Kitty
keyboard. The session sends the query, but a later `kittyKeyboardEnhancementFlags` event
does not update capabilities or enable the mode automatically. The demo observes the event
in its own state only. This is a correctness gap distinct from merely exposing a runtime
setter.

### Mutation invariants

- Color and hyperlink changes require renderer invalidation; otherwise an unchanged
  semantic buffer can retain stale SGR or OSC 8 state.
- Synchronized-output changes affect only future draw wrappers and need no repaint.
- Mode changes must go through `ModeLifecycle.apply`; writing enable/disable bytes
  directly would desynchronize cleanup state.
- Runtime mode state must be committed only after `apply` succeeds. A failure can leave a
  partially reconciled lifecycle with safe cleanup installed.
- Cursor style must be preserved while changing unrelated modes.
- Bracketed-paste mutation needs an explicit policy for an in-flight paste because the
  input parser is configuration-independent and may already be collecting pasted bytes.
- Kitty keyboard mutation must define negotiation and flag-stack behavior, not only emit
  an enable sequence.

## Conclusion

Three follow-up slices are credible before the view layer, ordered by value and risk:

1. **Runtime rendering policies** — add actor-isolated effective color,
   hyperlink-rendering, and synchronized-output setters. Color and hyperlink setters
   invalidate/repaint; sync affects subsequent draw wrappers. Add independent Phase 3 demo
   controls. This is the closest analogue to the underline controls and directly supports
   diagnosing rendering behavior across output paths.
2. **Runtime application modes** — establish authoritative actor-isolated application mode
   state and typed setters for mouse tracking and focus events first. Add bracketed paste
   only after defining in-flight paste behavior. Every setter must use
   `ModeLifecycle.apply`, preserve cursor style, commit after success, and remain
   teardown-safe.
3. **Kitty keyboard reconciliation** — make conditional keyboard negotiation a real state
   machine: consume probe evidence, enable only after support, expose runtime policy,
   handle timeout/unsupported results, and keep parser/mode state coherent. This closes
   the current `.kittyIfAvailable` active-detection gap.

A synchronized-output toggle is technically easy but lower-value and can remain part of
the first slice rather than receiving its own phase. Clipboard-policy mutation, graphics
configuration, raw/alternate-screen toggles, and mutable terminal identity/capability
metadata are not recommended as pre-view-layer phases.
