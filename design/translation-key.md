# omp2 to Tessera translation key

Plan 032 adopted omp2, the Rust rewrite of oh-my-pi's TUI (crate `omp-tui`), as the visual
and behavioural reference for the Phase 4 catalog. The two share an architecture: a
retained tree, measure, place, and paint passes, one-pass rendering, and semantic styles.
They do not share a vocabulary. An omp2 component reads markup attributes, keeps its own
state, and reports `UiEvent`s addressed by id; a Tessera view takes initializer
parameters, modifiers, and environment values, is controlled through bindings, and calls
closures.

This key settles that translation once. Each row maps one omp2 concept to the one Tessera
form that expresses it, or rejects it with a reason. omp2 citations point at its source at
the pinned commit `2f92f3b`. Each Tessera form links the Spec section or catalog doc that
owns it; the key restates none of their rules.

## How to apply it

Plan 032 step 7.1 applies the key to every doc in `primitives/` and `widgets/`:

1. Name the omp2 counterpart in the doc's prior-art section and cite its source at the
   pinned commit. [Coverage](#coverage) lists each doc's counterpart.
2. Express each concept the counterpart uses in the row's Tessera form, and cite the row
   by ID where the doc settles a translation, for example "key D3".
3. A doc that departs from a row records the departure as an owner decision in its own
   decisions or open questions, and the row gains the exception, so the key and the docs
   never disagree silently.

This is a reference doc, not a catalog component. It carries no status-ladder frontmatter
and no [Index](README.md#index) row, and the gallery does not list it. Like
[tokens.md](tokens.md) it holds shared vocabulary, but it defines no values: where a row
lands on a token, tokens.md owns the token.

## Ownership rules

Most omp2 components keep their data inside themselves and hand it out through `UiEvent`s
and `value()`. Tessera widgets are controlled
([state model](../docs/Spec.md#state-model-bring-your-own)). Four rules decide where each
omp2 state field goes, and the D rows apply them:

1. **Binding.** Data the user produces or the app must read or persist (text, a checked
   value, a selection, expansion, an active tab, pane sizes, a sort order) is an app-owned
   `Binding` that the initializer takes. The widget writes it only on the documented
   interaction and never retains an initial value.
2. **Initializer parameter.** Data the app supplies for display (a progress value, source
   text, an image source) is a plain parameter, redeclared on every update. A State model
   table still names its owner `Binding`, meaning app-owned
   ([README](README.md#state-model-table)).
3. **NodeState.** Position and interaction in flight (a cursor, a scroll position no
   binding owns, a caret, a pressed or open flag, an uncommitted draft) is `NodeState`.
   Losing it loses position or unfinished input, never committed data.
4. **Graph-owned.** Focus, hover, the clock, and environment values belong to the graph. A
   view reads them as `Environment` or `derived` state and never mirrors them into
   `NodeState`, per the runtime ownership invariant
   ([README](README.md#state-model-table)).

## Key

IDs are stable, because docs cite them. The table gives each concept, its omp2 source at
the pinned commit, and its Tessera form; the notes after it give each row's rule. Rows run
by family: A construction and identity, B attributes, C events and actions, D state, E
focus and keys, F pointer, G layout, H layering, I text, J theme and colour, K charset and
glyphs, L motion, and M component behaviours. "Rejected" means Tessera deliberately has no
counterpart; "Rejected for 1.0" means a catalog doc or owner decision defers it.

| ID  | omp2 concept                     | Source                                                | Tessera form                                                                   |
| --- | -------------------------------- | ----------------------------------------------------- | ------------------------------------------------------------------------------ |
| A1  | `Component` trait                | [component.rs:52][a1]                                 | `View` or `LeafView` ([View][s-view], [leaf][s-leaf])                          |
| A2  | `Slot` identity                  | [component.rs:30][a2]                                 | Structural identity ([identity][s-identity])                                   |
| A3  | `Cached` memo                    | [component.rs:189][a3]                                | Reconciliation, invalidation ([invalidation][s-invalidation])                  |
| A4  | `dom!` macro                     | [macros/lib.rs:27][a4]                                | `@ViewBuilder` ([View][s-view])                                                |
| A5  | Runtime markup                   | [markup.rs:1][a5]                                     | Rejected                                                                       |
| A6  | `CustomElement` registry         | [component.rs:1593][a6]                               | Rejected                                                                       |
| A7  | Child records, promoted children | [markup.rs:1334][a7], [boxed.rs:77][a7-2]             | Row closures or child views ([View][s-view])                                   |
| A8  | Imperative updates by id         | [ui.rs:292][a8]                                       | Rejected                                                                       |
| A9  | `when=` conditions               | [vocab/lib.rs:108][a9]                                | `if` and `switch` in `@ViewBuilder`                                            |
| A10 | Value harvesting                 | [component.rs:164][a10], [ui.rs:1084][a10-2]          | Rejected                                                                       |
| A11 | `UiContext`                      | [context.rs:751][a11]                                 | `EnvironmentValues` ([environment][s-env])                                     |
| B1  | `Prop` and `Props`               | [vocab/lib.rs:20][b1], [props.rs:240][b1-2]           | Parameter, modifier, or environment                                            |
| B2  | Sizing attributes                | [vocab/lib.rs:31][b2]                                 | `.frame`, `.flex` ([Frame][frame], [Flex][flex])                               |
| B3  | Padding attributes               | [vocab/lib.rs:25][b3]                                 | `.padding(_:)` ([Padding][padding])                                            |
| B4  | Stack attributes                 | [vocab/lib.rs:23][b4], [vocab/lib.rs:65][b4-2]        | Stack parameters, `Spacer`, `Divider` ([stacks][stacks])                       |
| B5  | Border chrome                    | [vocab/lib.rs:41][b5]                                 | `.border`, `Box`, `Divider` ([Border][border], [Box][box], [Divider][divider]) |
| B6  | Text attributes                  | [vocab/lib.rs:73][b6]                                 | Style modifiers ([modifiers][style-mods], [chains][s-style])                   |
| B7  | Wrapping and truncation          | [vocab/lib.rs:93][b7], [vocab/lib.rs:154][b7-2]       | `.lineLimit`, `.truncationMode` ([Text][text], [wrap rules][wrap])             |
| B8  | Row caps and overflow summary    | [vocab/lib.rs:158][b8], [components/mod.rs:104][b8-2] | `.maxRows(_:)` ([code view][code-overflow], [Image][image])                    |
| B9  | `id`                             | [vocab/lib.rs:106][b9]                                | Rejected as an address                                                         |
| B10 | `focus`                          | [vocab/lib.rs:208][b10], [component.rs:114][b10-2]    | `.focusable(_:)` ([focus model][s-focus])                                      |
| B11 | Content attributes               | [vocab/lib.rs:116][b11], [vocab/lib.rs:180][b11-2]    | Parameters and content modifiers                                               |
| B12 | Look and meaning selectors       | [vocab/lib.rs:95][b12], [button.rs:16][b12-2]         | Style modifier or parameter                                                    |
| B13 | Gradients                        | [props.rs:32][b13], [component.rs:95][b13-2]          | Rejected                                                                       |
| B14 | Pointer chrome                   | [vocab/lib.rs:204][b14]                               | Rejected                                                                       |
| B15 | `noselect`                       | [vocab/lib.rs:49][b15]                                | [Text selection][text-selection]                                               |
| B16 | `zone`                           | [vocab/lib.rs:51][b16]                                | Rejected                                                                       |
| C1  | `Flow`                           | [component.rs:41][c1]                                 | `EventDisposition` ([leaf][s-leaf], [routing][s-route])                        |
| C2  | `UiEvent::Pressed(id)`           | [input.rs:1837][c2]                                   | `Button(action:)`, `.onTap` ([Button][button], [Slice 5][s-s5])                |
| C3  | `UiEvent::Submit`                | [input.rs:1833][c3]                                   | The submitting control's action ([TextField][text-field])                      |
| C4  | `UiEvent::Cancel`                | [input.rs:1835][c4], [ui.rs:785][c4-2]                | Esc bubbles to the app ([routing][s-route])                                    |
| C5  | `UiEvent::Highlighted`           | [input.rs:1839][c5]                                   | Rejected                                                                       |
| C6  | `UiEvent::Changed`               | [input.rs:1846][c6]                                   | A `Binding` write ([state model][s-state])                                     |
| C7  | `UiEvent::Filtered`              | [input.rs:1879][c7]                                   | Rejected for 1.0                                                               |
| C8  | `UiEvent::TreeActivated`         | [input.rs:1853][c8]                                   | `onActivate:` closure ([List][list], [Table][table])                           |
| C9  | `UiEvent::TreeToggled`           | [input.rs:1860][c9]                                   | Expansion `Binding` write ([Outline][outline], [Section][section])             |
| C10 | `UiEvent::TreeAction`            | [input.rs:1870][c10]                                  | Rejected for 1.0                                                               |
| C11 | `UiEvent::Copied`                | [input.rs:1889][c11]                                  | Rejected for 1.0                                                               |
| C12 | Pressable container              | [col.rs:131][c12]                                     | `Button` with a custom `label:`                                                |
| C13 | Two-step `confirm`               | [button.rs:87][c13]                                   | Rejected                                                                       |
| D1  | User-produced values             | [checkbox.rs:42][d1], [tree.rs:130][d1-2]             | A `Binding` ([state model][s-state])                                           |
| D2  | Display data                     | [ui.rs:292][d2]                                       | A plain initializer parameter                                                  |
| D3  | Cursor indices                   | [select.rs:136][d3]                                   | `NodeState`, or the selection binding                                          |
| D4  | Scroll position                  | [scroll.rs:12][d4], [scroll.rs:55][d4-2]              | `NodeState` or an optional binding ([ScrollView][scroll-state])                |
| D5  | Text-editing positions           | [input.rs:42][d5]                                     | `NodeState` ([TextField][text-field-state])                                    |
| D6  | Edit history                     | [input.rs:18][d6]                                     | Rejected for 1.0                                                               |
| D7  | Interaction in flight            | [button.rs:28][d7], [form.rs:170][d7-2]               | `NodeState`                                                                    |
| D8  | Uncommitted draft text           | [select.rs:136][d8]                                   | `NodeState` until commit                                                       |
| D9  | Focus entry: `enter(forward)`    | [component.rs:120][d9]                                | The cursor's reset rule                                                        |
| D10 | Layout caches                    | [tree.rs:252][d10]                                    | `derived` state ([README][readme-state])                                       |
| E1  | Focus ring                       | [component.rs:114][e1]                                | `.focusable(_:)` ([focus model][s-focus])                                      |
| E2  | `PaintCtx.focus`                 | [component.rs:1378][e2]                               | `isFocused`, `focus` role ([focus][t-focus], [border][focus-border])           |
| E3  | `Component::key`                 | [component.rs:133][e3]                                | `handleEvent`, `.onKey` ([handlers][s-handlers], [Key table][readme-key])      |
| E4  | `Ui::handle_key` fallback        | [ui.rs:779][e4]                                       | Rejected                                                                       |
| E5  | `Keymap`                         | [input.rs:1599][e5]                                   | Rejected in the graph ([Slice 4][s-flags4])                                    |
| E6  | `EventCtx`                       | [component.rs:1477][e6]                               | `ResponderContext` ([handlers][s-handlers])                                    |
| E7  | Paste                            | [component.rs:150][e7]                                | Paste routed like a key ([routing][s-route], [contract][paste])                |
| E8  | Key hints                        | [settings.rs:23][e8]                                  | [KeyLegend][key-legend]                                                        |
| E9  | Layer keyboard capture           | [ui.rs:720][e9]                                       | A focus scope ([focus scopes][s-focus-scope])                                  |
| F1  | `HitTag` regions                 | [component.rs:1668][f1], [component.rs:138][f1-2]     | Hit testing ([Slice 5][s-s5], [Mouse table][readme-mouse])                     |
| F2  | `HitTag::Scrollbar`              | [component.rs:1685][f2]                               | Rejected                                                                       |
| F3  | `Mouse` gestures                 | [input.rs:1803][f3]                                   | `.onTap`, `.onMouse` ([Slice 5][s-s5])                                         |
| F4  | Hover: `PaintCtx.hover`          | [component.rs:1380][f4]                               | Graph-owned, `derived` ([Slice 5][s-s5], [fill roles][t-fill])                 |
| F5  | Input modality                   | [component.rs:1385][f5]                               | Rejected                                                                       |
| F6  | Click focuses and activates      | [input.rs:1806][f6]                                   | Click-to-focus, then tap ([Slice 5][s-s5])                                     |
| F7  | Wheel order                      | [input.rs:1818][f7]                                   | Innermost scrollable moves ([cutover][s-cutover])                              |
| G1  | `measure` and `height`           | [component.rs:74][g1]                                 | `sizeThatFits(_:)` ([layout][s-layout], [leaf][s-leaf])                        |
| G2  | `place`                          | [component.rs:78][g2]                                 | `placeSubviews` ([layout][s-layout])                                           |
| G3  | Chrome outside content           | [component.rs:84][g3], [component.rs:243][g3-2]       | Wrapper modifiers ([decoration][s-decoration])                                 |
| G4  | `paint` and `PaintCtx`           | [component.rs:1368][g4]                               | `render` into a `RenderRegion` ([region][s-region])                            |
| G5  | Stack helpers, `grow`            | [layout.rs:12][g5], [layout.rs:146][g5-2]             | Stacks, `Spacer`, `Flex` ([stacks][stacks], [Flex][flex])                      |
| G6  | `wrap` rows                      | [row.rs:106][g6]                                      | Flow layout ([fitting][s-fit])                                                 |
| G7  | Cross-axis stretch               | [markup.rs:180][g7], [component.rs:110][g7-2]         | Rejected as a container default                                                |
| G8  | Percent widths: `Dim::Pct`       | [markup.rs:110][g8]                                   | `.percentage(_:)` ([Flex][flex])                                               |
| G9  | Column solving                   | [layout.rs:200][g9], [layout.rs:242][g9-2]            | Table and Grid on Flex ([Slice 6][s-s6])                                       |
| G10 | Width-dependent arrangement      | [fact.rs:74][g10]                                     | `ViewThatFits` ([fitting][s-fit])                                              |
| G11 | Virtualized painting             | [tree.rs:369][g11]                                    | Visible rows only ([Outline][outline])                                         |
| H1  | Overlay layers                   | [overlay.rs:1][h1], [overlay.rs:57][h1-2]             | Rejected for 1.0                                                               |
| H2  | Nested scratch paint             | [component.rs:1434][h2]                               | A translated `RenderRegion` ([ScrollView][s-scrollview])                       |
| H3  | Inline dropdowns                 | [form.rs:170][h3]                                     | Picker menu in a host row ([Picker][picker-host])                              |
| I1  | `RichText` runs                  | [rich.rs:138][i1], [rich.rs:359][i1-2]                | `Text + Text` ([styled runs][text-runs])                                       |
| I2  | Rich-text pipeline               | [rich.rs:686][i2]                                     | Text wrapping ([wrapping][text-wrapping], [wrap rules][wrap])                  |
| I3  | `Truncate`, `TextWrap`           | [markup.rs:156][i3]                                   | `.truncationMode(_:)`, word wrap ([code view][code-view])                      |
| I4  | Width policy                     | [rich.rs:106][i4], [context.rs:763][i4-2]             | Phase 2 grapheme widths ([Buffer][s-width])                                    |
| I5  | Inline `<ico:name/>`             | [markup.rs:1008][i5]                                  | Icon run in running text ([Label][label-inline])                               |
| I6  | Bare text is Markdown            | [markup.rs:29][i6]                                    | `Markdown(_:)` ([Markdown][markdown])                                          |
| I7  | Links                            | [vocab/lib.rs:176][i7], [markdown/mod.rs:127][i7-2]   | `.link(URL)` ([decoration][s-decoration])                                      |
| J1  | `Theme`                          | [context.rs:398][j1]                                  | Semantic roles ([roles][t-roles], [plumbing][s-plumbing])                      |
| J2  | `Theme::for_appearance`          | [context.rs:548][j2]                                  | Rejected                                                                       |
| J3  | `Appearance`                     | [context.rs:371][j3]                                  | `\.colorScheme` ([scheme][t-scheme])                                           |
| J4  | Colour values                    | [markup.rs:35][j4], [props.rs:28][j4-2]               | A role or a `Color` override ([overrides][t-overrides])                        |
| J5  | Tone names                       | [callout.rs:15][j5]                                   | Hue roles ([hue roles][t-hue])                                                 |
| J6  | Contrast and depth helpers       | [context.rs:490][j6]                                  | Blend rules, tiers ([rules][t-blend], [tiers][t-tiers])                        |
| J7  | Named JSON palettes              | [context.rs:771][j7]                                  | Rejected                                                                       |
| K1  | `Charset`                        | [context.rs:38][k1]                                   | `\.charset` ([charset][t-charset])                                             |
| K2  | `Icon` catalog                   | [context.rs:71][k2]                                   | `Label(_:icon:)` ([icons][t-icons], [Label][label])                            |
| K3  | Marks                            | [context.rs:98][k3], [context.rs:328][k3-2]           | Marks and widget glyphs ([marks][t-marks])                                     |
| K4  | Box glyphs: `Border`             | [markup.rs:96][k4], [context.rs:82][k4-2]             | `BorderStyle` ([border sets][t-borders])                                       |
| K5  | `Charset::grid`                  | [context.rs:185][k5]                                  | Table's `.grid` style ([Table][table])                                         |
| K6  | `Charset::guides`                | [context.rs:141][k6]                                  | Outline's guides ([Outline][outline])                                          |
| K7  | Rules and rails                  | [context.rs:158][k7], [context.rs:235][k7-2]          | Divider glyphs, leading rail ([glyphs][t-dividers], [rail][leading-rail])      |
| K8  | `Charset::scrollbar`             | [context.rs:211][k8]                                  | Indicator presets ([presets][t-scroll], [indicator][scroll-indicator])         |
| K9  | `Charset::progress`              | [context.rs:219][k9]                                  | [Bars and ramps][t-bars]                                                       |
| K10 | `pill_caps`                      | [context.rs:227][k10]                                 | [Caps][t-caps] tokens                                                          |
| K11 | Spinner frames                   | [context.rs:275][k11]                                 | [Spinner][t-spinners] sets                                                     |
| L1  | Presentation clock               | [component.rs:1389][l1], [context.rs:780][l1-2]       | Clock environment value ([motion][s-motion])                                   |
| L2  | Wake scheduling                  | [component.rs:1453][l2], [ui.rs:449][l2-2]            | Declared tick requirement ([motion][s-motion])                                 |
| L3  | `Frames`                         | [anim.rs:209][l3]                                     | `derived` frame index ([ProgressView][progress-state])                         |
| L4  | Tweens                           | [anim.rs:19][l4], [anim.rs:145][l4-2]                 | Rejected                                                                       |
| L5  | `Shimmer`                        | [anim.rs:252][l5]                                     | A motion view (L1, L2)                                                         |
| L6  | Reveal and `partial`             | [anim.rs:325][l6], [vocab/lib.rs:226][l6-2]           | Rejected for 1.0                                                               |
| M1  | Validation                       | [component.rs:104][m1], [form.rs:750][m1-2]           | `.required`, `.pattern` ([Form][form-validation])                              |
| M2  | Fuzzy filtering                  | [select.rs:161][m2]                                   | Rejected for 1.0                                                               |
| M3  | Syntax highlighting              | [text.rs:517][m3]                                     | Highlighter hook ([code view][code-hook], [roles][t-syntax])                   |
| M4  | Markdown rendering               | [markdown.rs:16][m4]                                  | `Markdown(_:)` ([Markdown][markdown])                                          |
| M5  | Images, graphics tiers           | [context.rs:735][m5], [vocab/lib.rs:104][m5-2]        | Image's protocol tiers ([Image][image])                                        |
| M6  | Value formatting                 | [number.rs:19][m6]                                    | `FormatStyle` parameters ([Stepper][stepper])                                  |
| M7  | Input `limit`                    | [input.rs:196][m7]                                    | `.characterLimit(_:)` ([counter][text-field-counter])                          |
| M8  | `mask`                           | [vocab/lib.rs:146][m8]                                | The `secret` icon ([Form][form])                                               |

## Rules

One note per key row: what the omp2 concept covers, then the rule that settles its Tessera
form.

### A: Construction and identity

- **A1.** A retained object that measures, places, and paints itself. A counterpart that
  composes existing catalog views is a composite `View`. Only one that paints cells no
  composition can draw (text, border rings, indicator thumbs, spinner frames) is a
  `LeafView`: Callout is a rail, a Label and a body, not a painter.
- **A2.** omp2 takes identity from a process-wide counter; Tessera uses structural
  identity plus explicit ids. Identity is the position in the tree plus `ForEach` ids,
  documented and dumpable.
- **A3.** Memoized output keyed by component version and context revision. Components keep
  no version counters. The app redeclares views and calls `graph.update()`; a leaf asks
  for redraw or relayout through `ResponderContext` (E6); an environment change dirties
  the subtree below it.
- **A4.** Markup with child-level `for`, `if`, and `match`; Tessera uses `ForEach`, `if`,
  and `switch`. Tags become views, attributes follow the B rows, and control flow stays
  Swift control flow.
- **A5.** `Ui::from_markup` and the parse-once tag grammar. Tessera has no markup runtime.
  Views are typed Swift values, so string attributes, CSS colour syntax, and late tag
  resolution have no counterpart.
- **A6.** `CustomElement` and the `ElementFactory` registry for unknown tags. Third
  parties conform to `View` or `LeafView` ([leaf seam](../docs/Spec.md#the-leaf-seam));
  there is no tag registry to extend.
- **A7.** Parent-owned records (`option`, `segment`, `tab`, `node`, `field`, `step`, `tr`,
  `td`) and promoted children such as Boxed's title. Tessera uses app data plus a row
  closure, or a typed child view in the builder. A data record (an option's value, label,
  and description) is an element of the app's collection, drawn by a row or content
  closure. A content record is a child view in the builder (`Tab`, `Section`,
  `TableColumn`). A promoted slot is a named `@ViewBuilder` parameter (`label:`,
  `header:`) with a `String` convenience.
- **A8.** `set_text`, `update_component`, `set_prop`, `set_visible`, `invalidate`. Views
  are redeclared from app state on every update
  ([state model](../docs/Spec.md#state-model-bring-your-own)); nothing is addressed by id.
- **A9.** Visibility conditioned on another component's value. The condition reads app
  state, which the app already holds through its bindings.
- **A10.** `Component::value` and `Ui::values` collect a JSON map. Every user-produced
  value is already in an app-owned `Binding` (D1), so there is nothing to collect.
- **A11.** One presentation context threaded through parse, layout, and paint; Tessera has
  one environment key per concern. Appearance, charset, theme, and clock become separate
  environment values (J3, K1, J1, L1). The width policy and the element registry have no
  counterpart (I4, A6).

[a1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L52-L173
[a2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L30-L39
[a3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L189-L212
[a4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/macros/src/lib.rs#L27-L35
[a5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markup.rs#L1-L13
[a6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1593-L1611
[a7]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markup.rs#L1334-L1336
[a7-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/boxed.rs#L77-L94
[a8]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/ui.rs#L292-L499
[a9]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L108-L109
[a10]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L164-L167
[a10-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/ui.rs#L1084-L1087
[a11]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L751-L794

### B: Attributes

- **B1.** One typed slot per well-known attribute. Content and meaning (a title, a role,
  data, a binding) is an initializer parameter. Presentation of one view (padding, frame,
  border) is a modifier. Presentation that cascades to descendants (line limit,
  truncation, roles, charset, control styles) is an environment value set by a modifier.
  The other B rows apply this rule per attribute family.
- **B2.** `w` in cells or percent, `min`, `max`, `h`, `grow`. `w` and `h` become
  `.frame(width:height:)`; `min` and `max` become `.frame(minWidth:maxWidth:)`; `grow=n`
  becomes `.flex(.fill(n))` inside `Flex`, or a `Spacer()` in a stack; `w=40%` is G8.
- **B3.** `pad`, `pad-x`, `pad-y`. A wrapper node with edge insets, not a chrome inset
  (G3).
- **B4.** `gap`, `sep`, `align`, `valign`, `justify`. Tessera uses the stacks' `spacing:`
  and `alignment:`, `Spacer`, and `Divider`. `gap` is `spacing:`; `align` and `valign` are
  `alignment:`; `justify` is `Spacer`s between children; `sep` is explicit `Divider()`
  children. `valign=stretch` is G7.
- **B5.** `border`, `bc`, `edge`, `bleed`, `title`, `title-align`, `title-pad`, `footer`,
  `footer-align`. Tessera uses `.border(_:_:)` and `Box(title:border:content:)`; a
  labelled rule is a Divider. `border` is a `BorderStyle` (K4); `bc` and `edge` are the
  line style or a `border` role override; `bleed` is modifier order (`.background` outside
  `.border`); `title` is Box's title, and a rule's label and alignment are Divider's. A
  border `footer` is rejected: Box draws a title only.
- **B6.** `fg`, `bg`, `on`, `bold`, `dim`, `italic`, `underline`, `undercurl`, `reverse`,
  `strike`, `color`. The modifiers apply over the inherited `defaultStyle`.
  `.foreground(_:)`, `.background(_:)`, `.bold()`, `.italic()`, `.underline()`, and
  `.style(_:)` for the rest. A colour token such as `fg=accent` is a role (J4), never a
  fixed colour.
- **B7.** `wrap`, `truncate`, `truncate-from`, `max-chars`. Text word-wraps by default.
  `truncate` is `.lineLimit(1)` with `.truncationMode(.tail)`, or `.head` for
  `truncate=start`; both cascade through the environment as omp2's `truncate` cascades to
  implicit text children. A display `max-chars` cap is rejected because Tessera shows what
  fits; an input cap is M7. Wrap modes are I3.
- **B8.** `max-rows`, `overflow`, and the `... N more` footer. Tessera puts `.maxRows(_:)`
  on views whose doc defines the footer. The footer counts toward the cap. Stacks and
  collections take no cap: an overflowing list scrolls. The catalog spells the modifier
  `.maxRows(_:)`.
- **B9.** The lookup key for updates, values, conditions, and button events. Updates
  redeclare (A8), values live in bindings (A10), and events are closures (C2). Identity
  uses `ForEach` ids (A2); focus uses an explicit `FocusID` (E1).
- **B10.** Any component joins the focus ring; Tessera requires an explicit `FocusID`. A
  control documents how it becomes focusable; a container that wants keys is focusable and
  handles them with `.onKey` (E3).
- **B11.** `label`, `desc`, `icon`, `badge`, `placeholder`, and a number field's `min`,
  `max`, and `step`. `label` is a title `String` or a `@ViewBuilder label:`; `desc` is
  Picker's `.optionDescription(_:)`; `icon` is `Label(_:icon:)` (K2); `badge` is
  `.badge(_:tone:)` ([Badge](primitives/badge.md)); `placeholder` is TextField's
  `prompt:`; a number field's range and step are Stepper's `in:` and `step:`. Two docs
  record exceptions. Callout's header badge is an initializer parameter drawn as a
  standalone `Badge` ([Callout](widgets/callout.md#api-direction)), because the owner
  limits `.badge(_:)` to list rows and tab items
  ([Badge](primitives/badge.md#api-direction)). Divider keeps its label a `String` or
  `Text` rather than a `@ViewBuilder label:` (owner decision,
  [Divider](primitives/divider.md#decisions)), since B5 leaves the label to Divider.
- **B12.** `variant` (Pill, Soft, Tint, Ghost), `kind`, `status`, `submit`, `cancel`. A
  style modifier expresses a look, and an initializer parameter a meaning. A closed set of
  looks is a style modifier read from the environment: `.buttonStyle(_:)`,
  `.pickerStyle(_:)`, `.toggleStyle(_:)`. A meaning is a parameter: `ButtonRole`,
  `CalloutKind`, `BadgeTone`. omp2's Ghost is `.plain` ([Button](widgets/button.md)).
- **B13.** Two-stop `fg` and `bg` ramps, `angle`, `spin`, `gradient_bounds`. Hues come
  only from the terminal's ANSI slots ([colour model](tokens.md#colour-model)); gradient
  fills are a post-1.0 idea
  ([Discussion #30](https://github.com/robfeldmann/tessera/discussions/30)).
- **B14.** The `hover` border colour, `lift` elevation, and the shadow under it. Tessera
  has no elevation. Hover is a row fill or a label underline, decided per doc (F4).
- **B15.** Excludes a subtree from host text selection. Selection and copy are
  application-owned; the doc is a sketch.
- **B16.** An OSC 133 shell-integration zone. Shell prompt zones belong to apps that are
  shells; the catalog has no consumer.

[b1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L20-L231
[b1-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/props.rs#L240-L256
[b2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L31-L40
[b3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L25-L30
[b4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L23-L24
[b4-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L65-L72
[b5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L41-L62
[b6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L73-L101
[b7]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L93-L103
[b7-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L154-L161
[b8]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L158-L159
[b8-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/mod.rs#L104-L138
[b9]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L106-L107
[b10]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L208-L209
[b10-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L114-L119
[b11]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L116-L135
[b11-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L180-L191
[b12]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L95-L96
[b12-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/button.rs#L16-L25
[b13]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/props.rs#L32-L33
[b13-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L95-L103
[b14]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L204-L207
[b15]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L49-L50
[b16]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L51-L52

### C: Events and actions

- **C1.** `Skip`, `Consumed`, or `Event(UiEvent)`. `Skip` is `.ignored` and the event
  bubbles; `Consumed` is `.handled`; `Event` is `.handled` after the widget writes its
  binding or calls its action closure. Emitting an event is calling a closure.
- **C2.** Tessera uses `Button(action:)`, or `.onTap(perform:)` on other views. The
  closure is the address, so no id travels with it. Pressable containers are C12.
- **C3.** From a `submit` button, a multi-select Enter, or Input's Enter. Tessera uses
  TextField's `onSubmit:`, or a `Button` with `.keyboardShortcut(.defaultAction)`. There
  is no framework-level submit; the control that submits owns the closure.
- **C4.** Esc unhandled at the top level, or a `cancel` button. A cancel button is
  `Button(role: .cancel, action:)`. `graph.dispatch` returns `.ignored` and the app
  decides what Esc means; `.keyboardShortcut(.cancelAction)` binds Esc to a cancel button.
- **C5.** A select's cursor rests on a new option. A menu cursor is position, not data
  (D3). Where moving is choosing (List, Outline), the selection binding already follows
  the cursor.
- **C6.** A select commits the option under its cursor. The widget writes its selection on
  the documented commit; the app observes the write.
- **C7.** A filterable select's query changed. Picker has no type-to-filter
  ([Picker](widgets/picker.md#out-of-scope)); see M2.
- **C8.** Enter, Right on a leaf, or a row click. The closure is optional. The closure
  receives the element; Enter and double-click call it.
- **C9.** Outline takes `Binding<Set<ID>>`, and Section takes `isExpanded: Binding<Bool>`.
  Expansion is data the app may persist (D1).
- **C10.** A row's trailing action chip. Row action chips are post-1.0
  ([Outline](widgets/outline.md)); when they land they are `Button`s inside the row (C2).
- **C11.** The host writes copied text to the clipboard. TextField defers clipboard work
  ([TextField](widgets/text-field.md#deferred-post-10)); copy policy belongs to
  [Text selection](primitives/text-selection.md).
- **C12.** A `col` or `box` with `focus` and `id` emits `Pressed` on Enter or on a click
  in its zone. A container that acts is a Button; stacks and boxes gain no press
  behaviour.
- **C13.** The first press arms, the second acts. Activation stays Button's contract, and
  a style changes appearance only ([Button](widgets/button.md)).

[c1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L41-L50
[c2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1837-L1838
[c3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1833-L1834
[c4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1835-L1836
[c4-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/ui.rs#L785
[c5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1839-L1845
[c6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1846-L1852
[c7]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1879-L1888
[c8]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1853-L1859
[c9]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1860-L1869
[c10]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1870-L1878
[c11]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1889-L1892
[c12]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/col.rs#L131-L157
[c13]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/button.rs#L87-L90

### D: State

- **D1.** Kept inside the component: `checked`, a chosen index or set, input text, the
  active tab, a tree's selection and open set, form values. Tessera widgets are
  controlled: the initializer takes the app's binding, never an initial value, and the
  widget writes it only on the documented interaction. omp2's seeding attributes (`value`,
  `checked`, `open`, `selected`) have no counterpart.
- **D2.** Supplied as attributes and refreshed with `set_prop` or `set_text`: Progress's
  value, Markdown and Pre text, Img's `src`. Redeclared on every update and never copied
  into widget state. A State model table still names its owner `Binding`, meaning
  app-owned ([README](README.md#state-model-table)).
- **D3.** Select, Tree, and Form `cursor`. A cursor that only marks a position is
  NodeState: losing it loses position, never data ([README](README.md#state-model-table)).
  List and Outline move their selection binding instead and keep no separate cursor.
- **D4.** Scroll `off`, Tree `scroll_top`, Select and Form `scroll`, and Scroll's `chase`
  of a focused descendant. ScrollView's binding is `Binding<TerminalPosition>?`. Position,
  not data. List, Table, Outline, Form, and Picker's menu keep it in NodeState; ScrollView
  takes an optional binding. One owner per value, never both
  ([README](README.md#state-model-table)). Following focus is reveal on focus change (plan
  032 step 12.2).
- **D5.** Input's cursor and selection. The caret, the selection anchor, and the
  horizontal reveal offset are NodeState; the text is the binding (D1).
- **D6.** Input's undo stack (100 entries) and kill ring (60). TextField's key table has
  no undo or yank ([TextField](widgets/text-field.md#key-table)). If the shared text
  editing core adds them, history is NodeState: losing it loses no committed text.
- **D7.** Button `armed`, Form's open dropdown and `editing`, Select's `editing`. Pressed,
  open, editing, and dragging flags are NodeState, with reset rules (focus loss closes,
  Esc cancels) in the doc's State model table; SplitView's divider drag is one
  ([SplitView](widgets/split-view.md#state-model)). omp2's scrollbar drag has no
  counterpart, because indicators are output-only (F2).
- **D8.** Select's custom-row text. A draft the widget discards on Esc is scratch;
  committing writes the binding ([Picker](widgets/picker.md#menu)). See Open questions.
- **D9.** Positions internal selection for the direction focus came from. Tessera states
  the cursor's reset rule in the doc's State model table. Tessera has no focus-entry hook.
  A doc states where its cursor starts (Picker: on the chosen option); direction-aware
  entry, such as the last row on Shift-Tab, is rejected.
- **D10.** Row tables, natural heights, `rows_dirty`. Recomputed during layout or render,
  never stored.

[d1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/checkbox.rs#L42-L45
[d1-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tree.rs#L130-L134
[d2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/ui.rs#L292
[d3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L136-L154
[d4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/scroll.rs#L12-L16
[d4-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/scroll.rs#L55
[d5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L42-L55
[d6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L18-L19
[d7]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/button.rs#L28-L30
[d7-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L170-L180
[d8]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L136-L154
[d9]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L120-L123
[d10]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tree.rs#L252

### E: Focus and keys

- **E1.** `focusable()` and `ring()` collect slots in document order; Tessera uses
  `FocusManager`'s document order. IDs are explicit, and a removed focused node clears
  focus instead of guessing a neighbour.
- **E2.** Focus at paint. Tessera draws the `isFocused` environment value with the `focus`
  role and the focus border. omp2 paints focus in `accent`; Tessera's focus is its own
  role, so it never reads as a tone.
- **E3.** `key(ec, key) -> Flow`. The doc's Key table specifies the handler. Each consumed
  key is a deliberate row; unlisted keys bubble.
- **E4.** Unhandled Tab, Enter, and arrows move focus, and Esc becomes `Cancel`. The graph
  never interprets an unhandled key: no implicit Tab handling
  ([focus model](../docs/Spec.md#focus-model)). The app, or the Phase 5 runtime as a
  default policy, adds `.onKey(.tab)`.
- **E5.** A chord table resolving chords to semantic keys such as `WordLeft`, `Copy`, and
  `Paste`. Widgets match normalized `Key` and `Modifiers` chords in their Key tables;
  rebinding belongs to apps.
- **E6.** Width, visible rows, modifiers, and `request_layout`. `nodeBounds` gives the
  size; `setNeedsDisplay()` and `setNeedsLayout()` replace repaint and relayout requests.
  The context cannot render or reach app state.
- **E7.** `paste`, and `paste_raw` to bypass smart paste. Tessera routes paste to the
  focused node like a key, per the doc's paste contract. `paste_raw` is rejected: Tessera
  has no smart paste to bypass.
- **E8.** Hand-written muted strings in each panel's footer. The legend lists the focused
  responder chain's declared keys; no view writes hint text by hand.
- **E9.** A modal overlay takes the keys, and Esc dismisses it. Tessera plans a focus
  scope that traps traversal inside an overlay and restores focus on dismissal
  ([focus scopes](../docs/Spec.md#focus-appearance-focus-scopes-and-declared-key-bindings)).
  No catalog doc owns the focus scope yet; see Open questions. Viewport-anchored modal
  layers are H1.

[e1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L114-L132
[e2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1378-L1379
[e3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L133-L137
[e4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/ui.rs#L779-L789
[e5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1599-L1613
[e6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1477-L1510
[e7]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L150-L163
[e8]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/chat/src/overlays/settings.rs#L23-L28
[e9]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/ui.rs#L720-L752

### F: Pointer

- **F1.** `HitTag` values pushed into `PaintCtx.hits` during paint and routed to
  `mouse(tag)`. Tessera hit-tests the regions named in the doc's Mouse table. A region
  that is its own child view gets its own handler; a leaf that paints many regions maps
  the point against `nodeBounds` in `handleEvent`. `Row` and `TreeRow` are rows, `Chip` is
  a chip, segment, or tab, `Press` is the whole control, and `Sub` is a menu row in a host
  row. `Wheel` is F7, `Zone` C12, `TreeAction` C10, `Scrollbar` F2.
- **F2.** A click or drag jumps the thumb. Indicators are output-only
  ([ScrollIndicator](../docs/Spec.md#scrollindicator)); a drag on one returns `.ignored`
  ([ScrollView](widgets/scroll-view.md#mouse-table)).
- **F3.** `Click`, `RightClick`, `MiddleClick`, `Move`, `Drag`, `Release`, and the wheel.
  Mouse tables name `click`, `double-click`, `drag`, `wheel-*`, and `move`. Right and
  middle clicks have no catalog use: context menus are deferred ([List](widgets/list.md)).
- **F4.** `PaintCtx.hover` (slot and tag) and `pointer`. Tessera reads graph-owned hover
  at render as derived state and draws it with the `hover` role. Like focus, the graph
  owns hover and clears it on focus loss. A view derives its hovered row from it and never
  stores it in NodeState or a binding ([List](widgets/list.md#state-model)). Motion
  tracking is requested only while a hover consumer is on screen. See Open questions.
- **F5.** `PaintCtx.keyboard` hands hover and lift chrome back to the keyboard. Tessera
  tracks no modality; focus appearance and hover are independent.
- **F6.** `Mouse::Click` focuses and activates its target. A click activates through the
  same binding or action path as the keyboard
  ([pointer cutover](../docs/Spec.md#pointer-cutover-for-controls-fields-panes-and-viewports)).
- **F7.** Scroll viewports first, then list cursors. Tessera moves the innermost
  scrollable offset, which bubbles at a boundary. List, Table, and Outline scroll without
  moving the selection; a doc may route the wheel to its cursor, as Picker's menu does.

[f1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1668-L1709
[f1-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L138-L149
[f2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1685-L1687
[f3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1803-L1826
[f4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1380-L1384
[f5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1385-L1388
[f6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1806-L1807
[f7]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/input.rs#L1818-L1821

### G: Layout

- **G1.** `measure` returns `(min, nat)` widths, then `height(width)`. One proposal-based
  question: the ideal answers `nil`, the minimum answers zero
  ([Flex allocation](../docs/Spec.md#flex-allocation-normative)), and height for a width
  is a proposal of that width with a `nil` height.
- **G2.** `place(ctx, content)`. Placement is integer cells, and `dump()` shows every
  frame.
- **G3.** `Cached` adds border and padding insets; `paints_border` and `paints_background`
  opt out. Border, padding, and background are nodes around the content, so a view opts
  out of chrome by not applying it.
- **G4.** `paint(pc, rect)` writes the frame through `PaintCtx` and its clip; Tessera uses
  `render(in:state:environment:)`. The region is clipped and translated; a leaf cannot
  write outside it. One recorded departure: a scroll indicator placed on a Box's border
  has its thumb on the ring, outside the scrolling view's region, so Box paints those
  cells after its descendants. The channel that carries the resolved thumb geometry up to
  Box is deferred to plan 032 step 9.4
  ([ScrollIndicator](primitives/scroll-indicator.md#open-questions)).
- **G5.** `stack_place` and `distribute`. Stacks give leftover space only to flexible
  children; weighted shares are `FlexConstraint.fill(_:)`.
- **G6.** A row flows children onto as many lines as fit. Not an HStack mode
  ([stacks decisions](primitives/stacks.md#decisions-and-deferred-scope)); Picker's radio
  chips wrap with it.
- **G7.** Rows stretch children by default, and `stretch_in_row` opts a child in. Stack
  children keep their measured cross-axis extent
  ([Linear stacks](primitives/stacks.md#variants)). Divider, omp2's `stretch_in_row` user,
  fills its stack's cross axis itself ([Divider](../docs/Spec.md#divider)).
- **G8.** Tessera's form is `FlexConstraint.percentage(_:)`. Resolved against a finite
  proposal only.
- **G9.** `grid_measure` and `solve_columns`, shared by tables and grids. One allocator;
  Table resolves its column widths once across all rows. Column constraints live on the
  container, not on cells: Grid's `columns:` ([Grid](primitives/grid.md#public-api)) and
  `TableColumn`'s `width:` ([Table](widgets/table.md)), where omp2 reads `w`, `min`,
  `max`, and `grow` from each cell.
- **G10.** Fact's inline or stacked geometry. Tessera's form is `ViewThatFits` with layout
  priority. No per-component fitting rules: Form, Picker, ProgressView, and LabeledContent
  choose arrangements through it.
- **G11.** Only visible rows are built and painted; Tessera evaluates the row closure for
  visible rows. Outline builds visible rows only; List and Table make no virtualization
  claim yet.

[g1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L74-L77
[g2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L78-L81
[g3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L84-L94
[g3-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L243-L258
[g4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1368-L1374
[g5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/layout.rs#L12-L13
[g5-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/layout.rs#L146-L189
[g6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/row.rs#L106-L107
[g7]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markup.rs#L180-L199
[g7-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L110-L113
[g8]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markup.rs#L110-L117
[g9]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/layout.rs#L200-L201
[g9-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/layout.rs#L242-L243
[g10]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/fact.rs#L74-L114
[g11]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tree.rs#L369-L371

### H: Layering

- **H1.** `Ui::show_overlay` with viewport-anchored `OverlayOptions` (anchor, z order,
  modal). Tessera layers in flow with `.overlay`, `.background`, and `ZStack`
  ([Overlay](primitives/overlay.md), [ZStack](primitives/z-stack.md)); viewport-anchored
  modal presentation is deferred, and Picker's menu stays inline
  ([Picker](widgets/picker.md#open-questions)).
- **H2.** Nested paint passes into a scratch frame, copied in at an offset. Tessera's
  region is translated and clipped. Content renders once into its region at the effective
  offset; there is no scratch copy.
- **H3.** Form paints an open dropdown's rows under the field. The open list takes rows in
  flow; it is not a layer.

[h1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/overlay.rs#L1-L6
[h1-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/overlay.rs#L57-L99
[h2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1434-L1437
[h3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L170-L180

### I: Text

- **I1.** `RichText` and `RichSink`: styled runs pushed and measured once. Tessera's form
  is `Text + Text` styled runs (plan 032 step 9.1), owned by Text. The runs form one
  `Text` that wraps and measures as one ([styled runs](primitives/text.md#styled-runs)).
  Whether the spelling stays `+` or becomes interpolation is a Text open question for that
  step.
- **I2.** Word and character wrap, clip with an ellipsis, row caps, hanging prefixes.
  Tessera uses Text's wrapping and truncation. A hanging prefix is layout, not text: a
  leading rail or a Label's icon column holds it. The ellipsis is `truncation.mark`
  ([truncation](tokens.md#truncation)).
- **I3.** `Truncate` (`End`, `Start`) and `TextWrap` (`Word`, `Char`, `Pre`). Tessera uses
  `.truncationMode(_:)` (`.tail`, `.head`, `.middle`) and word wrap; `Pre` is the code
  view. `Char` flow is rejected: Tessera breaks inside a word only when the word is wider
  than the line.
- **I4.** `cell_width` and the Hangul Jamo width policy. One width table for the process;
  a per-UI Jamo policy is rejected.
- **I5.** Inline icons in text and titles. Tessera's form is an icon-catalog glyph as a
  run in running text. The glyph takes the surrounding text role
  ([icon catalog](tokens.md#icon-catalog)). label.md shows it as a wireframe only; the
  run's spelling is deferred to plan 032 step 9.1
  ([Text open questions](primitives/text.md#open-questions)).
- **I6.** In markup, bare text is Markdown; Tessera makes it an explicit view. `Text`
  never parses markup.
- **I7.** `href` (an OSC 8 target) and Markdown links styled accent and underlined.
  Tessera's `.link(URL)` is an OSC 8 style attribute. Markdown emits OSC 8 on link text.

[i1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/rich.rs#L138-L160
[i1-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/rich.rs#L359-L361
[i2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/rich.rs#L686-L760
[i3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markup.rs#L156-L178
[i4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/rich.rs#L106
[i4-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L763-L768
[i5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markup.rs#L1008-L1013
[i6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markup.rs#L29-L31
[i7]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L176-L177
[i7-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markdown/mod.rs#L127

### J: Theme and colour

- **J1.** A struct of semantic colours. Tessera resolves semantic roles, each a complete
  `Style`, through the environment. Components name roles, never colours.
  [Theme fields](#theme-fields) maps each field.
- **J2.** Fixed per-appearance palettes. Hues come from the terminal's 16 ANSI slots, and
  shades derive from its own colours ([colour model](tokens.md#colour-model)).
- **J3.** `Dark` or `Light` from the background's luminance. An unknown background counts
  as dark unless `COLORFGBG` says light.
- **J4.** Theme tokens, `#hex`, `rgb()`, `oklch()`, and other CSS forms in attributes.
  Tessera uses a role, or an explicit `Color` override for a subtree. `fg=accent` is the
  `accent` role, and `.tint(_:)` overrides `accent`. CSS colour syntax is rejected.
- **J5.** On `kind`, `variant`, and `status`: info, ok, warn, err, muted, accent, pending.
  `ok` is `success`, `warn` is `warning`, `err` is `error`, and `muted` is `secondary`;
  `pending` is an icon name drawn in `secondary`. Tessera has no `user` tone.
- **J6.** `foreground_on` and `quantized_256`. Derived shades are quantised at 256 colours
  and dropped at 16.
- **J7.** `UiContext.palettes`, one per appearance. No app ships a theme; overrides are
  per role and per subtree ([overrides](tokens.md#overrides)).

[j1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L398-L481
[j2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L548-L549
[j3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L371-L396
[j4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markup.rs#L35-L38
[j4-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/props.rs#L28-L33
[j5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L15-L50
[j6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L490-L504
[j7]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L771-L777

### K: Charset and glyphs

- **K1.** `Unicode` by default, `NerdFont`, `Ascii`, on `UiContext`. Tessera's `\.charset`
  has an `.automatic` intent. Every glyph family reads it, and each glyph row falls back
  from Nerd Font to Unicode to ASCII.
- **K2.** `Charset::icon` and `icon_named`; Tessera draws the icon catalog through Label.
  Unknown names draw their raw name, as in omp2, and default roles follow omp2's rule.
- **K3.** `cursor`, `radio`, `checkbox`, `expander`, `beam`, `check`, `arrows`,
  `dropdown`. Tessera uses the Marks tokens and each widget's glyph table. `cursor` is
  `cursor`, `expander` is `disclosure.*`, and `dropdown` is `dropdown`; radio and checkbox
  marks are Toggle's and Picker's glyphs; `arrows` are Stepper's and Picker's chevrons;
  `beam` is TextField's caret.
- **K4.** `Border` (`Square`, `Dash`, `Round`, `Heavy`, `Double`) and `Charset::border`.
  `square` is `.single`, `round` is `.rounded`, and `heavy` and `double` keep their names;
  ASCII is `.ascii`. Dashed boxes are rejected: dashes exist only as divider glyphs.
- **K5.** Table grid glyphs; Tessera uses border-set junctions. Junctions draw in
  `border`.
- **K6.** Tree guides and the `guides` attribute. Guides draw in `border`.
- **K7.** `rule`, `rule_fill`, `quote_rail`, and `rail`. Rails use the `light`, `heavy`,
  and `ascii` verticals.
- **K8.** omp2's look is the `standard` preset.
- **K9.** `bar.fill` in `accent` on `bar.track` in `border`.
- **K10.** Powerline caps draw only under `.nerdFont`.
- **K11.** `Charset::spinner` and `status_spinner`. `braille` at 80 ms is the default, and
  `line` is the ASCII set.

[k1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L38-L49
[k2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L71-L80
[k3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L98-L140
[k3-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L328-L368
[k4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markup.rs#L96-L108
[k4-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L82-L96
[k5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L185-L210
[k6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L141-L157
[k7]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L158-L183
[k7-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L235-L240
[k8]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L211-L218
[k9]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L219-L226
[k10]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L227-L234
[k11]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L275-L309

### L: Motion

- **L1.** `PaintCtx.now` and `UiContext.now`. The view reads an instant and stores no
  timer and no state; a frame is a pure function of it, as in omp2.
- **L2.** `PaintCtx::wake`, `wake_layout`, `Ui::tick`, and `Ui::next_wake`. Each motion
  view declares a tick requirement with its frame interval, aggregated over live nodes
  like `TerminalRequirements`. No per-node deadlines: whoever drives the graph redraws at
  the aggregated cadence and stops when no motion view is live. Step 16.1 settles the
  Swift spellings.
- **L3.** A periodic glyph cycle with `at(now)` and `next_change`. Tessera derives the
  index as `(now / interval) mod count`. Recomputed each render, never stored.
- **L4.** `anim`, `ease`, and `spin` on any component. General animation is not Phase 4
  ([performance posture](../docs/Spec.md#phase-4-performance-posture)); the spinner is the
  catalog's only animation ([spinners](tokens.md#spinners)).
- **L5.** A brightness crest sweeping across text. No catalog doc defines one yet; see
  Open questions.
- **L6.** `Reveal`, `RevealState`, and `partial`: streamed text paced grapheme by
  grapheme. Markdown re-renders a changed source in full
  ([Markdown](widgets/markdown.md#state-model)).

[l1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1389-L1390
[l1-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L780-L784
[l2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L1453-L1458
[l2-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/ui.rs#L449-L491
[l3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/anim.rs#L209-L250
[l4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/anim.rs#L19-L28
[l4-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/anim.rs#L145-L151
[l5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/anim.rs#L252-L262
[l6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/anim.rs#L325-L344
[l6-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L226-L227

### M: Component behaviours

- **M1.** `validation_error`, `required`, `match`. Tessera uses Form's `.required(_:)` and
  `.pattern(_:message:)`, sketch names, with an inline message. The app declares the
  rules; the message is derived and painted on the row, where omp2 computes it but never
  paints it.
- **M2.** `SearchIndex` and `Query`. Filtering is out of Picker's scope
  ([Picker](widgets/picker.md#out-of-scope)); a searchable list is later work.
- **M3.** From built-in grammars. Tessera uses an app-installed `SyntaxHighlighter`
  returning syntax roles. No grammar ships in 1.0.
- **M4.** `markdown::render` behind `<md>`. Fenced code goes through the same highlighter
  hook (M3).
- **M5.** `Graphics` tiers (cells, sixel, Kitty, iTerm2), the off-thread `loader`, and
  `trim`. Tessera uses Image's protocol tiers over the Phase 3 Kitty substrate, and
  `.trim()`. Graphics capability is terminal state, never a view attribute.
- **M6.** `NumberLeaf`'s compact and byte counts. Tessera uses Foundation `FormatStyle`
  parameters, such as Stepper's `format:`. Tessera ships no formatters of its own.
- **M7.** An input character cap with a counter. The counter counts graphemes, never caps
  input, and shows overage as `+N` in `error`.
- **M8.** Obscured input. Tessera paints the `secret` icon in place of a masked value.
  Editing masked text, a secure field, is post-1.0
  ([TextField](widgets/text-field.md#deferred-post-10)).

[m1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L104-L109
[m1-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L750-L765
[m2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L161-L183
[m3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/text.rs#L517-L556
[m4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/markdown.rs#L16
[m5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/context.rs#L735-L793
[m5-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L104-L105
[m6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/number.rs#L19-L20
[m7]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L196-L200
[m8]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/vocab/src/lib.rs#L146-L147

## Theme fields

How row J1 maps each `Theme` field ([context.rs:398][j1]). Tessera roles with no omp2
field are `focus`, `disabled`, `disabled.label`, `disabled.fill`, `selection.inactive`,
and the [syntax roles](tokens.md#syntax-roles).

| omp2 field                                                  | Tessera role     | Note                                                                                                           |
| ----------------------------------------------------------- | ---------------- | -------------------------------------------------------------------------------------------------------------- |
| `fg`                                                        | `primary`        |                                                                                                                |
| `accent`                                                    | `accent`         | omp2 also paints focus in `accent`; Tessera's `focus` is a separate role (E2).                                 |
| `info`                                                      | `info`           |                                                                                                                |
| `ok`                                                        | `success`        |                                                                                                                |
| `warn`                                                      | `warning`        |                                                                                                                |
| `err`                                                       | `error`          | Button's destructive intent uses `destructive`.                                                                |
| `muted`, `dim`, `output`                                    | `secondary`      | One receding ink; `secondary` absorbs all three.                                                               |
| `border`, `border_muted`, `code_border`                     | `border`         | Markdown's fence rows are `border`.                                                                            |
| `surface`                                                   | `surface`        |                                                                                                                |
| `hover`                                                     | `hover`          |                                                                                                                |
| `selection`                                                 | `selection.fill` |                                                                                                                |
| `contrast`                                                  | `contrast`       | The label inside `solid(R)`.                                                                                   |
| `error_surface`                                             | `faint(error)`   |                                                                                                                |
| `secondary`                                                 | Rejected         | omp2's second accent for cost figures. Tessera's `secondary` is receding text, so the names do not correspond. |
| `panel`, `shadow`                                           | Rejected         | Tessera has no elevated surfaces (B14).                                                                        |
| `python`                                                    | Rejected         | An app-specific identity colour.                                                                               |
| `tool_diff_added`, `tool_diff_removed`, `tool_diff_context` | Rejected for 1.0 | Diff views are post-1.0 ([Discussion #33][discussion-33]).                                                     |
| `status_bg` and the other `status_*` fields                 | Rejected for 1.0 | The status band is post-1.0 ([Discussion #36][discussion-36]).                                                 |

[discussion-33]: https://github.com/robfeldmann/tessera/discussions/33
[discussion-36]: https://github.com/robfeldmann/tessera/discussions/36

## Coverage

Every doc in `primitives/` and `widgets/`, its omp2 counterpart, and the key rows that the
counterpart's concepts land on. Counterparts come from each doc's prior-art section, else
from plan 032's classification of omp2 components; a doc without a counterpart names the
omp2 attributes that express the same thing.

Rows that every counterpart uses through the `Component` trait, markup, and `Cached` are
left out of the lists: A1, A2, A3, A4, A5, A9, A11, B1, B9, B13, B14, B16, F5, G1, G2, G4,
K1, and L4. Every interactive counterpart also uses C1 and E6. Rows A6, E4, E9, J2, J3,
J6, and J7 describe omp2's `Ui` runtime and theme machinery, which no single counterpart
uses.

### Primitives

- [Background](primitives/background.md): None named; the `bg`, `on`, and `bleed`
  attributes painted as chrome. Rows: B5, B6, G3.
- [Badge](primitives/badge.md): Button's pill ([button.rs:115][cov-1]), Callout's header
  badge ([callout.rs:297][cov-2]), DiffStat's tone counts ([diffstat.rs:50][cov-3]). Rows:
  B11, B12, J1, J5, K10.
- [Border](primitives/border.md): None named; the `border`, `bc`, and `edge` attributes
  drawn as chrome ([component.rs:84][cov-4]). Rows: B5, E2, G3, J1, K4.
- [Box](primitives/box.md): Boxed ([boxed.rs:14][cov-5]). Rows: A7, B5, B10, C12, E2, F1,
  G3, J1, K4.
- [Divider](primitives/divider.md): Hr ([hr.rs:129][cov-6]). Rows: B5, B6, G3, G7, I2, K4,
  K7.
- [Flex](primitives/flex.md): None named; the layout helpers ([layout.rs:146][cov-7]) and
  Row's track solver ([row.rs:180][cov-8]). Rows: B2, G5, G8.
- [Flow](primitives/flow.md): Row in `wrap` mode ([row.rs:13][cov-57]) and Tabs' chip wrap
  ([tabs.rs:183][cov-58]). Rows: G6, G7.
- [Frame](primitives/frame.md): None named; the `w`, `h`, `min`, and `max` attributes.
  Rows: B2.
- [Grid](primitives/grid.md): None named; the shared column solver
  ([layout.rs:200][cov-9]). Rows: B2, G8, G9.
- [Label](primitives/label.md): Icon ([icon.rs:12][cov-10]) and State's lifecycle glyphs
  ([state.rs:80][cov-11]). Rows: B6, I5, J5, K2, L1, L3.
- [Leading rail](primitives/leading-rail.md): Callout's rail ([callout.rs:153][cov-12]),
  Quote ([quote.rs:13][cov-13]), Input's focus rail ([input.rs:443][cov-14]). Rows: E2,
  I2, J1, J5, K7.
- [Overlay](primitives/overlay.md): None in flow; omp2's layers are viewport-anchored
  ([overlay.rs:1][cov-15]). Rows: H1, H2.
- [Padding](primitives/padding.md): None named; the `pad`, `pad-x`, and `pad-y`
  attributes. Rows: B3, G3.
- [Readable width](primitives/readable-width.md): None; the nearest is the `max` width
  attribute. Rows: B2.
- [ScrollIndicator](primitives/scroll-indicator.md): Scroll's scrollbar
  ([scroll.rs:168][cov-16]). Rows: F2, J1, K8.
- [Linear stacks](primitives/stacks.md): Col ([col.rs:16][cov-17]), Row
  ([row.rs:18][cov-18]), Spacer ([hr.rs:301][cov-19]). Rows: B2, B4, B8, B10, C12, D10,
  F1, G5, G6, G7, G8.
- [Style modifiers](primitives/style-modifiers.md): None named; the text attributes and
  colour tokens. Rows: B6, J1, J4.
- [Text](primitives/text.md): TextLeaf ([text.rs:20][cov-20]). Rows: A8, B6, B7, D2, I1,
  I2, I3, I4, L1, L2, L5, L6.
- [Text selection](primitives/text-selection.md): None named; the `noselect` attribute and
  the host-owned clipboard. Rows: B15, C11.
- [ViewThatFits](primitives/view-that-fits.md): Fact ([fact.rs:74][g10]), Tabs' collapse
  ([tabs.rs:153][cov-59]), and Status ([status.rs:48][cov-60]). Rows: G10.
- [ZStack](primitives/z-stack.md): None in flow; omp2's layers are viewport-anchored
  ([overlay.rs:1][cov-21]). Rows: H1.

### Widgets

- [Button](widgets/button.md): Button ([button.rs:33][cov-22]). Rows: B11, B12, C2, C3,
  C4, C13, D7, E1, E2, E3, F1, F3, F4, F6, J1, K10.
- [Callout](widgets/callout.md): Callout ([callout.rs:53][cov-23]). Rows: A8, B11, B12,
  I2, J1, J5, K2, K7, M4.
- [Code view](widgets/code-view.md): Pre ([text.rs:443][cov-24]) and the overflow footer
  ([components/mod.rs:104][cov-25]). Rows: A8, B8, D2, I3, J1, K7, M3.
- [ContentUnavailableView](widgets/content-unavailable-view.md): Loader, rejected as a
  reference ([loader.rs:20][cov-26]); Select's empty filter result
  ([select.rs:464][cov-27]). Rows: A8, B11, C7, J1, K7, K11, L1, L2, L3, M2.
- [Form](widgets/form.md): Form ([form.rs:171][cov-28]); Wizard's validation line,
  rejected placement ([wizard.rs:258][cov-29]). Rows: A7, A10, B11, D1, D3, D4, D7, D9,
  E1, E2, E3, E7, F1, F2, F4, H3, J1, K3, K8, M1, M8.
- [Image](widgets/image.md): Img ([img.rs:105][cov-30]). Rows: B2, B8, D2, J1, K2, K4, M5.
- [KeyLegend](widgets/key-legend.md): The settings screen's footers
  ([settings.rs:23][cov-31]). Rows: E8.
- [LabeledContent](widgets/labeled-content.md): Fact ([fact.rs:20][cov-32]). Rows: B4, B6,
  B11, G10, J1.
- [List](widgets/list.md): Select's rows ([select.rs:192][cov-33]) and the settings list
  ([settings.rs:1771][cov-34]). Rows: A7, C6, C8, D3, D4, D10, E1, E3, F1, F3, F4, F7,
  G11, J1, K3, K8.
- [Markdown](widgets/markdown.md): Markdown ([markdown.rs:16][cov-35]). Rows: A7, A8, D2,
  I1, I6, I7, J1, K5, L1, L2, L6, M3, M4.
- [MultiPicker](widgets/multi-picker.md): Select with `multi` ([select.rs:514][cov-36]).
  Rows: A7, B11, C3, C6, C7, D1, D3, D4, D7, D8, D10, E1, E3, E7, F1, F3, F7, J1, K3, M2.
- [NavigationSplitView](widgets/navigation-split-view.md): The settings screen's columns
  ([settings.rs:1771][cov-37]). Rows: B2, G5, K7.
- [Outline](widgets/outline.md): Tree ([tree.rs:165][cov-38]) and Files
  ([files.rs:46][cov-39]). Rows: A7, A8, A10, B8, B11, C8, C9, C10, D1, D3, D4, D9, D10,
  E1, E2, E3, F1, F3, F4, F7, G11, I2, J1, K2, K3, K6, K7.
- [Picker](widgets/picker.md): Radio ([radio.rs:22][cov-40]), Segmented
  ([segmented.rs:26][cov-41]), Select ([select.rs:192][cov-42]). Rows: A7, A10, B11, B12,
  C5, C6, C7, D1, D3, D4, D7, D8, D9, D10, E1, E2, E3, E7, F1, F3, F4, F7, G11, H3, J1,
  K2, K3, K10, M2.
- [ProgressView](widgets/progress-view.md): Progress ([progress.rs:12][cov-43]) and
  Spinner ([spinner.rs:31][cov-44]). Rows: A8, B11, B12, D2, J1, K9, K11, L1, L2, L3.
- [ScrollView](widgets/scroll-view.md): Scroll ([scroll.rs:19][cov-45]). Rows: D4, E1, E3,
  F1, F2, F3, F7, H2, J1, K8.
- [Section](widgets/section.md): Hr's labelled rule ([hr.rs:65][cov-46]), Boxed's title
  ([boxed.rs:21][cov-47]), ToolCard's collapsible card ([`tool_card.rs`:31][cov-48]).
  Rows: A7, B5, C9, D1, J1, K3, K7, K11, L1, L2.
- [SplitView](widgets/split-view.md): The settings screen's sidebar and vertical rule
  ([settings.rs:1783][cov-49]). Rows: B2, G5, K7.
- [Stepper](widgets/stepper.md): Form's number field ([form.rs:910][cov-50]). Rows: B11,
  D1, E3, K3, M6.
- [TabView](widgets/tab-view.md): Tabs ([tabs.rs:38][cov-51]). Rows: A7, A10, B11, D1, E1,
  E2, E3, F1, F4, G6, G10, J1, K2, K3, K7, K10.
- [Table](widgets/table.md): Table ([table.rs:28][cov-52]) and Markdown's tables
  ([markdown/mod.rs:1529][cov-53]). Rows: A7, B4, B7, B8, D10, G9, I1, I2, J1, K5.
- [TextField](widgets/text-field.md): Input ([input.rs:143][cov-54]). Rows: A10, B11, C3,
  C6, D1, D5, D6, E1, E2, E3, E5, E7, F1, F3, J1, K3, K7, M7, M8.
- [Toggle](widgets/toggle.md): Checkbox ([checkbox.rs:12][cov-55]) and Choice's marks
  ([choice.rs:13][cov-56]). Rows: A10, B11, D1, E1, E2, E3, F1, F3, F4, J1, K2, K3.

[cov-1]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/button.rs#L115-L133
[cov-2]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L297-L311
[cov-3]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/diffstat.rs#L50
[cov-4]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/component.rs#L84-L94
[cov-5]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/boxed.rs#L14-L209
[cov-6]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/hr.rs#L129-L252
[cov-7]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/layout.rs#L146-L189
[cov-8]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/row.rs#L180-L237
[cov-9]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/layout.rs#L200-L299
[cov-10]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/icon.rs#L12-L86
[cov-11]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/state.rs#L80
[cov-12]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L153-L166
[cov-13]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/quote.rs#L13
[cov-14]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L443-L445
[cov-15]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/overlay.rs#L1-L6
[cov-16]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/scroll.rs#L168-L193
[cov-17]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/col.rs#L16
[cov-18]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/row.rs#L18
[cov-19]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/hr.rs#L301-L353
[cov-20]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/text.rs#L20
[cov-21]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/overlay.rs#L1-L6
[cov-22]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/button.rs#L33
[cov-23]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/callout.rs#L53
[cov-24]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/text.rs#L443-L555
[cov-25]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/mod.rs#L104-L138
[cov-26]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/loader.rs#L20-L134
[cov-27]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L464-L486
[cov-28]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L171
[cov-29]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/wizard.rs#L258-L266
[cov-30]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/img.rs#L105
[cov-31]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/chat/src/overlays/settings.rs#L23-L28
[cov-32]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/fact.rs#L20
[cov-33]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L192
[cov-34]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/chat/src/overlays/settings.rs#L1771-L1796
[cov-35]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/markdown.rs#L16
[cov-36]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L514-L715
[cov-37]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/chat/src/overlays/settings.rs#L1771-L1796
[cov-38]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tree.rs#L165
[cov-39]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/files.rs#L46
[cov-40]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/radio.rs#L22
[cov-41]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/segmented.rs#L26
[cov-42]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/select.rs#L192
[cov-43]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/progress.rs#L12
[cov-44]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/spinner.rs#L31
[cov-45]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/scroll.rs#L19
[cov-46]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/hr.rs#L65
[cov-47]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/boxed.rs#L21
[cov-48]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tool_card.rs#L31
[cov-49]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/chat/src/overlays/settings.rs#L1783-L1787
[cov-50]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/form.rs#L910-L922
[cov-51]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L38
[cov-52]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/table.rs#L28
[cov-53]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/markdown/mod.rs#L1529-L1541
[cov-54]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/input.rs#L143
[cov-55]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/checkbox.rs#L12-L158
[cov-56]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/choice.rs#L13
[cov-57]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/row.rs#L13-L17
[cov-58]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L183-L199
[cov-59]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/tabs.rs#L153-L200
[cov-60]:
  https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/tui/src/components/status.rs#L48-L70

Concepts used only by omp2 components without a catalog doc are not keyed: the diff views
(`UiEvent::DiffAction`), the editor composer and its completion popup, the status band,
Wizard's paging, Todo, Time, Countdown, Pulse, Latex, JsonPreview, Qr, Logo, Brand,
Shader, and Scene. A doc for one of them extends the key first.

## Open questions

Design choices in this key that need the owner's confirmation:

- **Hover ownership (F4).** The key follows omp2: hover is graph-owned and derived at
  render. [Button](widgets/button.md#state-model), [Form](widgets/form.md#state-model),
  and [List](widgets/list.md#state-model) now derive it from the graph.
  [Slice 5](../docs/Spec.md#slice-5-mouse-and-hit-testing) does not yet expose the hovered
  point to rendering the way the environment exposes `isFocused`; that is deferred to plan
  032 step 11.2. Awaiting owner confirmation.
- **Uncommitted drafts (D8).** Picker's and MultiPicker's custom-row draft is NodeState.
  That reads the README's "never data" rule as "never committed data". Catalog status:
  [Picker](widgets/picker.md) and [MultiPicker](widgets/multi-picker.md) keep the draft in
  NodeState (key D8). Awaiting owner confirmation.
- **Highlight events (C5).** No `onHighlight` closure: an app that previews the option
  under a menu cursor has no hook. Catalog status: neither [Picker](widgets/picker.md) nor
  [MultiPicker](widgets/multi-picker.md) defines a highlight callback. Awaiting owner
  confirmation.
- **Outline activation (C8).** [Outline](widgets/outline.md#key-table) toggles expansion
  on Enter and has no `onActivate:`, unlike List and Table, so omp2's `TreeActivated` has
  no Outline counterpart. Catalog status: Outline now has `onActivate:`, which Enter calls
  with the selected node, and Space toggles expansion (key C9); `TreeActivated` maps to
  it. Awaiting owner confirmation.
- **Shimmer (L5).** The omp2 review's owner decision 3 (2026-10-08) puts shimmer in 1.0,
  but no catalog doc defines it and [spinners](tokens.md#spinners) says the spinner is the
  only animation. The answer blocks
  [ProgressView](widgets/progress-view.md#open-questions)'s `ready`.
- **Box title slot (A7).** The key makes a promoted title child a `@ViewBuilder` slot with
  a `String` convenience, as plan 032 step 9.3 asked for Box. [Box](primitives/box.md) now
  follows the key. Awaiting owner confirmation.
- **Row caps (B8).** The catalog spells the overflow-summary modifier `.maxRows(_:)`; the
  omp2 review called it `.rowLimit`.
- **Two-step confirmation (C13).** [Button](widgets/button.md) rejects arming, but the
  omp2 review listed two-step confirmation among the 1.0 modifiers.
- **Focus scope (E9).** The Spec describes the focus scope
  ([focus scopes](../docs/Spec.md#focus-appearance-focus-scopes-and-declared-key-bindings))
  and plan 032 step 10.2 builds it, but no catalog doc owns it.
- **Title argument label (B5).** Box's `String` form keeps the labelled `title:` that B5
  names, while Section, Picker, and Toggle take an unlabelled `_ title:`. Should Box match
  them? A taste question raised while applying the key.
- **Rejected omp2 conveniences.** Border footers (B5), direction-aware focus entry (D9),
  character-flow wrapping (I3), cross-axis stretch as a row default (G7), and dashed boxes
  (K4).

[s-view]: ../docs/Spec.md#the-view-protocol-and-builders
[s-leaf]: ../docs/Spec.md#the-leaf-seam
[s-identity]: ../docs/Spec.md#identity-model
[s-invalidation]: ../docs/Spec.md#invalidation-semantics-graph-wide-defined-here
[s-env]: ../docs/Spec.md#environment
[s-state]: ../docs/Spec.md#state-model-bring-your-own
[s-style]: ../docs/Spec.md#style-chains-and-inheritance
[s-plumbing]: ../docs/Spec.md#system-and-custom-style-plumbing
[s-decoration]: ../docs/Spec.md#decoration
[s-region]: ../docs/Spec.md#renderregion
[s-scrollview]: ../docs/Spec.md#scrollview-viewport-foundation
[s-focus]: ../docs/Spec.md#focus-model
[s-route]: ../docs/Spec.md#event-routing-normative
[s-handlers]: ../docs/Spec.md#handler-modifiers-and-respondercontext
[s-focus-scope]: ../docs/Spec.md#focus-appearance-focus-scopes-and-declared-key-bindings
[s-flags4]: ../docs/Spec.md#things-to-flag-3
[s-s5]: ../docs/Spec.md#slice-5-mouse-and-hit-testing
[s-cutover]: ../docs/Spec.md#pointer-cutover-for-controls-fields-panes-and-viewports
[s-layout]: ../docs/Spec.md#the-protocol
[s-fit]: ../docs/Spec.md#flow-layout-and-viewthatfits
[s-s6]: ../docs/Spec.md#slice-6-grid-table-and-fitting
[s-width]: ../docs/Spec.md#the-width-aware-buffer
[s-motion]: ../docs/Spec.md#motion-views-and-the-tick-requirement
[readme-state]: README.md#state-model-table
[readme-key]: README.md#key-table
[readme-mouse]: README.md#mouse-table
[wrap]: README.md#wrap-and-truncation
[t-focus]: tokens.md#focus
[t-fill]: tokens.md#fill-roles
[t-roles]: tokens.md#roles
[t-scheme]: tokens.md#colour-scheme
[t-overrides]: tokens.md#overrides
[t-hue]: tokens.md#hue-roles
[t-blend]: tokens.md#blend-and-contrast-rules
[t-tiers]: tokens.md#tiers
[t-charset]: tokens.md#charset
[t-icons]: tokens.md#icon-catalog
[t-marks]: tokens.md#marks
[t-borders]: tokens.md#border-sets
[t-dividers]: tokens.md#divider-glyphs
[t-scroll]: tokens.md#scroll-indicators
[t-bars]: tokens.md#bars-and-ramps
[t-caps]: tokens.md#caps
[t-spinners]: tokens.md#spinners
[t-syntax]: tokens.md#syntax-roles
[frame]: primitives/frame.md
[flex]: primitives/flex.md
[padding]: primitives/padding.md
[stacks]: primitives/stacks.md
[border]: primitives/border.md
[box]: primitives/box.md
[divider]: primitives/divider.md
[style-mods]: primitives/style-modifiers.md
[text]: primitives/text.md
[text-wrapping]: primitives/text.md#wrapping
[text-runs]: primitives/text.md#styled-runs
[text-selection]: primitives/text-selection.md
[focus-border]: primitives/border.md#focus-border
[label]: primitives/label.md
[label-inline]: primitives/label.md#in-running-text-40-columns
[leading-rail]: primitives/leading-rail.md
[scroll-indicator]: primitives/scroll-indicator.md
[button]: widgets/button.md
[text-field]: widgets/text-field.md
[text-field-state]: widgets/text-field.md#state-model
[paste]: widgets/text-field.md#paste-input-contract
[text-field-counter]: widgets/text-field.md#character-counter
[list]: widgets/list.md
[table]: widgets/table.md
[outline]: widgets/outline.md
[section]: widgets/section.md
[scroll-state]: widgets/scroll-view.md#state-model
[key-legend]: widgets/key-legend.md
[picker-host]: widgets/picker.md#menu-collapsed-in-a-host-row
[code-view]: widgets/code-view.md
[code-overflow]: widgets/code-view.md#overflow-footer
[code-hook]: widgets/code-view.md#syntax-highlighter-hook
[image]: widgets/image.md
[markdown]: widgets/markdown.md
[progress-state]: widgets/progress-view.md#state-model
[form]: widgets/form.md
[form-validation]: widgets/form.md#validation-inline-message
[stepper]: widgets/stepper.md
