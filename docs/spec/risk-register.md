---
type: spec
description: "Risk register"
---

# Risk register

This section is not a list of reasons to avoid the project. It is a list of places where
terminal libraries commonly go wrong, plus the mitigation the spec expects. When a future
implementation decision touches one of these risks, treat that as a signal to re-read the
relevant slice before changing course.

| Risk                                                   | Where it shows up                           | Mitigation                                                                                                                          |
| ------------------------------------------------------ | ------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Terminal not restored after exit                       | Phase 2 slice 3; Phase 3 mode slices        | `ModeLifecycle`, `CleanupRegistry`, signal/ctrl handlers, and conservative over-cleanup.                                            |
| Encoder API leaks raw escape strings                   | Phase 2 slice 2; all Phase 3 protocol modes | Keep semantic `ControlSequence` cases, explicit `RawTerminalPayload`, and byte-level golden tests.                                  |
| Raw escape hatch corrupts damage tracking              | Phase 2 slices 2/4; future protocols        | Pair raw payloads with `CellDiffPolicy`, opaque regions, reclaim tests, and virtual-terminal tests.                                 |
| Width bugs corrupt rendering                           | Phase 2 slice 4                             | Use explicit cell content states, continuation cells, width tests, and snapshot tests.                                              |
| Damage renderer leaves stale style state               | Phase 2 slice 4; Phase 3 OSC 8              | Treat style, hyperlink, raw payload, and cursor state as renderer-owned state machines.                                             |
| Input parser swallows or mislabels bytes               | Phase 2 slice 5; Phase 3 input protocols    | Keep parser streaming, expose `.unknown(bytes:)`, and test split/partial sequences.                                                 |
| ESC ambiguity makes Escape feel laggy                  | Phase 2 slice 5; Phase 3 Kitty keyboard     | Put timeout policy in the input task; use Kitty keyboard as the modern escape hatch.                                                |
| Bracketed paste is parsed as typed input               | Phase 3 slice 1                             | Treat paste as a parser mode that suspends normal key parsing.                                                                      |
| Mouse tracking breaks the user's shell                 | Phase 3 slice 3                             | Disable mouse modes on every teardown path; prefer button-event tracking over any-event mode.                                       |
| Kitty keyboard over-expands public API                 | Phase 3 slice 4                             | Add key cases deliberately and keep legacy parsing as the compatibility baseline.                                                   |
| OSC 8 enables escape injection                         | Phase 3 slice 5                             | Validate/sanitize hyperlink URI/ID fields and keep OSC bytes out of cell symbols.                                                   |
| Capability detection makes startup fragile             | Phase 3 slice 6                             | Treat capabilities as advisory hints with timeouts and user-visible configuration.                                                  |
| Tessera becomes a compatibility ceiling                | Cross-cutting; raw protocols                | Stay a producer, expose scoped raw payloads, and avoid mux/emulator responsibilities in core.                                       |
| Windows diverges semantically                          | Phase 2 slice 6; Phase 3 protocols          | Require VT mode and keep OS differences inside `PlatformIO` and cleanup code.                                                       |
| Modular targets create public API pressure             | Package layout                              | Use `package` access for cross-target internals and thin re-export targets for users.                                               |
| Phase 4 view layer designs around missing substrate    | Phase 4                                     | Honor the Phase 4 prerequisites table; do not start a slice before its substrate slice lands.                                       |
| No interactive UI hurts motivation                     | Cross-cutting                               | Consider low-level examples like `TerminalLab`, but do not let them drive the view API prematurely.                                 |
| Graphics protocol leaves orphaned images or placements | Phase 3 slice 7                             | Unconditional delete-all in teardown/emergency cleanup, alt-screen confinement, and harness placement tests.                        |
| Image payloads flood terminals that ignore them        | Phase 3 slice 7                             | Blind emission is app opt-in; Slice 6's bounded probe and capability hints inform apps; `t=d` chunking keeps sequences well-formed. |

A risk becomes urgent when implementation pressure tempts the opposite mitigation: raw
escape strings at call sites, raw bytes outside render transactions, parser special cases
without tests, hidden capability switches, platform-specific public events, or Phase 4
convenience APIs before the terminal substrate is stable.
