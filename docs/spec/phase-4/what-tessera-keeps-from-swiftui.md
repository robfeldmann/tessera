---
type: spec
description: "What Tessera keeps from SwiftUI, and what it deliberately rejects"
---

# What Tessera keeps from SwiftUI, and what it deliberately rejects

| SwiftUI concept              | Tessera counterpart                                                         |
| ---------------------------- | --------------------------------------------------------------------------- |
| `body` + result builders     | Kept. `View.body`, `@ViewBuilder`, `ForEach`, conditionals.                 |
| Modifier chains              | Kept. `.padding(2).border(.rounded).onKey { … }` lower to wrapper nodes.    |
| Environment                  | Kept. `EnvironmentValues` + `EnvironmentKey`, propagated through the tree.  |
| Two-pass `Layout` protocol   | Kept, integer-cell flavored. `sizeThatFits` / `placeSubviews`.              |
| Structural identity          | Kept, but **documented and dumpable** instead of implicit folklore.         |
| AttributeGraph / hidden deps | Rejected. Reconciliation is a plain tree diff you can read in one file.     |
| `@State` / `@StateObject`    | Rejected in composite views. Widgets use explicit `NodeState`; apps BYO.    |
| Implicit invalidation        | Rejected. The app calls `graph.update()`; widgets call `setNeedsDisplay()`. |
| Opaque layout failures       | Rejected. Layout is integer math with documented rounding; `dump()` shows   |
|                              | every node's proposal, size, and frame.                                     |

Design note from SwiftUI's actual machinery: Tessera copies the useful mental model, not
the hidden implementation. View values are disposable descriptions; the persistent state
is the runtime graph. A runtime node is semantic/debug structure, not a terminal resource.
Many nodes coalesce into one buffer render, and the terminal session remains the only
owner of modes and bytes.
