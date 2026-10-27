---
type: spec
description: "Slice 6: Terminal capability detection"
---

# Slice 6: Terminal capability detection

Slice 6 establishes conservative, inspectable capability evidence and the policy boundary that consumes it. It does not promise that terminal behavior can be known perfectly in advance. The current runtime also supports one bounded active-probe generation per session; that work is reconciled in Slice 12 rather than treated as a startup-only snapshot.

The first five Phase 3 slices established the intentionally opportunistic baseline: Tessera can enable or encode a protocol without introspection, and a terminal that ignores an opt-in sequence should leave the app usable. Detection remains deliberately bounded, optional, and observable so it improves policy without making startup fragile.

But some questions eventually matter:

- Should Tessera enable Kitty keyboard by default in this terminal?
- Should it prefer one keyboard protocol level over another?
- Should examples or docs warn that the current terminal lacks focus, mouse, or hyperlink support?
- Should the future view/runtime layer adapt features based on known terminal behavior?
- Should Windows Terminal, tmux, SSH, and nested terminals get different defaults?

This slice should answer those questions pragmatically. It is optional in the sense that Tessera can be useful without it, but if implemented it should be conservative, bounded, and observable.

## Design principle: hints, not truth

Terminal capability detection should produce hints, not hard guarantees.

Terminals, multiplexers, SSH sessions, shells, and environment variables all sit between Tessera and the emulator. A query can time out. A multiplexer can rewrite responses. A terminal can support a protocol but not advertise it. Another terminal can advertise a feature but implement it incompletely. The only truly reliable evidence is the byte stream Tessera actually receives and the rendering behavior the user actually sees.

So the public model should avoid names like `supportsMouse == true` if that implies a promise. Prefer a report that communicates confidence and source:

```swift
public struct TerminalCapabilities: Equatable, Sendable {
    public var bracketedPaste: CapabilityStatus
    public var focusEvents: CapabilityStatus
    public var mouseTracking: CapabilityStatus
    public var kittyGraphics: CapabilityStatus
    public var kittyKeyboard: CapabilityStatus
    public var osc8Hyperlinks: CapabilityStatus
    public var osc52Clipboard: CapabilityStatus
    public var nerdFontCoverage: CapabilityStatus
    public var synchronizedOutput: CapabilityStatus
    public var underlineDeclarations: TerminfoUnderlineDeclarations
    public var privateModeStates: [Int: PrivateModeState]
    public var color: ColorCapability
    public var colorReport: TerminalColorReport
    public var identity: TerminalIdentity
    public var isNested: Bool
}

public enum CapabilityStatus: Equatable, Sendable {
    case notDetectable
    case probing
    case supported
    case unknown
    case unsupported
}
```

`CapabilityStatus` is protocol-native evidence, not requested policy and not a record of what Tessera successfully enabled. `.supported` and `.unsupported` require conclusive protocol-native evidence; `.unknown` means there is no reliable answer; `.probing` is transient while the single active generation is running; and `.notDetectable` means the protocol has no standard active query. OSC 8 and OSC 52 are `.notDetectable`, and so is Nerd Font coverage (`nerdFontCoverage`) until a protocol-native coverage query is adopted.

`TerminalIdentity` and `isNested` are passive diagnostic hints. They may help a status panel explain the surrounding environment, but they never prove protocol support or choose production protocol policy. Color is likewise detected environmental evidence, distinct from the application's `ColorCapabilityOverride` and the renderer's effective color depth.

`colorReport` holds the terminal's own colors as the [color round](#terminal-color-reports) reports them: the default foreground (OSC 10), the default background (OSC 11), and the 16 ANSI slots (OSC 4), each an 8-bit RGB value or unknown. It is evidence like `color`; the view layer derives its role shades from it.

`underlineDeclarations` is a third kind of evidence, separate from both `CapabilityStatus` and identity: a bounded terminfo reader can report `.declared`, `.notDeclared`, or `.unknown` independently for extended underline style and color. A declaration is compatibility metadata, not proof that the active terminal implements the feature.

This is only a suggested shape. The important API decision is that detection results are advisory and inspectable, not hidden global switches that make behavior mysterious.

