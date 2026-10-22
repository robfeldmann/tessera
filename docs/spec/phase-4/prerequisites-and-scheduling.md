---
type: spec
description: "Prerequisites and scheduling"
---

# Prerequisites and scheduling

Phase 4 deliberately starts only after the substrate it renders into exists:

- **Slices 1–3** require Phase 2 Slice 4 (width-aware `Buffer`, real `Style`,
  damage-tracking renderer). Text measurement is grapheme-width measurement.
- **Phase 2.5** requires Phase 4 Slice 2 and lands Flex plus final SplitView negotiation
  before styling or input code can depend on the temporary static allocator.
- **Slice 4** requires Phase 2 Slice 5 (`Key`, `KeyCode`, `Modifiers`, semantic key
  events). Kitty keyboard (Phase 3 Slice 4) improves it but is not a prerequisite.
- **Slice 5** requires Phase 3 Slice 3 (SGR mouse events).
- **`Image`** requires Phase 3 Slice 7 (the Kitty graphics protocol substrate:
  transmission, placement, and pixel geometry).
- **Derived color roles** read Phase 3 Slice 6's
  [terminal color reports](../phase-3/slice-06-terminal-capability-detection.md#terminal-color-reports).
  Without them every role resolves in the `slots` tier of
  [docs/design/tokens.md](../../design/tokens.md#tiers), so the reports improve Phase 4
  styling but do not gate it.

Slices 1 and 2 and Phase 2.5 are implemented. The rest of Phase 4 does not land slice by
slice: it follows Phases 8–17 of
[plan 032](../../plans/omp2-reference-gallery-and-phase-4-redesign.md), which put layout,
styling, focus, mouse, and ScrollView before the controls, then collections and SplitView,
then the remaining 1.0 views and the intro app. The slice sections below stay the
technical contracts; each names the plan phases that deliver it, and the
[landing map](architecture.md#phase-4-implementation-order-and-component-landing-map)
lists them in order.

Each component lands with its tests and a small standalone demo that runs live and renders
headlessly at the `desktop` (80x24) and `mobile` (40x16) sizes of
[docs/design/tokens.md](../../design/tokens.md#viewports); demo renders are snapshot
fixtures. Plan 032 Phase 17 composes the demos into an intro app that adds navigation, not
component behavior. A step may use the smallest temporary scaffold needed to demonstrate
its foundation, but deletes that scaffold at the later cutover that replaces it: Phase 2.5
deleted the Slice 2 static SplitView allocator before style, keyboard, and pointer
behavior attached to pane geometry.

## The 1.0 surface

Each catalog doc owns its component's contract and records what is in 1.0; this list
gathers those decisions.

- **Layout and decoration:** [`Text`](../../design/primitives/text.md), the
  [stacks](../../design/primitives/stacks.md) and `Spacer`,
  [`frame`](../../design/primitives/frame.md),
  [`padding`](../../design/primitives/padding.md),
  [`ZStack`](../../design/primitives/z-stack.md),
  [`Flex`](../../design/primitives/flex.md), [`Grid`](../../design/primitives/grid.md),
  [`Flow`](../../design/primitives/flow.md),
  [`ViewThatFits`](../../design/primitives/view-that-fits.md),
  [`Divider`](../../design/primitives/divider.md),
  [borders](../../design/primitives/border.md), [`Box`](../../design/primitives/box.md),
  [`background`](../../design/primitives/background.md),
  [`overlay`](../../design/primitives/overlay.md), the
  [style modifiers](../../design/primitives/style-modifiers.md),
  [`ScrollIndicator`](../../design/primitives/scroll-indicator.md), the
  [leading rail](../../design/primitives/leading-rail.md), and
  [readable width](../../design/primitives/readable-width.md).
- **Controls:** [`Button`](../../design/widgets/button.md),
  [`Toggle`](../../design/widgets/toggle.md), [`Picker`](../../design/widgets/picker.md),
  [`MultiPicker`](../../design/widgets/multi-picker.md),
  [`Stepper`](../../design/widgets/stepper.md), and
  [`TextField`](../../design/widgets/text-field.md).
- **Containers and collections:** [`ScrollView`](../../design/widgets/scroll-view.md),
  [`SplitView`](../../design/widgets/split-view.md),
  [`List`](../../design/widgets/list.md), [`Section`](../../design/widgets/section.md),
  [`Outline`](../../design/widgets/outline.md) (including path mode),
  [`Table`](../../design/widgets/table.md), [`TabView`](../../design/widgets/tab-view.md),
  and [`Form`](../../design/widgets/form.md).
- **Status and content:** [`ProgressView`](../../design/widgets/progress-view.md)
  (determinate and indeterminate), [`Callout`](../../design/widgets/callout.md),
  [`LabeledContent`](../../design/widgets/labeled-content.md),
  [`Label`](../../design/primitives/label.md) with the icon catalog,
  [`Badge`](../../design/primitives/badge.md),
  [`KeyLegend`](../../design/widgets/key-legend.md),
  [`ContentUnavailableView`](../../design/widgets/content-unavailable-view.md),
  [`Markdown`](../../design/widgets/markdown.md),
  [`CodeView`](../../design/widgets/code-view.md), and
  [`Image`](../../design/widgets/image.md).

[`NavigationSplitView`](../../design/widgets/navigation-split-view.md) is post-1.0 (owner
decision, 2026-10-09): 1.0 apps compose multi-column layouts from nested `SplitView`s.
Source browsing and mapping are post-1.0 too, as is each deferral a catalog doc records
(for example secure text entry and Stepper's `.compact` style). Application-owned text
selection is decided in plan 032 step 11.3: Slice 5 either adopts its
[catalog contract](../../design/primitives/text-selection.md) or records its deferral.
