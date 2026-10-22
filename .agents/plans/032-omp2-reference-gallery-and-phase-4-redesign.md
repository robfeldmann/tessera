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
updated: 2026-10-21
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
- [x] **Phase 5 — Owner taste review**
  - [x] 5.1 Review the gallery and record decisions
  - [x] 5.2 Move adjusted designs into the design catalog as wireframes
  - [x] 5.3 Propose token changes implied by the decisions
- [x] **Phase 6 — Write the Rust-to-Swift translation key**
  - [x] 6.1 Map omp2 concepts to Tessera's API vocabulary
- [x] **Phase 7 — Revise the Phase 4 catalog and plan**
  - [x] 7.1 Write or update per-component Swift design docs
  - [x] 7.2 Amend `docs/Spec.md` Phase 4 and `design/tokens.md` after owner confirmation
  - [x] 7.3 Sequence the implementation (replaces plan 030; Phases 8-17 below)
  - [x] 7.4 Remove the omp2 scaffolding from the working tree
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
  - [ ] 12.1 Keyboard and wheel scrolling
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
  2026-10-08. The assessment's "1.0 additions" section linked each one; since step 7.4
  deleted the assessment, `design/inbox.md` ("Filed as Discussions") links them. The value
  inspector (#39) is an app-facing view (renamed `ValueTree` to avoid clashing with the
  Showcase inspector), not developer infrastructure; Phase 4's own debugging tool remains
  the Slice 1 diagnostics snapshot and the Showcase inspector.
- Acceptance: each idea is posted once, after the owner approves the drafts, and linked
  from `design/inbox.md`.

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
- Done (2026-10-10), pending owner review of the staged diff: every accepted Tessera
  wireframe and every adopted omp2 case is now a `wireframe` block, with callouts and a
  styled grid where colour or focus matters, in 13 updated docs and 13 new ones (Badge,
  Label, Callout, ContentUnavailableView, Form, KeyLegend, LabeledContent, Outline,
  ProgressView, TabView, Markdown, code view, Image). Decisions are attributed in each doc
  as "owner decision, omp2 review, 2026-10", and prior-art links point at omp2's source on
  GitHub at the pinned commit. Box and Border carry the focus rules; Table, SplitView,
  Button, and Stepper follow them. Showcase mentions are gone from the catalog (the
  `docs/Spec.md` Slice 7 anchor stays until step 7.2). `scripts/check-wireframes.py` now
  accepts scroll thumbs (`█▐▌`) in a box's vertical edge, which in-border indicator
  placement needs.
- Status re-check: Border, Box, Button, Divider, Picker, ScrollIndicator, ScrollView,
  SplitView, Stepper, and Toggle dropped from `ready` to `specified`; most wait on token
  rows (step 5.3) or on open questions their docs now list. New docs are `wireframed`,
  except Markdown, code view, and Image, which stay `sketch` until they have a `min` state
  (omp2 has no minimum case for them).
- Button redesign (2026-10-10): the omp2-derived pill/soft/tint/ghost set proved
  confusing, so the owner set the API first, then judged looks in a coloured "Button lab"
  on the review site. Button now has four independent dimensions: intent (`role:`
  `.cancel`/`.destructive`, `.keyboardShortcut(.defaultAction)`), emphasis
  (`.filled`/`.tinted`/`.plain`; the default action resolves to filled, everything else to
  tinted), shape (`.squared` default, `.capsule`, `.rectangle`, `.brackets`, `.box`,
  `.custom` with optional per-charset pairs), and state. The API is the same in every
  charset and under NO_COLOR; modes only change how a shape draws.
- Review round 3 applied (2026-10-11): the owner answered the critic's suggested answers
  in a hunk review of the staged diff; every answered thread is applied in its doc and
  deleted. Form now treats its select and multi rows as Picker's menu collapsed in a host
  row, stacks labels above values below 24 columns through `ViewThatFits`, and takes its
  validation wording from the app. Picker gained multi-select (`.menu` and radio group
  only), digit 1-9 quick-select, and one-line option descriptions; the fuzzy filter stays
  out of 1.0 (`design/inbox.md`). Left for the owner: the 13 token threads on
  `design/tokens.md` (step 5.3 input), the ScrollIndicator preset list, and the inferences
  listed in Form's and Picker's open questions (Form's 12-cell narrow floor and default
  `<Label> is required` / `<Label> is invalid` wording; Picker's multi initializer shape,
  digits past 9, and description layout). Corrected (2026-10-21): Form no longer switches
  at a fixed column count. `ViewThatFits` keeps the side-by-side layout while every row
  fits and stacks otherwise, so the switch point depends on the content; the anatomy
  fixture stacks at 17 columns (`design/widgets/form.md`, "Narrow: 17 columns").
