---
name: Phase 4 salvage review of abandoned branches
date: 2026-10-10
status: resolved
---

# Phase 4 salvage review of abandoned branches

## Question

Before plan 032 step 5.2, what is worth keeping from the abandoned Phase 4 work (the
`phase4` branch, the `phase4-review-*` branches, a catalog workbench branch, and five
stashes), and what can be deleted with confidence?

## Outcome

The owner chose to restart the Phase 4 implementation from `main` (Slices 1, 2, and 2.5
stay) and port old code selectively, one step at a time, against the revised catalog. The
old work is kept as annotated tags so it can still be read with `git show <tag>:<path>`;
every branch, worktree, and stash was then deleted.

| Tag                                 | Was                                                                                                                                                      |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `archive/phase4`                    | Branch `phase4` (37 commits on `0697fe2`, ending `f1061a0`) plus a final commit holding its uncommitted and untracked files (`StacksDemo.swift`).        |
| `archive/phase4-review-loop`        | Branch `phase4-review-loop` (18 commits on `0697fe2`, ending `b21e6a9`) plus a final commit holding 26 uncommitted and untracked files.                  |
| `archive/phase4-unicode-demo-stash` | The stash "plans/032 2.2 unicode demo": `UnicodeDemo.swift` and `UnicodeDemoTests.swift` for the phase4 gallery.                                         |
| `archive/catalog-workbench`         | Branch `wip/catalog-workbench-2026-07-17`: a Swift catalog review web app (Hummingbird, GRDB, TCA, about 35k lines). Everything else on it is in `main`. |

Deleted without tags: `phase4-review-docs` and `phase4-review-export` (ancestors of the
review loop), `phase4-review-vt` (same patch as review-loop commit `2a62cd8`), and four
stashes: two Showcase redesigns, a pre-commit focus snapshot superseded by `phase4`, and a
pre-launch snapshot whose content is already in `main`. The remote branch
`origin/phase4-review-loop` was left for the owner to delete.

Branch `tess` (a separate AppKit product) contains `phase4`'s first 15 commits, including
the tooling below, so that tooling is also preserved there.

## What the old work contained

### `phase4`

- View layer, Slices 3 and 4: styling and decoration (`1014004`), focus routing and focus
  appearance (`6ba369b`), controlled keyboard responders (`c34129f`), deterministic focus
  restoration across pane groups (`7519623`), and ScrollView fixes found by demos
  (`8ffffc2`, `9dcc46e`, `5192e7f`). Core/Layout/Widgets grew from 4.3k to 9.4k lines. 187
  view-layer tests pass (verified 2026-10-10 in a throwaway copy).
- A demo gallery (`f193135`, `60b076b`, `f1061a0`): an ArgumentParser runner with one
  subcommand per demo; a `DemoModel` protocol (title, key hints, status, content,
  `handle(Key)`, resize, animation frames); `DemoHost` (session, event coalescing, focus
  traversal, quit grammar); `DemoScaffold` (header, focusable scrolling viewport, key-hint
  footer); demos `hello`, `graph` (905 lines), `responder` (758 lines), and an untested
  `stacks`; demo-local `FlowRow` and `EqualColumns` layouts with tests.
- Catalog work: Slice 3 and Slice 4 docs promoted to `ready`, List and Section
  `specified`, NavigationSplitView rewritten, `grid.md`, and many `inbox.md` entries.
- Tooling, also on `tess`: tracked git hooks replacing Lefthook after it lost unstaged
  work (`5e89cab`, investigation 029 on `tess`), Windows VM hardening, an agent-controlled
  macOS VM with Lume metadata recovery, xcsift compiler output, and a Monodraw snippet
  pipeline. Only on `phase4`: the Monodraw snippet library itself and a `PHILOSOPHY.md`
  with an `AGENTS.md` rewrite.

### `phase4-review-loop`

