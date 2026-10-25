---
type: hub
stage: living
description: Durable decisions and their rationale, promoted out of plans when they close.
---

# Architecture

Durable decisions, one page each, promoted out of a plan when it closes (the plan's Decisions section keeps the dated record; the page here keeps the current rule and why). The [spec](spec.md) remains the constitution for the library's design; this directory holds repository, toolchain, and developer-tooling decisions that the spec does not cover. A page may also be written while its plan is open, when the plan builds the thing it describes; such a page says so and the plan keeps it current.

- [API deprecation](architecture/api-deprecation.md): a public API is hard-deprecated (one minor release before 1.0, until the next major after), then removed behind an `unavailable` stub that lasts until the next major release; package traits are the option for staging a major release.
- [Developer tooling](architecture/developer-tooling.md): the demos, headless driver, scenario language, locators, checks, shots, trace, `tessera-dev`, and catalog conformance that Phase 4 builds, and the rules they follow.
- [libghostty-vt distribution](architecture/libghostty-vt-distribution.md): libghostty-vt ships as a prebuilt SE-0482 artifact bundle that Tessera's CI builds once per Ghostty pin, under a source `CGhosttyVT` with committed headers, so no consumer or test job runs Zig.
- [Toolchain lanes](architecture/toolchain-lanes.md): the Swift 6.3.3 baseline on every lane, a Swift 6.4 lane beside it, and how each is selected.
