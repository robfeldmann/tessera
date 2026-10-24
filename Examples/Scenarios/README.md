# Scenarios

A scenario is a plain text file that drives one app and says what the screen should show. It is a test, a bug report, and a fixture at once: a person or an agent can write it without reading Tessera's source, and `tessera run` runs it the same way on macOS, Linux, and Windows. This file is the grammar's single source. The design behind it is [Developer tooling](../../docs/architecture/developer-tooling.md), and the `tessera-devtools` skill is how to use it.

```sh
mise run dev:run Examples/Scenarios            # every scenario under a directory
mise run dev:run Examples/Scenarios/counter-basics.scn --pretty
```

`tessera run PATH...` takes `.scn` files and directories. A directory contributes every `.scn` file under it, in sorted order. Each scenario starts a fresh app and a fresh virtual terminal, so scenarios share no state.

## A scenario

```text
# The counter steps on `+` and `-`, resets on `0`, and ignores everything else.
app counter
size mobile
term colors=256 theme=dark

expect screen <<EOF
Counter
────────────────────────────────────────
Count                                  0
────────────────────────────────────────
+ up   - down   0 reset   q quit
EOF

type "++"
bytes "+\x1b[A"
paste "+++"
expect text 2 "Count                                  3"
shot after-steps
```

A scenario has a header and a body. The header is the `app`, `size`, and `term` statements; it binds the app, the terminal size, and the terminal before anything runs, and it must come before the first body statement. The body is everything else, run in order. A failed `expect` or `shot` is recorded with the screen as it was, and the run continues, so one run reports every failure.

## Statements

One statement per line. Blank lines are ignored.

