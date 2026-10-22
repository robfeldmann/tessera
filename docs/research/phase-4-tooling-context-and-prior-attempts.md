---
type: research
observed: 2026-10-19
status: resolved
description: Phase 4 tooling context and prior attempts
---

# Phase 4 tooling context and prior attempts

## Question

What tooling does Phase 4 already plan (demo runner, headless driver, viewport sizes), what prior tooling attempts exist and why were they abandoned, which pieces are slated for porting, and what must the devtools satisfy for the Phase 4 workflow?

Citations are to the main working copy (`tessera/main`, uncommitted work included) unless a tag is named. Archived code is cited as `archive/<tag>:<path>` and was read with `git show`. Nothing was built, linted, or tested.

## Outcome

- Phase 4 already plans one developer tool: a demo runner with a headless driver (plan 032 Phase 8). One executable lists and runs small demos by name. The headless driver renders any demo at fixed sizes from scripted input into `VirtualTerminal`, and demo renders are snapshot fixtures. Everything else is existing substrate (diagnostics, snapshot helpers, architecture gates, the wireframe checker) or not yet specified.
- Viewport sizes disagree across sources. `docs/design/tokens.md` and `docs/design.md` define `mobile` as 40 columns at natural height. Plan 032 Phase 8.2, the widget template, and several catalog docs still assume a 40x16 frame. Devtools need one answer before they hard-code sizes.
- Two Phase 4 lines carried demo or capture harnesses (`archive/phase4`, `archive/phase4-review-loop`). `archive/catalog-workbench` is a separate review app. The only written analysis of why the Phase 4 lines were abandoned is investigation 036. Its causes: controls built before pointer input, docs written after code, state-ownership defects, a pressed state that never rendered, test affordances leaking into public API, and process weight. The Showcase was superseded on 2026-10-10. The repository records no reason for abandoning the catalog workbench.
- The omp2 capture program and review site have no commit at all. `DevTools/omp2-gallery/` and `scripts/omp2-gallery*` exist only in the working copy. Plan 032 step 7.4 deletes them. Whether any piece survives needs a decision before that step.
- Hard constraint: the frozen diagnostics snapshot is local-only and has "no serialization, persistence, logging, telemetry, or remote transport" (`docs/spec.md:7422-7440`). A control socket or remote inspector cannot read `TesseraCore` directly. Export belongs in test or example support, where the review loop put its JSON.
- Porting candidates are in the port map below: the demo driver and key matching, styling, focus and responder routing, ScrollView and ScrollIndicator, pointer capture, and controls. Review bundles, committed captures, the Showcase, and the review-loop process documents are excluded (plan 032 `:507-509`).

## Phase 4 status as of 2026-10-19

Plan 032 (`docs/plans/omp2-reference-gallery-and-phase-4-redesign.md`, updated 2026-10-10) is the live Phase 4 plan. Plan 030 (`docs/plans/phase-4-view-layer-and-showcase.md`) is superseded by it.

- Done: Phases 1-4 (inventory, capture program, every renderable component captured, classification). Phase 5 is the owner taste review (`:345-415`).
- Done, committed: step 5.2 catalog wireframes (`e5fe358`, `31966cc`, both 2026-10-19; `:369` onward).
- Open: 5.3 token proposals (`:433`), 6.1 Rust-to-Swift translation key (`:445`), 7.1 per-component Swift docs (`:457`), 7.2 Spec and tokens amendments after owner confirmation (`:464-473`), 7.4 scaffolding removal (`:481-500`).
- Not started: Phases 8-17 (`:514-704`).
- `docs/project-status.md:83-99` lists the same sequence as roadmap steps and says, "Each step lands its components with tests and a demo." Step 5 is "The demo harness."

## Planned tooling for Phase 4

### Demo runner and headless driver (plan 032 Phase 8)

