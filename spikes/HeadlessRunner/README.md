# Spike 1 — HeadlessRunner

Plan 033, Spike 1. A standalone package that depends on Tessera by path (`../..`) and uses public API only.

The code has since been copied into the root package's `TesseraHarness` target and `TesseraHarnessTests` (plan 036 Slice 3), where it is maintained. This package stays as frozen evidence.

## Hypothesis

A scenario file with `size`, `resize`, `key`, `type`, `shot`, `expect text`, `expect node … frame`, and `tree` can drive a HEAD app (Text, stacks, ScrollView, SplitView) through `ViewGraph` + `VirtualTerminal.snapshot`, emit the JSON and exit-code contract byte-identically across two runs, and derive `mobile` natural height from `GraphDiagnostics` under a tall proposal.

## How to run

```sh
cd spikes/HeadlessRunner
swift run headless run Scenarios/*.scn --json         # one JSON line per file, exit 0
swift run headless run Scenarios/failing/mismatch.scn # human form, exit 1
swift run headless run Scenarios/stack-mobile.scn --out /tmp/shots   # writes NAME.txt, NAME.tree.txt
swift run headless natural workspace --width 40       # natural-height probe
swift test                                            # 18 Swift Testing tests
```

Exit codes: `0` all passed, `1` an expectation failed (or the app could not satisfy `size`), `2` usage or parse error. Parse errors under `--json` are a failure with verb `parse`.

## Layout

- `Sources/HeadlessKit/Scenario.swift` — v0 grammar, shell-style tokenizer, fail-fast parser (`FILE:LINE: error:`; header statements bind before the first body statement).
- `KeyName.swift`, `Locator.swift` — Playwright-style key names; `type= id= text= nth=`.
- `Driver.swift` — `DemoApp` protocol and the per-event loop.
- `Registry.swift`, `Demos.swift` — two demos (`workspace`: header + `SplitView` of a `ScrollView` catalog and an inspector + status; `stack`: natural-height stacks) and the natural-height probe.
- `Runner.swift`, `Report.swift`, `CLI.swift` — execution, the single report type with JSON and human forms, hand-rolled argument parsing.
- `Scenarios/*.scn` pass; `Scenarios/failing/mismatch.scn` fails on purpose.

## The driver loop

`Driver.send(event)`: `resize` → `graph.resize` → `graph.dispatch` (returns `.ignored`) → `app.apply(event)` → `graph.update()` → `VirtualTerminal.snapshot { graph.render(into:) }`. One update and one presentation per event, including one event per character of `type`.

### How `key` / `type` are handled (`ViewGraph.dispatch` is a stub)

`ViewGraph.dispatch` returns `.ignored` for every event (investigation 039), so no view sees input. The demo owns its model (`DemoApp: AnyObject`, `root` reads it, `apply(_:)` mutates it), and `Driver` calls `apply` after `dispatch`. `key` becomes `.key(Key(code:modifiers:))`; `type "abc"` becomes one `.key(.character)` press per character (not `.paste`). `ScrollView` offset is a demo `Binding`; pane focus in `workspace` is a demo-owned string, not graph focus.

Seam real input needs: `dispatch` must route to a handler registered on a node (`NodeDiagnostics` already exposes `handlerKinds`; focus is not in the projection yet) and return a disposition the driver can trace; then `apply` shrinks to the events the graph ignored. The harness already calls `dispatch` first and records nothing about its result.

## Proves

- All eight verbs run against HEAD through public API only. Packages used: `Tessera` and `TesseraTerminalSnapshotSupport`; nothing `package`-level was needed (the spike does not fail on the "needs package API" criterion).
- Contract: one compact sorted-key JSON line per file with `scenario`, `passed`, `failures` (plus `observations`); exit 0/1/2 as specified, observed below; a failing `expect text` reports `expected`, `actual`, and the `screen` rows; the run continues after a failure.
- Determinism: two runs of the corpus produce identical bytes.
- `GraphDiagnostics` carries what `expect node … frame`, `tree`, locators, and natural height need (`frame`, `clip`, `measuredSize`, `parentIdentity`, `viewType`, `identity`).
- Responsive collapse (`workspace` at 50 columns) is observable: the catalog pane frame becomes `0,2,0x0` and the inspector takes `0,2,50x8`.

## Does not prove

- Real input routing, focus, or handlers (`dispatch` is a stub); `key` reaches only demo-owned state.
- Differential rendering: `VirtualTerminal.snapshot` allocates a fresh `Buffer` and Ghostty terminal per call, so every step is a full-frame render (no cross-step cursor/scrollback or diff-renderer state).
- Style assertions, `shot` SVG/grid shots, invariants, diffs, clock/`wait`, mouse, paste/bytes. `shot` writes `NAME.txt` and a plain `NAME.tree.txt`, not the plan's `.grid.txt` / `.tree.json`.
- Windows, and a release-build timing.

## Observed

