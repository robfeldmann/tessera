---
type: spec
description: "Identity model"
---

# Identity model

Identity is the part of SwiftUI people debug by superstition. Tessera writes it down.

A node's identity is its **path of slots from the root**:

```swift
public struct NodeIdentity: Hashable, Sendable, CustomStringConvertible {
    // conceptually: [Slot]
}

enum Slot: Hashable, Sendable {
    case body                 // composite view → its body
    case index(Int)           // position in a TupleView / fixed container
    case id(AnyHashable)      // ForEach element, keyed by the element's id
    case branch(Bool)         // if/else: true and false branches are DIFFERENT identities
    case explicit(AnyHashable) // .id(_:) modifier resets the path below it
}
```

The rules, exhaustively:

1. **Structural by default.** A view's identity is where it sits in its parent's children. Reordering siblings reorders identities.
2. **`ForEach` is always keyed.** Elements identify by `Identifiable` id or an explicit `id:` key path. Moves preserve node state; there is no index-keyed `ForEach` over non-identifiable data without an explicit key path.
3. **`if`/`else` branches are distinct.** Switching branches destroys the old subtree (and its `NodeState`) and builds the new one. Same as SwiftUI, but stated.
4. **`.id(_:)` resets identity.** Changing the value tears down and rebuilds the subtree. This is the explicit "reset this widget" lever. The explicit value is scoped by the structural path above it; duplicate `.id("row")` values in different parents are distinct, not aliased globally.
5. **Type change is identity change.** If the view type at a slot differs from last update, the old node is discarded.
6. **Identity loss is observable.** The graph can report created/destroyed node counts per update (`graph.statistics`), and `graph.dump()` prints every node's identity path, so "why did my text field lose its cursor" is answerable by looking.