- Step 8.1 retires the Showcase (`:519-524`). It is still in main at `Examples/Sources/TesseraShowcase/` (376 lines) with tests in `Examples/Tests/TesseraShowcaseTests/`.
- Step 8.2 (`:526-537`): "One executable lists and runs demos by name; each demo is a small self-contained type." A headless driver renders any demo "at fixed sizes (`desktop` 80x24 and `mobile` 40x16 from `docs/design/tokens.md`) from a scripted list of input events into `VirtualTerminal`, so demo renders are snapshot fixtures, as in Textual's widget tests." Acceptance: "a demo runs live in a terminal and renders identically headless; the snapshot test for a demo is a few lines."
- Step 8.3 (`:539-543`) adds demos for the landed primitives: Text (with the archived Unicode demo), stacks and Spacer, frame and padding, ZStack, and Flex. Each needs coverage at both sizes and must "read well at 40x16."
- Amendment dated 2026-10-19 to step 7.4 (`:483-488`): the Tessera review pages and the Tokens page stay in the repository as "the seed of the live demo gallery (Phase 8, as in Textual's demo app): each wireframe is later replaced by the real, interactive, snapshot-tested widget." The plan also says to decide where those pages live, separate from third-party captures, before deleting anything.
- Decision record row (`:156`): "Each component lands with a small standalone demo that runs live and renders headlessly at fixed sizes; demo renders are snapshot fixtures."
- The Spec says Phase 4 components "are exercised by small per-component demos that double as snapshot fixtures" (`docs/spec.md:6828-6833`). Its Phase 4 definition of done requires an intro app assembled from those demos, driven by a plain model object and by an `@Observable` variant (`docs/spec.md:8363-8380`).

### Viewport sizes

| Source | Desktop | Mobile | Other |
| --- | --- | --- | --- |
| `docs/design/tokens.md:14-26` | 80x24, "default for CI fixtures" | 40 columns; components "work at natural height"; `40x16` only for screen-filling compositions | `min` declared per component |
| `docs/design.md:60-67` (owner, 2026-10-10) | same | "at 40 columns, not padded to a 40x16 frame" | full-height mockups only when the screen is the point |
| `docs/design/templates/widget.md:38` | not listed | `mobile` (40x16) required to reach `wireframed` | `min` must be declared |
| `docs/design/widgets/scroll-view.md:368` | not listed | "the required `40x16` fixture" | none |
| `docs/design/primitives/picker.md:261` | not listed | "40 columns wide at natural height" | none |
| plan 032 Phase 8.2 (`:528-530`) | 80x24 "from `docs/design/tokens.md`" | 40x16 "from `docs/design/tokens.md`" | none |
| `docs/spec.md:~7866-7876` (Phase 2.5 DoD, from notes) | 80x24 evidence | 40x16 evidence | 120x24 evidence |
| `archive/phase4-review-loop:Examples/Sources/TesseraCapture/TesseraCapture.swift:41` | 80x24 | 40x16 | captures both sizes for every specimen |

Inference: the natural-height rule (`docs/design.md`, owner decision 2026-10-10) is the newer decision. The template, one Spec paragraph, and Phase 8.2 still assume a 40x16 frame. Devtools should take the size list from one place and let each demo declare its own minimum.

### Substrate already in main

- Graph surface: `ViewGraph` (`Sources/TesseraCore/Runtime/ViewGraph.swift`) exposes `terminalRequirements` (`:38`), `diagnostics` (`:53`), `update()` (`:78`), `render(into:)` (`:111`), `resize(to:)` (`:127`), `dispatch(_:)` (`:139`), and `dump()` (`:144`). Diagnostics types live in `Sources/TesseraCore/Diagnostics/` (`GraphDiagnostics`, `GraphStatistics`, `NodeDiagnostics`).
- Test snapshots: `Sources/TesseraTestSupport/ViewGraphSnapshotting.swift:6` provides `.viewGraph`; `Sources/TesseraTestSupport/GraphDiagnosticsSnapshotting.swift:7` provides `.diagnostics`. `Sources/TesseraTerminalTestSupport/VirtualTerminalSnapshotting.swift` provides `.terminalDebugDump` (`:16`), `.terminalText(trim:)` (`:23`), `.terminalStyledGrid` (`:32`), and `.terminalLinksGrid` (`:46`). The styled grid follows the Spec's representation (`docs/spec.md:931`).
- Terminal: `VirtualTerminal` (`Sources/TesseraTerminalSnapshotSupport/`) is backed by Ghostty (`VirtualTerminal+Ghostty.swift`) with a fallback when Ghostty is unavailable (`VirtualTerminal+ghosttyUnavailable.swift`). `InMemoryTerminalSession.withApplicationTerminal` (`Sources/TesseraTerminalTestSupport/InMemoryTerminalSession.swift:39`) runs the session lifecycle against memory.
- Architecture gates: `just quality architecture` runs `check-package-boundaries.py` and `check-frame-region-ownership.sh`. `Tests/TesseraArchitectureTests/ImportBoundaryTests.swift` covers imports.
- Catalog gate: `scripts/check-wireframes.py` (705 lines) with 19 unit tests in `scripts/test_check_wireframes.py` (228 lines), run from `just quality wireframes` (`justfiles/quality.just`). The checker validates dimensions, trailing whitespace, tabs, and box geometry. It does not check states, callouts, or style grids (`docs/design.md:162-165`, "Style grids are not linted"), and it does not check whether a demo exists for a wireframe.
- Current demos in `Examples/Sources/`: `HelloTessera`, `InputInspector`, `LifecycleModesDemo`, `Phase3ProtocolsDemo` (with support), `RendererDemo`, `ANSIEncoderDemo`, and `TesseraShowcase`. None is a catalog demo, and none sits behind a shared registry.

