# Phase 4 implementation review packet

The remaining P4.4–P4.8 implementation is committed and host-validated. All eight specimens
launch directly and produce real-rendered replay evidence. Full platform graduation is
**not complete**: Linux compilation failed on a compiler/SDK mismatch, Linux and Windows
runtime checks remain unavailable, and human API/style and visual approval remain open.

## Run and inspect

Worktree: `/Users/rob/Developer/robfeldmann/tessera/tessera-phase4-review-loop`.
Branch: `phase4-review-loop`. Use this directory, not the original `phase4`.

```sh
swift run --package-path Examples TesseraLab list
swift run --package-path Examples TesseraLab run settings
swift run --package-path Examples TesseraLab run records
```

The complete registry is `layout`, `button`, `viewport`, `settings`, `collections`,
`panes`, `navigation`, and `records`. Each supports `TesseraLab run <id>`.
Tab/Shift-Tab traverse where installed; q quits only when the focused control does not
consume it. In a TextField, q is ordinary text: Tab out before quitting.

```sh
for id in layout button viewport settings collections panes navigation records; do
  scripts/capture-specimen.sh "$id" ".artifacts/review/$id"
done
```

Capture needs no interactive terminal or GUI permission. It uses the shared application
driver, parser/session boundary, renderer/encoder, and persistent Ghostty virtual terminal.
The wrapper supplies process-local macOS test-framework paths; the live executable does
not depend on test support. New captures record the current checkout revision.

## Commits and review order

Start from the previous published packet, `b668977`:

1. `9119ef3`: interactive viewport, editing, controlled controls, collections, panes,
   navigation, direct examples, Unicode cell export, tests, and durable documentation.
2. `5a22022`: Section height budgeting and extreme-spacing safety; retained record pane
   state; meaningful keyboard/divider replay; focused regressions and final status docs.
3. The following packet commit: saved evidence and execution/review status only.

Final implementation revision: `5a22022150df0676a5d0f8b6d69c7bd77743a91e`.

Review the production boundary before the examples:

- Core: `InputLeafView`, event/pointer/hover routing, clipped hit targets, focus eligibility
  before first placement versus hidden compact roles, and terminal requirements.
- Widgets: controlled values remain in bindings. Node state contains only interaction
  state such as caret/selection, capture, hover, and focus-reveal bookkeeping.
- Layout: Section reserves header and spacing before proposing content height. Existing
  integer-cell/Flex and adjacent-pair SplitView negotiation remain the geometry model.
- Driver/session: graph requests remain distinct from effective terminal modes. Bracketed
  paste, focus, mouse, and keyboard requirements preserve the host's original baseline.
- Examples: settings owns plain mutable state; records uses explicit actions/reduction and
  owns pane sizing. Neither model is silently observed or stored in the graph.

## Component and API-friction map

Every row has a direct launch, replay, and an inspected image. Root behavioral coverage is
in the corresponding layout/widget tests; shared-driver and registry coverage is in the
separate Examples suite.

| Specimen | Accepted surface and replay | API-friction note |
| --- | --- | --- |
| `layout` | Text, stacks, style, initial/update/resize | Ordinary view composition; no inspector or application shell required. |
| `button` | Focus, legacy/phased keys, primary pointer, cancellation, held styles | Actions stay ordinary closures; generic labels and appearance composition remain available. |
| `viewport` | ScrollView offsets, reveal, nested boundary, wheel and resize | Nested viewports require explicit focus IDs and app-owned offset bindings, not pilot-forced focus. |
| `settings` | TextField, Toggle, Stepper, Picker, selection, paste, submit | Binding closures are repetitive but keep ownership explicit; no Form or store abstraction was added. |
| `collections` | Section, keyed List, Grid, Table selection/sort intent/resize | Callers provide IDs and columns; no virtualization or data-source framework was introduced. |
| `panes` | SplitView keyboard/drag, hover enter/blur/reenter/leave | Pane sizing values are explicit app state; the sizing setup is the main boilerplate. |
| `navigation` | Controlled regular/compact role composition | Visibility and compact selection are app-owned; no Showcase breakpoints became framework rules. |
| `records` | Record/detail selection and retained divider sizing | A small explicit reducer works without automatic observation or framework-owned business state. |

The ownership requirement is demonstrated by plain and **reducer-style** examples, not by
an added Observation dependency. Public symbols and enduring contracts are documented in
DocC; catalog-deferred APIs were not invented to fill out this matrix.

## Saved images and critique

These are exact generated SVG files, not reconstructed illustrations:

- [Layout](artifacts/p48-layout.svg)
- [Button held](artifacts/p48-button-held.svg)
- [Nested viewport boundary](artifacts/p48-viewport-boundary.svg)
- [Settings after selected paste](artifacts/p48-settings-paste.svg)
- [Collections after correction](artifacts/p48-collections-after.svg)
- [Split divider drag](artifacts/p48-panes-drag.svg)
- [Hover entered](artifacts/p48-panes-hover.svg)
- [Compact navigation](artifacts/p48-navigation-compact.svg)
- [Record selection and retained pane resize](artifacts/p48-records-resized.svg)

The [failed collection image](artifacts/p48-collections-before.svg) preserves the actual
pre-fix overlap at `9119ef3`: multiline List content painted into the following Grid.
The final Section budget fixes the cause rather than covering the stray cells. The compact
result displays fewer list rows and leaves the Grid and Table legible. A composition
regression now covers the failure; extreme spacing is separately guarded against overflow.

