---
name: Redistribute Ownership and Isolation Material
description:
  Move detailed ownership/isolation rules from the top thesis into their relevant spec
  phases and slices.
status: completed
created: 2026-06-03
updated: 2026-06-03
---

## Progress

- [x] **Phase 1 — Keep thesis concise**
  - [x] 1.1 Shrink top ownership/isolation section to project values and principles
- [x] **Phase 2 — Move terminal substrate details**
  - [x] 2.1 Move session/raw-handle/output visibility details into Phase 2 Slice 3
  - [x] 2.2 Move render transaction/frame details into Phase 2 Slice 4
  - [x] 2.3 Move input backpressure details into input/protocol slices
- [x] **Phase 3 — Move view/runtime details**
  - [x] 3.1 Move view, context, Sendability, and terminal requirements into Phase 4
  - [x] 3.2 Move optional runtime, stepping, clocks, and test support into Phase 5
  - [x] 3.3 Move module/test-support/SPI details into package layout
- [x] **Phase 4 — Validate and review**
  - [x] 4.1 Remove duplicated or stale ownership material
  - [x] 4.2 Validate Markdown with `pnpx markdownlint-cli docs/Spec.md`

## Overview

The ownership/isolation material currently captures the right architectural decisions but
is too detailed near the top of the spec. This plan keeps the top section as a concise
project thesis and redistributes concrete API rules to the phases where they are designed
or implemented. The goal is a document that reads naturally phase-by-phase while
preserving the safety model.

## Phase 1 — Keep thesis concise

**Goal**: Make the top section state the project value and architectural lens, without
front-loading Phase 4/5 API details.

### Step 1.1 — Shrink top ownership/isolation section

- File: `docs/Spec.md`
- Replace the long top section with concise thesis prose, the SQLite analogy, and a short
  map of how later phases apply the thesis.
- Acceptance: The top section no longer defines detailed Phase 4/5 APIs.

## Phase 2 — Move terminal substrate details

**Goal**: Put terminal foundation rules where implementers will look for them.

### Step 2.1 — Session/raw-handle/output visibility

- File: `docs/Spec.md`
- Move `TerminalSession`, `TerminalOutput`, `PlatformHandles`, raw-handle privacy, public
  write prohibition, and configuration-scoped application entry into Phase 2 Slice 3.
- Acceptance: Phase 2 Slice 3 owns low-level terminal capability visibility.

### Step 2.2 — Render transaction/frame rules

- File: `docs/Spec.md`
- Move borrowed `Frame`, synchronous render body, renderer actor state, and
  `invalidateRendererState()` rules into Phase 2 Slice 4.
- Acceptance: Phase 2 Slice 4 owns render transaction safety.

### Step 2.3 — Input backpressure

- File: `docs/Spec.md`
- Move semantic/coalesced/noisy input policy into Phase 2 Slice 5 and/or Phase 3 protocol
  slices where paste, mouse, focus, and resize are discussed.
- Acceptance: Input policies are near parser/protocol design.

## Phase 3 — Move view/runtime details

**Goal**: Put higher-level UI/runtime rules in later phases.

### Step 3.1 — View-layer rules

- File: `docs/Spec.md`
- Move `View`, `ViewContext`, `ResponderContext`, `TerminalRequirements`, display/layout
  invalidation, and non-`Sendable` view/widget policy into Phase 4.
- Acceptance: Phase 4 owns view and widget isolation details.

### Step 3.2 — Runtime/test rules

- File: `docs/Spec.md`
- Move optional `@MainActor` runtime, stepping/drain, injected clocks, Point-Free testing
  tools, and terminal snapshots into Phase 5.
- Acceptance: Phase 5 owns runtime and deterministic testing details.

### Step 3.3 — Package layout and SPI

- File: `docs/Spec.md`
- Move `TesseraTerminalTestSupport` and SPI guidance into proposed module/file layout.
- Acceptance: package/API visibility notes live with target layout.

## Phase 4 — Validate and review

**Goal**: Ensure the document is coherent and lint-clean after the moves.

### Step 4.1 — Remove duplication/stale references

- File: `docs/Spec.md`
- Search for duplicated definitions and stale references caused by moving content.
- Acceptance: ownership concepts are not repeated unnecessarily and no stale API names
  remain.

### Step 4.2 — Validate Markdown

- File: `docs/Spec.md`
- Run `pnpx markdownlint-cli docs/Spec.md`.
- Acceptance: markdownlint reports no warnings.

## References

- `docs/Spec.md`
- `.agents/plans/001-terminal-ownership-isolation-spec.md`
