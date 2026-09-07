---
name: Phase 4 - small complete interfaces and inspectable development
status: in-review
created: 2026-09-07
reviewed-base: 0697fe28d1accdd2621cdb0d5426a053ed3a2c2d
---

# Phase 4: small complete interfaces and inspectable development

This is the self-contained implementation companion to the Phase 4 revision discussed with
the maintainer. [START-HERE.md](START-HERE.md) authorizes and scopes the autonomous session.
It is not a claim of implementation or test success. The broader Phase 4 roadmap remains
subject to human review; the execution brief permits reversible work on the feature branch
without waiting for that review. Newly invented API names and CLI examples below are
illustrative, not existing or compile-verified APIs.

The reviewed `main` was `0697fe28d1accdd2621cdb0d5426a053ed3a2c2d`; its dispatch method was
still a no-op. More advanced work on local `phase4` takes precedence as implementation to
inspect and preserve, not as unverified proof of correctness. Do not start the framework
over merely because this roadmap reorders its delivery.

## 1. Purpose and preserved architecture

The unit of progress is a small complete interaction that a human and an agent can operate,
inspect, and review. The Showcase is no longer the acceptance vehicle. Replace its growing
application shell with independent specimens and eventually two small realistic examples.

```text
small contract -> implementation -> real input -> completed observation
               -> assertions and visual critique -> revision -> human review
```

Preserve Tessera's existing foundation:

- Value-description views, explicit ViewGraph reconciliation, documented structural/keyed
  identity, controlled Binding-based widgets, and application-owned business state.
- Integer-cell layout, the existing Text/width machinery, stacks, Flex, viewport and final
  SplitView negotiation, and one buffer Style vocabulary. Preserve generic view labels
  and component appearance composition; one Style is not a reason to reduce labels to text.
- Synchronous borrowed Frame/RenderRegion rendering; non-Sendable view/graph state;
  TerminalSession's sole authority over terminal modes, output, and cleanup.
- Full layout and full painting as the understandable initial correctness model, existing
  damage tracking, diagnostics, test infrastructure, and executable import/package gates.

Do not add hidden state observation, a second reconciler, a new terminal emulator, broad
Sendable workarounds, a CSS system, or a Showcase-shaped development environment.

## 2. One application-driving path

Bring the minimum deterministic driving/stepping contract forward from Phase 5, not its
whole convenience runtime. Live and headless hosts invoke the same event routing, explicit
update policy, layout, focus reveal, and presentation decisions. Event source and terminal
device differ; application semantics do not.

The driver coordinates an app-owned root factory and ViewGraph. It does not require
Tessera-specific State/Action/Effect types, store business values in nodes, or silently
observe models. Updating once after dispatch can be an explicit simple host policy. Apps
can also explicitly request updates when their own asynchronous work completes.

```text
live input / scripted input
          |
shared application driver
          |
graph dispatch -> app handlers -> explicit update
          |
layout and focus reveal -> borrowed render -> session presentation
          |
completed checkpoint
```

Keep the driver in a proven ownership domain. It can initially retain the current caller/
session-isolated arrangement. Compile-prove any MainActor/session bridge before publishing
it. Never transfer the graph unsafely, escape borrowed rendering, or use unchecked Sendable
to make a convenient host signature compile.

### Step and observation contracts

One step delivers one semantic event, completes its synchronous handlers and explicitly
requested updates, resolves required layout/reveal, renders at most once if required, and
awaits the owned presentation boundary. Initial presentation and external update/resize
operations have equally explicit checkpoints.

A returned checkpoint is not a promise that arbitrary asynchronous tasks are idle. Later
completions enter as later work. Drains and layout/reveal stabilization are bounded and
fail with a useful trace rather than looping indefinitely. Inject a clock when delayed UI
work is introduced. Never use sleeps or Task.yield to establish correctness.

