---
name: Phase 4 view layer, redesigned from the omp2 reference
description:
  Use oh-my-pi's omp2 TUI as the visual and behavioral reference for Tessera's Phase 4
  components (a verified prior-art inventory, a captured reference gallery with ASCII
  fallbacks, an owner taste review, a Rust-to-Swift translation key, and a revised
  catalog), then implement the view layer in dependency order with per-component demos.
  Replaces plan 030.
status: in-progress
created: 2026-10-08
updated: 2026-10-10
---

<!-- Allowed status values: planning, in-review, pending, in-progress, complete, superseded. -->

## Progress

- [x] **Phase 1 — Build the prior-art inventory**
  - [x] 1.1 Survey omp2 and the Tern Surface Protocol
  - [x] 1.2 Assemble, audit, and correct the inventory
  - [x] 1.3 Remove stale gap items
- [x] **Phase 2 — Build the capture program and pilot one component**
  - [x] 2.1 Build the capture program
  - [x] 2.2 Capture the Callout pilot
  - [x] 2.3 Owner review of the gallery format
- [x] **Phase 3 — Capture every component**
  - [x] 3.1 Add input directives and Rust-built fixtures to the capture program
  - [x] 3.2 Author fixtures for every renderable component
  - [x] 3.3 Capture and check in the gallery
  - [x] 3.4 Close the inventory's fallback gaps from captured frames
- [x] **Phase 4 — Classify components by Phase 4 relevance**
  - [x] 4.1 Classify every omp2 component and confirm with the owner
  - [x] 4.2 File post-1.0 ideas as GitHub Discussions
- [ ] **Phase 5 — Owner taste review**
  - [x] 5.1 Review the gallery and record decisions
  - [ ] 5.2 Move adjusted designs into the design catalog as wireframes
  - [ ] 5.3 Propose token changes implied by the decisions
- [ ] **Phase 6 — Write the Rust-to-Swift translation key**
  - [ ] 6.1 Map omp2 concepts to Tessera's API vocabulary
- [ ] **Phase 7 — Revise the Phase 4 catalog and plan**
  - [ ] 7.1 Write or update per-component Swift design docs
  - [ ] 7.2 Amend `docs/Spec.md` Phase 4 and `design/tokens.md` after owner confirmation
  - [x] 7.3 Sequence the implementation (replaces plan 030; Phases 8-17 below)
  - [ ] 7.4 Remove the omp2 scaffolding from the working tree
- [ ] **Phase 8 — Demo harness (replaces the Showcase)**
  - [ ] 8.1 Retire the Showcase example
  - [ ] 8.2 Build the demo runner and headless driver
  - [ ] 8.3 Add demos for the landed primitives
- [ ] **Phase 9 — Styling and decoration**
  - [ ] 9.1 Style environment, tones, and styled text runs
  - [ ] 9.2 Wrapping and truncation
  - [ ] 9.3 Borders, Box, background, overlay, and the focus border
  - [ ] 9.4 ScrollIndicator with its styles
- [ ] **Phase 10 — Focus, key routing, and KeyLegend**
  - [ ] 10.1 Focus identity, traversal, and responder routing
  - [ ] 10.2 Focus appearance and focus scopes
  - [ ] 10.3 KeyLegend from responder key bindings
- [ ] **Phase 11 — Mouse, hit testing, and hover**
  - [ ] 11.1 Hit testing, click-to-focus, and pointer capture
  - [ ] 11.2 Hover and motion requirements
  - [ ] 11.3 Application-owned text selection and copy
- [ ] **Phase 12 — Interactive ScrollView**
  - [ ] 12.1 Keyboard, wheel, and indicator interaction
  - [ ] 12.2 Reveal on focus change
- [ ] **Phase 13 — Controls**
  - [ ] 13.1 Button and button styles
  - [ ] 13.2 Toggle and Picker styles
  - [ ] 13.3 Stepper
  - [ ] 13.4 TextField on a shared text editing core
- [ ] **Phase 14 — Collections and fitting**
  - [ ] 14.1 Flow layout and `ViewThatFits`
  - [ ] 14.2 List and Section
  - [ ] 14.3 Outline, including path mode
  - [ ] 14.4 Grid and Table with table styles
- [ ] **Phase 15 — Interactive SplitView**
  - [ ] 15.1 Divider keyboard and mouse resizing, focus style, and the five edge cases
- [ ] **Phase 16 — Remaining 1.0 views**
  - [ ] 16.1 The animation path
  - [ ] 16.2 Status and content views
  - [ ] 16.3 TabView, Form, Markdown, code view, and Image
- [ ] **Phase 17 — Intro app and Phase 4 closure**
  - [ ] 17.1 Assemble the intro app from the demos
  - [ ] 17.2 Graduate the catalog and close Phase 4

