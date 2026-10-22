---
type: research
observed: 2026-07-22
status: resolved
description: Runtime state ownership audit
---

# Runtime state ownership audit

## Question

Do any implemented controls or sufficiently mature unimplemented catalog components risk
splitting ephemeral interaction state between leaf and responder runtime storage, as the
TextField implementation did?

## Findings

- `TextField` now uses only `LeafView.NodeState`; its event handler, measurement, and
  rendering share one `_TextFieldState` across graph updates.
- `_SplitViewDividerResponder` is the only implemented type combining `LeafView` and
  `_ResponderView`. Its `NodeState` is `Void`; its responder state is only an event-side
  resolved-pair cache that validates itself against the current pane configuration. There
  is no duplicated render or layout state.
- `Button`, `Toggle`, `_PickerResponder`, and `_StepperResponder` are responder-only
  controls. They have no independent leaf state.
- `ScrollView` is a layout/responder view, not a leaf. During an update it transfers
  geometry into the new view's single `_ScrollResponderState`; layout and event handling
  then share that reference. It does not have a second `NodeState` store.
- No other implemented interactive control has the faulty ownership shape.
- `NavigationSplitView` is wireframed and unimplemented. Its interaction state is already
  binding-owned or derived, but its design did not explicitly prohibit a future responder
  cache from mirroring visibility or focus restoration.
- `Table` is specified and unimplemented. It intentionally owns a scroll offset in
  `NodeState`, so it is the future component most exposed to recreating the defect if its
  keyboard or mouse handling uses an independent responder store.
- Other ready interactive catalog entries are implemented. Remaining unimplemented
  `sketch` components have not reached the requested catalog maturity.

## Conclusion

No additional implemented control required repair. The internal `_ResponderView` contract
and catalog-wide state-model rules now require one owner for each ephemeral value.
`NavigationSplitView` must remain binding-driven across updates. `Table` must route events
through the same `NodeState` used by layout and rendering, with a regression covering
successive selection moves separated by graph updates.