Preserve leaf -> wrapping handlers -> ancestors -> unhandled host routing. The graph does
not acquire implicit Tab/quit policy. Examples can install traversal explicitly. Global
quit shortcuts must not intercept ordinary text intended for a field.

Reading a checkpoint/diagnostic projection must not update, lay out, render, or change
focus. Exclude timestamps and performance durations from deterministic snapshot equality.

### Reuse real terminal infrastructure

Most view tests inject InputEvents. A smaller integration suite injects protocol bytes
through the existing parser/session to test that boundary too. Direct buffer assertions
pin component behavior; real renderer/encoder output fed into the existing VirtualTerminal
pins presentation. Preserve the virtual terminal across an entire scenario so stale cells,
incorrect erasure, cursor problems, and damage-tracking defects are observable.

Reuse InMemoryTerminalSession, its device, VirtualTerminal, ScreenSnapshot/RenderedCell,
and the existing graph/buffer snapshot strategies. Do not build a parallel terminal stack.

## 3. Three views of the same completed checkpoint

The agent needs actual screen output, operable semantics, and structural explanations.

**Screen:** styled cells, cursor, viewport, and a faithful image of captured rendering.
An image is not a second implementation that redraws a Button from its description.

**Interaction semantics:** a small opt-in automation identifier, role, enabled/focused/
selected/pressed state where relevant, allocated and visible clipped bounds, and supported
input. Automation identity is separate from `.id` and FocusID: adding a test label must
not recreate node state or make a control focusable. This metadata is not a claim of
screen-reader or operating-system accessibility support.

**Structural diagnostics:** existing node identity/type, hierarchy, proposal, measurement,
frame/clip, handlers, focus/capture ownership, requested/effective terminal requirements,
work counters, and concise routing/invalidation explanations. The session alone reports
effective terminal state; graph requests are not equivalent to successful mode application.

Tie the observations to the same event/frame sequence. Stable behavior tests should not
select nodes by fragile wrapper paths. Ambiguous identifiers fail with candidate details.
Labels and model values are subject to the capture policy, not arbitrary reflection.

### Honest pilot operations

A convenience click locates a currently visible target and injects ordinary pointer phases.
It must not call its action closure, bypass hit testing, silently reveal the target, force
focus, click through an overlay, or mutate the bound value. Missing, ambiguous, clipped,
and occluded targets produce actionable failures. Coordinate input remains available for
negative tests and outside release.

Expose down/up/move/wheel, key, paste, resize, and explicit update as their real seams land.
Do not fabricate unsupported input to make tests pass. Capture intermediate pressed states
with pointer down or a real phased-key case; legacy press-only keyboard input must retain
its documented immediate behavior. Programmatic state setup is a fixture, not proof that
a user interaction works.

## 4. Safe developer export and visual artifacts

The old spec forbids serialization/persistence of graph diagnostics. Amend that deliberately
before relying on developer export:

> Production diagnostics remain immutable observations and confer no graph, render, raw
> output, or session authority. Explicit developer/test tools may export a versioned,
> sanitized projection to a caller-chosen local destination. Capture is disabled by default.
> Automatic telemetry, ambient capture, network listeners, remote control, and arbitrary
> reflection remain prohibited. Observation does not trigger passes.

Input injection belongs to the separately enabled driver, not to a mutable inspector.
Raw byte traces are a separate opt-in protocol debugging facility, not a default attachment.
Never serialize closures, borrowed capabilities, NodeState objects, or raw handles.

Screenshots, identifiers, semantic labels, and replay scripts can reveal private content
even when graph values are omitted. Repository specimens use synthetic data. Real apps
require explicit capture permission and redaction covering images and scripts too, or
capture is refused. CI uploads only approved synthetic material.

Start with CLI commands and local files. No in-app inspector, server, browser terminal, or
MCP system is required. Illustrative developer commands are:

```sh
swift run --package-path Examples TesseraLab list
swift run --package-path Examples TesseraLab run layout --case compact
swift run --package-path Examples TesseraLab capture layout --size 40x16
swift run --package-path Examples TesseraLab replay button --scenario release-outside
```