## Overview

The owner is not satisfied with the Phase 4 view layer as planned in `docs/Spec.md` and
plan 030. This plan adopts omp2 (the Rust rewrite of oh-my-pi's TUI, crate `omp-tui`) as
the concrete reference for how Tessera's components look and behave, while Tessera keeps
its own architecture: an earlier review found that Tessera's `ViewGraph`, `Layout` passes,
`RenderRegion` cell rendering, and semantic `Style` roles already match omp2's retained
tree, measure/place/paint passes, one-pass rendering (omp2 ADR 0030), and presentation
policy (ADR 0032). What differs is the look vocabulary: the text model, tokens, and the
component catalog.

The work proceeds from facts to taste to design:

1. A frozen, cited inventory of what omp2 does (`design/prior-art/`). It stays
   Tessera-independent and is never "Swiftified"; it is cited like any other prior art.
2. A captured reference gallery: omp2's own renderer draws each component at fixed widths
   in every charset, producing a character grid, a semantic-role style grid, an ANSI file,
   and an SVG picture per capture. These are facts about omp2, regenerated from a pinned
   commit.
3. The owner's taste review. Adjustments live in the design catalog as `wireframe` blocks
   (which `scripts/check-wireframes.py` already treats as candidate golden fixtures), not
   in the captured gallery.
4. A translation key that settles the Rust-to-Swift mapping once (props, events, internal
   state, charset and theme, markup, animation, hit testing), so each component doc only
   applies it.
5. Per-component Swift design docs, which together are the revised Phase 4 catalog, then
   spec, token, and plan amendments.

Inputs carried into Phases 5 and 7 from earlier review sessions, all still proposals that
need owner confirmation before any spec or token change:

- Styled runs inside `Text` (`Text + Text`, measured once), pulled into Slice 3.
- Tones beyond the five roles (omp2's set: neutral, accent, info, success, warning, error,
  pending, muted, user; the Tern Surface Protocol uses the same nine), a semantic icon
  catalog with ascii/unicode/nerd charsets in the environment, and dim borders by default.
- New primitives: Badge, Kbd, Fact (label/value that stacks when narrow), Callout, titled
  Divider, and a Box whose title is a View.
- A minimal animation path: dedicated motion views (spinner, elapsed time, shimmer) on an
  app-supplied clock with a declared tick requirement aggregated like
  `TerminalRequirements`.
- Catalog mapping: Toggle as omp2's checkbox, Picker styles `.menu`/`.radio`/`.segmented`,
  Stepper as number, TextField as input, Section as a titled box or rule, a controlled
  TabView for 1.0, omp2's tree as post-1.0 Outline, and modal overlays named but deferred.
- A possible later `TesseraTern` backend for the Tern Surface Protocol, out of scope here;
  keeping semantic data (title, tone, status) on views keeps it possible.

From 2026-10-10 this plan also carries the Phase 4 implementation and replaces plan 030.
Slices 1, 2, and 2.5 in `main` stay. Everything after them restarts in the order of Phases
8-17, and the abandoned attempts at that work are archived as git tags and ported
selectively, step by step, against the revised catalog
(`.agents/investigations/036-phase-4-salvage-review.md` has the port map). The Showcase is
abandoned: small per-component demos, which double as snapshot fixtures, test each step,
and Phase 17 assembles them into an intro app.

## Decision record

| Area                 | Decision                                                                                                                                                                                                                                                         | Rationale                                                                                                                                                                        |
| -------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Inventory            | Keep `design/prior-art/` as frozen, cited facts about omp2 and TSP while this plan runs; never translate it                                                                                                                                                      | A Swift version is design work; mixing it into the inventory would blur what omp2 does with what Tessera should do.                                                              |
| Repository footprint | Commit only what Tessera keeps: catalog docs and wireframes, `design/tokens.md`, `docs/Spec.md`, the assessment's decisions, and this plan. The inventory, gallery, capture program, review site, and review folder stay uncommitted and are deleted in step 7.4 | Owner decision 2026-10-10: the omp2 tooling was a means to a design, not something the repository should carry.                                                                  |
| Reference renderer   | Capture with omp2's own `Ui::from_markup` headless render, not a terminal or libghostty                                                                                                                                                                          | omp2 paints into an in-memory `Frame`; its own tests read rows from it. This is deterministic and needs no pty.                                                                  |
| Pinned source        | Commit `2f92f3b5aa2035d21c9f016f9ff6350795e5685a` on the `omp2` branch                                                                                                                                                                                           | Matches the inventory snapshot; captures must be reproducible.                                                                                                                   |
| Build location       | Copy `DevTools/omp2-gallery` into a cached omp2 checkout as a workspace member and build there                                                                                                                                                                   | omp-tui inherits workspace dependencies and needs omp2's pinned nightly toolchain and `Cargo.lock`; building inside the workspace reuses all three.                              |
| Style roles          | Recover roles by rendering a second time with a probe theme that gives every `Theme` field a unique color                                                                                                                                                        | Several stock theme fields share values (`muted` and `dim` in both appearances), so matching real colors back to roles is ambiguous.                                             |
| Viewports            | Capture at `desktop` (80) and `mobile` (40) widths plus a per-fixture minimum; height is the natural height                                                                                                                                                      | Matches `design/tokens.md` viewports. omp2 lays out to a width and grows to its content height.                                                                                  |
| Charsets             | Capture Ascii, Unicode, and NerdFont for every fixture                                                                                                                                                                                                           | The fallback (ASCII) versions are first-class references.                                                                                                                        |
| No-color fallback    | The character grid is the no-color reference; there is no separate capture                                                                                                                                                                                       | omp2 has no `NO_COLOR` mode; a styled-grid snapshot's character grid is exactly what a no-color terminal shows.                                                                  |
| Picture appearance   | SVG and ANSI use the stock dark theme on a dark page                                                                                                                                                                                                             | One appearance keeps the pilot small; light can be added as a capture option if the review needs it.                                                                             |
| Taste adjustments    | Adjust in the design catalog as `wireframe` blocks, never in captured output                                                                                                                                                                                     | Captures are regenerated facts; wireframes are the catalog's existing fixture-grade design medium.                                                                               |
| Implementation base  | Keep `main`'s Slices 1, 2, and 2.5; restart the rest in Phases 8-17 and port archived code only where it survives review against the updated catalog doc                                                                                                         | Owner decision 2026-10-10. The archived code works (230 tests) but was built out of order, in large batches, and before the omp2 decisions; investigation 036 lists its defects. |
| Archived work        | `archive/phase4`, `archive/phase4-review-loop`, `archive/phase4-unicode-demo-stash`, and `archive/catalog-workbench` tags; read with `git show <tag>:<path>`                                                                                                     | Keeps old code readable for porting without branches, worktrees, or stashes.                                                                                                     |
| Demos                | Each component lands with a small standalone demo that runs live and renders headlessly at fixed sizes; demo renders are snapshot fixtures                                                                                                                       | Textual's widget examples are both documentation and snapshot tests; demos test the implementation as it is built.                                                               |
| Order                | Layout, styling, focus, mouse, and ScrollView before controls; collections and SplitView after; remaining 1.0 views, then the intro app                                                                                                                          | Demos need focus, scrolling, and pointer input to exercise controls honestly; both archived attempts built controls before mouse input.                                          |

## Phase 1 — Build the prior-art inventory

**Goal**: a verified, cited inventory of omp2's components and the Tern Surface Protocol's
node kinds, independent of Tessera.

### Step 1.1 — Survey omp2 and the Tern Surface Protocol

- Files: `design/prior-art/omp2-components.md`, `design/prior-art/tsp-components.md`,
  `design/prior-art/README.md`, `design/README.md`.
- Done: nine parallel surveys covered omp2's model and five component groups and TSP's
  model and three kind groups.

### Step 1.2 — Assemble, audit, and correct the inventory

- Done: first-pass audits found about 20–25% wrong claims; every section was re-verified
  against source. Second audits found no remaining omp2 defects in about 600 checked
  claims; the TSP and README defects they found were fixed. Markdown, spelling, and
  wireframe checks pass.

### Step 1.3 — Remove stale gap items

- Done: removed the claim that ADRs were missing and the unverified-test-citations item
  (citations checked against `tests.rs:748-857` and `form.rs:947, 978`); reworded the
  defaults item.

## Phase 2 — Build the capture program and pilot one component

**Goal**: a reproducible capture program and one fully captured component, so the owner
can judge the gallery format before the remaining components are captured.

### Step 2.1 — Build the capture program

- Files: `DevTools/omp2-gallery/Cargo.toml`, `DevTools/omp2-gallery/src/main.rs`,
  `scripts/omp2-gallery.sh`, `design/prior-art/omp2-gallery/README.md`.
- The script makes a sparse, blobless clone of oh-my-pi at the pinned commit under
  `${XDG_CACHE_HOME:-$HOME/.cache}/tessera/omp2/<commit>`, copies the capture crate in as
  a workspace member, and runs it with omp2's pinned nightly (`nightly-2026-08-08`,
  installed by `rustup` on first run). `OMP2_REPO` overrides the clone source (a local
  clone saves the download).