### Spec and plan constraints that bind tooling

- Diagnostics schema is frozen and local-only. It excludes "controlled values, raw view values, raw input, raw terminal bytes, `NodeState`, closures, and borrowed regions" (`docs/spec.md:7422-7440`).
- `dump()` is "the primary debugger, not a pretty extra" (`docs/spec.md:7416`). The Spec's rule: fix `dump()` or `statistics` rather than adding a print (`:7416-7424`). The Phase 4 DoD repeats it: "`graph.dump()` and `statistics` are good enough that every 'why did it render/focus' question..." (`:8368-8372`).
- Widget tests "remain deterministic state-machine tests with no terminal and no clocks" (`docs/spec.md:8339-8346`). Plan 030 Step 0.3 (`docs/plans/phase-4-view-layer-and-showcase.md:196-198`) forbids sleeps, `Task.yield()`, and live terminal dependence in diagnostic snapshots.
- Testing posture: exact integer tables, no tolerances, absence tested explicitly (`docs/spec.md:6936-6950`).
- Animation conflict. The Spec says "Animation is not Phase 4" (`docs/spec.md:8358`). Plan 032 Step 16.1 (`:683-686`) puts the animation path in Phase 16 (1.0), and `design/omp2-assessment.md` owner decision 3 (`:405-425`) does too.

### Catalog process as spec

- Status ladder and gates (`docs/design.md:32-58`): `ready` requires dependencies `ready` or `implemented` and open questions resolved. `implemented` requires DocC migration and wireframes landed as snapshot fixtures (`:302-322`; "CI enforces the pictures from then on," `:318-319`).
- Requirements are backticked sentences traced to a table row or wireframe state, and must be "assertable with graph + dispatch + buffer snapshot (no clocks, no live terminal)" (`docs/design.md:272-282`).
- Runtime ownership invariant (`docs/design.md:240-245`): "every `NodeState` row has exactly one live storage owner." Measurement and `body` stay pure; state changes only through event handling.
- Docs specify per-slice demo acceptance. Button's progressive slice sequence ends in a Phase 4 demo with named states (`docs/design/widgets/button.md:691-713`). Text's slice sequence (`docs/design/primitives/text.md:313-327`) and Decisions section say the Text demo "proves the public leaf through a real `ViewGraph` and `Frame`" (`:447-452`).
- Button's state model (`docs/design/widgets/button.md:580-595`) shows the state-owner pattern.
- Corpus, counted 2026-10-19: 42 primitive and widget docs (9 `ready`, 20 `specified`, 11 `wireframed`, 2 `sketch`) with 306 wireframe blocks in 40 of them.

### Owner review cadence

- "After each phase, pause for the owner's review before starting the next" (plan 032 `:512`).
- The precedent is the omp2 review. Decisions were captured in a local site with `design/omp2-review/feedback.json` (`design/omp2-review/README.md`) and then written into the catalog and `design/omp2-assessment.md` "Owner decisions" (`:405-425`).

## Prior attempts and lessons