A review-and-reset that restarted from `main`, re-salvaged `phase4`'s styling, focus, and
Button code, then added pointer input, Toggle, Picker, Stepper, a TextField editing model
(`TextFieldEditor.swift`, with selection), List, Section, Grid, Table, negotiated
SplitView with divider drag, a NavigationSplitView, automation identifiers in Core, a
specimen registry with `ApplicationDriver`, and about 1,800 lines of capture and
review-bundle tooling. Core/Layout/Widgets reached 13.4k lines. Its tests do not link
under the current toolchain because `TesseraCoreTests` imports `TesseraLayout` without
declaring it; with that one-line fix, 230 view-layer tests pass (verified 2026-10-10). Its
consolidated roadmap (`.agents/plans/030-phase-4-view-layer.md`, approved 2026-09-08)
already dropped the Showcase for "small directly runnable specimens".

## Lessons for the restart

1. **Order.** Both lines built controls before mouse input and hit testing, so pointer
   paths could not be exercised until later; the review loop then landed most of its
   widgets in one commit (`9119ef3`: 85 files, about +10.6k lines). Build layout, focus,
   ScrollView, and mouse first, and land each component with its tests and demo.
2. **Docs before code.** Several catalog docs were rewritten to describe what was built
   (`phase4`'s `text-field.md` narrowed to the implemented initializer; the review loop's
   `toggle.md` and Button "P4.3 implementation boundary"). Requirements come first.
3. **One owner per piece of state.** Defects found by reading:
   - review-loop `SplitView.remember()` builds a dictionary with `uniqueKeysWithValues`
     and traps on duplicate pane IDs, while `layout(for:)` guards the same case;
   - review-loop SplitView writes the app's pane binding from responder and update paths;
   - `phase4`'s TextField writes state inside `sizeThatFits`;
   - review-loop Table keys its sort descriptor by column title, so renaming a column
     changes sort identity. Measurement and `body` stay pure; collections key by stable
     IDs and fail closed on duplicates.
4. **Rendered state must reach rendering.** `phase4`'s Button tracks the pressed key but
   passes `isPressed: false` to its style, so the pressed look never shows. Test press,
   then render.
5. **Test affordances stay out of product API.** The review loop's automation identifiers
   (`87d3284`) are well designed (metadata-only, fail-closed lookup) but became public
   `TesseraCore` API used inside library views. Decide SPI or test-only before porting.
6. **Compare whole keys, not `Key` values.** Kitty enrichment (`shiftedCode`,
   `baseLayoutCode`, `associatedText`) breaks `==`; `DemoHost.isQuitKey` compares code,
   modifiers, and kind. Use the same rule for every shortcut.
7. **Demos find library bugs.** The gallery surfaced invisible focus in scrolled content
   (investigation 034), clipped intrinsic scroll indicators (investigation 035), reserved
   viewport extents, and dropped repeats. Fix the library with a regression test; never
   compensate inside a demo.
8. **Process weight.** The review loop's process documents (a 390-line plan and a 319-line
   start brief), 1,800 lines of capture machinery against about 400 lines of driver and
   registry, and roughly 2,900 lines of committed generated SVG and JSON were more weight
   than the components they reviewed. Ticks also ran ahead of committed work (plan boxes
   checked in uncommitted diffs and in stashes).

## Port map

Read each file from its tag before writing the step, and port only what survives review
against the updated catalog doc and
[`design/translation-key.md`](../../design/translation-key.md).