- Build overrides, all in the script: `RUSTUP_TOOLCHAIN` is set explicitly because an
  inherited value (mise sets one) beats `rust-toolchain.toml`; `RUSTFLAGS` replaces omp2's
  Homebrew `ld64.lld` link flag; `CARGO_PROFILE_DEV_CODEGEN_BACKEND=llvm` replaces omp2's
  Cranelift backend for workspace members, which replaces an AArch64 NEON intrinsic in
  omp-tui's graph with a trap.
- Fixtures are `design/prior-art/omp2-gallery/fixtures/<component>/<case>.tml`: omp2
  runtime markup with optional leading `#!` directive lines (`#! about …`,
  `#! widths 80 40 14`, `#! now 1200`). Output goes to
  `design/prior-art/omp2-gallery/captures/`, which the script replaces on every run and
  `.codespellrc` skips (narrow captures truncate words on purpose).
- Done: a cold build takes about 100 seconds; regeneration then takes about a second and
  was verified byte for byte across runs.
- Acceptance: one command regenerates every capture byte for byte from the fixtures.

### Step 2.2 — Capture the Callout pilot

- Files: `design/prior-art/omp2-gallery/fixtures/callout/{header,kinds,plain}.tml`,
  `design/prior-art/omp2-gallery/captures/callout.md`,
  `design/prior-art/omp2-gallery/captures/callout/**`.