## Information sources

Use information sources according to how trustworthy they are:

1. Generic environment conventions: `NO_COLOR`, `COLORTERM`, color-depth hints in `TERM`, `COLORFGBG`, the locale codeset (`LC_ALL`, `LC_CTYPE`, `LANG`), the generic `NERDFONT` variable, nested-session hints such as `TMUX`/`STY`, and Windows VT availability. These may inform color, glyph, and safety policy because they are not terminal-name protocol allowlists.
2. Passive observation: if Tessera receives a Kitty keyboard report, SGR mouse event, focus event, bracketed paste markers, KGP response, or other protocol-specific response, it knows that path is working.
3. Protocol-native active queries: DA1 sentinels, KGP `a=q`, Kitty keyboard queries, DECRQM for DEC private modes, and the OSC 10/11/4 color queries.

Do not use `TERM_PROGRAM`, `TERM`, `WT_SESSION`, `VTE_VERSION`, `KONSOLE_VERSION`, or similar terminal identity hints to decide that a modern protocol is supported or unsupported. Terminal identity can be useful diagnostic metadata for an example panel, but production protocol policy must not branch on concrete emulator names.

Output policy is separate from evidence. Environment and protocol-native observations are reported in `TerminalCapabilities`; requested policy is owned by the configuration/session; and the session exposes the policy that is actually effective for a frame or lifecycle transition. Terminal identity never selects output policy.

In particular, underline rendering is application-selected output policy, not detected protocol support. Its default is extended output. The optional terminfo-database compatibility projection is discussed in Slice 11; it is an explicit startup opt-in, not terminal-name inference. OSC 8 and OSC 52 remain not actively detectable because neither has a standard query.

> [!note] Ratatui References
>
> - Ratatui's `init` helpers are intentionally conservative: they enable raw mode, enter the alternate screen, install a panic hook, and restore on exit (`ratatui/src/init.rs`, lines 318-325 and 397-404). They do not attempt capability negotiation during normal startup, which supports Tessera's “do not make startup fragile” stance.
> - Ratatui's `try_restore` disables raw mode and leaves the alternate screen, and the panic hook calls `restore()` before delegating to the previous hook (`ratatui/src/init.rs`, lines 543-559). Tessera's capability queries must not interfere with this cleanup path.
> - crossterm has a narrow internal capability-query precedent: it parses keyboard enhancement flag responses and primary device attributes into `InternalEvent`s (`crossterm` `src/event/sys/unix/parse.rs`, lines 258-292), and filters for those internal responses separately from public input (`crossterm` `src/event/filter.rs`, lines 22-35). Tessera should use the same separation if it adds active queries.
> - Ratatui's flex demo reads `TERM_PROGRAM` / `TERM_PROGRAM_VERSION` only as local example behavior, not as core terminal policy (`examples/apps/flex/src/main.rs`, lines 602-607). Tessera can centralize that kind of passive hinting in `TerminalCapabilities`.

