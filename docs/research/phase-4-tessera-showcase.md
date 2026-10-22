---
type: research
observed: 2026-07-12
status: resolved
description: Phase 4 Tessera Showcase
---

# Phase 4 Tessera Showcase

**Superseded 2026-10-10.** The owner abandoned the Showcase in favour of small
per-component demos assembled later into an intro app, and `design/showcase.md` was
removed (it is in git history and in the `archive/phase4` tag). NavigationSplitView left
1.0, and `Form` and `Outline` moved into it; see
[the 1.0 surface](../spec/phase-4/prerequisites-and-scheduling.md#the-10-surface) and
plan 032. The record below is kept for its history; its links to `design/showcase.md` are
now plain text.

## Accepted decisions

- **1.0 boundary:** Button, Toggle, Picker, Stepper, TextField, List, ScrollView, Section,
  Table, SplitView, and NavigationSplitView are public; `Form`, `Outline`, source
  browsing, and source-to-node mapping are post-1.0. System and custom styles are public,
  and all five semantic roles are complete `Style` values. See the Showcase 1.0 boundary
  in `design/showcase.md`.
- **Diagnostics boundary:** the Inspector is presentation over the Spec-defined immutable
  completed-pass snapshot; it does not mutate the graph or trigger a pass. See the
  diagnostics presentation in `design/showcase.md` and the
  [normative Slice 1 contract](../spec/phase-4/slice-01-tesseracore.md).
- **Responsive policy:** `120x24` is a provisional Showcase fixture; compact roles replace
  rather than squeeze panes, critical content scrolls, and the app model survives a resize
  guard. See the responsive policy in `design/showcase.md`.
- **Seven-slice delivery:** the Showcase lands in dependency order, with each cutover
  deleting its temporary scaffold; progressive SplitView reaches final negotiation before
  NavigationSplitView composes it. See "How the Showcase grows" in `design/showcase.md`
  and the [Phase 4 slice plan](../spec/phase-4.md).

## Open reconciliation questions (resolve during Phase 4 planning)

These are finite decisions, not deferred product scope:

1. **Diagnostic schema:** Which exact public, immutable metadata fields and redaction rule
   are sufficient for local developer inspection while preserving the no-serialization,
   no-logging, no-telemetry, and no-raw-value boundary?
2. **Style API:** What concrete environment-key and type-erasure shape exposes system and
   custom styles while preserving all five semantic roles as complete `Style` values?
3. **Control signatures:** What exact initializer/configuration signatures make Button,
   Toggle, Picker, Stepper, and TextField controlled without leaking responder/session
   authority?
4. **List and Section:** What catalog contracts establish flat grouping, selection,
   scrolling, empty states, and the final Catalog integration before their 1.0 cutover?
5. **Table solver:** What shared public Flex/Grid representation finalizes
   `fixed`/`min`/`fill(weight:)`, priority dropping, and integer remainder order?
6. **Navigation compact fallback:** When an app binding names an unavailable role, what
   deterministic supplied-role fallback occurs without mutating that binding?
7. **Scroll input details:** Does the mouse event surface carry signed two-axis wheel
   deltas, and what single-line normalization applies to paste/dictation commits?
8. **Capability defaults:** Which indexed default values implement semantic accent and
   destructive styles before an app overrides them, while preserving token degradation?
