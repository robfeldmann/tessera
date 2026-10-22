---
type: spec
description: "Architecture: three layers, four passes"
---

# Architecture: three layers, four passes

```text
                ┌──────────────────────────────────────────────┐
   declarative  │ App views: value types, body, modifiers      │  app-owned state
                └──────────────────┬───────────────────────────┘
                                   │ 1. update pass (body evaluation + reconciliation)
                ┌──────────────────▼───────────────────────────┐
   explicit     │ ViewGraph: RuntimeNode tree                  │  identity, NodeState,
                │  • 2. layout pass (propose → size → place)   │  frames, focus,
                │  • 3. render pass (RenderRegion → Buffer)    │  handlers, environment
                └──────────────────┬───────────────────────────┘
                                   │ 4. present (session draw transaction)
                ┌──────────────────▼───────────────────────────┐
   substrate    │ TesseraTerminal: Frame/Buffer → damage       │  bytes, modes,
                │ renderer → ANSIEncoder → PlatformIO          │  lifecycle
                └──────────────────────────────────────────────┘
```

Input flows the opposite direction and never bypasses the graph:

```text
PlatformIO bytes → InputParser → InputEvent → graph.dispatch(event)
  → focus/hit-test routing → user handler closures → app mutates its own state
  → app calls graph.update() → passes 2–4 run on the next draw
```

Each pass is synchronous and pure-ish over the tree:

1. **Update** re-evaluates the root view value and reconciles it against the existing node tree. Output: an updated tree plus `needsLayout`/`needsRender` flags.
2. **Layout** runs top-down proposals and bottom-up sizes through the `Layout` protocol, then assigns each node an absolute `Rect`. Phase 4 keeps this deliberately simple: any `needsLayout` triggers a full relayout from the root, memoized per pass. Terminal trees are small; partial relayout is a Phase 5 performance-pass option, not a correctness feature.
3. **Render** walks the tree painter's-algorithm order and draws every node into a clipped `RenderRegion` over the frame's `Buffer`. Phase 4 renders the full tree each frame; minimal terminal output is already guaranteed by the Phase 2 buffer-diff renderer, so view-level render skipping is an optimization, not a requirement.
4. **Present** is Phase 2's existing draw transaction: buffer diff → damage → bytes.

This split is the transparency story: correctness lives in simple full passes plus the buffer diff; cleverness is opt-in later and always observable via diagnostics.

## Phase 4 implementation order and component landing map

The catalog owns component contracts; this map records the order in which their integration lands. Rows 8–17 are the phases of [plan 032](../../plans/omp2-reference-gallery-and-phase-4-redesign.md), run in sequence with an owner review after each; a step starts from a `ready` catalog doc, or finishes the doc first.

| Step | Lands | Contract |
| --- | --- | --- |
| Slice 1 | `View`, `ViewGraph`, reconciliation, `Text`, immutable local diagnostics snapshot (implemented) | Slice 1 |
| Slice 2 | `Layout`, stacks, `Divider`, static controlled SplitView pane geometry, static ScrollView viewport (implemented) | Slice 2 |
| Phase 2.5 | `Flex`, final min/ideal/max SplitView negotiation (implemented) | Phase 2.5 |
| 8 | Demo runner and headless driver; demos for the landed primitives | Testing posture |
| 9 | Style environment, roles, and tones; `Text + Text` styled runs; wrapping and truncation; borders, `Box`, `background`, `overlay`, and the focus border; `ScrollIndicator` | Slice 3 |
| 10 | Focus identity, traversal, and routing; focus appearance and focus scopes; `KeyLegend` | Slice 4 |
| 11 | Hit testing, click-to-focus, and pointer capture; hover and motion requirements; text selection or its deferral | Slice 5 |
| 12 | Interactive `ScrollView`: keyboard, wheel, boundary bubbling, and reveal on focus change | Slices 4 and 5 |
| 13 | `Button`, `Toggle`, `Picker`, `MultiPicker`, `Stepper`, and `TextField` on a shared text editing core | Slices 4, 5, and 7 |
| 14 | `Flow` and `ViewThatFits`; `List` and `Section`; `Outline`; `Grid` and `Table` | Slices 6 and 7 |
| 15 | Interactive `SplitView`: divider keyboard and pointer resizing, focus style | Slices 4 and 5 |
| 16 | Motion clock and tick requirement; `ProgressView`, `Callout`, `LabeledContent`, `Label`, `Badge`, `ContentUnavailableView`; `TabView`, `Form`, `Markdown`, `CodeView`, `Image` | Motion views |
| 17 | Intro app; catalog graduation to DocC; performance, platform, and quality checks | Phase 4 definition of done |

Three dependencies cut across the order. Form, the description layouts of Picker and MultiPicker, and ProgressView's label placement choose between arrangements with [`ViewThatFits`](../../design/primitives/view-that-fits.md), which lands in step 14.1 although Picker is scheduled earlier, in step 13.2. Markdown needs the `Text + Text` styled runs of step 9.1. List and Table reuse the ScrollIndicator geometry of step 9.4 and the interactive ScrollView of Phase 12.
