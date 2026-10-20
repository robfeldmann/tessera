# GraphQuery (plan 033, Spike 2)

Verdict: **pass**, with the caveats under [Findings](#findings).

## Hypothesis

`GraphDiagnostics` plus a `ScreenSnapshot` support locators `type=`, `id=`, `text=`,
`nth=`, a field-level node diff across a resize, and v0 invariants, with sorted-key JSON
output, using no `RuntimeNode` or `package`-level access.

Nothing outside `spikes/GraphQuery/` was edited. Dependencies are the `Tessera` and
`TesseraTerminalSnapshotSupport` products of the root package; every symbol used is
`public`.

## How to run

```sh
cd spikes/GraphQuery
swift test                                   # 30 Swift Testing tests
swift run graphquery demos                   # list fixture apps
swift run graphquery project --demo hello --pretty
swift run graphquery query --demo hello 'text="Hello"'
swift run graphquery query --demo hello type=Text 'text=Right'   # one clause per argv word
swift run graphquery project --demo hello --size 80x24 > before.json
swift run graphquery project --demo hello --size 80x24 --resize 40x16 > after.json
swift run graphquery diff before.json after.json
swift run graphquery check --demo overlap [RULE...]
swift run graphquery check --projection after.json
```

`query` and `check` take `--demo NAME [--size WxH] [--resize WxH]` or `--projection FILE`.
Every reply is one JSON object on stdout with an `ok` boolean; usage goes to stderr. Exit
codes: `0` ok, `1` no match or violations, `2` malformed request.

The executable target is `GraphQueryCLI` (product `graphquery`) because
`Sources/graphquery` and `Sources/GraphQuery` are the same directory on a case-insensitive
filesystem.

## What it contains

| File                                | Role                                                                          |
| ----------------------------------- | ----------------------------------------------------------------------------- |
| `Projection.swift`                  | `Projection(diagnostics:screen:)`: nodes, screen rows, counters, requirements |
| `TextAttribution.swift`             | recovers per-leaf text from the screen by paint order                         |
| `Locator.swift`                     | `type= id= text= text-exact= nth=` parser and resolver                        |
| `ProjectionDiff.swift`              | field-level diff keyed by identity path                                       |
| `Invariants.swift`                  | `check(_:rules:options:)` and the four v0 rules                               |
| `Reports.swift`                     | the JSON replies                                                              |
| `GraphSession.swift`, `Demos.swift` | a `ViewGraph` driver over public API and fixture apps                         |

`query`, `diff`, and `check` are pure functions of `Projection` values, so they run on
saved `.json` files as well as on a live session.

## Projection

Sorted-key JSON, one entry per node in pre-order (the order `ViewGraph.render` paints
leaves):

```text
path, parent, children, depth                 identity (NodeIdentity.description)
type, typeName, layout                         concise name, redacted reflected name,
                                               layout algorithm of a _LayoutContainer
proposal, measured, frame, clip                geometry
needsLayout, needsRender                       dirty flags
environmentOverrides, handlerKinds, requirements
text, textOverlaps                             attributed screen text (leaves only)
```

Plus `screen {columns, rows[], cursor}`, `statistics` (the counters and
`invalidationReasons`; the three `Duration`s are excluded because they are not
deterministic), `requirements`, and `version`. An 80x24 `hello` projection is 5,631 bytes
for 7 nodes; the screen rows are about a third of it.

## Locators

Clauses are whitespace separated and all must hold; `nth` (zero-based, tree order) applies
last whatever its position.

| Clause           | Matches                                                                                                                                    |
| ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `type=Text`      | module-free name, `Module.Type`, the full reflected name, or a `_LayoutContainer`'s layout name (`type=_FrameLayout`)                      |
| `id=PATH`        | the exact identity path, or a user id: the last path component is `explicit(X)` (`.id(X)`) or `id(X)` (`ForEach` key) and the value is `X` |
| `text="…"`       | the node's attributed text contains the substring                                                                                          |
| `text-exact="…"` | the node's attributed text equals the value after trimming whitespace                                                                      |
| `nth=N`          | the N-th survivor of the other clauses                                                                                                     |

On the command line a single argument is tokenised with double-quote support; several
arguments are one clause each, so `text=Hello, World` needs no quoting. A reply lists, per
clause, how many candidates remained (`steps`), so an agent sees which clause eliminated
the match. A no-match also lists `typesPresent`.

### How text-to-node attribution works

`GraphDiagnostics` holds no view values, so a node's text can only come from the screen.
At projection time:

1. Only **leaves** (nodes with no children) carry text. A container's rendered text is its
   leaves' text, and attributing it to the container would make every ancestor of a match
   also match.
2. Each leaf's paint region is its `clip` (always inside its `frame`) intersected with the
   screen. `Spacer`s and hidden nodes have empty regions and own nothing.
3. Leaves paint in `nodes` order, so for every cell the **last** leaf whose clip covers it
   is the one visible there: that is the tie-break for overlapping nodes. This is the same
   rule `ViewGraph.render` implements (pre-order, later overwrites earlier).
4. A leaf's `text` is the characters of the cells it owns, with cells owned by later
   leaves blanked, rows joined by `\n`, trailing blanks trimmed, empty leading and
   trailing rows dropped. The blank spacer cell after a wide grapheme is elided.
5. `textOverlaps` lists the other leaves that also cover a non-blank cell of this leaf's
   clip. The query reply sets `"ambiguous": true` when a text clause matched a node with
   overlaps.

Ambiguity rules, each pinned by a test:

- **Obscured text does not match.** In `overlap`, `AAAAAA` is drawn over by `BBBB`, so
  `text=AAAAAA` finds nothing and `text=AAA` finds the first Text with `ambiguous: true`.
- **Winner is the topmost leaf.** Two Texts in a `ZStack` resolve to the top one; the
  bottom one keeps only its uncovered cells.
- **A match must lie inside one leaf.** `HStack { Text("Hello"); Text("World") }` shows
  `HelloWorld`, but `text=HelloWorld` matches nothing.
- **Substring by default.** `text=Hello` matches both `Hello` and `Hello, World`;
  `text-exact=` or `nth=` disambiguates.
- **Ownership is geometric, not per-pixel.** A leaf is assumed to paint its whole clip. A
  leaf that covers cells but paints nothing (an empty custom leaf with extent) still
  steals ownership from earlier leaves. `textOverlaps` surfaces it; the projection cannot
  detect it, because it has no record of what each leaf wrote.
- **Identical text under identical geometry.** The later leaf owns the cells; the earlier
  has `text: null`. The locator still returns exactly one node.
- **Wide graphemes.** `Cell(character:).width == 2` marks the next cell as a spacer,
  because `RenderedCell` has no wide/spacer flag and the Ghostty snapshot returns a plain
  blank there.

## Diff

`diff before.json after.json` replies `ok:true` with `identical`, `added` and `removed`
(path, type, frame), `changed` (per path, per field: `before` / `after`), `statistics`,
`requirements`, and `screen {size, cursor, rows[]}` with the changed rows. It exits `0`
whether or not the projections differ; `identical` is the signal.

80x24 to 40x16 on `hello`, frames only:

```text
root                   VStack  0,0 80x24 -> 0,0 40x16
root/index(1)          HStack  0,1 80x1  -> 0,1 40x1
root/index(1)/index(1) Spacer  5,1 69x0  -> 5,1 29x0
root/index(1)/index(2) Text    75,1 5x1  -> 35,1 5x1      (text "Right")
```

`root/index(0)` (`Hello`) changes only `proposal` (width 80 to 40). All 24 screen rows
change. The cursor differs too, which is noise (see Findings).

## Invariants

| Rule                       | Severity | Meaning                                                                                               |
| -------------------------- | -------- | ----------------------------------------------------------------------------------------------------- |
| `no-dirty-after-pass`      | error    | any node with `needsLayout` or `needsRender`                                                          |
| `frame-inside-clip`        | warning  | a leaf with a non-empty frame whose `frame ∩ clip != frame`; the detail has the visible rect and text |
| `siblings-disjoint`        | error    | two children of a container have overlapping non-empty frames                                         |
| `measured-within-proposal` | error    | `measured` exceeds a constrained proposed axis                                                        |

`check` replies `ok:false` and exits `1` for any violation, warnings included.

Layout semantics each rule bakes in (all in `CheckOptions`):

- **`siblings-disjoint` exempts overlap by contract.**
  `CheckOptions.overlappingContainers` defaults to `["ZStack"]`, matched on
  `Node.layout ?? Node.type`. Every other container is held to disjoint children,
  including custom `Layout`s (`_LayoutContainer<StaggerLayout,…>` is checked) and
  `ForEach`. Any future overlay, popover, or modal container must be added to that set;
  the default fails loud rather than silent. Frames are compared, not clips, because this
  is a layout assertion; empty frames (spacers, hidden nodes) never overlap.
- **`frame-inside-clip` exempts scrolling.** Descendants of a `ScrollView`
  (`scrollingContainers`) are skipped, because clipping is the point. Only leaves are
  reported: a clipped container always has a clipped leaf to name.
- **`measured-within-proposal` skips never-placed nodes.** Hidden children keep a stale
  probe measurement (`place` assigns them an empty frame without re-measuring), so a node
  whose frame is empty and disagrees with its measurement is skipped.
- **`no-dirty-after-pass` needs a completed pass.** The projection does not record which
  pass produced it; the rule is meaningful only after `layoutIfNeeded()` and
  `render(into:)`. A projection of a never-rendered graph flags every node (tested).

Observed on the fixtures: `overlap` flags the `StaggerLayout` siblings and a clipped
`BBBB` but not the `ZStack`; `clipped` flags the Text under `frame-inside-clip` and
`measured-within-proposal`; `scroll`, `wide`, `hello` (at 80x24 and 40x16) are clean.

## Identity stability

`root/index(0)/explicit(submit)`-style paths are `NodeIdentity.description`. Tested:

- Across `graph.update()` on an unchanged tree (new root value, full reconcile) every path
  and every node field is identical; `diff` reports no added, removed, or changed nodes
  and no changed rows. Only the counters differ (`updateRequested`, `bodyEvaluations`).
- Across a text change the paths are unchanged.
- Across a conditional flip (`if flag { A } else { B }`) the subtree is rekeyed
  (`branch(true)` vs `branch(false)`), so its paths are all new.
- `ForEach` children are keyed (`id(KEY)`) and tuple children positional (`index(n)`).
  From `ViewGraph.reconcileChildren` (children reconcile by slot), keyed paths should
  survive reordering and positional paths shift when an earlier sibling is inserted or
  removed; that is read from the code, not tested.

## Proves / Does not prove

Proves:

- Locators, diff, and invariants work as pure functions over a value-only projection built
  from `GraphDiagnostics` + `ScreenSnapshot` with public API only.
- `text="Hello"` returns exactly one node with its frame; a no-match is `{"ok":false}`
  with exit `1`; the resize diff lists the changed frames; `check` flags a crafted overlap
  and a clipped Text.
- Output is byte-stable: two processes produce identical `project` output (`shasum`
  equal), and projection JSON round-trips through `Codable`.
- Paths are stable across `update()` on an unchanged tree.

Does not prove:

- Behaviour on Linux or Windows (`String(reflecting:)` formats, snapshot bytes). Only
  macOS arm64 was run.
- Text attribution for leaves that paint non-rectangular or partial regions, for styled
  text (style is not projected), or for a leaf painting outside its `frame` (clip bounds
  it, but a custom leaf could in principle write elsewhere).
- Any input path: `dispatch` is a no-op at this commit, so nothing about focus, handlers,
  or key routing is exercised.
- `requirements-aggregate` (listed in the plan's v0 set, not in this spike's brief).
- Scale: fixtures have at most 8 nodes. Cell ownership is `O(leaves x clip area)`.

## Findings

1. **Verdict.** Both fail conditions are avoided: paths are stable across `update()`, and
   overlapping text has a defined tie-break (topmost leaf) plus an explicit `textOverlaps`
   / `ambiguous` signal.
2. **What the projection lacks** (the plan's later locator keys cannot be served from
   `GraphDiagnostics` today):
   - **Text**: not in diagnostics at all; recovered from the screen as above.
   - **Role and label**: absent, so `role=` and `label=` need a new semantics field.
   - **Focus and focusability**: absent (`focusChanges` is a counter only), so `focused`
     and `focusable` locators and `exactly-one-focus` need schema.
   - **Handlers**: `handlerKinds` is projected but is `[]` for every node in these
     fixtures; there is no event or binding information beyond kind names.
   - **Which leaf painted which cell**, whether a pass completed, and whether a node was
     placed or hidden (stale `proposal` / `measured` on hidden nodes).
   - **View values** by design, so there is no way to ask "which node holds the string
     `Submit`" except through pixels.
3. **`type` names are not golden-safe as reflected.** `String(reflecting:)` gives
   `TesseraLayout.(unknown context at $…)._FrameLayout` for private types in another
   module, with a build-specific address, and `Pack{…}` for variadic tuples. The
   projection redacts the address to `(local)`, keeps the reflected `typeName`, and adds
   concise `type` (`VStack`) and `layout` (`_FrameLayout`, `StaggerLayout`). Recommend
   goldens and `tree.json` carry `type` and `layout` only, or that Core expose a concise,
   stable name.
4. **`frame`, `padding`, and custom layouts all project as `_LayoutContainer`.** Without
   the `layout` field they are indistinguishable by `type=`.
5. **Surprise: `ForEach` inside a stack is not flattened at this commit.**
   `VStack { Text; ForEach(...) }` (and `VStack { ForEach(...) }`) makes the `ForEach` one
   stack child, and its keyed children are all placed at its origin, so rows overlay
   (`nested-foreach` demo; `siblings-disjoint` flags `id(b)` against `id(a)`, and `id=a`
   has `text: null`). `_visitLayoutChildren` flattens only a top-level `_ViewList`. Not
   verified whether this is intended; the invariant caught it unprompted.
6. **`Text` ignores its proposal** (`sizeThatFits` is width-independent), so every
   truncated Text triggers both `frame-inside-clip` and `measured-within-proposal` on the
   same node. Expect that to vanish when Text wraps (the catalog now says wrap by
   default); until then the plan should dedupe or tolerate the pair.
7. **`screen.cursor` is noise in diffs** (it follows the last write). Recommend the
   default diff ignore it or show it under a separate key.
8. **`RenderedCell` has no wide or spacer flag**; a wide grapheme's second cell is a plain
   blank. A seam exposing it (or a `ScreenSnapshot` row-text accessor that elides spacers)
   would remove the `Cell.width` recomputation.
9. **`effectiveTerminalRequirements` is always `nil`** from `ViewGraph.diagnostics`; the
   projection carries it as optional.
10. **`GraphStatistics` fields are readable** (only setters are `package`), so counters
    and `invalidationReasons` project without a seam. Durations are non-deterministic and
    excluded.
11. **Public reach is sufficient.** `Rect`, `TerminalSize`, `Cell`, and `ProposedSize`
    come through the `Tessera` umbrella product's `@_exported` imports; no module beyond
    the two products was needed, and nothing required `package` access.
12. **Package identity.** A path dependency's identity is its directory name, so the
    manifest says `package: "devtools"` (the worktree directory), not `"tessera"`. Spikes
    copied into the root package in Phase A.3 drop this.
13. **Cost.** `swift run graphquery query --demo hello 'text="Hello"'` takes about 20 ms
    wall (process start, Ghostty VT, render, projection, query) in a debug build.
