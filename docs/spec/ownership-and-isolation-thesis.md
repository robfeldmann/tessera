---
type: spec
description:
  "Ownership and isolation thesis: illegal terminal operations should be unrepresentable"
---

# Ownership and isolation thesis: illegal terminal operations should be unrepresentable

Tessera's safety goal is to make invalid terminal operations unrepresentable in ordinary
API use. A terminal UI framework should not rely on documentation to prevent writes
outside a render transaction, concurrent rendering, leaked file descriptors, escaped frame
contexts, or app-state mutation from the wrong isolation domain. The public API should
make safe usage the natural usage.

The guiding analogy is a SQLite wrapper that never leaks its raw connection pointer and
only lends transaction-local capabilities inside scoped closures:

- `Database` owns a connection pool; `TerminalSession` owns terminal mode, raw handles,
  input production, and output serialization.
- An actor-backed database writer serializes writes; terminal output is serialized by the
  session/output actors.
- Scoped database read/write closures lend a `Reader` or `Writer`; scoped terminal
  operations lend a `Frame`, `Screen`, event context, or responder context.
- `Reader: ~Copyable, ~Escapable` cannot be stored or escaped; borrowed terminal
  capabilities should have the same shape.
  - Implementation note: a `~Escapable` type (`Reader`, `Frame`, and any future borrowed
    capability) needs a lifetime-dependency source on its initializer, written with
    `@_lifetime(borrow …)` on a stored borrow (typically an `UnsafeMutablePointer` to
    caller-owned storage). `@_lifetime` requires `.enableExperimentalFeature("Lifetimes")`
    in `Package.swift`, which is already enabled package-wide. Without it the compiler
    rejects the initializer with `an initializer cannot return a ~Escapable result`. The
    lending scope (e.g. `TerminalSession.draw`) owns storage that outlives the synchronous
    borrowed body and calls the body directly so a `sending` result is preserved. Types
    that only need to forbid copying/storing (`RenderRegion`, `ResponderContext`) can be
    plain `~Copyable` and do not require this machinery.
- Raw `OpaquePointer` values are private; raw file descriptors and platform handles are
  private and never public API.

This thesis shows up throughout the spec:

1. **Terminal lifecycle owns raw authority.** Phase 2's terminal foundation owns raw
   handles, terminal modes, cleanup, input production, output serialization, and the
   public session capability. Public users get scoped operations, not file descriptors or
   arbitrary live-terminal writes.
2. **Rendering is a scoped transaction.** Phase 2's renderer opens synchronous borrowed
   frame transactions. `draw` may be async to enter the actor, but the render body does
   not suspend while a borrowed frame is live.
3. **Input is semantic and bounded.** Phase 2/3 input design preserves ordered semantic
   input, coalesces latest-value events such as resize, and bounds noisy streams such as
   mouse movement.
4. **Raw terminal output is scoped data, not raw authority.** The producer escape hatch is
   a `RawTerminalPayload` rendered through a borrowed frame and paired with explicit
   diff/opaque-region policy. It must not expose file descriptors, platform handles, or a
   way to write arbitrary bytes outside a render transaction.
5. **Views declare requirements; they do not mutate terminal modes.** Phase 4 view APIs
   can express focus, layout/display invalidation, and terminal requirements
   declaratively. The session/runtime arbitrates and applies mode changes centrally.
6. **Optional runtime isolation is UI-oriented, not business-state ownership.** Phase 5
   may provide an `@MainActor` runtime for event delivery, responder routing,
   invalidation, and render scheduling, but users remain free to bring TCA or any other
   state architecture.
7. **Tests are deterministic by construction.** Test support should provide explicit input
   sources, test terminals, snapshots, stepping, bounded drains, and injected clocks
   rather than relying on `Task.yield()` or wall-clock sleeps.

Do not solve concurrency warnings by making everything `Sendable`. Use `Sendable` for
semantic values that cross isolation domains. Keep views, widgets, app state, dependency
containers, caches, and scoped capabilities inside the isolation domain where they are
valid. Non-sendability is a feature when it prevents invalid cross-domain use.