| Attempt | Evidence | Tooling it carried | Why it ended | Lesson for devtools |
| --- | --- | --- | --- | --- |
| `archive/phase4` (tag; 37 commits from `0697fe2`, tip `f1061a0`, plus `wip` `3781bbc`) | `036:40-59`; commits `f193135`, `60b076b`, `8ffffc2`, `9dcc46e`, `5192e7f` (`03b8731` names `f193135` and `f1061a0`) | ArgumentParser runner (`Examples/Sources/TesseraGallery/Gallery.swift:26-29`); `DemoModel` protocol (`DemoHost.swift:11`), `DemoHost` (`:73`), `run` (`:86`), `isQuitKey` (`:204-206`); `DemoScaffold.swift`; demos hello, graph (905 lines), responder (758 lines), stacks (untested) | Demos were not snapshot-tested; Button tracked pressed state but passed `isPressed: false` to its style (`036:91-92`); TextField wrote state inside `sizeThatFits` (`036:86-87`) | The registry and live loop work. Keep the key matching. Make every demo snapshot-testable from the start. |
| `archive/phase4-review-loop` (tag; 19 commits from `0697fe2`, tip `b21e6a9`, plus `wip` `48cb42d`) | `036:61-72`; `9119ef3`, `87d3284`, `03b8731`, `18f80a4` | `ApplicationDriver` (`Examples/Sources/SpecimenSupport/ApplicationDriver.swift`, 137 lines; `package final class` `:8`; `present(to:)` `:66`); `SpecimenRegistry` (`Examples/Sources/SpecimenSupport/SpecimenRegistry.swift:36-38`, "the only selection point"); scripted input as bytes through `InputParser` (`RegisteredCapture.swift:33` and header `SpecimenRegistry.swift:5-6`); `TesseraCapture` at 80x24 and 40x16 (`Examples/Sources/TesseraCapture/TesseraCapture.swift:41`); `ReviewBundle` writes per-checkpoint `.json`, `.graph.txt`, `.input.txt`, `.txt`, `.svg` (`Examples/Sources/SpecimenCaptureSupport/ReviewBundle.swift:239-241`) and a `manifest.json` written last (`:354-378`); about 1,800 lines of capture tooling in total (`036:104-108`) | Controls landed before pointer input, and most widgets in one commit (`9119ef3`, 85 files, about +10.6k lines; `036:76-79`); a SplitView trap on duplicate IDs and binding writes during update (`036:83-86`); Table sorted by column title (`036:88-89`); automation IDs became public `TesseraCore` API (`036:94-96`); about 2,900 lines of committed generated SVG and JSON, and process documents heavier than the components (`036:104-108`); tests did not link until a one-line fix (`036:68-70`) | Byte-level scripted input, one update policy for live and headless (`03b8731`), and fail-closed capture are sound. Keep bundles out of the repo and out of Core. Keep test affordances in SPI or test code. |
| `archive/phase4-unicode-demo-stash` (tag, object `4397cea`; "Stash 'plans/032 2.2 unicode demo' (UnicodeDemo + tests, gallery on phase4). Archived 2026-10-10") | `git show archive/phase4-unicode-demo-stash` | `UnicodeDemo.swift` (214 lines) and `UnicodeDemoTests.swift` (163 lines), per `036` and the notes | Stash on the phase4 line; not built on main | Port into the Phase 8.3 Text demo (`:541`). |
| `archive/catalog-workbench` (branch `wip/catalog-workbench-2026-07-17`, WIP `3582c94`, 2026-07-17) | `docs/plans/029-tessera-catalog-workbench.md` (`status: pending`, Phase 5 unchecked); `036:27` | Hummingbird server-rendered catalog review app; `Sources/TesseraCatalog` parser with typed IR, anchors, fingerprints, and cell mapping (`CatalogBlockParser`, `WireframeCellMap`); TCA workflow; SQLite persistence; ArgumentParser CLI | No reason recorded in the repository. `036` describes it without judgement. It is absent from the 036 port map and from plan 032 | The parser and cell-coordinate mapping are the only plausible reuse. The Python checker in main is simpler. Any port needs an explicit owner decision. |
| Showcase (`Examples/Sources/TesseraShowcase/`, still in main) | `docs/project-status.md`; investigation `020:9-13`; plan 030 superseded | One integration app with a layout explorer, inspector, and scenario fixtures | Superseded 2026-10-10 by per-component demos assembled later (`020:9-13`; plan 032 Overview `:134-137`) | Remove it (plan 032 Step 8.1). Do not extend it. |
| Review-loop roadmap (`docs/plans/030-phase-4-view-layer.md`, consolidated in `ed714da`) | `036:70-72` (approved 2026-09-08) | "small directly runnable specimens" instead of a Showcase | Dropped the "small directly runnable specimens" framing before the Showcase was retired; plan 030 superseded by plan 032 (`84beec8`) | Same direction as plan 032. The lesson stands. |
| `tess` branch tooling (local branch, not an ancestor of `archive/phase4`) | `tess:docs/research/029-lefthook-unstaged-work-loss.md`, `031-monodraw-json-format.md`, `032-omp-cua-vm-integration.md`, `033-lume-detached-runtime-metadata.md`; `tess:scripts/macos-cua-*`, `tess:scripts/monodraw/` | Git hook tracking (replacing Lefthook), Windows VM hardening, macOS VM control, Monodraw snippets | Outside the Phase 4 port map (`036:35-36`, `:142-143`) | Not Phase 4 scope. `036:57-59` attributes the Monodraw library only to `phase4`, but `tess` also contains `scripts/monodraw/`. |
| omp2 capture program and review site (working copy only) | `git log --all -- DevTools/omp2-gallery scripts/omp2-gallery.sh` is empty; cache `~/.cache/tessera/omp2/2f92f3b5aa2035d21c9f016f9ff6350795e5685a` | Headless capture through omp2's own `Ui::from_markup`, `frame_text`, `frame_ansi` (`DevTools/omp2-gallery/src/main.rs:309-349`); probe theme that gives each `Theme` field a unique color to recover roles (`main.rs:73-130`; mismatch check `:361`); `#!` fixture directives (`main.rs:1-25`); `scripts/omp2-gallery-serve.py` review site | Not abandoned. A design-phase tool slated for deletion in step 7.4 | The only tool here not tied to Tessera internals. Its fixture directives (`widths`, `now`, `focus`, `keys`, `type`, `paste`) are a model for demo scripts. Archive before deleting if any part should survive. |