Implement only the subset justified by the first specimen, then expand. Document actual
names and failure behavior. `run` uses real terminal dimensions; headless `--size` controls
the test device. PTY tests set the PTY window size rather than pretending the host is smaller.
A PTY checkpoint needs a causal completion acknowledgement outside the display stream,
not a guessed delay. This integration can follow the in-memory loop.

A bundle records source revision/dirty marker, case/scenario, viewport, policy profile,
seed when used, exporter configuration, checkpoints, styled text, sanitized diagnostics,
bounded trace, and images. Failures retain the last successful checkpoint. Separate output
from approved baselines. Keep logging away from the application's terminal display stream.

The exporter renders actual captured cells and handles the features it claims: widths,
continuation cells, styles/backgrounds, reverse video, clipping, and cursor. Unsupported
attributes or glyphs are explicit limitations. Pin font configuration, cell geometry,
palette/default colors, rasterizer, and exporter version for canonical images. Do not commit
font files. Exact styled-cell comparisons are the portable oracle; images support review.
Cross-platform/emulator pixel identity is not a goal.

A VT projection is not a screenshot of the emulator GUI. Open readable individual frames;
a contact sheet is supplemental. Add exporter conformance cases for wide text and styles
as those enter the specimen; do not silently simplify them into misleading pictures.

## 5. Specimens instead of application scaffolding

Use primitive specimens (one rendering/layout idea), interaction specimens (one component
and visible outcome), then small integration apps. Select cases before entering terminal
mode. Before Picker exists, a command-line case is enough. Before scrolling exists, show
one short case at a time. No fake controls, handwritten navigation router, or temporary
public API is needed to configure the example.

Share the actual app-owned model and root factory across live runs, scenarios, and docs
captures. Keep expected outcomes independently reasoned, not generated from the same
algorithm being tested. Keep framework contract tests independent of demo titles/chrome.

Examples-local support holds specimen definitions and host glue, not a second widget
library. Root package tests must not depend on the Examples package; put specimen tests
in Examples/Tests. A configurable Button playground can come later as an additional
example, never a replacement for the tiny canonical specimen.

Use 80x24 and 40x16, relevant natural/minimum sizes, and one-cell boundary neighbors. Zero/
one-cell geometry belongs in focused tests. Do not make the old Showcase's 23/48/73-column
role breakpoints framework-wide requirements. Test representative known light/dark default
palettes, NO_COLOR, ASCII decoration fallback, and applicable keyboard modes without an
exhaustive Cartesian product on every commit.

## 6. Design review without a human bottleneck

Use existing component contracts and design/tokens.md as the initial authority. Engineering
readiness for a scoped capability requires a known public shape, state ownership, geometry,
relevant interaction rules, and acceptance scenarios. Future catalog work must not block
an unrelated vertical slice. Do not relabel an incomplete whole component as complete.

Use the simplest restrained visual treatment when a human has not approved a new reference.
Mark it provisional and continue implementation/testing. Final human approval of visual
baselines is a separate state; it is not fabricated and not required to keep coding on this
branch. Approved existing baselines must not be overwritten merely to make tests pass.
Candidate changes have a rationale, before/after evidence, and separate identification.

Review task clarity, hierarchy, alignment/spacing, purposeful borders, focus/press/disabled/
selection differentiation, color-independent signals, compact behavior, and feedback/recovery.
Avoid turning each specimen into a miniature desktop application. Prefer consistent glyphs,
compact actions, aligned content, and meaningful whitespace over decorative chrome.

The agent must open actual images before claiming visual review. A screenshot test can
preserve bad design; a green test or numerical self-rating does not certify taste. A second
review pass helps but cannot grant maintainer approval. Record unavailable image or terminal
review honestly. Known default colors are needed for numeric contrast claims.

Each specimen has an API-friction note: what normal app code required, any internal access,
and whether helper code hides essential complexity. Repeated friction across independent
examples justifies API changes better than one unusual demo.

