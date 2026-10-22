---
name: Phase 3 runtime configurability
date: 2026-07-09
status: resolved
---

# Phase 3 runtime configurability

## Question

Which Phase 3 application configuration values can change during a live `TerminalSession`,
which remain intentionally fixed, and how do live evidence and failure-safe mode
reconciliation behave after Slice 12?

## Findings

Slice 12 closed the prior runtime-control gaps. Configuration still expresses startup
intent, but the session now owns actor-isolated live policy, evidence, and lifecycle
state. The following reflects the implemented post-plan-028 contract.

### Runtime rendering policy

| Policy              | Current runtime behavior                                                                                                                                                                                                                                                                                  |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Color               | `setColorCapability(_:)` updates application override intent. The session keeps detected `capabilities.color` separate from `effectiveColorCapability`; it invalidates the renderer only if the effective depth changes. `NO_COLOR` and dumb-terminal constraints pin the effective result to `.noColor`. |
| Hyperlinks          | `setHyperlinkRendering(_:)` changes OSC 8 rendering and invalidates the renderer, so unchanged semantic cells are repainted with or without link metadata.                                                                                                                                                |
| Synchronized output | `setSynchronizedOutput(_:)` changes only future frame wrappers and requires no renderer invalidation.                                                                                                                                                                                                     |
| Underlines          | `setUnderlineRendering(_:)` immediately overrides the startup projection and invalidates the renderer when the output projection changes.                                                                                                                                                                 |
| Cursor style        | `setCursorStyle(_:)` changes or clears the effective style when cursor styling is enabled, through the serialized lifecycle reconciler.                                                                                                                                                                   |

### Runtime application modes

| Policy         | Current runtime behavior                                                                                                                                                                              |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Mouse tracking | `setMouseTracking(_:)` changes disabled, button-event, or any-event tracking through the lifecycle transaction.                                                                                       |
| Focus events   | `setFocusEvents(_:)` enables or disables focus reporting through the lifecycle transaction.                                                                                                           |
| Kitty keyboard | `setKeyboardProtocol(_:)` applies explicit required/legacy policy immediately. Conditional `.kittyIfAvailable` remains requested but enables only after positively observed protocol-native evidence. |

Raw mode and alternate screen remain fixed scoped-session ownership. Bracketed paste
remains startup-only because changing it during an in-flight paste has no settled parser
contract. Clipboard-writing policy remains fixed and security-sensitive. Kitty Graphics
remains operational (`query`, `transmit`, `delete`) rather than a persistent application
mode.

### Live evidence and reconciliation

- `TerminalSession.capabilities` and `enabledProtocolModes` are actor-isolated live
  values, not immutable startup snapshots. `protocolModeReport` distinguishes requested
  policy, effective lifecycle modes, and possibly-active modes after ambiguous I/O.
- Environment-derived terminal identity is diagnostic only. It does not prove support or
  select protocol policy. Active evidence is protocol-native parser evidence.
- Active probing is one permanently cached, bounded generation. Query bytes alone do not
  reconcile a capability: parsed responses update evidence and conditional Kitty
  negotiation. Later setters never launch another probe or trust passive metadata.
- `.terminfoDatabase` is an explicit startup opt-in for underline compatibility. Its
  `Smulx`/`Setulc` declarations are advisory, as are missing, malformed, or unknown
  declarations. They do not silently downgrade `.extended`; the runtime underline setter
  takes precedence over its startup projection.

### Lifecycle safety invariants

- Every lifecycle write is serialized by a non-reentrant transaction gate. Startup,
  teardown, and concurrent setters cannot interleave a mode transition across suspension.
- Cleanup for requested and possibly-active modes is installed before the first mutating
  byte can reach the terminal. After an ambiguous write or flush failure it remains
  installed, while lifecycle belief records the uncertain mode.
- A requested runtime policy commits only after successful apply. Failure preserves
  successfully effective state, records ambiguity where needed, and keeps defensive
  cleanup until successful teardown; retry and repeated cleanup remain safe.

### Demo surface

`Phase3ProtocolsDemo` exposes live controls `d`, `y`, `h`, `t`, `f`, `k`, `s`, `c`, and
`x`, with global `q`, `g`, and `m`. Controls accept press/repeat events and ignore
releases; the capability and protocol panels display live requested/effective/
possibly-active state rather than support inferred from terminal identity.

## Conclusion

The earlier startup-only policy and send-only-probe characterizations are obsolete.
Selected rendering policies and mouse/focus/keyboard modes are now live session controls
with authoritative state and failure-safe lifecycle reconciliation. The deliberately fixed
boundaries are bracketed paste, raw mode, alternate screen, clipboard policy, and graphics
configuration; graphics operations themselves remain available at runtime.
