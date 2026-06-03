---
name: Terminal Ownership and Isolation Spec
description: Convert ownership/isolation review notes into normative Tessera architecture and resolve open design questions.
status: completed
created: 2026-06-03
updated: 2026-06-03
---

## Progress

- [x] **Phase 1 — Separate review notes from spec language**
  - [x] 1.1 Mark or move strengths/risks review material out of normative spec flow
  - [x] 1.2 Keep the introductory thesis and SQLite analogy in the spec
- [x] **Phase 2 — Make ownership rules normative**
  - [x] 2.1 Replace suggestion-style sections with scoped capability rules
  - [x] 2.2 Define actor/global actor ownership surfaces as architecture
  - [x] 2.3 Define Sendability policy as architecture
  - [x] 2.4 Define deterministic testing contract as architecture
- [x] **Phase 3 — Answer open questions one by one**
  - [x] 3.1 Decide primary API shape and canonical isolation model
  - [x] 3.2 Decide runtime isolation domain
  - [x] 3.3 Decide whether rendering can ever be async
  - [x] 3.4 Decide effect/state mutation boundaries
  - [x] 3.5 Decide render invalidation ownership
  - [x] 3.6 Decide input backpressure policy
  - [x] 3.7 Decide deterministic test drain/step APIs
  - [x] 3.8 Decide public/package/internal capability boundaries
  - [x] 3.9 Decide dynamic terminal mode policy
  - [x] 3.10 Decide intentionally non-Sendable types
- [x] **Phase 4 — Final cleanup**
  - [x] 4.1 Remove remaining audit/review wording from `docs/Spec.md`
  - [x] 4.2 Validate Markdown with `pnpx markdownlint-cli docs/Spec.md`

## Overview

The current ownership/isolation material is useful but mixes public-spec architecture with
review notes. This plan converts the useful parts into normative API constraints, preserves
or removes temporary audit language, and resolves the remaining design questions through a
one-question-at-a-time discussion. The goal is a spec where illegal terminal operations are
front-and-center and made unrepresentable by isolation and ownership.

## Phase 1 — Separate review notes from spec language

**Goal**: Keep the thesis and analogy in the spec while preventing review/audit language
from sounding like final public architecture.

### Step 1.1 — Mark or move review notes

- File: `docs/Spec.md`
- Either mark strengths/risks sections as temporary review notes or move them to an
  investigation file.
- Acceptance: The spec no longer reads as if strengths/risks are final product guidance.

### Step 1.2 — Preserve thesis and analogy

- File: `docs/Spec.md`
- Keep the introductory ownership thesis and SQLite analogy in concise normative prose.
- Acceptance: The analogy remains visible and readable without wide tables.

## Phase 2 — Make ownership rules normative

**Goal**: Convert sections 4–6 from suggestions into architectural rules.

### Step 2.1 — Scoped capability rules

- File: `docs/Spec.md`
- Define `TerminalSession`, `Frame`, `Screen`, `EventContext`, and raw-handle ownership as
  normative scoped capabilities.
- Acceptance: Public APIs cannot write outside transactions, leak frames, or leak raw
  handles by design.

### Step 2.2 — Actor/global actor surfaces

- File: `docs/Spec.md`
- Define actor-owned surfaces such as output, renderer state, mode lifecycle, input, and
  runtime isolation.
- Acceptance: Serialization boundaries are described as architecture, not suggestions.

### Step 2.3 — Sendability policy

- File: `docs/Spec.md`
- Define where `Sendable` is required and where it is intentionally avoided.
- Acceptance: `View`/widgets/app state are not broadly required to be `Sendable` unless a
  boundary requires it.

### Step 2.4 — Deterministic testing contract

- File: `docs/Spec.md`
- Define explicit event/render stepping and forbid tests relying on sleeps or `Task.yield`.
- Acceptance: The test model has a concrete deterministic shape.

## Phase 3 — Answer open questions one by one

**Goal**: Use a grill-me loop to resolve design questions before finalizing the spec.

### Step 3.1 — Primary API shape

- File: `docs/Spec.md`
- Decide whether immediate-mode, runtime-driven, or both is primary and which owns the
  canonical isolation model.
- Acceptance: The spec identifies the canonical isolation entry point.

### Step 3.2 — Runtime isolation domain

- File: `docs/Spec.md`
- Decide between `TerminalSession` actor, `AppRuntime` actor, custom global actor, or a
  hybrid.
- Decision: core immediate-mode APIs have no global actor requirement. The optional
  runtime uses `@MainActor` for UI delivery/familiarity and does not require a
  Tessera-specific `State`/`Action` program model.
- Acceptance: State update, event delivery, effect delivery, and render invalidation have
  a named isolation domain.

### Step 3.3 — Async rendering

