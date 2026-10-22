---
type: spec
description: "Slice 7: Catalog integration — List, Section, and controlled widgets"
---

# Slice 7: Catalog integration — List, Section, and controlled widgets

This slice completes catalog integration rather than introducing another widget subsystem. Plan 032 delivers it with the components: the controls and TextField in Phase 13, and List, Section, and Outline in steps 14.2 and 14.3. [`List` and `Section`](../../design/widgets/list.md) compose their catalog-owned selection, section, and overflow contracts into the graph, and [`Outline`](../../design/widgets/outline.md), including its path mode, does the same with controlled selection and expansion; [`ScrollView`](../../design/widgets/scroll-view.md) uses the same completed viewport and indicator behavior. Final system and custom control styles apply the Slice 3 complete semantic `Style` roles consistently across the public controls.

[`TextField`](../../design/widgets/text-field.md) completes its public controlled contract. Edits write through `Binding`; `NodeState` holds only the grapheme-safe cursor and reveal offset, clamps both on every bound-value update, and never retains the controlled text. Focused paste and dictation commits write through the binding, and submit routes through the documented action. Rendering requests the hardware cursor at the resolved caret with `RenderRegion.requestCursor(at:)`; the graph forwards the last focused request to the session draw and the session positions or hides the terminal cursor.

The intro app (plan 032 step 17.1) composes the per-component demos; it adds navigation, not component behavior. The graph requests `TerminalRequirements`; the session remains the authority that decides and reports effective requirements, including in the diagnostics snapshot.

Widget tests remain deterministic state-machine tests with no terminal and no wall clock: build a graph, dispatch key/paste/pointer scripts, and assert bindings, ephemeral `NodeState` through test hooks, diagnostics snapshots, and chosen buffer snapshots. Grapheme cursor movement, bound-value replacement, paste/dictation commit, submit, selection out of range, and session-effective requirements are mandatory cases.

## Definition of done for slice 7

1. List, Section, and Outline integrate their catalog contracts; all 1.0 controls have final system/custom styles and remain controlled.
2. TextField binding edits, grapheme-safe cursor/reveal state, paste/dictation commits, submit, and hardware-cursor requests have deterministic tests.
3. Every 1.0 component has a demo with snapshot coverage at `desktop` and `mobile` sizes, and any diagnostics inspector reads the immutable Slice 1 snapshot without graph mutation or pass triggering.
4. Graph-requested and session-effective `TerminalRequirements` are demonstrably distinct values with session authority preserved.

## Things to flag

1. **Controlled-only is the hill to hold.** The first request will be "can `TextField` just own its text?" The answer is `@Observable` in the app plus a one-line binding. Owning text in `NodeState` would quietly become the state-management coupling this whole layer exists to avoid.
2. **Grapheme-aware cursor movement is the hard 20%.** Budget for it; reuse Phase 2 Slice 4's width/cluster machinery rather than re-deriving it in the widget.

---