Commit history for reference: `f193135` added the runner, `hello`, and the scaffold; `60b076b` added the graph reconciliation watcher; `5192e7f`, `9dcc46e`, and `8ffffc2` are scroll fixes.

### Abandonment evidence

- Investigation 036 is the only written analysis. Its outcome (`036:15-20`) reads: "The owner chose to restart the Phase 4 implementation from `main` (Slices 1, 2, and 2.5 stay) and port old code selectively, one step at a time, against the revised catalog. The old work is kept as annotated tags so it can still be read with `git show <tag>:<path>`; every branch, worktree, and stash was then deleted." Its lessons (`:74-108`) are the reasons, restated in the table above.
- Commit messages record the verification gaps. `9119ef3` reports "784 root tests, 36 Examples tests" and "Linux static build failed: installed Swift 6.3.2 SDK is incompatible with the available Swift 6.3.3 compiler." `18f80a4` says "Linux and Windows runtime environments remain unavailable." `03b8731` says "Visuals remain provisional." `3e3e763` salvages the keyboard Button with "immediate keyboard activation" only (body truncated in the log).
- `STATE.md:41-49` (review-loop plan, archived) records that workers wrote into the original worktree instead of their assigned ones; main restored six paths from `f1061a0`. Devtools that write into the repo need worktree guards.
- `84beec8` (on main) supersedes plan 030 for "a demo-first order." `45d79dc` records investigation 036.

## Port map

Source: 036 port map (`:110-126`), checked against plan 032 Phases 8-16. Nothing from the archive is on main yet; Slices 1, 2, and 2.5 are the only Phase 4 code in main. 036 says: "port only what survives review against the updated catalog doc and the omp2 decisions" (`design/omp2-assessment.md`).

