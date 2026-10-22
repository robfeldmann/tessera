---
type: spec
description: "Motion views and the tick requirement"
---

# Motion views and the tick requirement

Phase 4 has one motion path, delivered by plan 032 step 16.1. A motion view derives its
frame from a clock environment value, an instant that the app or the Phase 5 runtime
supplies, and stores no timer and no state: the indeterminate
[`ProgressView`](../../design/widgets/progress-view.md) spinner draws frame
`(now / interval) mod frames.count`. Each motion view declares a tick requirement with its
frame interval, and the graph aggregates it over live nodes like `TerminalRequirements`,
so whoever drives the graph knows whether, and how often, to redraw. Tests set the clock
and sample frames; nothing sleeps. Step 16.1 settles the Swift spellings of the clock
value and the tick requirement. Tessera has no reduced-motion setting in 1.0
([spinners](../../design/tokens.md#spinners)).