- Done: 3 cases, 24 captures (`header` and `plain` at 80, 40, and 14 columns; `kinds` at
  80 and 40), each in three charsets. Markdown, spelling, and wireframe checks pass.
- Observations for the review, all facts about omp2 rather than decisions:
  - The whole body takes the kind's color, not only the rail; bold survives, but inline
    code (`just warm`) loses both its backticks and any distinct style.
  - At 14 columns (the measured minimum) the header clips to `Build warnin` with no
    ellipsis and drops the badge.
  - ASCII swaps the icon for a bracketed marker (`[!]`) and the rail `▎` for `|`; Nerd
    Font swaps only the icon.
- Acceptance: each case renders at every width and charset with a character grid, style
  grid and legend, ANSI file, and SVG, and the generated page passes the Markdown checks.

### Step 2.3 — Owner review of the gallery format

- Decide whether the format needs changes before scaling up: grid layout, role legend,
  light-theme pictures, page organization, and file count.
- Viewing: SVGs did not open well on the owner's phone, so `scripts/omp2-gallery-serve.py`
  serves all captures as one HTML page on the Tailscale address (port 8790), with a
  charset switcher, the text snapshot under each picture, and a locally installed Nerd
  Font so icons render on the phone.
- Done: the owner kept the format unchanged and chose to capture every component.
- Acceptance: format changes are made to the capture program and the pilot is regenerated.

## Phase 3 — Capture every component

**Goal**: a complete reference of omp2 as it is, before any Tessera adjustment. The owner
chose to capture every renderable component rather than only Phase 4 candidates, so
classification (Phase 4) no longer gates capture.

### Step 3.1 — Add input directives and Rust-built fixtures to the capture program

- Files: `DevTools/omp2-gallery/src/main.rs`, `DevTools/omp2-gallery/src/builtins.rs`,
  `scripts/omp2-gallery-serve.py`.
- Done: fixtures can apply `#! focus <id>`, `#! keys <chord> …`, `#! type <text>`, and
  `#! paste <text>` in order before capture, and `#! rust <builder>` builds components
  that have no markup tag through `builtins.rs`. Pages show the whole fixture, titles use
  the inventory's component names (`diff-view` → `DiffView`), and `captures/README.md`
  indexes every component.

### Step 3.2 — Author fixtures for every renderable component

- Files: `design/prior-art/omp2-gallery/fixtures/<component>/*.tml`, with `<component>`
  the kebab-case inventory name; `DevTools/omp2-gallery/src/builtins.rs` for Loader,
  Countdown, Logo, Brand, Shader, Scene, ToolCard, DiffPane, and CustomElement.
- Every component in the inventory's registry except the helpers and data models
  (`layout`, `text_limit`, `RevealState`, `SpeedGauge`, `DiffDocument`, `EditBuffer`),
  which draw nothing themselves. Cases cover variants, tones, states (focus, selection,
  editing, open popups), motion frames, and narrow widths, at `80 40` plus the component's
  minimum width where it differs.
- Done: 51 components, 190 cases, 1,293 captures. Seven parallel authors wrote the
  fixtures and validated each case's character and style grids in all three charsets.
  Builders in `builtins.rs` cover the nine tagless components plus four states markup
  cannot reach: Strike text (the `<strike>` body is dropped), Spinner and Pulse labels and
  the Pulse throughput badge (also dropped from markup bodies), and the editor completion
  picker (completion is a runtime setter). `strike/markup` deliberately records the blank
  markup rendering.
