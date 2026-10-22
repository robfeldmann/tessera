---
name: Scroll focus conventions
date: 2026-07-23
status: resolved
---

# Scroll focus conventions

## Question

Should a ScrollView remain focusable when its content fits, and what should visually
communicate that focus when no scroll indicator is present?

## Findings

- Apple's HIG says focus helps people visually confirm the object their interaction
  targets. AppKit exposes `NSView.focusRingType`, and SwiftUI documents default focus
  rings and hover effects through `focusEffectDisabled(_:)`. Apple treats focus
  presentation as separate from scroll indicators. The searched Apple documentation did
  not state a general overflow-dependent focus rule for `ScrollView`.
- Textual declares `ScrollableContainer(Widget, can_focus=True)`, independent of current
  overflow. Its automatic scrollbar suppresses its thumb when the viewport covers the
  virtual content. Applications use `:focus` CSS for focus presentation, so a border or
  other focus treatment remains available without a scrollbar.
- Cursive takes the stricter approach. Its `ScrollView` delegates focus to its child and
  otherwise claims focus only when `core.is_scrolling().any()` reports a scrollable axis.
  It draws no independent focus chrome.
- Ratatui has no framework focus manager. `Paragraph` and `Scrollbar` are independent
  rendering widgets; applications own focus routing, active styling, and whether to render
  a scrollbar. A fitting nonzero scrollbar is not automatically suppressed.
- Bubble Tea's Bubbles viewport similarly has no focus field or built-in scrollbar. The
  application owns focus and styling.
- Tessera currently follows neither complete pattern: an explicitly identified
  `ScrollView` remains focusable whenever enabled, indicators appear only for overflow,
  and the ScrollView supplies no independent focus chrome. This creates an invisible focus
  target when content fits.

## Sources

- [Apple HIG: Focus and selection](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection)
- [AppKit `NSView.focusRingType`](https://developer.apple.com/documentation/appkit/nsview/focusringtype)
- [SwiftUI `focusEffectDisabled(_:)`](<https://developer.apple.com/documentation/swiftui/view/focuseffectdisabled(_:)>)
- [Textual scroll containers](https://github.com/Textualize/textual/blob/main/src/textual/containers.py)
- [Textual scrollbar rendering](https://github.com/Textualize/textual/blob/main/src/textual/scrollbar.py)
- [Cursive `ScrollView`](https://github.com/gyscos/cursive/blob/master/cursive-core/src/views/scroll_view.rs)
- [Bubbles viewport](https://github.com/charmbracelet/bubbles/blob/main/viewport/viewport.go)
- `~/Developer/ratatui/ratatui/main/ratatui-core/src/widgets/widget.rs`
- `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/scrollbar.rs`
- `~/Developer/ratatui/ratatui/main/ratatui-widgets/src/paragraph.rs`

## Conclusion

Tessera should keep explicitly focusable ScrollViews in a stable focus order regardless of
transient overflow and hide indicators when no overflow exists. Focus ownership should
remain with the interactive child, while focus appearance can be resolved separately: the
runtime walks from the focused node toward its ancestors and lets the nearest willing
appearance host, such as `Box`, restyle its existing border with `semantic.focus`. If no
ancestor accepts, the focused control supplies its local fallback effect. The host does
not enter the focus list or receive the child's events. This follows Apple's
focus-visibility principle and Textual's separation of focus from overflow while avoiding
focus-order changes during resize. A future opt-in `whenScrollable` policy could support
Cursive-style eligibility, but it should not be the default.