```text
$ swift run headless run Scenarios/*.scn --json > r1.json; echo $?     # 0
$ swift run headless run Scenarios/*.scn --json > r2.json
$ shasum r1.json r2.json
ddecb4cdd268c4a9a605b53db152f735ed4f7267  r1.json
ddecb4cdd268c4a9a605b53db152f735ed4f7267  r2.json            # 4 lines, 6432 bytes
$ headless run Scenarios/*.scn Scenarios/failing/mismatch.scn --json   # exit 1; shasum identical x2
e2377cecd1b515c4ae2c3db3c1872f698fe13be9
$ headless run bad.scn --json                                           # exit 2
{"failures":[{"line":3,"message":"/tmp/hr/bad.scn:3: error: unknown statement `blink`;
 accepted: app, size, resize, key, type, shot, tree, expect text, expect node",
 "statement":"","verb":"parse"}],"observations":[],"passed":false,"scenario":"/tmp/hr/bad.scn"}
$ headless run                                                          # exit 2 (usage)
$ headless run Scenarios/failing/mismatch.scn                           # exit 1
FAIL Scenarios/failing/mismatch.scn
  line 6: expect text 0 "Stack demos"
    row 0 text differs
    expected: Stack demos
    actual:   Stack demo
    screen:
      0| Stack demo
      ...
  line 10: expect node type=Missing frame 0,0,1x1
    locator `type=Missing` matches no node
    actual:   (no node; types: VStack, Text, Divider, HStack, Spacer)
```

Whole corpus, debug build, including process start: `real 0m0.117s`. `--out` rewrites a file only when bytes differ (mtime unchanged after a 2 s wait).

## Mobile natural height

Measure: render at 40 columns with a 500-row proposal and read the root node's `measuredSize.rows` from `GraphDiagnostics`.

```text
headless natural stack --width 40      stack     root_rows=6   fills_proposal=false
headless natural workspace --width 40  workspace root_rows=500 fills_proposal=true
```

- `stack` (Text, Divider, HStack with Spacer) gives 6 rows, the same at 80 columns because `Text` does not wrap at HEAD; `size mobile` then renders 40x6.
- A demo containing `ScrollView` or `SplitView` fills the proposal (`ScrollView._sizeThatFits` returns `proposal.height ?? contentHeight`), so the root measures to exactly the probe. The projection cannot tell "greedy" from "exactly 500 tall"; the driver treats `rows == probeRows` as "no natural height" and `size mobile` fails with a message pointing at `mobileScreen` (40x16), which matches the plan's split between `mobile` and `mobileScreen`.
- `ViewGraph.layoutIfNeeded` always proposes `ProposedSize(width: size.columns, height: size.rows)`; public API cannot propose `height: nil`. [INFERENCE, not tried: a nil-height proposal would make `ScrollView` report its content height and give a true natural height for greedy demos.]

## Findings for the plan

1. Verdict **pass**: the grammar, JSON and exit contract, determinism, and natural-height derivation work through public API. One caveat: natural height is unavailable for any demo that contains a height-greedy view, so `Viewport.mobile` must be an explicit per-demo choice or error, not a default.
2. Package identity: SwiftPM derives the identity of a path dependency from the directory name (`devtools` at the time), not from the root manifest's `name: "tessera"`, so the manifest first said `package: "devtools"`. The port to main (plan 035 Step 3.2) pins it with `.package(name: "tessera", path: "../..")`, which holds for any checkout name. Phase A.3's copy-migration removes it.
3. `diagnostics.statistics` holds `Duration` fields (`updateDuration`, `layoutDuration`, `renderDuration`); they are not byte-stable. The projection must exclude durations (the plan's trace "statistics delta" needs counters only). `GraphStatistics`' counters are `public package(set)`, readable and stable.
4. `NodeIdentity.description` is `root/index(2)/id(catalog)/index(0)`; the `SplitView` divider is `explicit(_SplitViewDividerID(leading: AnyHashable("catalog"), ...))`, a Swift description rather than a designed id. `id=` locators on it are brittle; prefer `type=` plus `nth=` or a designed id scheme. `viewType` is a reflected name with generics (`TesseraWidgets.ScrollView<…>`); `Locator.baseTypeName` strips module and generics, and framework-private types show up (`_SplitPane`), so `type=` should be documented as including them.
5. `ForEach` inside a `VStack` lays every item out at one frame in the layout-only tree (30 items, each `frame=0,2,6x1`); the spike works around it with a multi-line `Text`. Worth a separate bug before demos use `ForEach`.
6. `Spacer` in an `HStack` has `frame 4,3,51x0` (zero height); `Text` is non-wrapping and clips instead (relevant to `mobile` fixtures).
7. Keys: terminals report Ctrl/Alt/Meta chords with the lowercase base letter. `key Ctrl+C` must normalise to `.character("c")` plus `.control` or demos matching `"c"` never fire. The harness owns that normalisation (done in `KeyName`). `Shift+Tab` is `Key(code: .tab, modifiers: .shift)`; a real terminal sends backtab, which the parser may map differently.
8. Grammar choices the plan should confirm: `expect text "…"` (no row) is substring-on-any-row while `expect text ROW "…"` is whole-row equality after trailing-space trim; `expect node` accepts `frame X,Y,WxH` and the plan's `X,Y WxH`; a locator matching several nodes without `nth=` is a failure (strict), and one matching none is a failure that names the node types present; `size`/`app` after the first body statement is a parse error naming `resize`. `tree` takes no selector yet and emits one line per node (`identity type frame=… clip=…`).
9. Failure payload that worked for agents: `{line, statement, verb, message, expected, actual, screen[]}`; `screen` drops trailing empty rows so a 500-row probe stays small. JSON is about 1.5 KB per passing scenario with one `shot` and 2.1 KB per failing scenario (screen repeated per failure); consider one `screen` per scenario or on request if corpora grow.
10. `VirtualTerminal.snapshot(size:draw:)` is sufficient for text. Style assertions would use `ScreenSnapshot.cells`; nothing in this spike needed more than `character`.