The settings label remains above a single three-row editor while focused. Full-width focus
emphasis is conspicuous and remains provisional. Pane dividers and compact role controls
are visible, but narrow panes deliberately clip or wrap content rather than impersonating a
desktop layout. Review the spacing and emphasis policies as design choices, not approved
baselines. No numeric contrast or font-rasterization claim is made.

Actual images were opened in explicitly spawned, isolated headless Helium. The final
collection and record images were opened from the final code revision; seven other saved
previews were byte-identical to already inspected images. No browser relay was used in this
continuation. SVGs use canonical terminal cell widths and a generic monospace font; the
captured cells, not browser glyph rasterization, are authoritative. A magenta outline marks
the recorded cursor coordinate, not observed cursor visibility or shape.

## Replay and provenance

[Provenance and checksums](artifacts/p48-provenance.json) and
[all 16 manifests](artifacts/p48-manifests.json) identify **232 checkpoints** at 40x16 and
80x24 starting sizes. Each final manifest reports the implementation revision above and
`sourceDirty: false`. The older failed collection image has its own explicit revision.

Local complete bundles are:

```text
.artifacts/phase4-review-loop/p48-published/
.artifacts/phase4-review-loop/p48-published-repeat/
```

`diff -rq` returned 0 with no differences across JSON, input traces, text, graph diagnostics,
SVGs, and manifests. Both runs used the graph-managed truecolor profile. This is not a
claim that every visual has been reviewed under every terminal/color/font combination.

Observed intermediate consequences include:

- At both sizes, the inner viewport reaches offset `0,6`; the next Down leaves it there
  and moves the outer viewport to `0,1`.
- Settings changes to `Grace`, volume 4, disabled toggle, and submission count 1.
- Hover is true on enter, false on terminal blur, true on reentry, and false on leave.
- Records selects ID 2 through ordinary keyboard input; divider drag changes requested
  ideals from `28,48` to `36,40`, retained after release and update.
- Button replay retains press/repeat/release and outside/blur/disable/removal cancellation
  checkpoints; selectors inject ordinary input rather than calling action closures.

## Final host validation

Commands run after the last production edit:

| Command | Result |
| --- | --- |
| `swift test --filter CollectionsTests` | 9 passed |
| `swift test --package-path Examples --filter SpecimenRegistryTests` | 5 passed |
| `just core test` | 786 passed |
| `swift test --package-path Examples` | 37 passed |
| `just quality format` | Passed; scoped formatting diff inspected |
| `just quality lint` | Passed; 0 SwiftLint violations |
| `just quality architecture` | Passed |
| `just docs lint` | Passed |
| `pnpx markdownlint-cli` on changed Markdown | Passed |

All eight live specimen commands launched through PTYs and exited 0 on q. In settings,
Tab then q inserted text rather than quitting. Home, Shift-End, bracketed paste `Grace`,
and Enter produced `Grace` and `Submitted: 1`; Tab then q exited and the alternate-screen
projection cleared. The final records app received Tab, Tab, Enter and emitted Waypoint's
app-owned detail, then exited 0. Protocol replay supplies the finer intermediate-state
and divider assertions; host PTY smoke does not certify Linux or Windows behavior.

## Measured performance

[Raw results](artifacts/p48-performance.json) and
[machine/configuration/method](artifacts/p48-performance-context.json) record a release
benchmark on Apple M5 Max, arm64 macOS, Swift 6.3.3, Xcode 26.6. It uses 200 keyed leaves
plus the root at 200x50, updates visible leaf 20, and resizes to 180x45. Seven samples per
scenario used actual graph work and terminal presentation; counters were deterministic.

| Scenario | Median wall ms | Min–max ms | Flushed bytes per sample |
| --- | ---: | ---: | ---: |
| Initial | 2.577 | 2.262–3.044 | 10359 |
| Forced unchanged presentation | 1.330 | 1.267–1.872 | 10 |
| One visible leaf update | 1.357 | 1.259–1.373 | 25 |
| Resize | 1.870 | 1.820–2.022 | 8424 |

The unchanged case intentionally forces a draw; it is not an idle-driver benchmark and
does not emit zero bytes. These measurements are evidence for this machine/configuration,
not a cross-platform latency guarantee. The temporary harness stayed outside the
repository; no permanent production target or performance dependency was added.

## Unclosed gates and source preservation

- **Failed Linux static build:** `just linux build` reached compilation, then Swift 6.3.3
  rejected modules from the installed Swift 6.3.2 static SDK. `swift sdk list`,
  `swiftly list`, and local Toolchains directories found no matching installed compiler.
- **Unrun Linux runtime:** the known VM is stopped; the packet forbids VM bootstrap.
- **Unrun Windows runtime:** the configured Frost CLI is unavailable and no running usable
  UTM guest was available. No VM, toolchain, or system-tool installation was attempted.

A matching Linux compiler/SDK and usable Linux/Windows runtime environments are required
before those gates can close. PLAN.md intentionally remains `in-progress`; host success
is not reported as complete platform graduation. Human API/style and visual-baseline
approval also remains open. Broad gestures, IME pre-edit, cross-view text selection, and
explicitly deferred catalog surfaces remain outside this accepted scope.

The original `phase4` remains at `f1061a0224bbbfe01a04d95f74ad660acc40454a`, with the same
five dirty-file hashes and staged-entry listing. [STATE.md](STATE.md) preserves the earlier
source-preservation incident: restored file/index contents match, but original raw index
bytes were not preserved. This continuation's read-only checks match the post-incident
index hash; no new original-worktree changes are claimed.

Publication is limited to the normal feature branch. No PR, merge, main push, release,
force-push, or human baseline approval is part of this handoff.
