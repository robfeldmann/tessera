---
type: spec
description: "Testing posture: Tessera-native oracles"
---

# Testing posture: Tessera-native oracles

SwiftUI is a useful API reference, not Tessera's correctness oracle. Phase 4 behavior is graded against this spec and Tessera's terminal substrate:

- Layout tests use exact integer tables from the normative algorithms. There is no tolerance: cells and frames either match or the rule is wrong.
- Render tests compare cell buffers and `VirtualTerminal` snapshots, including style, clipping, wide grapheme continuation cells, and paint order.
- Event tests use constructed trees and exact routing tables; the graph never consumes an input unless a user-installed handler says so.
- Reconciliation tests count work that would otherwise be invisible: body evaluations, equatable skips, node creates/destroys, and `NodeState` lifetime.
- Demo tests drive each component's standalone demo headlessly through the harness's driver, which takes the same drawing path as a live run, from a scripted list of input events into a `VirtualTerminal`, and snapshot it at each viewport the demo declares: `desktop` (80x24), `mobile` (40 columns at the demo's natural height), and `mobileScreen` (40x16). A demo's snapshot test is a few lines.
- Scenario tests are the behaviour layer. A scenario is a text file that names an app, a terminal size, and a terminal, sends input (`key`, `type`, `paste`, `bytes`, `resize`), and asserts what the screen and the node tree show (`expect text`, `expect screen`, `expect node`) and what a `shot` compares with its committed text golden; a failed expectation is recorded and the run continues, so one run reports every failure. `check` is the third part of the layer: named structural invariants over the same run, added with the projection they read. The `TesseraHarness` library runs scenarios from `swift test` (`ScenarioRunner`) and from a development executable (`HarnessCLI`), so an app outside this repository tests and checks itself the same way; CI runs `tessera run Examples/Scenarios` on macOS, Linux, and Windows beside the Swift tests. Scenarios sit beside snapshots and unit tests, not in place of them: a scenario states behavior in a language an agent can write without reading Tessera's source, a snapshot pins a render, and a unit test pins a rule. Committed goldens are text only, and drift fails unless a run is told to record. The design is [Developer tooling](../../architecture/developer-tooling.md), which each tooling change keeps current.
- Absence is tested explicitly: no out-of-bounds writes, no hidden key handling, no stale focus, no terminal mode ownership in views, and no forbidden imports.
