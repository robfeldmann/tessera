---
type: spec
description: "Definition of done for Phase 4"
---

# Definition of done for Phase 4

1. All seven slices' definitions of done hold, and so does the acceptance of each step in plan 032 Phases 8–17.
2. The Phase 4 intro app, assembled from the per-component demos, is the integration proof: it composes the 1.0 surface with stacks, flex, borders, focus, mouse, and controlled widgets, driven by a plain model object — and by an `@Observable` variant — proving architecture-agnosticism.
3. `graph.dump()` and `statistics` are good enough that every "why did it render/focus/ lay out like that" question in this phase's development was answered with them, not with print statements. (If they weren't, fix the tools.)
4. The source import-boundary test passes, and the package graph boundary checker is wired into `just quality lint`.
5. The view layer never imports `TesseraTerminalIO`; everything reaches the terminal through `Frame`/`TerminalSession` and declared `TerminalRequirements`.
6. View-layer targets do not import SwiftUI, AppKit, UIKit, or platform IO shims.
7. Each implemented catalog doc has moved its durable content into DocC and is marked `implemented`, and the performance budgets above hold.

**End of Phase 4:** the library does what it says on the tin. You can build real TUI apps.
