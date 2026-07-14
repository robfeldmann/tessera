---
kind: widget
status: sketch
---

# WidgetName

One-paragraph overview: what it is, what it is for, and the one-sentence version of its
state story (what the app owns vs what is ephemeral). Widgets are controlled; see
[Slice 7](../../docs/Spec.md#slice-7-catalog-integration--list-section-controlled-widgets-and-the-showcase).

## Prior art

Cite concrete sources with paths or links, and say what to copy and what to reject.

- Ratatui: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/<file>.rs` -- ...
- Bubbles / Textual / SwiftUI -- ...

## Anatomy

One wireframe at a natural component size, followed by callouts. Callout region names are
the vocabulary for the mouse table. Schemas and conventions:
[README](../README.md#wireframe-conventions).

```wireframe 10x3
┌────────┐
│ TODO   │
└────────┘
```

```text
Callouts (10x3, 0-based):
1. r0-r2   Frame -- Border primitive, token `light`
```

## States

Required to reach `wireframed`: `mobile` (40x16) and `min` (declare the floor).
Recommended: empty, focused vs unfocused, overflow, degraded (ascii/no-color).

## State model

Schema: [README](../README.md#state-model-table).

| State | Owner | Type | Reset or clamp rule |
| ----- | ----- | ---- | ------------------- |
| TODO  | TODO  | TODO | TODO                |

## Key table

Schema: [README](../README.md#key-table).

| Key  | Precondition | Effect | Consumed |
| ---- | ------------ | ------ | -------- |
| TODO | TODO         | TODO   | TODO     |

## Mouse table

Schema: [README](../README.md#mouse-table). Regions must be named in Anatomy callouts.

| Event | Region | Precondition | Effect | Consumed |
| ----- | ------ | ------------ | ------ | -------- |
| TODO  | TODO   | TODO         | TODO   | TODO     |

## Sizing

Schema: [README](../README.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum.

| Proposal  | Result | Rule |
| --------- | ------ | ---- |
| nil x nil | TODO   | TODO |

## Environment

Tokens consumed, each defined in [tokens.md](../tokens.md).

## Primitive dependencies

Link every primitive this widget composes; note missing ones -- the `ready` gate requires
them to exist.

## Requirements

Backticked sentence-style test names, each traced to a table row or wireframe state.
Schema: [README](../README.md#requirements-list).

- `TODO` (trace)

## Degradation

What changes at `NO_COLOR`, 16-color, ascii-only, and below `min`. Reference the
[degradation ladder](../tokens.md#degradation-ladder).

## Open questions

Decisions deliberately not made yet, each with what unblocks it.

## Inspiration

Triage destination for inbox entries about this component.