- File: `docs/Spec.md`
- Decide whether rendering must be synchronous while holding a borrowed frame.
- Decision: render transactions and `View.render` are synchronous and non-suspending. The
  `draw` call may be async to enter the session/renderer actor, but the borrowed frame body
  cannot suspend.
- Acceptance: The spec states whether `View.render` may suspend.

### Step 3.4 — Effect/state mutation boundary

- File: `docs/Spec.md`
- Decide whether effects can access mutable state or only emit actions.
- Decision: Tessera's optional runtime does not define `Effect`, `State`, or `Action`, and
  does not own application business-state mutation. Runtime contexts expose UI-scoped
  capabilities only; async user work re-enters through explicit `@MainActor`
  invalidation/event APIs.
- Acceptance: State mutation boundaries are explicit.

### Step 3.5 — Render invalidation ownership

- File: `docs/Spec.md`
- Decide who can invalidate rendering and how invalidations are coalesced.
- Decision: invalidation is requestable, rendering is owned. Runtime API uses
  `setNeedsDisplay()` and `setNeedsLayout()`; lower-level session/renderer API uses
  `invalidateRendererState()`. Runtime invalidations are coalesced and only the
  session/runtime opens render transactions.
- Acceptance: Invalidation is not an ad hoc side effect.

### Step 3.6 — Input backpressure

- File: `docs/Spec.md`
- Decide buffering/coalescing/drop policy when input outpaces update/render.
- Decision: preserve ordered semantic input, coalesce latest-value events, and bound noisy
  streams. Key/paste/focus events are not silently dropped; resize, display/layout
  invalidation, and mouse movement are coalesced by default. Overflow is explicit.
- Acceptance: Input delivery has a documented pressure policy.

### Step 3.7 — Deterministic test stepping

- File: `docs/Spec.md`
- Decide test APIs for draining effects, stepping input, and rendering frames.
- Decision: core tests use explicit test terminals and input sources; runtime tests use
  precise `step` and bounded `drain` APIs. Timers/animations use injected clocks such as
  Point-Free's `TestClock`; snapshots use explicit terminal snapshots rather than sleeps or
  `Task.yield()`.
- Acceptance: Tests do not require sleeps or scheduler guessing.

### Step 3.8 — Capability visibility

- File: `docs/Spec.md`
- Decide public/package/internal boundaries for terminal writes, buffers, handles, and
  renderer escape hatches.
- Decision: public API exposes safe values and scoped operations, not raw authority.
  `TerminalSession.draw` is public; `Frame` is public but not publicly constructible;
  `Buffer` and semantic values are public. Raw handles, arbitrary live terminal writes,
  renderer commit escape hatches, and cleanup internals are package/internal. Test support
  lives in `TesseraTerminalTestSupport`; SPI may be used sparingly for diagnostics and
  test hooks, but not production ownership bypasses.
- Acceptance: Public API cannot bypass ownership guarantees.

### Step 3.9 — Dynamic terminal modes

- File: `docs/Spec.md`
- Decide whether widgets may request modes dynamically and who arbitrates conflicts.
- Decision: views/widgets do not directly mutate terminal modes. Lifecycle modes are
  session-owned; protocol modes are controlled by application configuration and/or dynamic
  declarative `TerminalRequirements`; the runtime/session arbitrates and applies changes
  through `ModeLifecycle`. Frame-scoped terminal state is renderer-owned.
- Acceptance: Mode toggling and teardown ordering are deterministic.

### Step 3.10 — Intentionally non-Sendable types

- File: `docs/Spec.md`
- Decide which types should be non-`Sendable` as a feature.
- Decision: `Sendable` is for semantic values that safely cross isolation domains. Views,
  widgets, scenes, responders, app state, dependency containers, caches, and user-provided
  closures do not broadly require `Sendable`. Scoped capabilities and raw handles are
  noncopyable/nonescapable where possible. `Buffer` is `Sendable` only while it remains
  pure value storage.
- Acceptance: The spec documents non-sendability as intentional safety, not a missing
  conformance.

## Phase 4 — Final cleanup

**Goal**: Make the document read as a coherent architecture spec.

### Step 4.1 — Remove audit wording

- File: `docs/Spec.md`
- Remove or relocate leftover review phrases such as strengths, smells, suggestions, and
  before/after framing.
- Acceptance: The ownership/isolation material reads as final spec prose.

### Step 4.2 — Validate Markdown

- File: `docs/Spec.md`
- Run `pnpx markdownlint-cli docs/Spec.md`.
- Acceptance: Markdownlint reports no warnings.

## References

- `docs/Spec.md`
- `.agents/skills/planning/SKILL.md`
- `/Users/rob/Documents/pfw-concurrency-skill/skills/swift6-concurrency-migration/examples/sqlite-ownership-and-testing.md`