## 7. Delivery order and acceptance

These milestones describe dependencies, not instructions to recreate completed work or a
promise of session scope.

### P4.0 - Rebaseline and decouple

Inventory and preserve local work, establish provenance and baseline failures, extract one
existing text/layout specimen, and retire Showcase-only acceptance gates. Keep useful tests
and historical progress. No bulk rewrite or wholesale deletion of the Showcase is needed.

### P4.1 - Review-loop skeleton

Share driving logic; add deterministic initial/update/resize checkpoints, real in-memory
presentation/VT integration, styled/structural capture, and the first faithful image. Prove
two sizes and a persistent multi-frame case. Observation must not trigger passes. A broken
layout must fail its intended test. No fake Button input before routing exists.

### P4.2 - Complete needed visual primitives

Adopt existing Text, layout, Flex, clipping, environment, and negotiation. Complete only
missing wrapping/truncation, style inheritance, and decoration needed for the next control.
Test exact measurement/render agreement, wide/combining text, insets, zero/one-cell geometry,
and fallback. Calibrate small provisional references rather than designing a whole app.

### P4.3 - One fully operable Button

Complete focus/key routing, explicit traversal, basic pointer hit testing/phases, click-to-
focus, capture/cancellation as needed, controlled actions, and visible states. Add selectors
and pilot operations alongside the real seams. Use a Button/result and a second focus target.

Cover legacy Enter/Space, phased activation, primary down/up, outside release, disabled
behavior, removal during a press, and clipped/overlapping targets. Keyboard-only progress
can land independently but does not finish the milestone. Hover is a separate small addition
with motion-requirement and focus-loss coverage before mouse APIs graduate as complete.
Do not include broad text selection or a gesture framework.

### P4.4 - Complete viewport

Reuse existing ScrollView geometry and output-only ScrollIndicator. Add clamping, keyboard/
wheel movement, focus reveal, and documented track/thumb behavior. A few overflowing Text/
Button rows and one nested-boundary case suffice; no public List is needed for this demo.

Offscreen scrollable descendants may remain logical traversal candidates, while hidden,
collapsed, or disabled controls do not. Reveal after focus is real shared-driver behavior,
not pilot magic. Removal still clears focus rather than guessing a neighboring control.

With binary handled/ignored routing, consume a wheel event when any local movement occurs;
bubble only when none occurs. Do not partly move and then resend the full delta to a parent.
Residual-delta routing would require a separate explicit contract. Test resize, changing
content, clips, reachable offscreen controls, and indicator agreement.

### P4.5 - Editing and small controlled controls

Move complete single-line TextField editing ahead of navigation: app-owned text, ephemeral
grapheme-safe caret/selection/reveal state per catalog, insertion/deletion, committed paste,
submission, click-to-caret, external text replacement, and hardware-cursor requests. Do not
mistake committed text for full IME pre-edit support. Do not store a second text copy in
NodeState. Follow with separate Toggle/Stepper/Picker increments and a tiny settings editor;
a public Form is not required.

### P4.6 - Collections

List/Section precede Grid/Table and navigation composition. Reuse the Flex resolver and
viewport/indicator contracts. Test keyed identity, data/selection reconciliation, empty and
long content, resize, and keyboard/pointer behavior. No virtualization, spanning, or general
data-source/sorting framework unless an existing accepted contract requires it.

### P4.7 - Panes and navigation

Keep final SplitView negotiation; complete keyboard/pointer adjacent-pair resizing,
constraints, collapse, capture, and resize-during-drag in a two-pane specimen. Then compose
NavigationSplitView's generic regular/compact roles and controlled visibility. Preserve app
state and documented focus semantics during role replacement. Do not revive Showcase-
specific breakpoint requirements.

### P4.8 - Graduation

