---
type: spec
description: "Phase 0 frozen module and ownership contract"
---

# Phase 0 frozen module and ownership contract

The Phase 4 target graph is acyclic and intentionally narrow: `TesseraCore` directly depends only on `TesseraTerminalCore`, `TesseraTerminalBuffer`, and `TesseraTerminalInput`; `TesseraLayout` depends only on `TesseraCore`; and `TesseraWidgets` depends only on `TesseraCore` and `TesseraLayout`. `Tessera` is the public re-export surface for those three view targets and `TesseraTerminal`.

`Frame` belongs to `TesseraTerminalBuffer`, alongside `Buffer` and `Style`. This is the narrow terminal substrate seam: `TesseraCore` may render synchronously into the borrowed, noncopyable `Frame` and use geometry, buffer/style, and input-event values without importing `TesseraTerminal`, `TesseraTerminalIO`, platform shims, or UI frameworks. Only `TerminalSession` owns mode lifecycle, capabilities, presentation, and the construction of a frame during its draw transaction. The `TesseraTerminal` and `Tessera` facade source files contain re-exports only; implementation code imports its narrow dependency directly.

`TesseraWidgets` starts with the Slice 2 static `ScrollView` viewport and `SplitView` geometry, receives controlled responders once focus routing lands (plan 032 Phase 10), and completes its standard widget set with the remaining 1.0 views (plan 032 Phase 16). There is no temporary widget target.
