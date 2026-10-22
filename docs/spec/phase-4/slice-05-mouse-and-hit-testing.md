---
type: spec
description: "Slice 5: Mouse and hit testing"
---

# Slice 5: Mouse and hit testing

Requires Phase 3 Slice 3 (SGR mouse events). Plan 032 Phase 11 delivers this slice: hit testing, click-to-focus, and pointer capture (step 11.1), hover and motion requirements (11.2), and the text selection decision (11.3). Each component's pointer path lands with the component: ScrollView in Phase 12, the controls in Phase 13, Table and List row hover in Phase 14, and SplitView in Phase 15.

- Layout already records absolute frames; hit testing is deepest-first search of nodes containing the point, respecting clip rects and ZStack order (topmost first), skipping `.allowsHitTesting(false)` subtrees.
- API:

  ```swift
  extension View {
      public func onTap(
          perform: @escaping (inout ResponderContext) -> Void) -> some View
      public func onMouse(
          _ handler: @escaping (MouseEvent, inout ResponderContext) -> EventDisposition
      ) -> some View
      public func onHover(
          perform: @escaping (_ isHovered: Bool, inout ResponderContext) -> Void
      ) -> some View
      public func allowsHitTesting(_ enabled: Bool) -> some View
  }
  ```

  `.onTap` is press+release of the primary button within the same node (no drag threshold cleverness — cells are coarse). `.onMouse` exposes the raw stream (move, drag, scroll, per Phase 3's bounded-coalescing policy) for widgets like `List` and `ScrollView`; `.move` events are delivered only while any-event tracking is active.

  `onHover` derives enter and exit from hit-testing incoming `.move` positions against the node's frame; it never receives raw mouse events. Because `.move` only exists while any-event tracking is active, a view with an `onHover` handler needs that broader granularity — see `wantsMouseMotion` below.

- Routing: hit-test the deepest handler-bearing node, bubble while `.ignored`, same as keys. A primary-button press on a `.focusable` node focuses it before tap delivery (click-to-focus); this is the one built-in behavior, and it is documented and disableable (`.focusOnTap(false)` if real demand appears — do not pre-build it).
- Pointer capture: the node that receives a primary-button press keeps receiving the drag that follows until release or cancellation, even outside its frame or clip.
- Presence of any mouse handler (`.onTap` or `.onMouse`) sets `terminalRequirements.wantsMouse`; presence of any `onHover` handler (or a widget that requests motion directly) sets `terminalRequirements.wantsMouseMotion`. Table and List request motion tracking for their default row hover while they are live in the graph ([terminal requirements](slice-04-focus-and-key-routing.md#terminal-requirements-aggregation)); `.rowHover(.disabled)`, a placeholder spelling that [Table](../../design/widgets/table.md) and [List](../../design/widgets/list.md) settle, removes both the hover fill and the request. The session maps these onto Phase 3's `MouseTracking`: `wantsMouseMotion` → `.mouseTracking(.anyEvent)`; `wantsMouse` alone → `.mouseTracking(.buttonEvents)`; neither → mouse tracking disabled. This extends the existing dynamic-disable behavior below to two escalating tiers instead of one on/off switch.
- Hover state clears on `focusLost` and whenever motion tracking disables — terminals give no mouse-leave signal, so a stuck "hovered" view is otherwise unavoidable once the pointer or focus moves away without a trailing event to notice.
- Text selection: plan 032 step 11.3 records here either the application-owned selection and copy contract ([Text selection](../../design/primitives/text-selection.md)) or its explicit deferral.
- Tests: hit-test tables over constructed layouts (overlapping ZStack children, clipped overflow, disabled subtrees); scroll-event routing; click-to-focus; pointer capture through release and cancellation; hover enter/exit tables over constructed `.move` position sequences; `wantsMouse`/`wantsMouseMotion` escalation and de-escalation as handlers and row-hovering collections are added and removed.

## Pointer cutover for controls, fields, panes, and viewports

Control clicks activate the focused responder through the same controlled binding/action path as keyboard activation (plan 032 Phase 13). [`TextField`](../../design/widgets/text-field.md) gains the click-to-caret substrate: hit testing maps the visible grapheme-cell position to its ephemeral caret state without capturing the bound text. The [`SplitView`](../../design/widgets/split-view.md) divider gains pointer drag in plan 032 Phase 15; the drag holds pointer capture and writes the controlled pane state through Phase 2.5's final negotiation.

[`ScrollView`](../../design/widgets/scroll-view.md) gains pointer input in plan 032 Phase 12. Wheel events first attempt to change the clamped local offset; when the requested movement reaches a boundary, the viewport returns `.ignored` so the event bubbles to an eligible ancestor. This makes nested viewport boundaries explicit rather than silently swallowing motion. Its indicators stay output-only in 1.0: clicks and drags on them return `.ignored`.

## Definition of done for slice 5

Hit testing matches the table tests; a pointer demo mixes keyboard and mouse focus; a press keeps its drag captured until release or cancellation; removing all mouse handlers drops `wantsMouse` and the session disables mouse mode mid-run; adding and removing `onHover` handlers, or Table and List rows with default hover, escalates and de-escalates `wantsMouseMotion` independently of `wantsMouse`; hover state clears correctly on focus loss and on motion-tracking disable. Control clicks, TextField click-to-caret, SplitView divider drag, and ScrollView wheel input with boundary bubbling have deterministic routing tests. Text selection has a contract or a recorded deferral.

---