- Added on request: omp2's `/settings` panel (`settings-panel`, 3 cases) as a reference
  for sidebar-plus-detail screens. It lives in the heavy `omp-chat` crate, so
  `DevTools/omp2-gallery/src/settings_panel.rs` repeats its view code (`rebuild`,
  `list_row`, `tab_strip`, `SETTING_TABS`) with real Appearance declarations. omp2 has no
  reusable master-detail or key-legend component: screens compose `box`, `tabs`, `row`,
  fixed-width `col`s and a vertical `hr`, and every panel writes its key legend as a muted
  string constant.
- Not captured: the Input selection highlight (Input ignores `shift+left`, so there is
  nothing to show) and Form's validation message (`Form::validation_error` is never
  painted). Wizard's validation message is captured.
- Acceptance: every renderable component has at least one case, and anything that could
  not be captured is recorded here with the reason.

### Step 3.3 — Capture and check in the gallery

- Done: regeneration is byte-for-byte deterministic; Markdown, spelling, and wireframe
  checks pass. The capture output is about 8.7 MB, mostly SVG. Generated pages use code
  fences longer than any backtick run in their content, and style grids fall back to
  naming blended colors `derived` when a capture has more than 62 styles (shaders,
  gradients). The viewer now serves an index and one page per component, because inlining
  every SVG in one page was too heavy for a phone.
- Acceptance: the gallery regenerates byte for byte, the Markdown, spelling, and wireframe
  checks pass, and `captures/README.md` indexes every component page.

### Step 3.4 — Close the inventory's fallback gaps from captured frames

- Replace the "fallback inferred from charset calls" gap items in
  `design/prior-art/omp2-components.md` with links to the captured frames, and correct any
  inventory claim a capture contradicts.
- Done: every component entry links its gallery page; fallback text now cites captured
  frames; captures corrected about 30 entries (among them: `<spinner>`, `<pulse>`, and
  `<strike>` markup bodies are dropped; Form never paints its validation message; Tabs
  collapses every inactive tab to its icon; `<fact bold>` bolds the value too; Markdown
  table alignment needs `:---`). Eleven unsupported claims were dropped. Open gaps left:
  Select's recommended-first ordering under a query, a typed custom Select row, Tree rows
  at width 20, and markup attribute spelling for a few controls.

## Phase 4 — Classify components by Phase 4 relevance

### Step 4.1 — Classify every omp2 component and confirm with the owner

- The inventory deliberately does not classify relevance. Classify each of the 56 entries
  in `design/prior-art/omp2-components.md` as Phase 4, post-1.0, or out of scope (agent-
  or showpiece-specific), using the Phase 4 slice map in `docs/Spec.md`, the inputs listed
  in the Overview, and the gallery. The owner confirms the classification.
- Done: `design/omp2-assessment.md` classifies all 57 registry entries and extracts about
  30 reusable pieces. After the owner's review (hunk comments, 2026-10-08): 14 planned
  1.0, 13 added to 1.0 (Callout, Fact, Icon, Progress, Spinner, Tabs, Tree, Files,
  Markdown, Pre, Img, Form, Loader), 6 post-1.0, 17 kept only for extracted aspects, 2 not
  needed, 5 helpers. Decisions: `KeyLegend` in Slice 4, `ViewThatFits` for priority
  fitting, animation in 1.0, `TabView` and `Badge` in 1.0, a dedicated focus border, value
  formatting post-1.0 through Foundation `FormatStyle`, and "list-detail" instead of
  "master-detail". The assessment's "Owner decisions" section is the record.
- Acceptance: the owner confirms the classification and the 1.0 additions, and the
  assessment records every component with its class and the Tessera concept it informs.

### Step 4.2 — File post-1.0 ideas as GitHub Discussions

- The owner asked that out-of-scope and post-1.0 ideas from the assessment go to the
  repository's "Feature Requests, Ideas" Discussions, using its template, so they are not
  forgotten. Twelve ideas cover Canvas, sub-cell graphics, gradient fills, Markdown math,
  a scroll overview, a diff view, `TextEditor` with completion, paged flows with a step
  indicator, a status bar, a checklist view, `FormatStyle` value formatting, and a
  structured value inspector.
- Done: the owner approved the drafts, and they were posted as Discussions #28–#39 on
  2026-10-08. The assessment's "1.0 additions" section links each one. The value inspector
  (#39) is an app-facing view (renamed `ValueTree` to avoid clashing with the Showcase
  inspector), not developer infrastructure; Phase 4's own debugging tool remains the Slice
  1 diagnostics snapshot and the Showcase inspector.
- Acceptance: each idea is posted once, after the owner approves the drafts, and linked
  from the assessment.

