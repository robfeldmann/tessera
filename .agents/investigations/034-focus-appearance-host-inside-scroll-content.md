---
name: Focus appearance host resolves into scrolled content
date: 2026-08-25
status: resolved
---

# Focus appearance host resolves into scrolled content

## Question

In `gallery graph`, Tab cycles through three focus stops but only two are visible: the
specimen box and the graph box highlight, while a third stop between them shows no visual
treatment at all. What is taking focus, and why is it invisible?

## Findings

- The third stop is the demo scaffold's outer content viewport: `DemoScaffold` wraps demo
  content in `ScrollView(offset:).focusable(viewportFocusID)` so arrow keys can scroll the
  page vertically.
- Focus itself works (arrows scroll the page when the viewport is focused). Only the
  appearance is wrong.
- `ViewGraph.resolveFocusAppearanceIfNeeded()` starts appearance resolution at
  `deepestFocusAppearanceResponder(in: focusedNode)`
  (`Sources/TesseraCore/Runtime/ViewGraph.swift:1010,1175`). That search recurses into
  every descendant of the focused subtree, skipping only children that carry their own
  `focusID`. For a focusable ScrollView whose _content_ contains other appearance
  responders, the search crosses the viewport boundary into user content and returns a
  descendant — here the demo's specimen `Box` (the inner ScrollViews are skipped because
  their `.focusable` wrappers carry focus IDs, but the `Box`es are bare responders).
- The ancestor walk then starts at that `Box`, and `Box` inherits the default
  `_FocusAppearanceResponder` conformance, which returns `.handled` unconditionally
  (`Sources/TesseraCore/Input/FocusAppearance.swift:51-56`). The specimen box becomes the
  appearance host for the _viewport's_ focus.
- Net effect: focusing the outer viewport re-highlights the specimen box, which is usually
  already highlighted from the previous Tab stop, so nothing visibly changes.
  `ScrollView._renderFocusAppearanceFallback` (which would paint a visible perimeter in
  the focus style, black-on-yellow bold) is never reached.
- Evidence (pyte cell-attribute diff across Tab presses at 80x24):
  - Tab 1 → specimen box border turns `cdcd00` bold (144 cells changed).
  - Tab 2 → 0 cells changed (viewport focused, host = already-lit specimen box).
  - Tab 3 → specimen unhighlights, graph box highlights (207 cells changed).
- A gallery-level remedy cannot work: `.focusAppearance(.ring)` or `.none` on the viewport
  is an _ancestor_ modifier, but resolution begins at the deepest descendant and the
  content `Box` answers `.handled` before the walk ever reaches the viewport's ancestors.

## Conclusion

Framework defect in appearance-host resolution: `deepestFocusAppearanceResponder` should
not descend across a content-clipping responder boundary (a focusable ScrollView's
content) when picking the appearance node; the focused viewport's own chrome — not
arbitrary content descendants — should host or fall back. Fixing it belongs in
`TesseraCore` with focus-appearance tests (focusable viewport containing `Box`es must
light its own perimeter, and composite `focusable(Box { ScrollView })` must keep its
current behavior). Until then, `gallery graph`'s middle Tab stop scrolls correctly but
shows no highlight, and the specimen box shows a stale highlight while the page viewport
is focused.

## Resolution (2026-08-25)

Fixed in `ViewGraph`: `nearestFocusAppearanceResponder` replaces the deepest-responder
search. The focused node hosts its own appearance when it is a responder, and descent
stops at the first responder boundary instead of crossing a viewport into its content.
Regression: `a focusable viewport signals focus through its indicator, not its content`
(`Tests/TesseraWidgetsTests/FocusAppearanceTests.swift`) snapshots the focused viewport
telegraphing focus through its indicator thumb in the focus accent with the content box
unstyled; the composite `focusable(Box { ScrollView })` suites are unchanged. Related
ergonomics landed with it: `ScrollView.focusable(whileScrollable:)` registers as focusable
only while content overflows, scroll keys act on repeat events (fixing held-arrow
scrolling under the kitty keyboard protocol), and keys a focused viewport cannot use
bubble to the nearest enclosing viewport whose subtree holds focus. Follow-up gap (not a
defect): focusing an off-screen viewport does not scroll it into view; scroll-to-focus
remains future work.
