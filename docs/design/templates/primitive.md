---
kind: primitive
status: sketch
---

# PrimitiveName

One-paragraph overview: what it renders and what it deliberately does not do. Primitives are stateless or nearly so: no focus, no bindings, no key/mouse handling. If this doc needs a key table, it is a widget.

## Prior art

Concrete sources with paths or links; what to copy, what to reject.

## Anatomy

One or more wireframes with callouts. Conventions: [README](../../design.md#wireframe-conventions).

```wireframe 8x1
────────
```

```text
Callouts (8x1, 0-based):
1. r0   TODO
```

## Variants

Style variants, keyed to [tokens.md](../tokens.md) glyph tables.

## Sizing

Schema: [README](../../design.md#sizing-table). Mandatory rows: nil x nil, tight, under-minimum, over-maximum.

| Proposal  | Result | Rule |
| --------- | ------ | ---- |
| nil x nil | TODO   | TODO |

## Environment

Tokens consumed, each defined in [tokens.md](../tokens.md).

## Requirements

Backticked sentence-style test names, each traced. Schema: [README](../../design.md#requirements-list).

The plain list holds the requirements no capability owns: layout, sizing, anatomy, and degradation. Capability requirements go under the `Focus`, `Pointer`, `Scroll`, and `Clock` subsections below, in that order. Keep a subsection only if the primitive needs that capability, and delete the others; a primitive with no input and no motion keeps none. A requirement that needs several capabilities goes under the one that lands last.

- `TODO` (trace)

### Focus

Keyboard handling and focused appearance.

- `TODO` (trace)

### Pointer

Clicks, drags, hover, hit testing, and wheel that does not scroll.

- `TODO` (trace)

### Scroll

Interactive scrolling: offset, reveal, paging, and wheel scrolling.

- `TODO` (trace)

### Clock

Time and animation.

- `TODO` (trace)

## Degradation

Behavior at ascii-only and other reduced capabilities; reference the [degradation ladder](../tokens.md#degradation-ladder).

## Open questions

## Inspiration
