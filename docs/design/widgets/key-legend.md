---
kind: widget
status: ready
---

# KeyLegend

`KeyLegend` is Tessera's one-row strip of key hints: `⏎ change · ⇥ next tab · esc close`.
It is built from the focused responders' key bindings and their descriptions, so the
legend always matches what the keys actually do. It draws only: it takes no focus and
consumes no keys. Entries are chrome (owner decision, 2026-10-18): each key and
description is a `Text` with `.lineLimit(1)` applied by KeyLegend itself, so an app's
inherited `lineLimit` never reaches it. When the row is too narrow, it drops whole
entries, lowest priority first, and never cuts an entry in half or wraps it onto a second
row.

Owner decision, omp2 review, 2026-10: `plain` is the default look, and `keycaps` also
ships in 1.0 as an option. ASCII spells the keys out.

## Prior art

- omp2 has no legend component (key E8). Each screen writes its own muted footer string by
  hand; the settings panel's footer constants in
  [`crates/chat/src/overlays/settings.rs`](https://github.com/can1357/oh-my-pi/blob/2f92f3b5aa2035d21c9f016f9ff6350795e5685a/crates/chat/src/overlays/settings.rs#L23-L28)
  (`Enter to save · Esc to cancel`) show the layout Tessera keeps: key first, then its
  description, entries separated by `·`. Tessera rejects the hand-written strings. A
  string cannot follow the bindings that actually handle the keys, and it cannot drop
  entries by priority when the row is narrow. omp2's chord table (`Keymap`) has no
  counterpart in the graph either (key E5): a declaration describes a handler and remaps
  nothing.

## API

Swift in SwiftUI vocabulary. The declarations come from
[declared key bindings](../../spec/phase-4/slice-04-focus-and-key-routing.md#focus-appearance-focus-scopes-and-declared-key-bindings):
responders declare the keys their handlers consume (key E3), each with a short
description. Plan 032 step 10.3 settles the Swift spellings of the declaration and of
`legendPriority(_:)`.

Owner decision, 2026-10-10: `KeyLegend` is an explicit view. The app or host places it
where the legend belongs. It reads the focused responder chain's bindings from the
environment; there is no magic overlay.

```swift
KeyLegend()
```

Each declared binding may set its priority with `legendPriority(_:)`. The modifier is
modelled on SwiftUI's `layoutPriority`: the larger value is kept longer. A binding that
declares none has priority 0. Equal priorities drop as a unit (owner decision,
2026-10-10).

```swift
extension View {
    func legendPriority(_ priority: Double) -> some View
}

enum LegendPriority {
    static let required: Double = 1000
    static let high: Double = 750
    static let low: Double = 250
}
```

The named values use UIKit's autolayout scale. The numbers are derived from UIKit; omp2's
footers have no priorities.

## Anatomy

A single row of the `plain` look at its design width of 60 columns. Each entry is a key
and a description in `Text`, chrome, one row; the legend composes the entries in one row.

```wireframe 60x1
↑↓ move · ⏎ change · ⇥ next tab · / search · esc close
```

```text
Callouts (60x1, 0-based):
1. r0 c0-c6    Move entry, priority `low` -- key `↑↓` bold `secondary`; description `secondary`; chrome, one row
2. r0 c10-c17  Change entry, priority `required` -- key `⏎`; description `secondary`
3. r0 c21-c30  Next tab entry, priority `high` -- key `⇥`; description `secondary`
4. r0 c34-c41  Search entry, priority default (0) -- key `/`; description `secondary`
5. r0 c45-c53  Close entry, priority `required` -- key `esc`; description `secondary`
6. r0 c7-c9, c18-c20, c31-c33, c42-c44  Separators ` · ` -- `border`
```

```text
── chars ──
↑↓ move · ⏎ change · ⇥ next tab · / search · esc close
── style ──
KKDDDDDSSSKDDDDDDDSSSKDDDDDDDDDSSSKDDDDDDDSSSKKKDDDDDD
── legend ──
.  default
K  fg=secondary bold
D  fg=secondary
S  fg=border
```

## States

### Keycaps

`keycaps` puts each key on a filled keycap. It is the same entries in the same order, at
the same 60-column design width. It ships in 1.0 as an option.

```wireframe 60x1
 ↑↓  move   ⏎  change   ⇥  next tab   /  search   esc  close
```

```text
Callouts (60x1, 0-based):
1. r0 c0-c3, c11-c13, c23-c25, c37-c39, c49-c53  Keycaps -- one per key, padded one cell
   each side; `primary` text on the `surface` fill
2. r0 c4-c8, c14-c20, c26-c34, c40-c46, c54-c59  Descriptions -- `secondary`, outside the keycaps
```

```text
── chars ──
 ↑↓  move   ⏎  change   ⇥  next tab   /  search   esc  close
── style ──
CCCCDDDDD..CCCDDDDDDD..CCCDDDDDDDDD..CCCDDDDDDD..CCCCCDDDDDD
── legend ──
.  default
D  fg=secondary
C  fg=primary bg=surface
```

### Mobile (40 columns)

When the legend does not fit, it drops whole entries, lowest priority first. Priorities
are declared per binding: change and close are `required`, next tab is `high`, move is
`low`, and search declares none (priority 0). At 40 columns, move and search drop. The
legend is 33 cells wide here, inside its 40-column design width.

```wireframe 40x1
⏎ change · ⇥ next tab · esc close
```

```text
Callouts (40x1, 0-based):
1. r0 c0-c7    Change entry, priority `required` -- key `⏎`; description `secondary`
2. r0 c11-c20  Next tab entry, priority `high` -- key `⇥`; description `secondary`
3. r0 c24-c32  Close entry, priority `required` -- key `esc`; description `secondary`
4. r0 c8-c10, c21-c23  Separators -- `border`
```

```text
── chars ──
⏎ change · ⇥ next tab · esc close
── style ──
KDDDDDDDSSSKDDDDDDDDDSSSKKKDDDDDD
── legend ──
.  default
K  fg=secondary bold
D  fg=secondary
S  fg=border
```

### ASCII

ASCII spells the keys out, so the same entries need more columns. At the 60-column design
width, the full set would take 65 cells, so search drops out and the legend is 54 cells
wide.

```wireframe 60x1
up/down move | enter change | tab next tab | esc close
```

```text
Callouts (60x1, 0-based):
1. r0 c0-c11   Move entry, priority `low` -- key `up/down`; description `secondary`
2. r0 c15-c26  Change entry, priority `required` -- key `enter`
3. r0 c30-c41  Next tab entry, priority `high` -- key `tab`
4. r0 c45-c53  Close entry, priority `required` -- key `esc`
5. r0 c12-c14, c27-c29, c42-c44  Separators -- `border`
```

```text
── chars ──
up/down move | enter change | tab next tab | esc close
── style ──
KKKKKKKDDDDDSSSKKKKKDDDDDDDSSSKKKDDDDDDDDDSSSKKKDDDDDD
── legend ──
.  default
K  fg=secondary bold
D  fg=secondary
S  fg=border
```

### Screen context (40x16)

Screen context, labelled as such (owner decision, 2026-10-10). This is the canonical
`mobile` viewport: 40x16, with the legend on the bottom row under a [List](list.md) in its
mobile state, the second canonical use case. It is not the component's frame; the
component's own mobile state is the 40-column wireframe above. Rows 0-14 are the List's
rows, shown only for placement; the legend is the bottom row. The legend's last cell keeps
the List's trailing scroll indicator in column 39.

```wireframe 40x16
 Maya Chen                       09:41 │
  Fixed the split view divider drag    │
▌Build Bot                       09:37 │
▌ tessera CI: 734 tests passed on main █
 Rob                             09:12 █
  Can List sections collapse in v1?    █
 Priya Patel                     08:58 █
  Monodraw snippet library feedback    █
 Deploy Bot                      08:30 █
  demo app preview deployed to staging │
 Maya Chen                       07:55 │
  Scroll indicator thumb rounding      │
 Linh Tran                       07:41 │
  Table column solver notes            │
 Rob                             07:02 │
⏎ change · ⇥ next tab · esc close      │
```

```text
Callouts (40x16, 0-based):
1. r15 c0-c32  Key legend, narrow entries -- change, next tab, and close; move and search
   drop at 40 columns (see Mobile (40 columns) above)
2. r0-r14      List rows -- composed under the legend for placement only; not KeyLegend output
3. c39         Scroll indicator -- List-owned; the legend leaves column 39 for it
```

### Min (20x1)

The declared floor is 20 columns: the `required` entries only, change and close.
Derivation (replaces the earlier inconsistent 20-versus-24 values, one value now): the
change entry is 8 cells (`⏎ change`), the separator 3 (`·`), and the close entry 9
(`esc close`), so the two `required` entries take 20 cells. Both have `required` priority,
so they drop together or stay together; below 20 cells the legend draws nothing (owner
decision, 2026-10-10).

```wireframe 20x1
⏎ change · esc close
```

```text
Callouts (20x1, 0-based):
1. r0 c0-c7    Change entry, priority `required` -- key `⏎`; description `secondary`
2. r0 c11-c19  Close entry, priority `required` -- key `esc`; description `secondary`
3. r0 c8-c10   Separator -- `border`; next tab (`high`), move (`low`), and search (default) have dropped
```

```text
── chars ──
⏎ change · esc close
── style ──
KDDDDDDDSSSKKKDDDDDD
── legend ──
.  default
K  fg=secondary bold
D  fg=secondary
S  fg=border
```

## Key table

None. The legend takes no focus and consumes no keys. It reads the bindings the focused
responders already declare, per
[declared key bindings](../../spec/phase-4/slice-04-focus-and-key-routing.md#focus-appearance-focus-scopes-and-declared-key-bindings).

## Mouse table

None. The legend takes no pointer input.

## State model

Schema: [README](../../design.md#state-model-table). Focus is graph-owned, so both rows
are `derived` and nothing is mirrored into `NodeState` (key ownership rule 4; key E8).

| State    | Owner   | Type                                                                 | Reset or clamp rule                                                                            |
| -------- | ------- | -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| bindings | derived | key, description, and priority from the focused chain's declarations | recomputed on every focus change and render; never stored                                      |
| entries  | derived | the bindings that fit, in declared order                             | drop whole entries, lowest priority first, until the row fits; equal priorities drop as a unit |

## Sizing

Schema: [README](../../design.md#sizing-table). Mandatory rows: nil x nil, tight,
under-minimum, over-maximum.

| Proposal                 | Result | Rule                                                                                                                                    |
| ------------------------ | ------ | --------------------------------------------------------------------------------------------------------------------------------------- |
| nil x nil                | 54x1   | Plain look at its ideal width; every entry fits (derived). Keycaps are 60x1 and ASCII 65x1 (derived).                                   |
| 54 x nil (tight)         | 54x1   | The proposal equals the ideal width; all entries fit, and the ideal width is the tight width.                                           |
| 40 x nil                 | 33x1   | Drop whole entries, lowest priority first, until the row fits: search (0) and move (`low`) drop; leading-aligned (Mobile (40 columns)). |
| 20 x nil                 | 20x1   | The floor: only the `required` entries fit, `⏎ change · esc close`, leading-aligned (Min). Entries never wrap or cut.                   |
| 19 x nil (under-minimum) | 0x0    | Below the 20-cell floor the legend draws nothing (owner decision, 2026-10-10).                                                          |
| 80x1 (over-maximum)      | 54x1   | The legend keeps its ideal width and is leading-aligned; it does not stretch (owner decision, 2026-10-10).                              |

## Environment

- Key glyphs and keys in `secondary`, bold: `secondary` is in
  [tokens.md](../tokens.md#text-roles); bold is its style.
- Descriptions: `secondary` ([text roles](../tokens.md#text-roles)).
- Separators and the `plain` key-to-description rule: `border`
  ([text roles](../tokens.md#text-roles)).
- `keycaps` glyphs: `primary`, which is in [tokens.md](../tokens.md#text-roles).
- `keycaps` fill: `surface` ([fill roles](../tokens.md#fill-roles)).

## Primitive dependencies

- [Text](../primitives/text.md) for each entry's key and description.
- [Style modifiers](../primitives/style-modifiers.md) for the bold key and the keycap
  fill.
- The focus and key routing that supplies the bindings, from
  [declared key bindings](../../spec/phase-4/slice-04-focus-and-key-routing.md#focus-appearance-focus-scopes-and-declared-key-bindings)
  (Slice 4; plan 032 step 10.3).

## Requirements

- `legend shows all five entries at 60 columns` (anatomy)
- `plain legend keys are bold secondary and descriptions are secondary` (anatomy: callouts
  1-5)
- `keycaps legend fills each key on a keycap` (states: keycaps)
- `narrow legend drops move and search at 40 columns` (states: Mobile (40 columns))
- `narrow legend drops whole entries lowest priority first` (states: Mobile (40 columns);
  sizing: 40 x nil)
- `legend at 20 columns keeps only change and close` (states: min)
- `legend never cuts an entry in half` (state model: entries)
- `legend drops equal-priority entries as a unit` (state model: entries; API:
  legendPriority)
- `legend draws nothing below 20 cells` (sizing: 19 x nil)
- `legend entries are one row and drop whole by priority instead of wrapping or truncating`
  (anatomy callouts 1-6; state model: entries; sizing: 40 x nil, 20 x nil)
- `NO_COLOR legend keys stay bold with no brackets or reverse video` (degradation:
  NO_COLOR)
- `over-maximum legend keeps its ideal width and leading alignment` (sizing: 80x1)
- `ascii legend spells keys out and drops search at 60 columns` (states: ASCII)
- `ascii legend separates entries with a pipe` (states: ASCII; degradation: ASCII)
- `NO_COLOR legend falls back to the plain look for keycaps` (degradation: NO_COLOR)
- `legend entries come from the focused responder's bindings` (state model: bindings)
- `legend takes no focus and consumes no keys` (key table: none)
- `light sixteen colour legend falls back to the plain look for keycaps` (degradation:
  16-colour)

## Degradation

- `NO_COLOR`: colour is lost, and keycaps fall back to the plain look (owner decision,
  2026-10-10). Keys stay bold: attributes survive `NO_COLOR`, so the bold key is the cue
  and nothing else is added: no brackets, no reverse video (owner decision, 2026-10-18).
- 16-colour: roles take their slots columns ([roles](../tokens.md#roles)). On a dark
  scheme `surface` is the ANSI 8 background (owner decision, 2026-10-10); on a light
  scheme `surface` has no fill, so keycaps fall back to the plain look, as under
  `NO_COLOR` (owner decision, 2026-10-19;
  [composite styles](../tokens.md#composite-styles)). Geometry is unchanged.
- ASCII: keys are spelled out (`up/down`, `enter`, `tab`), and entries are separated by
  `|` (owner decision, 2026-10-10).
- Below the floor (20 columns): entries drop whole, lowest priority first. Below 20 cells
  the legend draws nothing (owner decision, 2026-10-10).

This design was reviewed against the [Phase 4 theses](../../spec/phase-4.md): the legend
is a value description that derives its entries from graph-owned focus and the responders'
declarations at render, stores nothing, and takes no input; a declaration installs no
behaviour, so the graph still routes without interpreting keys; and the row is
deterministic integer-cell output.

## Open questions

- **Key glyphs (deferred to plan 032 step 10.3).** The legend draws `⏎`, `⇥`, `↑↓`, `/`
  and `esc`, and ASCII spells `enter`, `tab` and `up/down`. No table yet gives the glyph
  and the ASCII spelling of the other keys in the README's
  [key notation](../../design.md#key-table) (`Home`, `End`, `PgUp`, `PgDn`, `Backspace`,
  `Delete`, `Space`, and modifier chords), or says whether `↑↓` is one declaration or two
  merged entries. Step 10.3 settles them with the declaration's Swift spelling.

## Inspiration

None yet.
