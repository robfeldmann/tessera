---
type: research
observed: 2026-10-27
status: resolved
description: How good terminal UIs make "what am I looking at, and what can I do" obvious without saying it, where Tessera's first demos fall short, and what a blind trial of the resulting skill showed.
---

# Intuitive TUI design

## Question

The owner tried the first component demos (`stacks`, `flex`, `frame-padding`, `zstack`, `foreach`, `text`, `workspace`, `counter`) and found them ugly and unintuitive: it is not clear what you are looking at or what is being demonstrated. A title line or a "what to watch" sentence would not fix that. How do terminal UIs that do this well make the subject, its state, and the available keys obvious without spelling them out, and what does that say about Tessera's demos? The answer feeds the [`tui-design` skill](../../.agents/skills/tui-design/SKILL.md).

## Findings

### Method

- Ran, headless, in a pseudo-terminal rendered by [pyte](https://github.com/selectel/pyte) through a throwaway script (`/tmp/tui-research/capture.py`): ratatui's `flex`, `constraint-explorer`, `constraints`, and `demo2` examples, built from the local checkout `~/Developer/ratatui/ratatui/main/` at `a2ca2df5`, and lazygit 0.66.2 (the version `mise` installs) in a scratch repository with a modified and an untracked file and a fresh config directory. The captures below are pyte's text, trimmed to the rows that matter, with panel margins, scrollbars, and Nerd Font icons removed; colours were read from the code, not the capture.
- Read the source of shallow clones (commits in the links): Bubbles, Bubble Tea, gum, and Lip Gloss from Charm; btop; htop; lazygit; k9s; and Textual's demo app. htop, btop, k9s, gum, and Textual are not installed here and were not run; their screens come from code and README images, and are marked where that matters.
- Read Tessera's design catalog ([design hub](../design.md), [tokens](../design/tokens.md), [KeyLegend](../design/widgets/key-legend.md)) and the cancelled [omp2 reference plan](../plans/omp2-reference-gallery-and-phase-4-redesign.md), which is where the omp2 look reached Tessera. The oh-my-pi checkout itself holds no design catalog; omp2's own examples (`crates/tui/examples/footers.rs` and `gallery/`) were read on GitHub by a survey agent and are cited from its report only.
- Took text shots of every demo with `mise run dev:shot NAME desktop` and `NAME mobile` (`workspace` at `mobileScreen`) at `1e24260`, and read the demo sources in `Examples/Sources/DemoSupport/`.

### ratatui's layout examples draw the space itself

ratatui's `flex`, `constraints`, and `constraint-explorer` examples demonstrate the same thing as Tessera's `stacks` and `flex` demos: how a row of constraints divides a width. They never describe the result; they draw it. The `flex` example at 100x30, first rows of its body:

```text
 Legacy   Start   Center   End   SpaceAround   SpaceEvenly   SpaceBetween

 <----------------------------------------------99 px---------------------------------------------->
// Fill(u16) takes any excess space always
▛▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▜▛▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▜▛▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▜▛▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▜
▌    Length(20)    ▐▌  Percentage(20)  ▐▌    Ratio(1, 5)   ▐▌               Fill(1)               ▐
▌       20 px      ▐▌       20 px      ▐▌       20 px      ▐▌                39 px                ▐
▙▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▟▙▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▟▙▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▟▙▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▟
```

- Every child is a filled block that carries two labels: the constraint as written and the width it resolved to (`"{constraint}\n{width} px"`, `~/Developer/ratatui/ratatui/main/examples/apps/flex/src/main.rs:514-525`). The input and the solver's answer sit in the same cell, so the rule is learned by looking, not by reading a caption.
- Each constraint kind has its own fill colour (`color_for_constraint`, `main.rs:527-536`), so the eye groups `Length` blocks across rows without reading their labels.
- Leftover space is drawn as an object: a dim box with only its corners, labelled with its width when it is wide enough (`render_spacer`, `main.rs:469-511`). After switching the mode with `l`, the capture's last rows end in an empty cornered region labelled `69 px`: the free space is visible, where a plain row would only show blank cells.
- A ruler spans the true width, `<---- 99 px ---->`, and adds `(gap: N px)` when spacing is not zero (`main.rs:296-303`); `constraint-explorer` does the same (`examples/apps/constraint-explorer/src/main.rs:308-313`). Pressing `+` there changes the gap columns, the gap labels (`2` between blocks), and the ruler in the same frame.
- Variants are rows of identical height under one ruler, and the mode is a tab bar, so one variable changes per row and the rows compare like a table. `constraint-explorer` labels each mode row in bold, `Flex::Start` and so on (`constraint-explorer/src/main.rs:362`), and lets the user swap the selected constraint with `1`-`6`; its swap legend doubles as a colour key, since each chip is drawn in the colour of the constraint it produces (`main.rs:281-300`). Its live result after pressing `1` on the first block is the same row re-laid out, `Min(20)` now `60 px`, with no message.
- The one prose line per example is a comment-styled description (`// Fill(u16) takes any excess space always`, italic in a dim colour, `main.rs:447-455`). It states the rule once, above the picture, and never says what to watch.

### ratatui's demo2: an app, not a specimen

`demo2` is the README demo, a fixed 81x18 app with five tabs (`~/Developer/ratatui/ratatui/main/examples/apps/demo2/src/main.rs:43-44`). Its first screen is a mascot and a short About panel; the Email tab, reached with `l` twice:

```text
Ratatui                                Recipe  Email  Traceroute  Weather
▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀▀
  Inbox    Sent    Drafts
>>Alice <alice@example.com>     Hello
  Bob <bob@example.com>         Re: Hello
  Charlie <charlie@example.com> Re: Hello
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  From: Alice <alice@example.com>
  Subject: Hello
     H/←  Left  L/→  Right  K/↑  Up  J/↓  Down  D/Del  Destroy  Q/Esc  Quit
```

- Realistic content does the explaining: a recipe, an inbox, a traceroute map, a weather gauge. Nobody needs to be told that the highlighted row is selected and the pane below shows that message.
- State shows where the eye already is. Moving the traceroute selection redraws the path on the map (`tabs/traceroute.rs`, `render_map`), the weather gauge's label turns from `Downloading: N%` into `Download Complete!` (`tabs/weather.rs:147-151`), and an inbox with nothing selected says `No email selected` (`tabs/email.rs:154`).
- The selected tab is the only reverse-video element in the title bar (`theme.rs:69-73`); one yellow marks selection; hues otherwise appear only as data (map endpoints).
- The key bar is one centred row of key chips and descriptions in two inks (`app.rs:172-190`): the key on a dark chip, the description in dark grey. It is the lowest-contrast band on screen, so it is found when wanted and ignored otherwise.
- The demo is authored as a tour of states: `examples/vhs/demo2.tape` presses keys with pauses on each interesting state.
- Counter-example in the same repository: the per-widget examples under `ratatui-widgets/examples/` open with a literal title line, `Block Widget (Press 'q' to quit)` (`ratatui-widgets/examples/block.rs:44-48`). They work because each variant underneath sits in its own bordered block titled with the variant it shows (`Bordered block`, `Styled block`), not because of that line.

### lazygit: numbered panels and a legend that follows focus

lazygit 0.66.2's first screen, after closing the welcome popup, at 100x28 (left column; the diff pane on the right is cut):

```text
╭─[1]─Status─────────────────────╮
│repo → main                     │
╰────────────────────────────────╯
╭─[2]─Files - Worktrees - Submod─╮
│▼  /                            │
│   M  a.txt                     │
│  ??  new.txt                   │
╰─────────────────────────1 of 3─╯
╭─[3]─Local branches - Remotes -─╮
│  * main                        │
╰─────────────────────────1 of 1─╯
Stage: <space> | Commit: c | Stash: s | Discard: d | Reset: D | …         Donate Ask Question 0.66.2
```

- Each panel names itself in its top border, with the key that jumps to it as a prefix (`[2]`, from `keyToTitlePrefix` in [views.go:254](https://github.com/jesseduffield/lazygit/blob/4e1eebe278790f257a875da6633234391a5a85b3/pkg/gui/views.go#L254)), and its sub-views as a title list (`Files - Worktrees - Submodules`). The bottom border carries the position, `1 of 3`. Navigation, identity, and state cost no rows.
- The bottom line is the focused panel's bindings, not a global list: after `Tab` moved focus to branches, it read `Checkout: <space> | New branch: n | Delete: d | Rebase: r | Reset: g | …`. It is built from the current context's bindings that are marked for display, have a key, and are not disabled ([options_map.go:37-58](https://github.com/jesseduffield/lazygit/blob/4e1eebe278790f257a875da6633234391a5a85b3/pkg/gui/options_map.go#L37-L58)), joined with ` | ` and cut with `…` when too long ([options_map.go:112-116](https://github.com/jesseduffield/lazygit/blob/4e1eebe278790f257a875da6633234391a5a85b3/pkg/gui/options_map.go#L112-L116)). The legend changing as focus moves is itself the proof that focus moved.
- Focus is the border colour: green and bold for the active panel ([user_config.go:907](https://github.com/jesseduffield/lazygit/blob/4e1eebe278790f257a875da6633234391a5a85b3/pkg/config/user_config.go#L907)); the focused side panel also grows while the others shrink to their titles.
- `?` opens a bordered `Keybindings` menu grouped by context (`─── Local`), with keys right-aligned against their descriptions; the bottom line switches to `Execute: <enter> | Close/Cancel: <esc>`.
- First run shows a one-time bordered popup with three numbered points and `Press <enter> to get started.` The popup is the only prose, and it is dismissed for good.

### btop, htop, and k9s: keys live in the chrome

- btop writes each box's title into its top border, bold, after a superscript box number ([btop_draw.cpp:316-322](https://github.com/aristocratos/btop/blob/af521aed05948627a56837f6953e6709a3ae812d/src/btop_draw.cpp#L316-L322)); its README screenshots show `¹cpu ²mem ³net ⁴proc` [UNVERIFIED: read from `Img/normal.png`, not run]. Buttons are words in the border with their hotkey letter in the highlight colour and the rest in the title colour: `m` + `enu` ([btop_draw.cpp:627](https://github.com/aristocratos/btop/blob/af521aed05948627a56837f6953e6709a3ae812d/src/btop_draw.cpp#L627)). The action row in the process box's bottom border (`↑ select ↓`, `info ↵`) turns to the inactive colour while nothing is selected ([btop_draw.cpp:1948-1954](https://github.com/aristocratos/btop/blob/af521aed05948627a56837f6953e6709a3ae812d/src/btop_draw.cpp#L1948-L1954)): an unavailable action is still visible, just quiet. Toggles in a title are bold while on (`proc_per_core`, [btop_draw.cpp:1928](https://github.com/aristocratos/btop/blob/af521aed05948627a56837f6953e6709a3ae812d/src/btop_draw.cpp#L1928)).
- htop's bottom row is a ten-slot function-key bar: each key in one colour pair and its label, padded to six cells, in another ([FunctionBar.c:99-107](https://github.com/htop-dev/htop/blob/394b4a3fc0df593a00be452a1862057b88b4eaf7/FunctionBar.c#L99-L107); white on black and black on cyan, [CRT.c:132-133](https://github.com/htop-dev/htop/blob/394b4a3fc0df593a00be452a1862057b88b4eaf7/CRT.c#L132-L133); labels [MainPanel.c:29](https://github.com/htop-dev/htop/blob/394b4a3fc0df593a00be452a1862057b88b4eaf7/MainPanel.c#L29)). Labels flip with mode rather than adding a status line: `Filter` becomes `FILTER` while a filter is active, and `Tree` becomes `List` in tree view ([MainPanel.c:34-35](https://github.com/htop-dev/htop/blob/394b4a3fc0df593a00be452a1862057b88b4eaf7/MainPanel.c#L34-L35)). In monochrome the bar is reverse video ([CRT.c:251-252](https://github.com/htop-dev/htop/blob/394b4a3fc0df593a00be452a1862057b88b4eaf7/CRT.c#L251-L252)).
- k9s puts its hints in a grid of at most six rows in the header, `<key>` in one style and the description in another ([menu.go:21-22](https://github.com/derailed/k9s/blob/e20d5eb66b5f4206b50acd5f4b944aaa3cf804bd/internal/ui/menu.go#L21-L22), columns grow with the hint count at [menu.go:83-84](https://github.com/derailed/k9s/blob/e20d5eb66b5f4206b50acd5f4b944aaa3cf804bd/internal/ui/menu.go#L83-L84)), rebuilt from the view stack as views are pushed and popped. The focused table's border takes the focus colour ([table.go:335](https://github.com/derailed/k9s/blob/e20d5eb66b5f4206b50acd5f4b944aaa3cf804bd/internal/ui/table.go#L335)). Its default skin spends many hues on chrome (header, crumbs, counters, hints) [UNVERIFIED: read from `assets/screen_po.png` and the default style code], which makes the pods screenshot busy; it is the counter-example for colour restraint.

### Charm: one accent, faint help, the user's own words

- Bubbles' help line is three greys: keys `#909090`, descriptions `#B2B2B2`, separators `#DADADA` on a light background, and three darker greys on a dark one ([help.go:51-53](https://github.com/charmbracelet/bubbles/blob/e04077d178b7752a88ad0f687966fd10e6effd3a/help/help.go#L51-L53)), joined with ` • ` ([help.go:95](https://github.com/charmbracelet/bubbles/blob/e04077d178b7752a88ad0f687966fd10e6effd3a/help/help.go#L95)). It has no hue at all, so it never competes with content. Short help truncates with an ellipsis to the width it is given.
- Bubble Tea's `help` example has one key map feeding a one-line short help and a multi-column full help; `?` toggles between them ([main.go:27-38](https://github.com/charmbracelet/bubbletea/blob/9c6c325f83348ee7215fb7a7aca3bc6316217056/examples/help/main.go#L27-L38), [main.go:105](https://github.com/charmbracelet/bubbletea/blob/9c6c325f83348ee7215fb7a7aca3bc6316217056/examples/help/main.go#L105)), and `?` advertises itself in the short line as `toggle help` ([main.go:59](https://github.com/charmbracelet/bubbletea/blob/9c6c325f83348ee7215fb7a7aca3bc6316217056/examples/help/main.go#L59)). Its empty state is a sentence in the content area, `Waiting for input...` ([main.go:122](https://github.com/charmbracelet/bubbletea/blob/9c6c325f83348ee7215fb7a7aca3bc6316217056/examples/help/main.go#L122)), replaced by the result.
- gum's commands are single-purpose screens: a prompt, the field or list, and at most one help line. `gum input` shows `>` and a grey placeholder, `Type something...` ([options.go:11-14](https://github.com/charmbracelet/gum/blob/879f048103adf0214b85943b52d8d65b08d772c5/input/options.go#L11-L14)); the placeholder is the empty state and the affordance at once. `gum choose` lists only the keys that apply (`toggle` appears only when several choices may be picked; [choose.go:49-53](https://github.com/charmbracelet/gum/blob/879f048103adf0214b85943b52d8d65b08d772c5/choose/choose.go#L49-L53), enabled for `--limit` above 1 at [command.go:114-116](https://github.com/charmbracelet/gum/blob/879f048103adf0214b85943b52d8d65b08d772c5/choose/command.go#L114-L116)). `gum confirm` labels its keys with the user's own button words ([confirm.go:31-50](https://github.com/charmbracelet/gum/blob/879f048103adf0214b85943b52d8d65b08d772c5/confirm/confirm.go#L31-L50)), so the hint and the buttons say the same thing.
- Lip Gloss's layout example is a composition showcase (tabs, a dialog, lists, a colour grid, a status bar) built from three named roles, `subtle`, `highlight`, and `special`, each with a light and a dark value ([main.go:49-51](https://github.com/charmbracelet/lipgloss/blob/19f011f1cc573e5d2bf9d7a9c4f14d429647759e/examples/layout/main.go#L49-L51)). Naming colours by role is the transferable part; the number of hues on its one screen is not a model of restraint.

### Textual's demo: generated footer, focus borders, and some prose

- The demo's footer is generated from the app's bindings (`Footer()`, [home.py:268](https://github.com/Textualize/textual/blob/5e5b7ef58b8c5572c13a3ff9027d756623661495/src/textual/demo/home.py#L268); bindings at [demo_app.py:36-72](https://github.com/Textualize/textual/blob/5e5b7ef58b8c5572c13a3ff9027d756623661495/src/textual/demo/demo_app.py#L36-L72)), so the shown keys are always the live ones.
- Focus is a border change: `border: wide $border-blurred` becomes `$border` on focus ([widgets.py:306-308](https://github.com/Textualize/textual/blob/5e5b7ef58b8c5572c13a3ff9027d756623661495/src/textual/demo/widgets.py#L306-L308)).
- Loading is designed: the home page sets `self.loading = True` and sleeps a second, commented "Time to admire the loading indicator" ([home.py:184-186](https://github.com/Textualize/textual/blob/5e5b7ef58b8c5572c13a3ff9027d756623661495/src/textual/demo/home.py#L184-L186)).
- It also does what the owner rejected: prose hints in the page, `**Hint:** press **C** to view the code for this page.` ([home.py:84](https://github.com/Textualize/textual/blob/5e5b7ef58b8c5572c13a3ff9027d756623661495/src/textual/demo/home.py#L84)) and `**Tip:** Focus the table and press ctrl+a` ([widgets.py:169](https://github.com/Textualize/textual/blob/5e5b7ef58b8c5572c13a3ff9027d756623661495/src/textual/demo/widgets.py#L169)). They read as documentation pasted into the UI.

### omp2 and Tessera's catalog

- The omp2 reference reached Tessera through the cancelled [omp2 reference plan](../plans/omp2-reference-gallery-and-phase-4-redesign.md) and the [translation key](../design/translation-key.md); the catalog is its distilled form. A survey agent read omp2's own examples on GitHub: its footers are one dim line, `↑/↓ scroll · PgUp/PgDn page · Home/End jump · q quits`, and its `footers` example runs six layout studies live, each with a bold title and a one-line note, "so spacing can be judged in motion" [UNVERIFIED: from the survey's report, not re-read].
- Tessera's catalog already encodes most of the restraint: text roles `primary`, `secondary` (receding text), `border` (structural lines), and `focus` (the default foreground in bold, never a background), one `accent`, and four tones ([tokens.md, Roles](../design/tokens.md#roles)). In the 16-colour `slots` tier and under `NO_COLOR`, `secondary` and `border` are dim; under `NO_COLOR`, `accent` is bold.
- The catalog's [KeyLegend](../design/widgets/key-legend.md) is the lazygit and Bubbles legend: one row, the key bold `secondary`, the description `secondary`, entries separated by a `border` ` · `, entries dropped whole by priority when narrow, and its content taken from the focused responder chain's declared keys rather than written by hand ([translation key row E8](../design/translation-key.md)).
- [Box](../design/primitives/box.md) puts a title on the top border, as btop and lazygit do.
- The catalog's wireframe dialect (`wireframe WxH` fences, callouts with `rN cN` regions, styled grids with role legends, [design.md, Wireframe conventions](../design.md#wireframe-conventions)) can already express everything above: what is drawn, where the eye goes (a callout), and in which role.

### What the good ones share, by lens

| Lens | What the good ones do | Evidence |
| --- | --- | --- |
| Where the eye lands | The subject is the largest, brightest, or only saturated thing; chrome is the dimmest | ratatui `flex` fills; demo2's key bar; Bubbles' grey help |
| Grouping and framing | A frame per thing, its name in the frame; few rules | lazygit and btop border titles; ratatui-widgets' titled variants |
| State | Shown on the subject (selection, a label that flips, a re-laid-out row), never in a sentence elsewhere | demo2 traceroute; htop `FILTER`; constraint-explorer re-layout |
| Keys | One quiet line in two inks, for the focused thing only; or the key inside the control's own label | lazygit options bar; htop F-keys; btop `m` + `enu` |
| Density | Variants as identical rows or cells under one scale | ratatui `constraints` rows; constraint-explorer |
| Empty, loading, error | Designed and specific: a placeholder that is also the affordance; a sentence in the content area | gum placeholder; `No email selected`; Textual's loading |
| Colour | Roles, not hues; one accent; greys for chrome; works in monochrome | Bubbles help; htop's reverse-video bar; Tessera's roles |
| Motion | Only to show liveness or a change in progress | btop graphs; demo2's gauge; omp2's live studies |
| Demos | Real content, or the measured result drawn beside the input; an authored tour of states | demo2; ratatui `flex`; demo2's VHS tape |

### Tessera's demos today

`mise run dev:shot stacks desktop`, the top half:

```text
Stacks
────────────────────────────────────────────────────────────────────────────────
A B C spacing 1
leading   center    trailing
a            a            a
bbbbbbb   bbbbbbb   bbbbbbb
cc          cc           cc
top   center   bottom   Spacer
M x     x        x      A
  y   M y        y
  z     z      M z      B
```

`counter` at desktop is five rows: `Counter`, a rule, `Count` at column 0 with `0` at column 79, a rule, and `+ up   - down   0 reset   q quit`.

- **Every demo has the same skeleton, and the skeleton is louder than the subject.** Title, full-width rule, samples, full-width rule, status line, legend (all eight sources in `Examples/Sources/DemoSupport/`). The rules are the longest marks on screen. No text uses any emphasis, although `Text(_:style:)` takes a `Style` with bold, dim, and reverse today (`Sources/TesseraCore/Views/Text.swift:14`, `Sources/TesseraTerminalBuffer/Style.swift:43-48`). Title, labels, values, and legend all have the same weight, so nothing says where to look.
- **The thing being demonstrated is invisible.** Alignment is only visible against the container's edges, and the `stacks` demo never draws a container: `a / bbbbbbb / cc` centred in an undrawn column looks like ragged text (`StacksDemo.swift:109-117`). The Spacer rows show `L`, `M`, `R` separated by blank cells; the space the Spacer took, its whole point, is drawn as nothing. ratatui draws exactly that space and labels it with its width.
- **Labels are API spellings, not meaning.** `length(4) fill(1) max(4)`, `two Spacers: earlier gets the odd cell`, `priority 1: first Spacer and neighbours`, `pad+frame`, `frame+pad`. The flex demo shows the constraint but never the width it resolved to, so the reader has to count `A`s (`FlexDemo.swift:59-90`); ratatui puts `Length(20)` and `20 px` in the same block.
- **State is narrated in a status line, away from what changed.** `spacing 1`, `alignment topLeading, bb on top`, `3 items`, `ascii: measures 5x1`, `focus=catalog scroll=0`. Pressing `a` in `frame-padding` moves `Go` inside the first sample and rewrites `alignment topLeading` below the closing rule; nothing at the sample says that it is the one the key acts on.
- **The legend lists keys, but nothing ties a key to its region.** `s spacing   v rows apart   q quit` sits under everything in the same ink as the content; `s` changes only the first row of `stacks`, `v` only the three alignment columns. lazygit's legend changes with focus, btop puts the key in the control's own label.
- **Some samples read as mistakes.** `zstack`'s anatomy sample renders `OKatus` (`OK` drawn over `status`, `ZStackDemo.swift:50-53`), the empty sample is `[]`, and the layers sample is `efcd`. `frame-padding`'s `max 4` sample is a four-cell Divider, `────`, with nothing to say it is a framed view. Without frames or emphasis, an overlap is indistinguishable from a typo.
- **Space is not used.** At 80 columns the counter's value sits 75 columns from its label at the right edge, the only thing that changes and the last place the eye goes; `stacks` and `zstack` leave the right half empty at desktop while cramming samples into the left 40 columns. `workspace` fills its catalog with `Item 0` to `Item 19`.
- **Focus is invisible.** `workspace` has two panes and a focus that `Tab` moves, shown only as `focus=catalog` in the status line. At `mobileScreen` the catalog pane collapses and the status line still says `focus=catalog`, so focus sits on a pane that is not on screen.
- **The `Demo` contract pushes toward specimen sheets.** "it shows every style and variant that can differ" (`Examples/Sources/DemoSupport/Demo.swift:11-13`) has produced screens that are inventories, with every variant at once and no hierarchy among them.
- **What works and should stay:** `frame-padding`'s dotted backdrop shows the size a modified view reports, which is the ratatui idea (draw the space) in Tessera's terms; `text`'s column ruler makes cell widths countable; `foreach`'s `r` reverses the list in place, which is state shown on the subject.

### A blind trial of the skill

On 2026-10-27 three agents were each given the skill (the version before this section was added) and asked to build a `flex` demo with it, without seeing each other's work: one revised the existing `FlexDemo`, two started from scratch. Each wrote a sketch before the code, built the demo with its scenarios, and ran review mode on the build. The write-ups were read for this record; the demos themselves are not in this repository.

- **What each built.** The revision drew rows of familiar interface strips (an editor status line, mail columns, a tab row, a search bar), each with its constraints written above it and its measured widths under it, under one width knob, with a footer of only `q quit`. The first scratch design was an editor window: four full-height panes (Files, Editor, Preview, Outline) whose widths were drawn as rulers with numbers under an offered-width ruler, a list of each pane's constraint, and a key-hint footer. The second scratch design repeated one three-pane row (Files, Editor, Output) at five widths, a ladder that shows the row shrinking, with a short key-hint footer.
- **What the owner preferred, and why.** The editor window. Its key-hint footer worked nearly as KeyLegend is designed, and its real panes made the kinds of layout constraint understandable. He wanted real content in place of its panes' rows of dots. Both scratch designs beat the revision of the existing demo.
- **What the skill drove.** All three credited principle 2 (draw the invisible and label it with its measured value) for their designs, principle 6 for the one-scale structure, the eye-path and interaction tests for the findings on their first builds, and the scratch-scenario recipe (a `shot` per state, `--record`, then `colors=none`) for reviewing without a terminal.
- **Gaps all three hit.**
  - No way to get the number principle 2 asks for: Tessera cannot report a view's size. All three wrote a small demo-local `LeafView` that renders the size it was offered, and asked whether that is allowed; the skill did not say.
  - "States not drawn" in the sketch template is where every first build failed: the minimum, maximum, and absent states of each interaction (a pane at 0 cells, at 4, spacing 0) were listed but not drawn.
  - Keys before colour roles: "the key letter in the accent" collapses to bold under today's attributes-only styling, and bold already marks the subject. Two used an underline, the menu-accelerator convention.
  - Principle 10 ("drop whole things rather than clip") conflicts with a screen whose subject is the cut.
  - Focus and selection under attributes only: the skill reserved reverse for selection and the tokens make focus bold, but did not say which attribute carries which when both appear.
  - The sketch template said `mobile (40x16)`, while the harness's `mobile` is 40 columns at natural height; the harness measures that height before the app's first resize, so an adaptive screen must start in its narrow layout.
  - Layout numbers: the sketch's widths had to be computed from the catalog's rules (two wrote a throwaway copy of the resolver, and the build matched it), or else be marked approximate and read from `tessera tree`.
  - Absence: a pane squeezed to zero cells has nothing to draw; the skill had no guidance for something that legitimately takes no space.
- **Scope (owner, 2026-10-27).** The skill is about building useful TUIs that look good and work well, not about demos. A demo is one use of it: a small, concrete application with a goal that the component serves, because agents told to "make a demo" fell back on abstract content (rows of dots, `A B C`).

The skill was revised for all of the above: applications first, demos as worked applications in its Tessera section, a stand-in rule for the measuring leaf and the key-hint footer, drawn extremes in sketch mode, underlined key letters, the clipping exception, focus and selection attributes, the natural-height template, computed sketch numbers, and absence.

## Conclusion

The demos are hard to read because they describe instead of show, and they give the description, the samples, and the chrome the same weight. Good TUIs do the opposite: the subject is the most prominent thing; the invisible part of it (space, bounds, focus, selection) is drawn and labelled with its measured value; each frame names itself in its border; state changes where the eye already is; keys sit in one quiet line, or inside the control they act on, and follow focus; colour comes from a few roles and still reads in monochrome; empty and loading states are designed. None of this needs a "what to watch" sentence.

These findings are written up as the [`tui-design` skill](../../.agents/skills/tui-design/SKILL.md), a skill for designing useful terminal applications: general principles, a sketch mode that produces a wireframe before a screen is built, and a review mode that judges the built screen from `tessera shot` and styled grids. The blind trial above confirmed that the principles produce better demos than the current ones and showed where the first version was silent; Tessera's demos use the skill by treating each demo as a small worked application.

Two constraints on applying them to the demos now. Tessera has emphasis today (`Text(_:style:)` with bold, dim, reverse, underline, and colours), but not yet the catalog's roles, Box, border styles, or KeyLegend, and no view can report its size, so a demo that follows the skill now uses attributes, layout, and the skill's small, named stand-ins, not frames or role colours. The demos also follow the `Demo` contract's "every style and variant" rule, which works against hierarchy; whether to keep it is for the owner.