| Plan 032 phase          | Port from                                                                                                                                                                                                                                                                                                                                                                        |
| ----------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Demo harness            | `archive/phase4-review-loop:Examples/Sources/SpecimenSupport/ApplicationDriver.swift` (137 lines; scripted input, baseline mode restore) and its registry shape; `archive/phase4:Examples/Sources/TesseraGallery/{DemoHost,DemoScaffold}.swift` and `DemoHostKeyTests`; the unicode demo from `archive/phase4-unicode-demo-stash`. Not the review bundles or committed captures. |
| Styling and decoration  | `archive/phase4-review-loop` commit `fde4552` (the tested salvage of `phase4`'s `1014004`): `TesseraLayout/{Styling,Decoration}.swift`, Text wrapping and truncation (collapse the duplicate clip/tail arms in `phase4` `Text.swift:127-134`).                                                                                                                                   |
| ScrollIndicator         | `archive/phase4:Sources/TesseraLayout/ScrollIndicator.swift` and `ScrollIndicatorTests` (includes `5192e7f`); add the omp2 thumb and track styles.                                                                                                                                                                                                                               |
| Focus and key routing   | `archive/phase4:Sources/TesseraCore/Input/{Focus,Responder}.swift`, `Environment/ControlEnvironment.swift`, `FocusRoutingTests` (document order, wrap, removal, leaf-to-ancestor bubbling, nested focusables), and `7519623`. Split the focus style out of `SemanticStyles` (`Styling.swift:78`) to match the focus border decision.                                             |
| Mouse and hit testing   | `archive/phase4-review-loop` commit `ab272c2` (pointer capture, click-to-focus, cancellation) and the hover/motion work in `9119ef3`.                                                                                                                                                                                                                                            |
| ScrollView              | `archive/phase4:Sources/TesseraWidgets/ScrollView.swift` and `ScrollViewTests` (overflow-gated focus, focus-within bubbling, repeat scrolling, reserved extents), compared with the review loop's 1,176-line `ScrollViewTests`.                                                                                                                                                  |
| Controls                | Review-loop Button (`3e3e763`, `ab272c2`), Toggle, Picker, Stepper (keep `clampedStepping` and its Int8/Int64 overflow tests; replace the `[-]`/`[+]` glyphs), and `TextFieldEditor.swift` (623 lines, selection model).                                                                                                                                                         |
| Collections             | Review-loop `Section.swift` (bounded layout, `5a22022`), `List.swift` (`_listSubtract` saturating helper), `Grid.swift` (`_gridMultiply`), `Table.swift` (re-key sort by column ID; add the decided table styles); `phase4` demo-local `FlowRow` and `EqualColumns`.                                                                                                             |
| SplitView               | Review-loop `SplitView.swift` (divider drag, keyboard, width restoration) after fixing the duplicate-ID trap and the binding writes.                                                                                                                                                                                                                                             |
| Post-1.0 reference only | Review-loop `NavigationSplitView.swift` (578 lines) and `phase4`'s NavigationSplitView catalog rewrite (ported as the current doc).                                                                                                                                                                                                                                              |

## Catalog port (done 2026-10-10)

The most advanced old version of each catalog doc was copied into `main` as the starting
point for plan 032 step 5.2:

- From `archive/phase4`: primitives Background, Border, Box, Overlay, ScrollIndicator,
  Style modifiers, Divider, and the new Grid sketch; widgets Button, Picker, Stepper,
  Toggle, List, Section, ScrollView, SplitView, Table, and NavigationSplitView;
  `inbox.md`; `tokens.md`; and the runtime ownership invariant in `design/README.md`
  (rewritten without the review loop's internal type names).
- From `archive/phase4-review-loop`: `widgets/text-field.md`, which keeps the
  label/prompt/style direction and adds the selection state that `phase4` dropped.
- Also from `archive/phase4`: investigations 027 (runtime state ownership), 028 (scroll
  focus conventions), 034 (focus appearance host inside scrolled content), and 035
  (intrinsic indicator clipping). Numbers 029-033 belong to `tess` tooling and were not
  ported.
- `design/showcase.md` was deleted. Several ported docs still mention the Showcase in
  prose; step 5.2 removes those mentions.

Alternatives kept in the review-loop tag for step 5.2 to consult: its Picker, Stepper,
Toggle, and Table docs (shorter, written after implementation), its Button implementation
notes, and its SplitView rename of `ideal` to `requestedIdeal`.

## Demo rules worth carrying forward

From `archive/phase4:.agents/plans/032-view-layer-gallery.md` ("Demo quality bar"): teach
rather than dump (each key press states its lesson, then shows evidence); every displayed
number has a truthful source; design demos against wireframes at several widths; color
encodes association, never decoration; the shared scaffold owns the UX floor (initial
focus, visible focus, unusable keys bubble, whole-unit key hints); QA means walking every
key in a real PTY at `40x16` and a desktop size; and a demo that exposes a library defect
gets a library fix with a regression test.

One rule changes: the old gallery exempted demos from snapshot tests. In the restart,
demos double as snapshot fixtures, as Textual's widget examples do
(`docs/examples/widgets/*.py`, run by `tests/snapshot_tests/test_snapshots.py`).