| Plan 032 step | Port from | Notes |
| --- | --- | --- |
| 8.2 demo harness | `review-loop:Examples/Sources/SpecimenSupport/ApplicationDriver.swift`; `review-loop` registry shape; `phase4:Examples/Sources/TesseraGallery/DemoHost.swift` (`isQuitKey`, `:204-206`) and `phase4:Examples/Tests/TesseraGalleryTests/DemoHostKeyTests.swift` | Read the code against the doc first (plan 032 `:503-507`). Key matching compares the whole key, including modifiers (036 lesson 6). |
| 8.3 Text demo | `phase4-unicode-demo-stash` (`UnicodeDemo.swift`, `UnicodeDemoTests.swift`) |  |
| 9.1-9.2 styling, wrapping | `review-loop` `fde4552` (`Sources/TesseraLayout/Styling.swift`, `Decoration.swift`); Text wrap and truncation at `phase4:Sources/TesseraCore/Views/Text.swift` (duplicate clip/tail arms, around `:127-134`) | Wrap rules are now catalog-wide (`docs/design.md:69-101`). |
| 9.4 ScrollIndicator | `phase4:Sources/TesseraLayout/ScrollIndicator.swift` and `Tests/TesseraLayoutTests/ScrollIndicatorTests.swift` (`5192e7f`) | Add the omp2 thumb and track styles as decided. |
| 10 focus, routing | `phase4:Sources/TesseraCore/Input/{Focus,Responder}.swift`, `Environment/ControlEnvironment.swift`, `FocusRoutingTests`, `7519623` | Split focus style out of `SemanticStyles` (036 port map). |
| 11 mouse, hover | `review-loop` `ab272c2` (capture, click-to-focus, cancellation); hover work in `9119ef3` |  |
| 12 ScrollView | `phase4:Sources/TesseraWidgets/ScrollView.swift` and `Tests/TesseraWidgetsTests/ScrollViewTests.swift` (1,137 lines); compare with review-loop's `ScrollViewTests` (1,176 lines) | Investigations 034 and 035 on main document focus-appearance and indicator-clipping defects. |
| 13 controls | Review-loop Button (`3e3e763`, `ab272c2`), Toggle, Picker, Stepper (keep `clampedStepping` and its overflow tests; replace the `[-]`/`[+]` glyphs, `036`), `TextFieldEditor` (623 lines, per 036) |  |
| 14 collections | Review-loop `Section.swift` (`5a22022`), `List.swift`, `Grid.swift`, `Table.swift` (re-key sort by column ID); phase4 demo-local `FlowRow` and `EqualColumns` (`Examples/Sources/TesseraGallery/`) |  |
| 15 SplitView | Review-loop `Sources/TesseraWidgets/SplitView.swift` after fixing the duplicate-ID trap and binding writes |  |
| Post-1.0 reference | Review-loop `Sources/TesseraWidgets/NavigationSplitView.swift` (578 lines) |  |

Not to port: review bundles, committed captures, Showcase code (plan 032 `:507-509`), review-loop process documents, and `tess` tooling.

## Requirements the devtools must satisfy

Each item cites its source. "Inference" marks what the sources do not state.

