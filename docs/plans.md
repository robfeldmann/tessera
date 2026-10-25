---
type: hub
stage: living
---

# Plans

One plan per piece of work, in order. This page is rendered from each plan's frontmatter by `scripts/plans.py`; change `stage`, `order`, `description`, or `completed` in the plan and re-run it (`mise run quality:lint` fails while the page is stale). Read a plan's Progress list and `Next:` line before resuming it, and its Approach and Acceptance before starting it.

## Next

1. [Build the Phase 4 view layer with the tooling that proves it](plans/phase-4-view-layer-and-developer-tooling.md): Build the Phase 4 view layer from the omp2-reviewed catalog and the developer tooling that drives, pictures, and checks it, in one slice order where each component lands with its demo, its scenario, and the harness capability it needs.

## Done

- 2026-06-03 [Terminal Ownership and Isolation Spec](plans/terminal-ownership-isolation-spec.md): Convert ownership/isolation review notes into normative Tessera architecture and resolve open design questions.
- 2026-06-03 [Redistribute Ownership and Isolation Material](plans/redistribute-ownership-isolation-material.md): Move detailed ownership/isolation rules from the top thesis into their relevant spec phases and slices.
- 2026-06-03 [Local Linux Dev Loop](plans/local-linux-dev-loop.md): Establish a Docker-free local loop for macOS builds, Linux cross-builds, and optional Linux test execution.
- 2026-06-04 [GitHub Actions Phase 0](plans/github-actions-phase-0.md): Add minimal GitHub Actions workflows for Swift build/test matrix and DocC validation.
- 2026-06-05 [Phase 1 Walking Skeleton](plans/phase-1-walking-skeleton.md): Build the Phase 1 Tessera walking skeleton.
- 2026-06-06 [Phase 2 Slice 1 Ghostty Snapshot Harness](plans/phase-2-slice-1-snapshot-harness.md): Build the Ghostty-backed virtual terminal harness for renderer snapshot coverage.
- 2026-06-07 [Phase 2 Slice 2 ANSI Encoder](plans/phase-2-slice-2-ansi-encoder.md): Implement the pure semantic ANSI control-sequence encoder with exact byte fixtures and Ghostty round-trip coverage.
- 2026-06-09 [Phase 2 Slice 3 Terminal Lifecycle](plans/phase-2-slice-3-terminal-lifecycle.md): Add scoped terminal sessions, real POSIX platform I/O, lifecycle rollback, emergency cleanup, and reset tooling.
- 2026-06-10 [Risk-Driven Test Coverage](plans/risk-driven-test-coverage.md): Improve coverage for terminal lifecycle, live POSIX I/O, ANSI encoding, and cancellation-sensitive code.
- 2026-06-13 [Phase 2 Slice 4 Width-Aware Renderer](plans/phase-2-slice-4-width-aware-renderer.md): Redesign terminal buffers for display-width correctness and replace full repaint rendering with stateful damage-tracked rendering transactions.
- 2026-06-13 [Phase 2 Slice 5 Legacy Input Parser](plans/phase-2-slice-5-legacy-input-parser.md): Replace the walking-skeleton byte parser with durable semantic terminal input events, a stateful legacy escape-sequence parser, and session event streams.
- 2026-06-16 [Frost Windows VM Prototype](plans/frost-windows-vm-prototype.md): Prototype a Frost-based Windows 11 ARM64 VM workflow as an alternative to the UTM Phase 0 setup.
- 2026-07-02 [Phase 2 Slice 6 Windows Terminal IO](plans/phase-2-slice-6-windows-terminal-io.md): Complete TesseraTerminalIO's Windows implementation and enable Windows CI for Phase 2.
- 2026-07-02 [Windows Ghostty Snapshot Enablement](plans/windows-ghostty-snapshot-enablement.md): Productize the Windows libghostty-vt build path proven by the Phase 5 spike and enable Ghostty-backed snapshot tests on Windows behind an explicit local gate.
- 2026-07-03 [Phase 3 Slice 1 Bracketed Paste Mode](plans/phase-3-slice-1-bracketed-paste-mode.md): Add bracketed paste as the first modern terminal protocol mode, with parser isolation, lifecycle cleanup, tests, and the initial Phase 3 demo app.
- 2026-07-04 [Phase 3 Slice 2 Focus Events](plans/phase-3-slice-2-focus-events.md): Add terminal focus gained/lost events using CSI focus tracking, sharing the Phase 3 mode lifecycle and preserving bracketed-paste isolation.
- 2026-07-05 [Phase 3 Slice 3 SGR Mouse Tracking](plans/phase-3-slice-3-sgr-mouse-tracking.md): Add SGR mouse tracking with semantic press, release, drag, scroll, and motion events, opt-in any-event hover tracking with bounded motion coalescing, mode lifecycle cleanup, parser coverage, and an interactive demo panel.
- 2026-07-05 [Kitty Keyboard Full Coverage](plans/kitty-keyboard-full-coverage.md): Expand Tessera keyboard input to preserve the full Kitty keyboard protocol surface and verify it with table-driven parser tests plus Ghostty key-encoder oracle tests.
- 2026-07-06 [Phase 3 Slice 4 Kitty Keyboard Protocol](plans/phase-3-slice-4-kitty-keyboard-protocol.md): Add Kitty keyboard parsing and lifecycle support, expand key metadata, and introduce dynamic application-mode reconciliation for Phase 4 requirements.
- 2026-07-06 [Phase 3 Slice 5 OSC 8 Hyperlinks](plans/phase-3-slice-5-osc-8-hyperlinks.md): Add semantic OSC 8 hyperlink styling, encoder support, renderer state transitions, hyperlink-aware snapshots, and a demo panel.
- 2026-07-07 [Phase 3 Slice 6 Terminal Capability Detection](plans/phase-3-slice-6-terminal-capability-detection.md): Add conservative terminal capability reporting and configuration policy so modern protocol enablement degrades gracefully.
- 2026-07-07 [Phase 3 Slice 7 Kitty Graphics Protocol](plans/phase-3-slice-7-kitty-graphics-protocol.md): Add first-class Kitty Graphics Protocol (KGP) support: APC encoding and parsing, per-cell pixel geometry, session-scoped image transmission, frame-scoped placement, unconditional cleanup, a Ghostty snapshot harness, and a procedural-gradient demo panel.
- 2026-07-08 [Phase 3 Slice 8 Color Degradation Baseline](plans/phase-3-slice-8-color-degradation-baseline.md): Add capability-aware color degradation so Tessera renders truecolor, 256-color, ANSI 16-color, and no-color output safely from the same semantic styles.
- 2026-07-09 [Phase 3 Slice 9 OSC 52 Clipboard](plans/phase-3-slice-9-osc-52-clipboard.md): Add policy-gated OSC 52 clipboard writes with semantic encoding, session integration, multiplexer-aware defaults, tests, docs, and demo coverage.
- 2026-07-09 [Phase 3 Slice 10 Cursor Styling](plans/phase-3-slice-10-cursor-styling.md): Add first-class session-scoped cursor shape and cursor color policy using DECSCUSR and OSC 12/112, with deterministic enter/apply/restore behavior and cleanup.
- 2026-07-09 [Phase 3 Slice 11 Underline Extensions](plans/phase-3-slice-11-underline-extensions.md): Add semantic SGR underline style variants and colored underlines: undercurl and other SGR 4:x styles, underline color/reset, renderer diffing, compatibility with the legacy underline bit, snapshots, exact byte tests, and documentation.
- 2026-07-11 [Phase 3 Modern Terminal Protocols](plans/phase-3-modern-terminal-protocols.md): Coordinate the twelve Phase 3 protocol slices so parser, lifecycle, renderer, live session policy, tests, and the example app evolve consistently.
- 2026-07-11 [Phase 3 Slice 12 Runtime Protocol Control](plans/phase-3-runtime-protocol-control.md): Reconcile active protocol evidence and make selected rendering policies and terminal modes adjustable during a live application session.
- 2026-07-20 [Tessera open-source readiness](plans/open-source-readiness.md): Prepare Tessera for a deliberate public GitHub launch with Apache-2.0 licensing, community governance, release notes, and post-launch static DocC hosting.
- 2026-10-22 [Tooling orchestration and Lefthook migration](plans/tooling-orchestration-and-lefthook.md): Unify formatter ownership, deterministic quality gates, hook management, and CI around repository-managed commands.
- 2026-10-22 [Terminal I/O concurrency review fixes](plans/terminal-io-concurrency-review-fixes.md): Fix the concurrency and isolation findings from a review of TesseraTerminal and TesseraTerminalIO: cancellation-safe teardown, serialized terminal output, blocking I/O off the cooperative pool, session and stream lifetimes, vouch cleanup, and deterministic terminal tests. Also the bug punchlist from the 2026-10-17 and 2026-10-20 repository review notes: nested view lists in layout containers, the parallel suite, error-type conformances, and CI coverage of the Examples package.
- 2026-10-22 [Toolchain, repository conventions, and plan consolidation](plans/toolchain-conventions-and-plan-consolidation.md): Baseline every local check, make Xcode 26.6 and Swift 6.3.3 the baseline on every lane while adding Swift 6.4 and Xcode 27 support, port plan 033 and its spikes to main, run plan 034, adopt the owner's newer repository conventions (unwrapped prose with rumdl, an IWE docs workspace with slug-named plans and a split spec, mise and hk in place of just and Lefthook, Tessera-owned Tart and Lima VMs, and a current Zig and libghostty-vt), then merge plans 032 and 033 into one plan.
- 2026-10-22 [Make UTM the one Windows lane and retire Frost](plans/windows-on-utm.md): Retire the Frost QEMU workflow and make the UTM guest the one scripted, rebuildable Windows lane, driven by scripts/vm.py like the macOS and Linux guests.
- 2026-10-23 [Ship libghostty-vt as a prebuilt binary](plans/libghostty-vt-binary-distribution.md): Ship libghostty-vt as a prebuilt SE-0482 static-library artifact bundle that Tessera's CI builds once per Ghostty pin, so apps can depend on Tessera by version and no build or test job runs Zig.
- 2026-10-25 [Run the file-level quality checks as hk steps](plans/hk-quality-steps.md): Replace the hand-written changed-file and pre-commit quality scripts with hk steps that the hook, `hk check`, and the full gate in CI share, so commits work from any shell.

