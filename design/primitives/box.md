---
kind: primitive
status: sketch
---

# Box

`Box` is a stateless composition primitive: border, content inset, and optional title
around one child. Its public direction is `Box(title:border:content:)`, with a rounded
border default. Box must compose the Border, Padding, Text, Style, and Frame contracts
rather than introducing private layout or input machinery.

## Prior art

- Ratatui `Block`: `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block.rs` — copy
  bounded titled chrome and explicit border configuration. Reject unstructured app state
  or input handling inside static decoration.
- Ratatui `Block` padding:
  `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/block/padding.rs` — use as
  contrast for title/chrome spacing; Tessera must preserve generic Padding as the
  authoritative content-inset primitive.
- Tessera [Slice 3](../../docs/Spec.md#slice-3-styling-text-wrapping-and-decoration) —
  owns the public API and default rounded-border direction.

## Future wireframe and specification notes

Wireframe untitled and titled boxes at normal, narrow, `1x1`, and zero-area bounds;
include long Unicode titles, title/content collision, each border style, ASCII fallback,
and nested Box behavior. Specify title placement and clipping, whether title interrupts or
overlays the top border, exact content insets and sizing, title and border style
inheritance, Frame/Padding order, and the relationship to the standalone Border modifier.

Specify Slice 5 behavior at the same time: Box chrome is decorative unless a descendant
installs a handler; hit testing follows the Box final frame and child clip, and
title/border cells do not accidentally intercept pointer input. Any future interactive
title affordance requires a separate widget contract.

## Open questions

- Define the initial title alignment and truncation policy; the Slice 3 Text contract owns
  grapheme-safe truncation once its public enum is finalized.
- Decide whether Box has fixed generic content padding or exposes padding only through
  ordinary child `.padding` composition.

## Inspiration

Box is static terminal chrome for grouping content. It must remain a primitive, not a
focusable panel widget.