| Group | Statement | What it does |
| --- | --- | --- |
| Header | `app NAME` | Selects the registered app (`tessera apps` lists them). Required. |
| Header | `size desktop\|mobile\|mobileScreen\|WxH` | The size the app starts at. `desktop` when omitted. |
| Header | `term colors=none\|16\|256\|true theme=light\|dark` | The terminal the app runs on. Both options are optional. |
| Input | `resize WxH` | Resizes the terminal. Both numbers are at least 1. |
| Input | `key NAME` | One key press, such as `key Tab` or `key Shift+Tab`. |
| Input | `type "text"` | One key press per character. |
| Input | `paste "text"` | One paste event holding the whole text. |
| Input | `bytes "\x1b[A"` | Raw terminal input, parsed as a terminal's input would be. |
| Observe | `shot NAME` | Takes the screen as a golden (see [Goldens](#goldens)). |
| Observe | `tree` | Adds the node tree to the report's observations. |
| Assert | `expect text [ROW] "text"` | With a ROW (counted from 0), that row, without its trailing spaces, is exactly the text. Without one, some row contains the text. |
| Assert | `expect screen <<WORD` | The screen is the lines that follow, up to a line holding only WORD. Trailing spaces on a row and trailing empty rows are not compared. |
| Assert | `expect node SEL frame X,Y,WxH` | The one node `SEL` selects has this frame, in screen cells. `X,Y WxH` is also accepted. |

### Quoting and comments

Words are separated by whitespace. `"…"` groups a word and accepts the escapes `\n`, `\t`, `\"`, `\\`, and `\xHH`, where HH is two hex digits from 00 to 7f. `'…'` groups a word literally. A `#` at the start of a word begins a comment that runs to the end of the line. Lines end at `\n`, and a `\r` before it is whitespace, so a file checked out with CRLF line endings parses as one with LF; a leading byte order mark is ignored.

Lines between `expect screen <<WORD` and the closing line are not tokenized: quotes, `#`, and leading spaces are part of the row. The closing line holds only WORD, and trailing spaces or tabs after it are ignored. Pick a WORD (letters, digits, `_`) that no row equals, since a row that equals it ends the screen.

### Input is events, not bytes

`key`, `type`, and `paste` deliver typed input events, the same ones the terminal's input parser produces, so a scenario states what happened and not how a particular terminal encoded it. `bytes` is the escape hatch for the case where the encoding is the point: its text is parsed by the same parser a live session uses, and a lone `\x1b` at the end becomes the Escape key. `type` sends characters as key presses, not as a paste.

### When the app finishes

An app that reports it is finished (`isFinished`, which is how a demo quits) ends a live run: in a terminal nothing after it can happen. A scenario obeys the same rule. The statement that finishes the app, `key q` for the counter, is the last one that runs, and the rest of its input is not delivered, so `type "q+"` stops after the `q`. Any statement after that fails with its own verb (statements that assert the finish itself may be added later), and its failure has a message that names the line that finished the app and carries no `screen`. The run ends there: no later `expect`, `shot`, or `tree` is evaluated. An app that is already finished when the scenario starts fails its first statement the same way. Assert what the app shows before the statement that finishes it.

### Key names

Key names follow Playwright and are case sensitive: `Enter`, `Escape`, `Tab`, `Space`, `Backspace`, `Delete`, `Home`, `End`, `PageUp`, `PageDown`, `ArrowUp`, `ArrowDown`, `ArrowLeft`, `ArrowRight`, `F1` to `F12`, or one character. Modifiers `Ctrl` (or `Control`), `Alt`, `Meta`, `Shift`, and `Super` join with `+`: `Ctrl+C`, `Shift+Tab`. A letter with `Ctrl`, `Alt`, `Meta`, or `Super` is reported in lower case, as terminals report it, so `key Ctrl+C` is the key `c` with Control. An unknown name is a parse error that lists the accepted ones.

### Sizes

| Size | Meaning |
| --- | --- |
| `desktop` | 80x24. |
| `mobile` | 40 columns at the height the app's content needs. An app whose content grows to any height it is offered has no such height, and the scenario fails at its `size` line with an error that names `mobileScreen`. |
| `mobileScreen` | 40x16, for apps that fill the screen. |
| `WxH` | Any size, both numbers at least 1. |

### Locators

A selector, written `SEL` above, is a list of `key=value` words that choose nodes in the app's view tree: `type=Text` (the short type name, without module or generics, including framework-private names), `id=root/index(2)/id(catalog)` (the node's full identity path), `text="Submit"` (the node's frame holds this text on screen), and `nth=2` (the zero-based pick among the matches, in tree order). Every word narrows the match. A selector that matches nothing is a failure that names the node types present, and one that matches several without `nth` is a failure that says to add it; neither is an empty result. A selector is re-resolved at every statement. `tessera tree NAME` prints the nodes and their identities. Prefer `type=` with `nth=` to an `id=` that names a framework-private node.

### The `term` header

`term` says what kind of terminal the app runs on, and nothing about the machine running the scenario.

| Option | Meaning |
| --- | --- |
| `colors=none\|16\|256\|true` | The colour level the session renders with. `none` when omitted: plain cells. |
| `theme=light\|dark` | The colour scheme the harness reports when the session asks the terminal for its colours (OSC 10, OSC 11, and OSC 4 for slots 0 to 15). Without a `theme` the colours are unknown: the harness answers no colour query, as a terminal that cannot report colours does. |

The harness answers colour queries itself, from these fixed values and never from the virtual terminal's own defaults, so a golden does not depend on any real terminal's palette. `dark` reports foreground `#d4d4d4` and background `#1e1e1e`, `light` reports `#1e1e1e` on `#ffffff`, and both report xterm's default values for slots 0 to 15. The harness always answers the primary device attributes query, so a probe round ends at once instead of at its timeout, and ignores every other query.

## Goldens

`shot NAME` takes the screen after the statements before it and compares it with a committed text file, its golden. For a scenario `counter-basics.scn`, the goldens are in a directory named like the file without its extension, beside it: `counter-basics/NAME.txt`. A shot name is letters, digits, `.`, `_`, and `-`, and is unique within its scenario ignoring case: goldens are files, and the file systems CI runs on (macOS and Windows) fold case, so `shot a` and `shot A` in one scenario is a parse error.

A golden is the screen as text: every row with its trailing spaces removed, trailing empty rows dropped, rows joined by `\n`, and one `\n` at the end. It holds no colours or styles. Text goldens are the only artefacts a scenario run commits.

- **Drift fails.** If the screen differs from the golden, the `shot` statement fails with the first differing row, the expected and actual text of that row, and the whole screen. Nothing is rewritten. A `shot` with no golden, or whose golden is not UTF-8 text, fails too, with a message that says what to do and no `expected`, `actual`, or `screen`, since there is nothing to compare; the screen is in the shot's observation.
- **`--record` writes goldens.** `tessera run --record` creates or replaces the goldens of the `shot` statements it runs and lists what changed. It records every `shot` the run reaches, including one after a failed expectation; the run still fails, so recording never turns a failing run green, but review the files it wrote. Never record to make a failing run pass: a failing run means the app changed, and the question is whether the change is intended.
- **LF line endings.** Goldens are LF files and are compared byte for byte. A golden checked out with CRLF fails with a message that says so, whether or not the screen has also changed, so a repository sets `*.txt text eol=lf` for its golden directories and `*.scn text eol=lf` for scenarios, as this one does in `.gitattributes`. A library rendering change (a widget drawing differently) drifts goldens like any other change; the release notes say so.

## Reports and exit codes

Each scenario produces one report, printed for a person or as JSON. `tessera run` writes the human form when standard output is a terminal and one JSON object otherwise; `--pretty` and `--json` force either.

```text
PASS Examples/Scenarios/counter-basics.scn
FAIL Examples/Scenarios/workspace-desktop.scn
  line 12: shot desktop
    shot `desktop` differs from `Examples/Scenarios/workspace-desktop/desktop.txt` at row 3: …
    expected: Item 1                          │Key: none
    actual:   Item 1                          │Key: Tab
    screen:
      0| Workspace 80x24
      …
```

```json
{"command":"run","exitCode":1,"scenarios":[{"failures":[{"actual":"…","expected":"…","line":12,"message":"…","screen":["…"],"statement":"shot desktop","verb":"shot"}],"observations":[{"line":12,"lines":["…"],"name":"desktop","verb":"shot"}],"passed":false,"scenario":"Examples/Scenarios/workspace-desktop.scn"}]}
```

The object has `command`, `exitCode`, and `scenarios`, one report per scenario in the order they ran. A report has `scenario` (the file's path, as the command was given it), `passed`, `failures`, and `observations`, plus `recorded` when `--record` wrote goldens (a list of `{"change": "created" or "updated", "path": …}`) and `seconds` (one per run) under `--timing`. A failure has `line`, `statement`, `verb`, and `message`, plus `expected`, `actual`, and `screen` when the statement compares values (`expect text`, `expect screen`, `expect node`, and a drifted `shot`). A failure that belongs to a file or a command rather than to a line (a path that is not a scenario, a file that cannot be read, a name registered twice) has `line` 0 and an empty `statement`, and a `repeat` failure has `line` 0 and `--repeat N` as its `statement`. An observation has `line`, `verb` (`shot` or `tree`), the `lines` it saw, and, for a shot, its `name`. Fields are sorted by name, and nothing in the output varies from run to run, so two runs of the same scenarios give the same bytes; only `--timing` adds numbers that differ.

A scenario that does not parse is not run. Its report is one failure with `verb` `parse`, the line, the offending `statement`, and the message; the human form prints it as `FILE:LINE: error: message`. The first error ends the parse, so a file with several mistakes reports them one at a time.

A failure's `verb` says what kind it is, and so what a command exits with:

| Exit | Meaning | Failure verbs |
| --- | --- | --- |
| 0 | Every scenario passed. | None. |
| 1 | An expectation did not hold. | The statement's own verb (`expect text`, `expect screen`, `expect node`, `shot`), `size` (the app cannot take the size), and `repeat` (a run differed from the first). |
| 2 | A scenario did not parse, or a path is not a scenario, or the command line is wrong. | `parse`, `usage`. |
| 3 | The harness failed: a name registered twice, a host that could not deliver an event, a golden that could not be written. | `harness`. |

When several apply, the highest wins. `--repeat N` runs each scenario N times and adds a `repeat` failure for each run whose report differs from the first, which is how a nondeterministic app shows up.

## Not yet expressible

These forms are part of the language's design and the harness cannot honour them yet. Each one is a parse error that says what it waits for, never a statement that is skipped. A scenario that uses one fails loudly on a harness that does not have it.

| Form | Waits for |
| --- | --- |
| `wait` | the schedulable clock |
| `settle` | the schedulable clock |
| `focus` | focus tracking and role and label locators |
| `mouse` | pointer input and hit testing |
| `hit` | pointer input and hit testing |
| `dump` | the projection |
| `check` | the invariant rules, which read the projection |
| `expect cell` | style and role assertions on cells |
| `expect cost` | the per-step cost counters |
| `expect focused` | focus tracking |
| `expect wireframe` | catalog conformance |
| `expect node SEL visible` | the projection |
| `expect node SEL clipped` | the projection |
| `expect node SEL count N` | the projection |
| `shot NAME SEL` | selectors over the projection |
| `tree SEL` | selectors over the projection |
| `term glyphs=` | ASCII glyph fallbacks in the views |
| `term keyboard=` | key routing that depends on the protocol |
| `term theme=probe` | semantic roles |

## Stability

Tessera 1.0 promises a small surface to app authors and their CI, and leaves everything else free to change.

Within a major version these stay as they are:

- **The grammar.** Every statement, header key, `term` option, locator key, key name, and check rule id in this file keeps its syntax and meaning. Additions are additive, and an unknown statement stays a parse error (exit 2), so a scenario that uses a newer statement fails loudly on an older harness. `type=` values are public view type names; framework-private names are not covered.
- **The exit codes**: 0 pass, 1 an expectation or check failed, 2 a usage or parse error, 3 a harness error.
- **The JSON report's fields.** Fields are added, never removed, renamed, or retyped, and consumers ignore fields they do not know.
- **The commands and flags**: `apps`, `launch`, `run`, `shot`, `tree`, `check`, and `help`, with `--record`, `--repeat N`, `--timing`, `--json`, and `--pretty`.
- **The golden file formats.** `NAME.txt` keeps its format, so a harness upgrade alone never drifts an app's goldens.
- **The check rule ids.** A rule added in a minor version runs when named and joins bare `check` only at the next major.

Free to change in any release: the node tree text that `tree` prints and, when they exist, the projection and trace JSON, the numbers `expect cost` compares, SVG and PNG pictures, `coverage` output, `conform`, and the live-inspection socket protocol.