- Committed (2026-10-18) as `e5fe358`, scaffolding excluded.
- Grill round (2026-10-18), applied: the owner settled the remaining non-token open
  questions (Q1-Q30). The biggest is a catalog-wide wrap rule: content word-wraps at any
  finite width, only an exhausted row budget truncates (the last visible row ends in `…`),
  chrome stays single-line, apps override with `lineLimit`, and deliberate breaks are
  documented in the component's own doc with a reason (docked titles, atomic values,
  TextField editing, code, Outline rows, Table). Also: `.readableWidth()` (a 72-cell
  maximum, prose only); List and Picker menu rows wrap; Picker and the new `MultiPicker`
  take SwiftUI-style titles and an optional `customOption:` row; a collapsed host-row
  value is content; Markdown links are OSC 8 only (in-app activation is
  [Discussion #40](https://github.com/robfeldmann/tessera/discussions/40)); Text ships
  `.lineLimit(Int?)` and `.truncationMode(_:)` without a character-wrap mode; and smaller
  answers for Form, KeyLegend, Outline, ContentUnavailableView, Image, Leading rail, and
  ProgressView. Applied by a `senior` contract (README rules, Text, ScrollView, readable
  width), six `engineer` slices, and a `critic` review whose findings were fixed and
  re-verified. Grid and TextSelection keep their open questions for their own design
  passes.

### Step 5.3 — Propose token changes implied by the decisions

- Tones, icon catalog and charsets, border defaults, and motion tokens for
  `design/tokens.md`. Proposals only; confirm with the owner before editing.
- Nothing in `design/tokens.md` is fixed: the proposals may overturn any existing row or
  rule, including "no `success`, `warning`, or `information` roles in 1.0" (owner
  decision, 2026-10-10). Inputs: every "token pending plan 032 step 5.3" marker in the
  catalog, the remaining `focus.border` consumers, and the critic's role-grouped token
  suggestions (posted to the owner's hunk review on `design/tokens.md`).
- Done (owner decisions, 2026-10-19): the policy is "terminal-native by default, derived
  shades, themes optional". Hues come from the terminal's 16 slots, shades are blended
  from the queried foreground, background and palette, light or dark is detected, and
  attributes are the fallback. `design/tokens.md` was rewritten and every marker replaced.
  The review site's Tokens page (`/tokens`, one page per question at `/tokens/qN`) renders
  the roles under Miniwinter Dark/Light, Catppuccin Mocha/Latte and the xterm defaults.

## Phase 6 — Write the Rust-to-Swift translation key

### Step 6.1 — Map omp2 concepts to Tessera's API vocabulary

- One table, at a design-catalog location chosen with the owner: `Prop` → initializer
  parameters, modifiers, or environment values; `UiEvent` → action closures; internal
  component state → `Binding` (Tessera widgets are controlled); `Charset` and `Theme` →
  environment values and semantic `Style` roles; `dom!` and markup → `@ViewBuilder`;
  `pc.wake`/`pc.now` → clock-driven views; `HitTag` → Slice 5 hit testing.
- Done (2026-10-21, commit `da2e962`): the key is `design/translation-key.md`, listed in
  `design/README.md`. The agent chose that location while the owner was away, not with the
  owner as planned, so it awaits owner review. Four ownership rules decide where omp2
  state lives (`Binding`, initializer parameter, `NodeState`, graph-owned). One table maps
  119 concepts in 13 families: 94 to a Tessera form and 25 rejected with a reason. Per-row
  notes carry the rules, a Theme-field table maps omp2's theme onto `design/tokens.md`
  roles, and a coverage appendix lists each catalog doc's omp2 counterpart and the rows it
  uses. omp2 sources are cited at the pinned commit on GitHub.
- Acceptance: every concept used by an in-scope component maps to one Tessera form, or is
  explicitly rejected with a reason.

## Phase 7 — Revise the Phase 4 catalog and plan

### Step 7.1 — Write or update per-component Swift design docs

- Apply the translation key to each in-scope component in `design/primitives/` and
  `design/widgets/`, and move each through the catalog's status ladder. Prior-art
  citations point at omp2's source at the pinned commit on GitHub, never at
  `design/prior-art/` or the gallery, because those are deleted in step 7.4.
- Done (2026-10-21, commit `c19e896`): every catalog doc names its omp2 counterpart, cites
  it at the pinned commit, applies the translation key's Tessera forms by row ID, and
  records its departures. Each doc was reviewed against the Phase 4 theses and promoted as
  far as its gates allow. Two new primitives serve step 14.1: `design/primitives/flow.md`
  (a greedy wrapping row) and `design/primitives/view-that-fits.md` (the first candidate
  whose ideal size fits, else the last). Form, Picker, MultiPicker, LabeledContent,
  ProgressView, and TabView build their arrangement choices on them. 39 of the 44
  component docs are `ready` (the `design/README.md` index). Below `ready`: Grid
  (`specified`, owner questions on extra and bare cells, row spacing, and cell priority),
  ProgressView (`specified`, the shimmer and elapsed-time question, key L5), Image
  (`specified`, Kitty tier sizing and loader ownership), Text selection (`sketch`, decided
  in step 11.3), and NavigationSplitView (`wireframed`, post-1.0).

### Step 7.2 — Amend `docs/Spec.md` Phase 4 and `design/tokens.md`

- Only after the owner confirms the specific amendments.
- Includes replacing the Phase 4 slice list with the order of Phases 8-17, removing the
  Showcase (Prerequisites and scheduling, Slice 7, and the Phase 4 definition of done),
  and updating the 1.0 surface from `design/omp2-assessment.md`.
- Also update Spec's Text API (`docs/Spec.md#text-grows-up` still shows `wrapped(_:)` and
  `truncation(_:)` with `.none` and `.clip` defaults) to the 2026-10-18 wrap rules: word
  wrapping by default, `.lineLimit(Int?)`, and `.truncationMode(_:)` (see
  `design/primitives/text.md`).
- Also add the step 5.3 terminal contracts to the Spec (owner decisions, 2026-10-19):
  - Phase 3 capability probe: OSC 10/11/4 colour queries join the DA1-terminated round
    with a 1 s timeout; the first frame waits; late replies repaint; mode 2031
    theme-change notifications; a re-query on resume; `NO_COLOR` queries only the
    background; new `TerminalCapabilities` fields for the reported colours and for Nerd
    Font coverage (`.notDetectable`); and an OSC reply path in the input parser, which has
    none today.
  - `\.colorScheme`: an unknown background counts as dark unless `COLORFGBG` says light.
  - Glyph charset, under the protocol enablement policy: "Glyph charset: `\.charset`
    defaults to `.unicode`, drops to `.ascii` when the locale codeset is not UTF-8,
    honours the generic `NERDFONT` variable (`0` caps at `.unicode` over app policy; `1`
    selects `.nerdFont` for automatic mode), may be set explicitly by the application, and
    reports Nerd Font coverage as `.notDetectable` until a protocol-native coverage query
    is adopted; terminal identity never selects it."
  - Phase 4 Slice 5: Table and List request motion tracking for their default row hover.
- Done (2026-10-21, commits `2010609` and `5c33360`). The agent applied these amendments
  while the owner was away, not after the owner confirmed them as planned, so they await
  owner review. Spec Phase 4 now follows Phases 8-17: Slices 1, 2, and 2.5 stay as
  implemented, the remaining slices are technical contracts naming the plan phase that
  delivers each, per-component demos and the Phase 17 intro app replace the Showcase, and
  a new "The 1.0 surface" list gathers the catalog docs' decisions, with
  NavigationSplitView post-1.0. Text follows the 2026-10-18 wrap rules; Slice 3 takes its
  role families from `design/tokens.md` with `\.colorScheme` and `\.charset`; Slice 4 adds
  focus appearance, focus scopes, and declared key bindings; Slice 5 adds pointer capture
  and default row hover motion tracking for Table and List; a new section covers motion
  views and the tick requirement. Phase 3 Slice 6 gains the terminal contracts listed
  above. A follow-up aligned the Spec's Box, background, ScrollIndicator, GridRow, and
  Flow/ViewThatFits sections and `design/tokens.md` with the revised catalog: focus clears
  after every layout pass, unplaced nodes are not focusable, and terminal requirements
  count every live node, placed or not.

### Step 7.3 — Sequence the implementation

- Done (2026-10-10): plan 030 is superseded, and Phases 8-17 below carry the rest of
  Phase 4. Their steps name components and acceptance; file-level detail is added to each
  phase before it starts, once 7.1 and 7.2 settle the catalog and spec.

### Step 7.4 — Remove the omp2 scaffolding from the working tree

> Amended (owner decision, 2026-10-19): keep the review site's Tessera pages, the Tokens
> page (`/tokens`) and the per-component review pages, in the repository. They become the
> seed of the live demo gallery (Phase 8, as in Textual's demo app): each wireframe is
> later replaced by the real, interactive, snapshot-tested widget. Before deleting
> anything below, decide with the owner where the kept pages live and how they are
> separated from the third-party omp2 captures and prior-art inventories, which still get
> removed.
>
> Done for the review site (2026-10-20): the Tessera pages became the component gallery,
> `scripts/gallery-serve.py` plus `DevTools/gallery/`. It reads wireframe fences straight
> from the catalog docs, renders colours with the final `design/tokens.md` rules, keeps
> the Tokens page, and leaves empty Current and Previous slots for plan 033's
> `.build/tessera-dev/` renders. The review site, its captures, labs and feedback
> machinery, and the capture program are deleted. A local backup branch,
> `backup/review-site-2026-10-20`, keeps all of it, including the gitignored `.build/`
> decision logs. Still to remove here: `design/prior-art/` and
> `design/omp2-assessment.md`, plus the `.codespellrc` `*/omp2-gallery/captures` skip and
> `ans` word, which exist only for `design/prior-art/omp2-gallery/`, and the four
> prior-art lines in `design/README.md`.

- After 7.1-7.3 are committed, delete `design/prior-art/` and the cached checkout under
  `~/.cache/tessera/omp2/`.
- Revert the edits made only for them: the `.codespellrc` skips for gallery captures,
  feedback, and wireframe text; the `.prettierignore` feedback entry; and the `prior-art/`
  lines in `design/README.md`.
- Decide with the owner whether `design/omp2-assessment.md` is committed (its owner
  decisions are the durable part) or folded into the Spec and catalog and deleted.
- Done (2026-10-21): `design/prior-art/`, `design/omp2-assessment.md`, and the cached
  checkout under `~/.cache/tessera/omp2/` are deleted; `backup/review-site-2026-10-20`
  keeps the inventory and the assessment. The agent folded the assessment's durable facts
  into `design/inbox.md` (including the step 4.2 Discussions) and the catalog docs rather
  than committing it, while the owner was away; that choice awaits owner review. The
  `.codespellrc` gallery-captures skip and `ans` word and the four prior-art lines in
  `design/README.md` are reverted. The `.prettierignore` feedback entry was already gone,
  and the `.codespellrc` wireframe regex stays because the catalog keeps its wireframes.
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

> Owner review (2026-10-21): no plan phase implements the Phase 3 colour-report probe that
> `docs/Spec.md` Phase 3 Slice 6 now specifies: the OSC 10/11/4 colour round in the
> DA1-terminated probe, mode 2031 theme-change notifications, the re-query on resume, and
> `TerminalCapabilities.colorReport` (`TerminalColorReport`). The derived colour roles
> this step resolves blend their shades from that reported foreground, background, and
> palette (`design/tokens.md`). Owner to decide where the probe lands: a step before or
> inside Phase 9, or a separate Phase 3 plan, with step 9.1 rendering the attribute
> fallbacks until it exists.

### Step 9.2 — Wrapping and truncation

- Word wrapping that breaks inside a word only when the word is wider than the line;
  character-flow wrapping is rejected (`design/primitives/text.md`, translation key I3).
  `.lineLimit(Int?)` and `.truncationMode(.tail/.head/.middle)` with the ellipsis keeping
  the text's style.

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

### Step 12.1 — Keyboard and wheel scrolling

- Keyboard and wheel scrolling, boundary bubbling to an enclosing viewport, and focus only
  while scrollable. Indicators stay output-only: a click or drag on one returns `.ignored`
  (`design/primitives/scroll-indicator.md`, translation key F2). Port from `phase4`
  `ScrollView.swift` and its tests.

### Step 12.2 — Reveal on focus change

- Moving focus into hidden content scrolls it into view (investigation 034).
- Phase acceptance: a ScrollView demo with nested viewports at both sizes.

## Phase 13 — Controls

Each control lands with its demo, keyboard and pointer paths, and disabled state.

### Step 13.1 — Button and button styles

- Button with the `.filled`, `.tinted`, and `.plain` emphases and the `.squared`,
  `.capsule`, `.rectangle`, `.brackets`, `.box`, and `.custom` shapes with their ASCII
  ends (`design/widgets/button.md`: omp2's Pill, Tint, and Ghost become the three
  emphases, and Soft has none); the pressed state must reach rendering (investigation 036,
  lesson 4).

### Step 13.2 — Toggle and Picker styles

- Toggle with the `.checkbox` (default) and `.circle` styles, taking the Form row focus
  rule inside a Form; Picker as radio group (chips wrap, never clip), menu (including the
  custom "Other" row), and segmented (icons-only and tail truncation when narrow).

> Owner review (2026-10-21): Picker's radio group wraps its chips with Flow, and
> `ViewThatFits` chooses its title layout and its menu's description layout; MultiPicker,
> which `docs/Spec.md` Phase 4 also places in Phase 13, does the same
> (`design/widgets/picker.md`, `design/widgets/multi-picker.md`). Both primitives are
> built in step 14.1, after this step. Button, Toggle, Stepper, and TextField do not use
> them, and Form, LabeledContent, ProgressView, and TabView land in Phase 16, after step
> 14.1. Proposal: move step 14.1 to the start of Phase 13, or into Phase 9. Phase 9 comes
> before focus and hit testing exist, so `ViewThatFits`'s rule that unchosen candidates
> leave focus and hit testing could only be tested once Phases 10 and 11 land. The order
> is unchanged until the owner decides.

### Step 13.3 — Stepper

- Arrows visible when unfocused, the limit arrow in the disabled colour, and a disabled
  state. Keep the review loop's clamped stepping and overflow tests.

### Step 13.4 — TextField on a shared text editing core

- A text editing core (grapheme-safe cursor, selection, reveal) under TextField, with the
  character counter. Port from review-loop `TextFieldEditor.swift`.

## Phase 14 — Collections and fitting

### Step 14.1 — Flow layout and `ViewThatFits`

- A wrapping row layout and `ViewThatFits` with layout priority (owner decision 2).
- Catalog docs: `design/primitives/flow.md` and `design/primitives/view-that-fits.md`,
  both `ready` since step 7.1. Form, Picker, MultiPicker, LabeledContent, ProgressView,
  and TabView wrap or choose between arrangements with them (owner decisions, 2026-10-18).
  See the owner review note under step 13.2 for this step's position.

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

- The remaining 1.0 views in `docs/Spec.md` ("The 1.0 surface"). This step first cited the
  "1.0 additions" in `design/omp2-assessment.md`, which step 7.4 deleted.

## Phase 17 — Intro app and Phase 4 closure

### Step 17.1 — Assemble the intro app from the demos

- A Textual-style intro app that composes the per-component demos; it adds navigation, not
  component behaviour.

### Step 17.2 — Graduate the catalog and close Phase 4

- Move each implemented doc's durable content into DocC, mark it `implemented`, run the
  performance and platform checks, and run the full quality gate.

## References

- Inventory (deleted in step 7.4; kept on the `backup/review-site-2026-10-20` branch):
  `design/prior-art/README.md`, `design/prior-art/omp2-components.md`,
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