## Phase 5 — Owner taste review

### Step 5.1 — Review the gallery and record decisions

- Per component: adopt as-is, adjust (what and why), or reject.
- Tooling: the review site at `/review` in `scripts/omp2-gallery-serve.py` (local, works
  offline) splits the 1.0 components plus three Tessera additions (Badge, KeyLegend, focus
  border) into six groups defined in `design/omp2-review/review.json`: layout and
  containers, text and content, status and progress, controls, collections and navigation,
  and Tessera additions. Feedback autosaves to `design/omp2-review/feedback.json` and the
  browser. The agent builds colored wireframes into
  `design/omp2-review/wireframes/<item>/` from that feedback, following
  `design/omp2-review/README.md`; the page shows them beside the omp2 captures and flags
  items whose feedback is newer than their wireframes.
- Acceptance: every item has a decision, and every adopted or adjusted item has wireframes
  the owner has accepted.
- Done (2026-10-10): all six groups reviewed, and every item is adopted as-is or has
  wireframes the owner accepted. The Tessera additions (Badge, KeyLegend, focus border)
  have no omp2 component, so they carry accepted wireframes instead of an
  Adopt/Adjust/Reject decision. Owner decisions live in each item's
  `design/omp2-review/wireframes/<item>/NOTES.md`, the answered notes in `feedback.json`
  (`resolved`), and `design/omp2-assessment.md` (decision 10: NavigationSplitView leaves
  1.0). Step 5.2 reads these as its input.

### Step 5.2 — Move adjusted designs into the design catalog as wireframes

- Start from the catalog docs ported on 2026-10-10 (the most advanced archived version of
  each; see investigation 036, "Catalog port"). The review loop's alternative Picker,
  Stepper, Toggle, and Table docs stay readable in `archive/phase4-review-loop`.
- Copy each adopted capture into its catalog doc as a `wireframe WxH` block, edit it to
  taste, and validate with `scripts/check-wireframes.py`. These become snapshot fixtures
  when the component is implemented.
- Remove the remaining Showcase mentions from the ported docs, and re-check each doc's
  status against its accepted adjustments: a doc whose decided behaviour is not yet
  written into it is not `ready`.

### Step 5.3 — Propose token changes implied by the decisions

- Tones, icon catalog and charsets, border defaults, and motion tokens for
  `design/tokens.md`. Proposals only; confirm with the owner before editing.

## Phase 6 — Write the Rust-to-Swift translation key

### Step 6.1 — Map omp2 concepts to Tessera's API vocabulary

- One table, at a design-catalog location chosen with the owner: `Prop` → initializer
  parameters, modifiers, or environment values; `UiEvent` → action closures; internal
  component state → `Binding` (Tessera widgets are controlled); `Charset` and `Theme` →
  environment values and semantic `Style` roles; `dom!` and markup → `@ViewBuilder`;
  `pc.wake`/`pc.now` → clock-driven views; `HitTag` → Slice 5 hit testing.
- Acceptance: every concept used by an in-scope component maps to one Tessera form, or is
  explicitly rejected with a reason.

## Phase 7 — Revise the Phase 4 catalog and plan

### Step 7.1 — Write or update per-component Swift design docs

- Apply the translation key to each in-scope component in `design/primitives/` and
  `design/widgets/`, and move each through the catalog's status ladder. Prior-art
  citations point at omp2's source at the pinned commit on GitHub, never at
  `design/prior-art/` or the gallery, because those are deleted in step 7.4.

### Step 7.2 — Amend `docs/Spec.md` Phase 4 and `design/tokens.md`

- Only after the owner confirms the specific amendments.
- Includes replacing the Phase 4 slice list with the order of Phases 8-17, removing the
  Showcase (Prerequisites and scheduling, Slice 7, and the Phase 4 definition of done),
  and updating the 1.0 surface from `design/omp2-assessment.md`.

### Step 7.3 — Sequence the implementation

- Done (2026-10-10): plan 030 is superseded, and Phases 8-17 below carry the rest of
  Phase 4. Their steps name components and acceptance; file-level detail is added to each
  phase before it starts, once 7.1 and 7.2 settle the catalog and spec.

### Step 7.4 — Remove the omp2 scaffolding from the working tree

- After 7.1-7.3 are committed, delete `design/prior-art/`, `design/omp2-review/`,
  `DevTools/omp2-gallery/`, `scripts/omp2-gallery.sh`, `scripts/omp2-gallery-serve.py`,
  and the cached checkout under `~/.cache/tessera/omp2/`.
- Revert the edits made only for them: the `.codespellrc` skips for gallery captures,
  feedback, and wireframe text; the `.prettierignore` feedback entry; and the `prior-art/`
  lines in `design/README.md`.
