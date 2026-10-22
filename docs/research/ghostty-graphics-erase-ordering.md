---
name: Ghostty graphics erase ordering and response feedback
date: 2026-07-11
status: resolved
---

# Ghostty graphics erase ordering and response feedback

## Question

Why did the Phase 3 demo show no image and continuously append
`Kitty graphics ERR id=1 placement=1 message=ENOENT: image not found` in vanilla Ghostty?

## Findings

- The demo's 32×32 RGBA transmission and 8×4-cell placement are valid. The linked Ghostty
  virtual terminal accepts the exact payload and exposes image 1 plus placement 1.
- Panel selection invalidated the renderer. The demo transmitted image 1 before calling
  `TerminalSession.draw`, but renderer invalidation emits `ED 2` before the next frame.
- Live Ghostty testing confirmed this sequence: transmission returns `OK`, `ED 2` removes
  the stored Kitty image data, and the following placement returns
  `ENOENT: image not found`.
- `Frame.placeImage` intentionally uses an always-repaint raw anchor. Every graphics
  response is also an input event that triggers a demo redraw. The placement error
  therefore caused a redraw, which emitted the same failed placement, which generated the
  next error indefinitely.
- Local write/flush success from `transmitImage` does not prove asynchronous terminal
  acceptance. A graphics response must be able to transition the demo into a stable
  failure state.

## Conclusion

Consume a pending full repaint before transmitting image data. On the first graphics draw,
render the panel without a placement so `ED 2` completes; then transmit the image and
perform a second draw that places it. Reset transmission state whenever a full repaint can
clear terminal image data. Match asynchronous failures for demo image 1, stop placement
and retransmission, display the complete error once, and let `g` clear the failure for an
explicit retry. Live Ghostty verification shows the RGBA gradient after this ordering
change with no repeated `ERR` events.