1. One registry, one selection point. Every demo is registered once, and live launch, headless render, and snapshot tests select it by the same name. Precedent: `SpecimenRegistry.swift:36-41`.
2. One update policy for live and headless. Each event gets one explicit update, and presentation follows it (`ApplicationDriver.swift:4-7`; `03b8731`: "Live and headless hosts use the same explicit update/presentation policy").
3. One size list. `desktop` 80x24 and `mobile` 40x16 are required by plan 032 Step 8.2 (`:528-530`) and 8.3 (`:541-543`). The natural-height rule (`docs/design/tokens.md:14-26`) must be reconciled first. Each demo declares its own `min`.
4. Scripted input. Plan 032 says "a scripted list of input events" (`:528-530`). The review loop sent bytes through `InputParser` (`RegisteredCapture.swift:33`). Choose one and record why. Inference: bytes exercise the parser; events do not.
5. Renders go through the real renderer into `VirtualTerminal`, so headless equals live (plan 032 `:528-537`). The review loop's byte path needed `just core build-libghostty-vt` (`scripts/capture-specimen.sh`). Windows snapshot coverage is deferred (`docs/spec.md:907-910`).
6. A demo snapshot is a few lines, using the existing strategies (`VirtualTerminalSnapshotting.swift`). Plan 032 `:537` sets the bar.
7. Every demo has coverage at both sizes and reads at 40x16 (plan 032 `:543`).
8. Diagnostics are read-only and local. `dump()` and `statistics` read the immutable snapshot. Serialization and transport live outside `TesseraCore` (`docs/spec.md:7422-7440`).
9. Deterministic. No sleeps and no wall clock. Motion uses an injected clock (plan 032 Step 16.1; Spec `:8339-8346`).
10. Test affordances stay out of product API (036 lesson 5). Use SPI or a test target.
11. Shortcuts match whole keys, not `Key` values (036 lesson 6).
12. Wireframes are fixture-grade and "CI enforces the pictures" once implemented (`docs/design.md:318-319`). A check that compares a demo render with its wireframe needs states and callouts. Inference: no such check exists yet.
13. Each step lands the component, its tests, and its demo together (plan 032 `:503-512`). The harness lands before any control (036:76-79; plan 032 `:157`).
14. The owner reviews after each phase (plan 032 `:512`). Review output must stay small enough to read in a diff and never be committed as generated artifacts (036 lesson 8; plan 032 `:144`).
15. Demo rules (`036:151-163`): each key press teaches one thing; every displayed number has a true source; design against wireframes at several widths; color encodes association; the scaffold owns the UX floor (initial focus, visible focus, bubbling, footer hints); walk every key in a real PTY at 40x16 and at desktop size; a demo that exposes a library defect gets a library fix with a regression test.
16. Catalog docs are the spec. Each step starts from a `ready` doc (plan 032 `:503-504`). Inference: demo tests should name the requirement sentence they cover.
17. Dev-only placement. Demos belong in the Examples package (`Examples/Package.swift`). `DevTools/` is a tracked, dev-only package included in `Tessera.xcworkspace` so tools can appear in Xcode's scheme picker (`DevTools/README.md:1-6`). Inference: a devtools executable belongs in one of these two, never in library targets.

## Implications for Tessera devtools

Everything below is [INFERENCE] unless it restates a cited requirement.

- Build the Phase 8 runner as the only devtool at first. Put one registry in `Examples/`, one headless render path, and one live path, and build any other tool on top of them.
- Settle the viewport answer in `docs/design/tokens.md` before code hard-codes 40x16. A reasonable split: fixed 80x24 and 40x16 for demo fixtures, and natural height for component wireframes, which is what `docs/design.md:60-67` already says.
- Choose headless fidelity deliberately. The review loop's byte path (scripted bytes, `InputParser`, renderer, Ghostty VT) tests more than omp2's in-memory frame capture, at the cost of a libghostty build. Use the byte path for demo fixtures and the frame path for fast unit assertions.
- Keep devtools outside `TesseraCore`. Any inspector, control socket, or remote view needs an explicit Spec amendment, because the frozen diagnostics schema forbids serialization and transport (`docs/spec.md:7422-7440`). Put exports in test or example support, as the review loop did.
- Bridge catalog and demo. Render a demo beside its wireframe at the same size and show the grid difference. The checker validates only geometry, so this is the missing link between catalog and implementation.
- The omp2 probe-theme technique recovers roles from colors because omp2 is a black box. Tessera resolves roles itself, so a role-tagged probe is simpler. Use the technique only if a styled grid needs role names that the Ghostty cell colors cannot supply.
- Resolve the animation conflict before the clock design. The Spec says animation is not Phase 4; plan 032 and the assessment put it in 1.0. The devtool needs an injected clock either way.
- Preserve or archive the omp2 capture program before step 7.4. No commit contains it, and deletion removes the only copy. The cached checkout pins `2f92f3b5…`, so recapture stays possible while that cache exists.
- Pitfalls to design against: demos exempt from snapshots (`phase4`); controls before pointer input (both lines); committed generated SVG and JSON (about 2,900 lines); process documents heavier than the code they govern (`036:104-108`); ticks ahead of committed work (`036:104-108`); workers writing into the original worktree (`STATE.md:41-49`); and tools shaped around a single integration app.
- Owner decisions still needed: the viewport answer; whether the omp2 program and review pages are kept, archived, or deleted; the animation timing; whether the catalog workbench parser is wanted; and where devtools live (`Examples/` or `DevTools/`).
