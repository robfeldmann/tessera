---
kind: primitive
status: sketch
---

# Text selection

Text selection is Tessera's application-owned interaction system for selecting rendered
text without inheriting the terminal emulator's layout-unaware row selection. It will map
pointer and keyboard gestures through `ViewGraph` frames, clips, wrapping, and scrolling
to semantic text ranges owned by the application. Adjacent `SplitView`, Grid, and Table
columns must remain independent selection regions even when they occupy the same terminal
rows.

This system does not make `Text` retain state or consume pointer events directly. It is
expected to compose selection scopes, controlled range state, rendering highlights, and
copy actions around otherwise stateless text. Terminal-native selection remains a separate
capability with an explicitly documented coexistence policy.

## Prior art

- Ratatui Paragraph: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/paragraph.rs` —
  retain its stateless rendering boundary as a negative example: rendered terminal cells
  do not retain enough source information to reconstruct semantic selection after layout.
- Crossterm mouse events:
  `~/.local/share/cargo/registry/src/index.crates.io-1949cf8c6b5b557f/crossterm-0.29.0/src/event.rs`
  — consume button, drag, modifier, column, and row input, but do not mistake raw screen
  coordinates for application layout or text offsets.
- Tessera [Text](text.md) — preserve immutable, pointer-free text values; selection must
  compose without adding business or ephemeral state to `Text` nodes.
- Tessera [Slice 5](../../docs/Spec.md#slice-5-mouse-and-hit-testing) — build on clipped,
  ordered hit testing and responder routing rather than adding terminal authority to
  views.

## Anatomy

The candidate system has five conceptual regions rather than settled visible chrome:

1. **Selection scope** — the layout-local boundary that owns or delegates a range.
2. **Selectable fragment** — semantic source text plus the rendered-cell mapping produced
   by wrapping, truncation, clipping, and scrolling.
3. **Anchor and head** — controlled semantic endpoints; drag direction does not reorder
   application state implicitly.
4. **Rendered segments** — visible highlights derived from the semantic range during a
   completed layout pass.
5. **Copy action** — an explicit application command that resolves selected semantic text
   and requests policy-gated clipboard output.

Wireframes and callout coordinates are deferred until Slice 5 specifies whether selection
is a modifier, scope container, environment facility, or dedicated view-layer service.

## Variants

The first specification must decide whether read-only text selection and editable
`TextField` range selection share one range model or only share coordinate-mapping
primitives. Word, line, and select-all gestures are candidate interaction variants, not
accepted behavior at sketch status.

## Sizing

Text selection has no independent size. It derives geometry from selected text fragments
inside their resolved frame and clip. Selection must not expand a view, alter Flex or Grid
allocation, or make intrinsic text measurement depend on interaction state.

## Environment

The specification must decide how selection scope identity, enabled state, active/inactive
presentation, and copy policy flow through the environment. Existing `selection.fill` and
`selection.inactive` tokens are candidates, but this sketch does not assume row-selection
styles are sufficient for partial text ranges.

## Requirements

Normative requirement names are intentionally deferred until the selection state model,
pointer tables, keyboard tables, and wireframes are specified in Slice 5. Promotion beyond
`sketch` is blocked on requirements for adjacent columns, clipped and scrolled text,
wrapped and wide graphemes, drag capture, selection replacement, and copy output.

## Degradation

Selection must remain geometrically correct without color and must not depend on OSC 52
availability. When clipboard output is unavailable or denied by session policy, the
selected semantic range and its visible highlight remain valid; the copy action reports or
ignores denial according to the future responder contract. ASCII-only presentation must
use an accepted shared token rather than altering selected text.

## Open questions

- What public type represents a semantic selection range, and is it always controlled by a
  binding?
- Is selection ownership application-wide, window-wide, focus-scoped, or explicitly nested
  through selection-scope identities?
- Can a drag cross sibling fragments inside one scope, and can it ever cross a
  `SplitView`, Grid, Table, overlay, or clipping boundary?
- Which responder captures a drag after the pointer leaves the originating fragment or
  viewport?
- How do wrapped rows, truncation, tabs, combining sequences, emoji clusters, and
  double-width cells map back to source offsets?
- How do ScrollView content offsets and clipped-away fragments participate in range
  extension and autoscroll?
- Are double-click word selection, triple-click line selection, select-all, and
  shift-extended keyboard selection required for 1.0?
- How does application-owned selection coexist with the terminal emulator's native
  selection modifier while mouse tracking is effective?
- Does copy preserve source newlines and spacing, or reconstruct visual rows after layout?
- Which operation authorizes OSC 52, and what observable result represents policy denial?
- Can `TextField` reuse the same range and highlight model without violating its
  controlled-value boundary?
- Which immutable diagnostics are safe to expose without leaking selected text content?

## Inspiration

- Terminal emulators separate native screen-cell selection from application mouse
  reporting; Tessera must make that policy explicit rather than relying on terminal
  defaults.
- Browser selection demonstrates semantic ranges rendered across layout fragments, but
  Tessera should reject DOM-specific implicit cross-container behavior and define explicit
  selection scopes.
