# ``TesseraCore``

@Metadata {
    @PageImage(purpose: icon, source: "core-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "core-card", alt: "Module card.")
}

Core view-layer protocols and shared types.
The graph routes semantic keyboard and pointer events without owning terminal bytes or
terminal modes. The `ViewGraph.dispatch` overloads accept parsed `InputEvent` values and normalized
`PointerEvent` phases; a session remains the authority that applies the graph's
``TerminalRequirements``.

## Pointer responders

The public pointer modifiers are deliberately small:

- ``View/onPointer(_:)`` receives normalized `PointerEvent` values, including `down`,
  `move`, `up`, and graph-generated `cancel` phases.
- ``View/onTap(perform:)`` handles a primary-button down/up pair and runs its action only
  when the graph can complete that pair on the same captured node.
- ``View/allowsHitTesting(_:)`` excludes a subtree from hit testing. A disabled topmost
  target remains occluding and can offer the event to pointer-responder ancestors; the
  graph never falls through it to a sibling underneath.

On a primary down, hit testing respects clips and reverse child paint order, focuses the
nearest focusable target, and captures the selected pointer responder. Subsequent move and
up phases go to that owner. An outside, occluded, invalid, disabled, removed, or focus-lost
release cancels the interaction and is not retargeted to an underlay; the cancellation is
unconsumed. This surface has no hover modifier or broad gesture framework: `move` is
only the captured motion stream, not hover state.

## Developer automation

``View/automationID(_:role:)`` supplies an explicit, value-free annotation for local
inspection. ``ViewGraph/automationSnapshot`` reads only the latest completed layout,
explicit identifiers and roles, structural identity, bounds/clips, and enabled/focused/
pressed/captured state. It never updates, lays out, renders, changes focus, or dispatches
input. Duplicate and missing identifiers fail deterministically. Button automation exposes
the immediate `enter`/`space` activation keys only; pointer and held-key protocols are
intentionally not advertised by this projection even though the graph supports them.

## Topics

### Views

- ``View``

### Input and runtime

- ``ViewGraph``
- ``ViewGraph/dispatch(_:)-(InputEvent)``
- ``ViewGraph/dispatch(_:)-(PointerEvent)``
- ``TerminalRequirements``

### Explicit developer observations

- ``ViewGraph/automationSnapshot``
- ``View/automationID(_:role:)``
- ``AutomationRole``
- ``AutomationElement``
- ``AutomationSnapshot``
