---
type: spec
description: "Testing posture: Tessera-native oracles"
---

# Testing posture: Tessera-native oracles

SwiftUI is a useful API reference, not Tessera's correctness oracle. Phase 4 behavior is
graded against this spec and Tessera's terminal substrate:

- Layout tests use exact integer tables from the normative algorithms. There is no
  tolerance: cells and frames either match or the rule is wrong.
- Render tests compare cell buffers and `VirtualTerminal` snapshots, including style,
  clipping, wide grapheme continuation cells, and paint order.
- Event tests use constructed trees and exact routing tables; the graph never consumes an
  input unless a user-installed handler says so.
- Reconciliation tests count work that would otherwise be invisible: body evaluations,
  equatable skips, node creates/destroys, and `NodeState` lifetime.
- Demo tests drive each component's standalone demo headlessly from a scripted list of
  input events into `VirtualTerminal` and snapshot it at `desktop` (80x24) and `mobile`
  (40x16); plan 032 Phase 8 builds that driver, so a demo's snapshot test is a few lines.
- Absence is tested explicitly: no out-of-bounds writes, no hidden key handling, no stale
  focus, no terminal mode ownership in views, and no forbidden imports.
