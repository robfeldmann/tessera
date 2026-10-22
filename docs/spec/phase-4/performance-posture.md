---
type: spec
description: "Phase 4 performance posture"
---

# Phase 4 performance posture

- Budgets (same spirit as Phase 2 Slice 4): full update+layout+render of a 200-node tree at 200×50 in well under a frame at 60 Hz on a laptop; `statistics` records pass durations and work counters so regressions are measurable, not vibes.
- The deliberate simplicities — full relayout, full repaint into the buffer, existential reconciliation — are recorded here as the future optimization surface (dirty-subtree layout, render skipping with overlap analysis, reconciler devirtualization, `@inlinable` audit). None of them may be taken early without a benchmark showing the simple pass missing budget, and any optimization must preserve the same `dump()`/`statistics` observability.
- General animation (transitions and interpolated presentation values) is not Phase 4; only the clock-driven motion views above are. If it lands later, app/model state jumps to the destination, presentation state is derived from an explicit animation record and deterministic clock, and tests sample the presentation values. A terminal runtime has no Core Animation render server, so it must not promise off-main-thread animation smoothness.
