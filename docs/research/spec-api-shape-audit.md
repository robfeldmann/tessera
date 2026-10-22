---
name: Spec API Shape Audit
date: 2026-06-05
status: resolved
---

# Spec API Shape Audit

## Question

Does `docs/Spec.md` contradict the intent that early phases should build the real public
API shape whenever feasible, rather than placeholder, temporary, or phase-named API?

## Findings

- Phase 1 language over-emphasized "crudest" and "replace," which could lead an agent to
  choose throwaway public names such as `parsePhase1`. The spec now says to build the
  smallest correct version, then refine and extend it.
- The input parser example used phase-named API (`Phase1Event`, `parsePhase1`) even though
  `InputEvent` and `InputParser.parse(_:)` are the durable API shape. The example now uses
  the durable names.
- Phase 0 placeholder symbols are a valid bootstrap exception because they existed only to
  wire modules, tests, and DocC before real API existed. The spec now labels them as a
  Phase 0-only bootstrap exception that should be deleted as real API appears.
- Several later sections said Phase 2 would "throw away" or "replace" Phase 1 code. These
  were updated to describe evolving, refining, or growing the existing API/implementation.
- The proposed file layout used "placeholder" for future view-layer files. It now calls
  those provisional view-layer slots and defers real target/file planning until the view
  API is designed.

## Conclusion

The spec now states the intended rule explicitly: early phases should keep behavior small
and incomplete, but use public API names and shapes that can survive later phases whenever
that shape is knowable. Placeholder/temporary public API is only acceptable for a specific
bootstrap reason, and phase-specific names should be private helpers with a clear
migration path.