## Cancelled

- [Phase 4 View Layer and Tessera Showcase](plans/phase-4-view-layer-and-showcase.md): Implement the seven-slice Tessera view layer with design-catalog readiness gates and a progressively executable Showcase integration app.
- [Phase 4 view layer, redesigned from the omp2 reference](plans/omp2-reference-gallery-and-phase-4-redesign.md): Use oh-my-pi's omp2 TUI as the visual and behavioral reference for Tessera's Phase 4 components (a verified prior-art inventory, a captured reference gallery with ASCII fallbacks, an owner taste review, a Rust-to-Swift translation key, and a revised catalog), then implement the view layer in dependency order with per-component demos. Replaces plan 030.
- [Developer tooling for agents and humans](plans/developer-tooling.md): A headless harness, a scenario language, semantic queries over the view graph, deterministic text/grid/SVG shots, invariant and cost checks, "why" traces, and a catalog review view, built on plan 032's Phase 8 demo runner and landing one capability per Phase 4 phase so agents can build, debug, and evaluate Tessera apps unattended.

## Plan numbers

Plans written before the docs workspace were numbered (`.agents/plans/NNN-slug.md`) and are cited by number in commit messages, research records, and older plans. The number is now the plan's `order`; this table maps each number to its page.

| Number | Plan | Stage |
| --- | --- | --- |
| 001 | [Terminal Ownership and Isolation Spec](plans/terminal-ownership-isolation-spec.md) | done |
| 002 | [Redistribute Ownership and Isolation Material](plans/redistribute-ownership-isolation-material.md) | done |
| 003 | [Local Linux Dev Loop](plans/local-linux-dev-loop.md) | done |
| 004 | [GitHub Actions Phase 0](plans/github-actions-phase-0.md) | done |
| 005 | [Phase 1 Walking Skeleton](plans/phase-1-walking-skeleton.md) | done |
| 006 | [Phase 2 Slice 1 Ghostty Snapshot Harness](plans/phase-2-slice-1-snapshot-harness.md) | done |
| 007 | [Phase 2 Slice 2 ANSI Encoder](plans/phase-2-slice-2-ansi-encoder.md) | done |
| 008 | [Phase 2 Slice 3 Terminal Lifecycle](plans/phase-2-slice-3-terminal-lifecycle.md) | done |
| 009 | [Risk-Driven Test Coverage](plans/risk-driven-test-coverage.md) | done |
| 010 | [Phase 2 Slice 4 Width-Aware Renderer](plans/phase-2-slice-4-width-aware-renderer.md) | done |
| 011 | [Phase 2 Slice 5 Legacy Input Parser](plans/phase-2-slice-5-legacy-input-parser.md) | done |
| 012 | [Phase 2 Slice 6 Windows Terminal IO](plans/phase-2-slice-6-windows-terminal-io.md) | done |
| 013 | [Frost Windows VM Prototype](plans/frost-windows-vm-prototype.md) | done |
| 014 | [Windows Ghostty Snapshot Enablement](plans/windows-ghostty-snapshot-enablement.md) | done |
| 015 | [Phase 3 Modern Terminal Protocols](plans/phase-3-modern-terminal-protocols.md) | done |
| 016 | [Phase 3 Slice 1 Bracketed Paste Mode](plans/phase-3-slice-1-bracketed-paste-mode.md) | done |
| 017 | [Phase 3 Slice 2 Focus Events](plans/phase-3-slice-2-focus-events.md) | done |
| 018 | [Phase 3 Slice 3 SGR Mouse Tracking](plans/phase-3-slice-3-sgr-mouse-tracking.md) | done |
| 019 | [Phase 3 Slice 4 Kitty Keyboard Protocol](plans/phase-3-slice-4-kitty-keyboard-protocol.md) | done |
| 020 | [Phase 3 Slice 5 OSC 8 Hyperlinks](plans/phase-3-slice-5-osc-8-hyperlinks.md) | done |
| 021 | [Phase 3 Slice 6 Terminal Capability Detection](plans/phase-3-slice-6-terminal-capability-detection.md) | done |
| 022 | [Phase 3 Slice 7 Kitty Graphics Protocol](plans/phase-3-slice-7-kitty-graphics-protocol.md) | done |
| 023 | [Kitty Keyboard Full Coverage](plans/kitty-keyboard-full-coverage.md) | done |
| 024 | [Phase 3 Slice 8 Color Degradation Baseline](plans/phase-3-slice-8-color-degradation-baseline.md) | done |
| 025 | [Phase 3 Slice 9 OSC 52 Clipboard](plans/phase-3-slice-9-osc-52-clipboard.md) | done |
| 026 | [Phase 3 Slice 10 Cursor Styling](plans/phase-3-slice-10-cursor-styling.md) | done |
| 027 | [Phase 3 Slice 11 Underline Extensions](plans/phase-3-slice-11-underline-extensions.md) | done |
| 028 | [Phase 3 Slice 12 Runtime Protocol Control](plans/phase-3-runtime-protocol-control.md) | done |
| 029 | [Tooling orchestration and Lefthook migration](plans/tooling-orchestration-and-lefthook.md) | done |
| 030 | [Phase 4 View Layer and Tessera Showcase](plans/phase-4-view-layer-and-showcase.md) | cancelled |
| 031 | [Tessera open-source readiness](plans/open-source-readiness.md) | done |
| 032 | [Phase 4 view layer, redesigned from the omp2 reference](plans/omp2-reference-gallery-and-phase-4-redesign.md) | cancelled |
| 033 | [Developer tooling for agents and humans](plans/developer-tooling.md) | cancelled |
| 034 | [Terminal I/O concurrency review fixes](plans/terminal-io-concurrency-review-fixes.md) | done |
| 035 | [Toolchain, repository conventions, and plan consolidation](plans/toolchain-conventions-and-plan-consolidation.md) | done |