Use two small realistic apps, a settings editor and record/detail browser, plus specimens
to cover the accepted surface. Demonstrate plain and Observable/reducer-style app ownership
without storing business state in the graph. Complete documented platform/terminal checks,
public-API examples, architecture gates, lifecycle coverage, and measured performance.
Every accepted component needs tests, direct launch, applicable replay evidence, and
explicit visual review. Report unsupported or unverified combinations honestly.

Expanded cross-view/container display-text selection and copy from plan 030 is separated
from ordinary mouse support and deferred to its own proposal. This does not remove the
TextField's scoped editing/selection contract. Animation, partial graph rendering, a large
Showcase, an in-app inspector, and an MCP server are not Phase 4 prerequisites.

## 8. Verification and package boundaries

Use four complementary layers: exact contract tests; headless interaction with the shared
driver; real session/renderer/encoder plus persistent VT integration; and selected PTY/
real-terminal smoke. Fast inner-loop checks are the first two. Full repository/platform
checks remain graduation gates, with any omissions explicitly recorded at handoff.

High-value cases include focused-node removal, keyed reordering, disabled controls, bound-
value replacement, outside release/capture cancellation, overlay/clipping, resize during
interaction, nested scroll boundaries, wide text, paste-as-commit, unchanged-frame output,
and terminal requirement escalation/de-escalation. Include intermediate states. Use bounded
seeded generated tests when useful, not only giant goldens or only random input.

Retain existing import/dependency restrictions. Core must not import Runtime, terminal IO,
test support, the CLI, or UI frameworks. A shared driver can justify an early narrow
TesseraRuntime target; it is not required merely for naming symmetry. Compile-prove the
seam before publishing it. Stable graph/driver testing adapters belong in TesseraTestSupport;
terminal-specific capture stays with terminal test support; CLI/example glue stays in
Examples. Optional visual-export/transport dependencies must not enter the ordinary view
product. Update executable boundary checks for deliberate new target edges.

Preserve deterministic work counters; benchmark durations with machine/configuration context.
Do not snapshot wall-clock values or optimize without evidence. Source comments and DocC
state enduring behavior/ownership, never phase numbers or temporary delivery status.

## 9. Repository adoption and evidence

Do not rewrite all of Spec.md before implementing the first specimen. Make a narrow branch-
local adoption note and update the conflicting sections alongside relevant implementation.
Mark plan 030 superseded for remaining delivery, without changing its historical checkboxes.
Update Phase 4 prerequisites/landing map/definition of done, diagnostics export, and Phase 5's
early-driver boundary as they are touched. Treat design/showcase.md as historical application
design rather than normative framework acceptance. Update ProjectStatus truthfully.

Remove stale references that put SplitView negotiation back in Slice 6, delay TextField
editing until final catalog integration, or require every slice to grow a Showcase. Do not
change established integer algorithms or ownership just to reconcile prose.

The handoff uses STATE.md for decisions/provenance/resume state and REVIEW.md for actual
launch commands, artifacts, commit order, test results, critique, and remaining approvals.
Implemented, behavior-tested, visually reviewed, real-terminal-checked, and human-approved
are distinct statuses. A passing snapshot never supplies all five.

## Source anchors

The enduring contracts remain in `docs/Spec.md`, the relevant `design/` component documents,
and `.agents/plans/030-phase-4-view-layer-and-showcase.md` except for the explicit revisions
above. Key reuse candidates on the reviewed main are `ViewGraph`, `GraphDiagnostics`,
`ViewGraphSnapshotting`, `InMemoryTerminalSession`, and the Showcase host/root factory.
Inspect actual local paths and signatures rather than copying illustrative APIs.

Development/quality conventions come from CONTRIBUTING.md, justfiles/quality.just, and
`docs/LocalDevelopmentState.md`. The existing worktree investigation records per-checkout
SwiftPM output and revision/platform-keyed shared Ghostty cache; respect those scopes.
This design borrows Textual's inspect/operate/review loop, not its appearance or architecture.
No external documentation is needed to begin the scoped first implementation.