- Decide with the owner whether `design/omp2-assessment.md` is committed (its owner
  decisions are the durable part) or folded into the Spec and catalog and deleted.
- Acceptance: `git status` shows none of the scaffolding, and no committed file links into
  it.

## Implementation rules for Phases 8-17

- Each step starts from a `ready` catalog doc. If the doc is not `ready`, finishing it is
  the first part of the step.
- Each component lands with its tests and its demo in the same step, small enough to
  review on its own.
- Port from the archive tags only after reading the code against the doc; the port map and
  known defects are in investigation 036. Never port the review bundles, committed
  captures, or Showcase code.
- Measurement and `body` stay pure; every `NodeState` row has one owner
  (`design/README.md`); collections key by stable IDs and fail closed on duplicates.
- After each phase, pause for the owner's review before starting the next.

## Phase 8 — Demo harness (replaces the Showcase)

**Goal**: a way to run any component on its own, live or headless, before more components
land.

### Step 8.1 — Retire the Showcase example

- Delete `Examples/Sources/TesseraShowcase/`, its tests, its just recipe, and its mentions
  in `README.md`, `docs/ProjectStatus.md`, `CONTRIBUTING.md`, and the changelog's
  unreleased notes.
- Acceptance: nothing in the repository builds, runs, or links the Showcase.

### Step 8.2 — Build the demo runner and headless driver

- One executable lists and runs demos by name; each demo is a small self-contained type
  that a reader can copy. A headless driver renders any demo at fixed sizes (`desktop`
  80x24 and `mobile` 40x16 from `design/tokens.md`) from a scripted list of input events
  into `VirtualTerminal`, so demo renders are snapshot fixtures, as in Textual's widget
  examples.
- Port from: review-loop `ApplicationDriver` and registry shape; `phase4` `DemoHost` key
  handling (`isQuitKey`) and its tests. Carry the "Demo rules" from investigation 036 into
  the harness's documentation.
- Acceptance: a demo runs live in a terminal and renders identically headless; the
  snapshot test for a demo is a few lines.

### Step 8.3 — Add demos for the landed primitives

- Text (including the archived Unicode demo), stacks and `Spacer`, `frame`/`padding`,
  `ZStack`, and Flex.
- Acceptance: each demo has snapshot coverage at both sizes and reads well at 40x16.

## Phase 9 — Styling and decoration

**Goal**: the look vocabulary from the omp2 review: tones, styled text, borders, and the
focus border.

### Step 9.1 — Style environment, tones, and styled text runs

- Inherited `Style` values through the environment, the tone set and semantic roles from
  step 5.3, and `Text + Text` styled runs measured once.

### Step 9.2 — Wrapping and truncation

- Word and character wrapping; `.truncationMode(.tail/.head/.middle)` with the ellipsis
  keeping the text's style.

### Step 9.3 — Borders, Box, background, overlay, and the focus border

- Border glyph families with ASCII fallbacks, `Box` with a View title, `background`,
  `overlay`, and the focus border style with the focus-within tint decided for Box.

### Step 9.4 — ScrollIndicator with its styles

- Output-only indicator geometry shared by ScrollView, List, and Table, with the thumb and
  track styles and in-border placement decided in review.
- Phase acceptance: demos for text styling, truncation, borders, and indicators;
  styled-grid snapshots cover every glyph family and its ASCII fallback.

## Phase 10 — Focus, key routing, and KeyLegend

### Step 10.1 — Focus identity, traversal, and responder routing

- Document-order focus with wrap, removal handling, and leaf-to-ancestor key bubbling.
  Port from `phase4` `Focus.swift`, `Responder.swift`, and `FocusRoutingTests`.

### Step 10.2 — Focus appearance and focus scopes

- The focus border applied by focus-appearance hosts, and a focus scope that traps
  traversal inside an overlay and restores focus on dismissal (`design/inbox.md`).

### Step 10.3 — KeyLegend from responder key bindings

- Responders declare their keys and descriptions; `KeyLegend` renders the focused chain's
  bindings, `plain` by default with `keycaps` as an option, dropping whole entries by
  priority when narrow.
- Phase acceptance: a focus demo and a KeyLegend demo; routing tables cover focused,
  bubbled, ignored, and removed responders.

## Phase 11 — Mouse, hit testing, and hover

### Step 11.1 — Hit testing, click-to-focus, and pointer capture

- Clipped, deepest-first hit testing in paint order, click-to-focus, and capture that
  keeps a drag routed to its origin until release or cancellation. Port from review-loop
  `ab272c2`.

### Step 11.2 — Hover and motion requirements

- Hover state, any-event tracking requested only while a handler needs it, and hover
  cleared on focus loss.