Implemented active queries include KGP `a=q` + DA1, Kitty keyboard query + DA1, DECRQM (`CSI ? Ps $ p`) + DA1 for the DEC private modes Tessera uses (`2004`, `1004`, `1000`, `1002`, `1003`, `1006`, and `2026`), and the OSC 10/11/4 color round ([Terminal color reports](#terminal-color-reports)). Primary/secondary device attributes and terminfo-style queries such as XTGETTCAP remain possible future inputs, but they must not become terminal-name allowlists.

## Startup behavior

Capability detection must not make terminal startup feel slow or brittle.

Rules:

- Prefer sentinel-based probes over wall-clock timeouts when the protocol defines one. KGP and Kitty keyboard can use DA1 as the sentinel: response before DA1 means supported, DA1 first means unsupported.
- DECRQM uses DA1 as an end-of-round sentinel only. Its requests go out in one write followed by one DA1, which a terminal answers after every reply it will give, so the round ends at the DA1 reply after one round trip instead of waiting out the timeout. A mode with no reply by then stays `.unknown`, not unsupported, because ignoring an unrecognized private mode says nothing conclusive. DA1 alone ends the round; having every mode answered does not, since the DA1 is still in flight and would otherwise satisfy the next round's sentinel. If the round times out without DA1, that DA1 may still arrive late, so the Kitty keyboard and Kitty graphics rounds are retired and their evidence stays `.unknown`; the color round still runs.
- Every round ends with one DA1, and the probe counts each DA1 it has written, or attempted to write, until its reply arrives: the DECRQM, Kitty keyboard, Kitty graphics, and color rounds of the generation, and every color re-run. A terminal answers them in order, so only the reply that brings the count to zero can end the current round; an earlier reply belongs to a round that timed out or to a cancelled or failed attempt and is skipped. This keeps a late DA1 from ending the round that follows the timed-out one, and keeps a retry after cancellation or a failed write from taking the abandoned attempt's DA1 for its own sentinel, which would shift every later round by one and cache a false `.unsupported`. A write that fails may still have sent its DA1, so it is counted too. The count is exact only while every counted DA1 is answered, and it does not heal, because nothing identifies which reply is missing. A DA1 that is counted but never answered leaves the count one too high for the rest of the session: a failed flush whose buffered output is then discarded, a reply the parser rejects (such as `CSI ? c`), and, once suspend handling exists, replies in flight at a suspend that the shell reads all do this. Every later round then adds one and its own reply only brings the count back to one, so each round ends by timeout. A generation still to run waits out two timeouts and caches Kitty keyboard and Kitty graphics as `.unknown`, because its DECRQM round times out and retires both, and every later color re-run waits out its full timeout while it holds the round gate. A terminal that never answers DA1 leaves the count above zero in the same way, and every round it is asked ends by timeout.
- A terminal that answers nothing at all waits out two timeouts at active startup: the DECRQM round's, whose timeout retires the Kitty rounds, and the color round's, which still runs so a slow link gets its colors as late replies. At the default `activeProbeTimeout` of 1 s that is 2 s of startup. A terminal that answers DA1 waits out none, because every round ends at its own DA1 after one round trip.
- For queries without a reliable sentinel, timeout means `.unknown`, not failure.
- Query responses must flow through a parser path that cannot steal ordinary user input indefinitely.
- Detection should not block raw-mode restoration or cleanup.
- The app should be able to opt out of active queries entirely.
- The color round is the one probe the first frame waits for, so that frame paints in its final color tier. It stays bounded: its DA1 reply or `activeProbeTimeout` ends it.

An active run exposes `.probing` while probes are in flight, `.supported` only after a protocol-native response, `.unsupported` only after a conclusive sentinel, and `.unknown` when there is no reliable answer. The test for this slice is not “does Tessera know every terminal?” The test is “does Tessera expose useful capability state without terminal-name hard-coding or fragile startup behavior?”

## Terminal color reports

Owner decisions, 2026-10-19: the active generation also asks the terminal for its own colors, so the view layer can derive shades from the user's palette instead of fixed values. [docs/design/tokens.md](../../design/tokens.md#probe) owns the full probe contract and the color arithmetic that consumes it; this section is the terminal-substrate half. Everything below is implemented except the fixtures bullet.

- **Round.** OSC 10/11/4 color queries join the generation as its last round, one DA1-terminated round: one write of `OSC 10 ; ? ST`, `OSC 11 ; ? ST`, and `OSC 4 ; n ; ? ST` for each slot `n` from 0 to 15, then the round's single DA1. The round ends at the DA1 reply or at `activeProbeTimeout`, whichever comes first; an input with no reply by then is unknown, not a failure. The timeout default is 1 s, up from 250 ms, because SSH links need it; the DA1 reply still ends the round after one round trip on any terminal that answers DA1. `.passive` and `.disabled` detection send no color queries, so every color input stays unknown. The round runs even when an earlier round timed out, so a slow link still gets its colors as late replies. Its DA1 is counted like every other round's ([Startup behavior](#startup-behavior)), so a DA1 left in flight by a round that timed out or by a cancelled attempt ends neither this round nor a later color re-run.
- **`NO_COLOR`.** The round asks only for the background (OSC 11), because the color scheme, which Image's density ramp follows, still needs it.
- **First frame.** The first frame waits for the round, so it paints in its final color tier.
- **Late replies.** A color reply that arrives after its round ended is still consumed and applied as an update: the session updates `TerminalCapabilities.colorReport` first and then delivers the reply on the input queue as `InputEvent.colorReport`, so the view layer can re-resolve its roles and repaint from the event.
- **Theme changes.** Active detection's startup enables color-scheme notifications (DEC private mode 2031, `CSI ? 2031 h`, the session-fixed `ModeLifecycle.Mode.colorSchemeNotifications`, acquired with raw mode and the alternate screen) and registers `CSI ? 2031 l` with cleanup. `.passive` and `.disabled` detection never enable it, because a notification only re-runs a round they never send. Each notification (`CSI ? 997 ; 1 n` for dark, `CSI ? 997 ; 2 n` for light, delivered as `InputEvent.colorSchemeChanged`) re-runs the color round without blocking input, so the round's replies still reach the parser. Rounds run one at a time, and a request that arrives while one is already queued adds nothing, because the queued round has not asked yet and will see the newest colors. A terminal that does not know mode 2031 ignores it.
- **Resume.** The session re-runs the color round on resume after a suspend, through `TerminalSession.resumeAfterSuspend()`. Tessera has no suspend handling yet, so nothing calls it today; the suspend path, when it lands, does. It does nothing unless the session ran its active generation.
- **Evidence.** Replies fill `TerminalCapabilities.colorReport`. Nerd Font coverage has no adopted protocol-native query, so `nerdFontCoverage` reports `.notDetectable`.
- **Parser.** The input parser has an OSC reply path. It accepts `rgb:` and `rgba:` bodies (alpha ignored) with 1 to 4 hex digits per channel, terminated by BEL or ST; scales each channel to 8 bits as `round(v * 255 / (16^d - 1))` for `d` digits; and takes OSC 4 replies in any order. A reply is `InputEvent.colorReport`, never a key event. `ESC ]` is also Alt+`]` in the legacy keyboard encoding, so the parser buffers only what a color reply can contain, starting with a digit; any other byte abandons the reply (`.unknown`) and is parsed again, and a bare `ESC ]` that input idles on is Alt+`]`.
- **Multiplexers.** A multiplexer may answer for the outer terminal, leave slots unanswered, or answer DA1 before a forwarded reply, which reads as unsupported. That failure is safe, and the late reply upgrades it. Tessera never wraps queries in DCS passthrough and never decides by terminal identity.
- **Fixtures.** Not implemented: the application configuration may supply fixed colors, which skip the round, and snapshot tests use them. Phase 4's harness instead answers the round's queries from a scenario's `term` header, so the configuration field waits until a caller needs it, and its public name is chosen then.

The color round is the one exception to [Slice 12](slice-12-runtime-protocol-control.md)'s single cached generation: notifications and resume re-run it, while DECRQM, Kitty keyboard, and Kitty graphics evidence stays cached. A color input without a reply stays unknown, and a role that reads it resolves in the `slots` tier of [docs/design/tokens.md](../../design/tokens.md#tiers).

## Protocol enablement policy

Do not let capability detection silently replace explicit protocol behavior.

Suggested policy:

- Colors: start from user policy first (`NO_COLOR` wins), then environment/detection. Downsample app-requested colors at the renderer/style-resolution layer before calling the encoder: truecolor → 256 → 16 → monochrome as needed.
- Color scheme: `\.colorScheme` is `.dark` or `.light`, decided from the reported background's luminance ([rule](../../design/tokens.md#colour-scheme)). An unknown background counts as dark unless `COLORFGBG` says light (a numeric background slot of 7 or 15); terminals that stay silent are overwhelmingly dark. The capability still records the background as unknown, so a later reply replaces the assumption.
- Glyph charset: `\.charset` defaults to `.unicode`, drops to `.ascii` when the locale codeset is not UTF-8, honours the generic `NERDFONT` variable (`0` caps at `.unicode` over app policy; `1` selects `.nerdFont` for automatic mode), may be set explicitly by the application, and reports Nerd Font coverage as `.notDetectable` until a protocol-native coverage query is adopted; terminal identity never selects it. The Glyph Protocol is deferred as that query: Ghostty's `q` coverage query reports registered glyphs only, so it answers no for the symbols Ghostty bundles; kitty and WezTerm do not implement it; and the specification is still moving. The full `NERDFONT` grammar and resolution order are in [docs/design/tokens.md](../../design/tokens.md#charset).
- Synchronized output: `TerminalApplicationConfiguration.synchronizedOutput` already exists as `SynchronizedOutputPolicy` (`.disabled`/`.enabled`, default `.enabled`, and `TerminalSession.draw` already wraps frames in DEC 2026). If detection warrants it, add an `.automatic` case to that existing enum rather than a parallel type; always keep the disable knob for nested or buggy environments.
- Bracketed paste: explicit configuration may still request it directly; availability reporting comes from DECRQM mode `2004`, not terminal identity.
- Focus events: explicit configuration may still request them directly; availability reporting comes from DECRQM mode `1004`, not terminal identity.
- SGR mouse: enable according to terminal/application configuration; availability reporting comes from DECRQM over the mouse modes Tessera emits (`1002`/`1003` plus `1006`, with `1000` queried for compatibility context).
- Kitty keyboard: `.kittyIfAvailable` enables Kitty keyboard only after active keyboard query support is observed. `.kittyRequired` remains the explicit opt-in that requests Kitty keyboard without waiting for capability evidence.
- OSC 8 hyperlinks: render when hyperlink metadata exists unless disabled; visible text remains useful on unsupported terminals, and support is reported as not actively detectable until a future standard query exists.
- Kitty graphics (Slice 7): active detection uses the protocol's `a=q` query immediately followed by DA1. Apps should not send large image transmit/place payloads until the KGP response is observed, unless the user explicitly opts in to blind output.
- Raw payloads: never enable or disable themselves. They are app-authored bytes; Tessera's job is to serialize them safely through the renderer and honor their opaque/repaint policy.

The exact defaults can change, but they must be documented. Users should be able to ask: “what did Tessera enable, what did it merely assume, and why?”

## Public configuration and state

`TerminalApplicationConfiguration` is the one startup configuration surface. Its intent fields include `capabilityDetection`, `activeProbeTimeout`, bracketed paste, focus, mouse, keyboard, OSC 8, synchronized output, color, underline rendering and underline compatibility, clipboard writing, and cursor styling. The intent initializer defaults to passive detection, a 1 s active-probe round timeout (raised from 250 ms by the [color round](#terminal-color-reports)), enabled bracketed paste/focus/OSC 8/synchronized output, disabled mouse and clipboard writing, `.kittyIfAvailable`, `.detect` color, `.extended` underline rendering, disabled underline compatibility, and disabled cursor styling. The low-level `modes` initializer remains for exact test and protocol-demo mode sets; normal applications should use the intent fields.

The configuration is a request, not a claim that bytes reached the terminal. During a session, inspect these distinct facts rather than collapsing them into one “capability” value:

- `capabilities` contains passive, active, and declaration evidence only.
- `colorCapability` is the application's requested override, while `effectiveColorCapability` is the depth used to encode the next committed frame. `NO_COLOR` and dumb `TERM` pin that effective value to `.noColor`, even for a forced color request.
- `protocolModeReport.requested` is the accepted application-mode policy; `.effective` is the lifecycle's successfully active belief; and `.possiblyActive` is the union that may have reached the terminal during ambiguous I/O. The latter is not omitted merely because a setter threw.
- `underlineDeclarations` reports terminfo declarations; `underlineRendering` is the concrete output policy selected for draws. They are intentionally independent.

`TerminalSession` exposes live, actor-isolated setters for output policy: `setColorCapability(_:)`, `setHyperlinkRendering(_:)`, `setSynchronizedOutput(_:)`, and `setUnderlineRendering(_:)`. A changed effective color, hyperlink, or underline policy invalidates renderer state so unchanged cells are erased and repainted under the new projection; an equal assignment is a no-op. A color request that remains pinned to the same effective depth also does not repaint. Synchronized output changes frame boundaries only and therefore does not invalidate cell state.

The session exposes throwing runtime setters for lifecycle-owned application modes: `setMouseTracking(_:)`, `setFocusEvents(_:)`, `setKeyboardProtocol(_:)`, and `setCursorStyle(_:)`. They share one non-reentrant, cancellation-safe transition gate and one reconciliation path; no setter reconstructs desired modes from a stale effective snapshot. Raw mode and alternate screen are fixed session ownership and cannot be mutated through that path. Bracketed paste is startup-only because changing it while the parser is collecting an in-flight paste has no settled contract.

The application's explicit mode policy wins over advisory DECRQM evidence: focus and mouse settings request their modes even when evidence is unknown, while evidence remains inspectable. `.kittyRequired` always requests Kitty keyboard, `.legacyOnly` disables it, and `.kittyIfAvailable` enables it only after positive active keyboard evidence. Conditional Kitty policy never infers support from identity or passive metadata. Synchronized output is also explicit application policy; its DECRQM evidence is advisory.

## Parser behavior

If active queries are added, their responses must be parsed without contaminating ordinary input events.

Requirements:

- Recognize expected query responses separately from user input where possible.
- Time out incomplete responses.
- Surface unexpected responses through the existing unknown/debug path only if useful.
- Do not break bracketed paste, focus, mouse, or keyboard parsing.
- Do not consume a user's real keypress because it happened while a capability query was pending.
- Parse OSC 10, 11, and 4 color replies, terminated by BEL or ST, into `InputEvent.colorReport`, the way the other probe replies are events ([Terminal color reports](#terminal-color-reports)).

Query responses are semantic `InputEvent` cases (`primaryDeviceAttributes`, `privateModeStatus`, `kittyGraphicsResponse`, `kittyKeyboardEnhancementFlags`, and `colorReport`), distinct from `key`. The session observes each one as probe evidence before delivering it on the input queue, so a reply is never mistaken for a key press.

## Tests

Add environment/passive detection tests for:

- common terminal environment variables produce expected advisory identity hints
- `NO_COLOR`, `COLORTERM`, and `TERM` produce conservative color hints
- tmux/screen/SSH presence is represented without pretending to know the underlying terminal
- Windows Terminal environment is recognized when relevant variables are present
- missing environment produces `.unknown`, not failure

If active queries are implemented, add tests for:

- query bytes are encoded exactly
- valid responses update `TerminalCapabilities`
- malformed responses are ignored or reported according to policy
- query timeout produces `.unknown`
- user input interleaved with query handling is not lost
- cleanup still runs if detection times out
- the color round sends one write, parses `rgb:` and `rgba:` replies with 1 to 4 hex digits per channel and either terminator, ends on DA1 or timeout, applies late replies as updates, sends only OSC 11 under `NO_COLOR`, re-runs on a color-scheme notification and on resume, and sends nothing (and never enables mode 2031) under `.passive` and `.disabled` detection
- a DA1 left in flight by a timed-out round, or by a cancelled or failed attempt, ends no later round: not a retry's DECRQM, Kitty keyboard, or Kitty graphics round (which keep their evidence), and not the color round or a color re-run

Add configuration tests for:

- active detection can be disabled
- passive-only detection performs no terminal writes
- protocol enablement follows explicit `TerminalApplicationConfiguration` values
- color policy downsampling happens before encoding, not inside `ANSIEncoder`
- synchronized output policy controls DEC 2026 wrapping
- users can inspect what was enabled and what was merely detected/assumed

## Non-goals

Do not build a complete terminal database. Tessera is not terminfo, ncurses, or a terminal compatibility registry.

Do not make capability detection mandatory for normal operation. Modern protocol slices must continue to work opportunistically.

Do not fail startup because a terminal does not answer a query.

Do not promise perfect support detection. The result is an advisory report, not a contract.

`TesseraTerminal` exposes conservative, configurable live evidence and output/application policy without making startup fragile. Evidence, requested policy, effective lifecycle belief, and possibly-active cleanup state remain distinguishable, so callers can reason about a terminal session without terminal-name hard-coding or a false capability promise.
