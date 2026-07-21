# Inbox

Append-only inspiration capture. One dated line per thought; links optional. Triage
periodically: every entry either dies or moves into a component doc's inspiration section.

Format: `- YYYY-MM-DD -- thought`

## Entries

- 2026-07-06 -- Table's column-width distribution is the same constraint problem as Grid's
  ([Slice 6](../docs/Spec.md#slice-6-flex-grid-and-composition)). Design the solver once;
  Table should be at least `wireframed` before Grid's API freezes.
- 2026-07-06 -- SplitView is the right second widget exemplar: it uniquely exercises
  divider drag, min-size negotiation, and collapse (Slice 5 hit testing), none of which
  Table touches.
- 2026-07-12 -- Mobile Showcase use makes ScrollView a critical-path component: land
  clipping, translation, and clamping with Layout, then add keyboard and pointer behavior
  as responder and mouse slices arrive. Triaged to [ScrollView](widgets/scroll-view.md).
- 2026-07-12 -- Keep adjacent pane geometry in [SplitView](widgets/split-view.md) and
  sidebar/content/inspector compact replacement in
  [NavigationSplitView](widgets/navigation-split-view.md); the Showcase needs both public
  responsibilities without one magical private shell.
- 2026-07-12 -- Rename the controlled single-line `TextInput` proposal to
  [TextField](widgets/text-field.md), matching the SwiftUI-shaped vocabulary while
  retaining grapheme-safe terminal editing and app-owned text.
- 2026-07-12 -- The Showcase's public control rule promotes [Button](widgets/button.md),
  TextField, ScrollView, SplitView, NavigationSplitView, and the existing Table design
  into the Phase 4 sequencing discussion; Form, Outline, and source browsing remain
  post-1.0.