### Step 11.3 — Application-owned text selection and copy

- The Spec's selection contract (`design/primitives/text-selection.md`), or an explicit
  deferral recorded in the Spec.
- Phase acceptance: a pointer demo; scripted pointer tests cover overlap, clipping,
  capture, and requirement de-escalation.

## Phase 12 — Interactive ScrollView

### Step 12.1 — Keyboard, wheel, and indicator interaction

- Keyboard and wheel scrolling, boundary bubbling to an enclosing viewport, and focus only
  while scrollable. Port from `phase4` `ScrollView.swift` and its tests.

### Step 12.2 — Reveal on focus change

- Moving focus into hidden content scrolls it into view (investigation 034).
- Phase acceptance: a ScrollView demo with nested viewports at both sizes.

## Phase 13 — Controls

Each control lands with its demo, keyboard and pointer paths, and disabled state.

### Step 13.1 — Button and button styles

- Button with the pill, soft, tint, and ghost styles and their ASCII ends; the pressed
  state must reach rendering (investigation 036, lesson 4).

### Step 13.2 — Toggle and Picker styles

- Toggle as a checkbox; Picker as radio group (chips wrap, never clip), menu (including
  the custom "Other" row), and segmented (icons-only and tail truncation when narrow).

### Step 13.3 — Stepper

- Arrows visible when unfocused, the limit arrow in the disabled colour, and a disabled
  state. Keep the review loop's clamped stepping and overflow tests.

### Step 13.4 — TextField on a shared text editing core

- A text editing core (grapheme-safe cursor, selection, reveal) under TextField, with the
  character counter. Port from review-loop `TextFieldEditor.swift`.

## Phase 14 — Collections and fitting

### Step 14.1 — Flow layout and `ViewThatFits`

- A wrapping row layout and `ViewThatFits` with layout priority (owner decision 2).

### Step 14.2 — List and Section

- One focus stop, controlled selection, the shared indicator, and badges on rows.

### Step 14.3 — Outline, including path mode

- Expanders, guides, a folder icon on the root, badges before icons, and path folding.

### Step 14.4 — Grid and Table with table styles

- Grid on the shared Flex solver; Table with `.plain` (default), `.bordered`, and `.grid`
  styles plus `.alternatingRowBackgrounds()`, sorted by column identity, not title.

## Phase 15 — Interactive SplitView

### Step 15.1 — Divider keyboard and mouse resizing, focus style, and the five edge cases

- Arrow and Shift+arrow steps, a wider grab target, double-click or `=` to reset, clipping
  without automatic collapse, the ASCII junctions, nesting, and the content-minimum
  sizing. Port from review-loop `SplitView.swift` after fixing its duplicate-ID trap and
  its binding writes during update.

## Phase 16 — Remaining 1.0 views

### Step 16.1 — The animation path

- A clock in the environment and a declared tick requirement aggregated like
  `TerminalRequirements`.

### Step 16.2 — Status and content views

- `ProgressView` (determinate and indeterminate spinner sets), `Callout`,
  `LabeledContent`, `Label` with the icon catalog, `Badge`, and `ContentUnavailableView`.

### Step 16.3 — TabView, Form, Markdown, code view, and Image

- The remaining views from `design/omp2-assessment.md` ("1.0 additions").

## Phase 17 — Intro app and Phase 4 closure

### Step 17.1 — Assemble the intro app from the demos

- A Textual-style intro app that composes the per-component demos; it adds navigation, not
  component behaviour.

### Step 17.2 — Graduate the catalog and close Phase 4

- Move each implemented doc's durable content into DocC, mark it `implemented`, run the
  performance and platform checks, and run the full quality gate.

## References

- Inventory: `design/prior-art/README.md`, `design/prior-art/omp2-components.md`,
  `design/prior-art/tsp-components.md`.
- omp2: <https://github.com/can1357/oh-my-pi>, branch `omp2`, commit
  `2f92f3b5aa2035d21c9f016f9ff6350795e5685a`; crate `crates/tui` (README "Element
  reference"; `src/markup.rs` module doc for the markup grammar; `src/debug.rs`
  `frame_text`/`frame_ansi`; `src/components/tests.rs` for headless rendering).
- Tessera: `docs/Spec.md` (Phase 4; Slice 1 "Snapshot representations"),
  `design/README.md` (status ladder and wireframes), `design/tokens.md` (viewports),
  `.agents/investigations/036-phase-4-salvage-review.md` (archived work and port map), and
  the superseded plan `.agents/plans/030-phase-4-view-layer-and-showcase.md`.
- Textual: `src/textual/demo/` (the demo app) and `docs/examples/widgets/` with
  `tests/snapshot_tests/test_snapshots.py` (examples that are snapshot fixtures).
