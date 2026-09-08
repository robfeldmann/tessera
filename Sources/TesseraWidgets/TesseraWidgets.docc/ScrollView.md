# ``ScrollView``

`ScrollView` presents application content through a cell-based viewport. The optional
`Binding<TerminalPosition>` supplied to `ScrollView.init(_:offset:content:)` is the source of
truth for the offset; the view clamps requested positions to the measured content and viewport
bounds. It never copies application data into graph state.

The enabled axes determine which dimensions can scroll. Keyboard and pointer wheel/track input
are handled only while the viewport is enabled and focused, and update the offset binding when
the requested movement changes the clamped position. A focused descendant can request reveal;
the viewport adjusts its offset so that the descendant remains visible without changing focus.

Overflow indicators are output-only children. Their reserved edge is included in viewport
measurement, and focused scrollable viewports use the focus accent on the indicator thumb rather
than painting over scrolled content. `focusable(whileScrollable:)` registers a conditional
focus stop only when an enabled axis actually overflows and requires an offset binding.

A viewport without an offset binding remains a display container: it can lay out overflowing
content and indicators but does not invent a private scrolling model or focus stop.
