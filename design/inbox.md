# Inbox

Append-only inspiration capture. One dated line per thought; links optional. Triage
periodically: every entry either dies or moves into a component doc's inspiration section.

Format: `- YYYY-MM-DD -- thought`

## Entries

- 2026-07-06 -- Table's column-width distribution is the same constraint problem as Grid's
  ([Slice 6](../docs/Spec.md#slice-6-grid-table-and-fitting)). Design the solver once;
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
- 2026-08-17 -- Symbol presets: an opt-in environment axis that re-skins glyph tokens at
  render time without touching the design contract. Motivation: the disclosure chevrons
  from Oh My Pi's TUI (rejected as _token values_ because they are Nerd Font Private Use
  Area codepoints, U+F078/U+F054 -- tofu without a patched font, no Unicode semantics for
  the ASCII ladder, and invisible-to-parity width skew). The precedent is omp's theme
  system (`omp://theme.md`): every glyph is an abstract symbol key resolved through a
  preset (`unicode | nerd | ascii`) plus per-key overrides, defaulting to `unicode`, so
  PUA is presentation a user opts into, never the source of truth. Tessera shape: the
  glyph-valued token families ([tokens.md](tokens.md) `disclosure.*`, `selection.bar`,
  `scrollbar.*`, `truncation.mark`) are designed to map onto a future `EnvironmentValues`
  key (tokens.md's stated plan); when that key lands, a `symbolPreset` environment value
  (or per-token override map) could map `disclosure.expanded` -> U+F078 etc. at render
  time. Canonical wireframes, fixtures, and the parity harness stay Unicode forever;
  snapshot tests would pin the non-default presets the way ASCII degradation is pinned
  today. Research pointers: Nerd Fonts codepoint ranges and "Mono" single-cell variants;
  Ghostty >= 1.2 ships a built-in Symbols Nerd Font fallback (release notes 1-2-0), which
  is why the chevrons render there regardless of configured font; risk to evaluate is
  wcwidth/PUA width ambiguity on other terminals.
- 2026-08-17 -- HintBar: a supplied bottom key-hint bar (Textual's `Footer`-renders-
  `BINDINGS` and Charm's `bubbles/help` are the precedent), potentially dynamic -- showing
  only currently-valid keybindings, ranked by priority. Needs its own design doc and,
  before that, a keybinding-introspection seam (responder-chain registration of key/label
  pairs) that does not exist yet. Prompted by the NavigationSplitView review: every
  surveyed ecosystem surfaces pane toggles in an app hint bar.
- 2026-08-17 -- Shortcut help overlay: a Tessera-provided `?` popup listing all registered
  shortcuts -- searchable, with a short hint or documentation for the selected item
  (LazyGit's help view is the favorite presentation). Shares the keybinding-introspection
  seam with HintBar; composes over Overlay once triaged.
- 2026-08-17 -- Color-selection controls beyond semantic roles: a Picker over the five
  semantic role names is the only color-editing control expressible today. Two researched
  follow-ups: an indexed/ANSI swatch browser as a List row builder (index + `█` swatch
  glyph; layout precedent
  `~/Developer/ratatui/ratatui/main/examples/apps/color-explorer/src/main.rs`) and a
  validated hex/RGB TextField escape hatch (precedent: textual-colorpicker's `RgbInputs`,
  `Integer(0,255)` validators). Rejected outright: graphical HSV drag pickers --
  mouse-drag driven, truecolor-only, no degradation story. The gallery `colors` demo (plan
  032 step 3.3) is the browsing half; an editing control awaits List.
- 2026-08-17 -- Bare-key accelerators (app-level single-key bindings like `s`/`i`/`d`
  panel toggles without Tab travel): blocked on a key-consumption policy for when a
  TextField owns focus -- which unmodified printable keys may an app claim, and how does
  the responder chain advertise the conflict? Every surveyed TUI (lazygit, gh-dash,
  posting) binds bare keys; Tessera's visible-control-only grammar avoids the conflict but
  costs travel.
- 2026-08-17 -- Focus glyph-weight escalation: crush escalates the selection bar glyph
  itself on focus (thin `│` blurred, solid `▌` focused; `quickstyle.go:852-895`) -- the
  only surveyed mechanism that survives a color-stripping pipe. Tessera's
  `selection.fill`/`selection.inactive` SGR pair is already more robust than crush's
  color-only variant; pursue only if a real NO_COLOR-pipe failure is reproduced.
- 2026-08-24 -- Scrolling-page layout idiom: Textual's demo (`uvx textual-demo`) presents
  its whole showcase as one scrolling column with modal overlays -- web/document DNA
  rather than pane DNA. A scrolling page degrades to mobile widths for free, with no
  responsive role replacement or breakpoint guards; candidate idiom for the post-mouse
  Showcase rework, and already the shape of the gallery scaffold (plan 032 step 1.3).
  Panes remain right for genuinely parallel content.
- 2026-08-24 -- Focus scope / modal focus trap: chrome-on-demand overlays (Textual's `c`
  code popup, its palette, the triaged `?` shortcut overlay) need focus advance to cycle
  inside the topmost overlay and restore the prior focus on dismissal. No scoping
  primitive exists in the focus model today; likely a FocusManager concern. Prerequisite
  for any Tessera-composed modal.
- 2026-08-24 -- Command palette: TextField + filtered List inside a centered Overlay
  (Textual's palette is the precedent). Composable once List lands plus the focus-scope
  primitive above; shares the keybinding-introspection seam already noted for HintBar and
  the shortcut help overlay.
- 2026-08-24 -- Spacing discipline: much of the Textual demo's perceived polish is
  generous padding and deliberate empty space, not machinery. Costs nothing today
  (`padding` exists); gallery demos and any Showcase rework should spend cells
  deliberately rather than hoarding them.
- 2026-08-24 -- Responsive arrangement primitives: the layout engine already redistributes
  extents on every pass (stacks, Flex), but arrangement _changes_ are app-level breakpoint
  arithmetic today. Two candidate primitives close the gap: `ViewThatFits` (SwiftUI
  semantics -- propose to alternatives in order, place the first that fits; app-owned
  bindings survive the structural swap by construction, only focus and ephemeral
  `NodeState` need a story) and a wrapping `Flow` layout (web
  `flex-wrap`/SwiftUI-community `FlowLayout`; expressible on the public `Layout` protocol
  first). They compose: ViewThatFits selects between arrangements, Flow wraps within one.
  Precedent that engines redistribute while arrangement changes are declared: Textual's
  width breakpoints swap CSS classes rather than reflowing.
- 2026-08-26 -- Scroll-to-focus: moving focus to a focusable inside a scrolled-out region
  (or to a viewport wholly below the fold, as in the gallery scaffold) leaves its focus
  treatment invisible; the enclosing ScrollView should translate to reveal the focused
  bounds. Discovered in investigation
  [034](../.agents/investigations/034-focus-appearance-host-inside-scroll-content.md);
  natural home is [ScrollView](widgets/scroll-view.md) (reveal-on-focus-change) plus a
  FocusManager hook exposing the focused node's bounds to enclosing viewports. SwiftUI
  precedent: `ScrollViewReader.scrollTo(_:)` and automatic focus-driven scrolling in
  `List`/`Form`.
- 2026-08-26 -- Equal-column tracks: the gallery's lesson chips implement a demo-local
  `EqualColumns` layout on the public `Layout` protocol (equal integer shares of the real
  proposal, gutter, trailing remainder slack). When [Grid](primitives/grid.md) lands (plan
  030 phase 6), decide whether equal-track sizing belongs in its contract so apps do not
  each rewrite this layout; the gallery chips should migrate to it. SwiftUI precedent:
  `Grid`/`GridRow` column behavior.
- 2026-10-11 -- Picker fuzzy filter: type-to-filter the menu's options with fuzzy matching
  (omp2's select has it). Deferred out of 1.0 by the owner; worth a "Feature Requests,
  Ideas" GitHub Discussion if it isn't picked up later. Multi-select, digit quick-select,
  and option descriptions are in 1.0 (see [Picker](widgets/picker.md)).
