---
type: spec
description: "Slice 12: Runtime protocol control"
---

# Slice 12: Runtime protocol control

Slice 12 closes Phase 3's live-session contract. It makes the distinction between advisory
evidence, application request, effective terminal state, and ambiguous state observable;
it also lets an application adjust selected output policies and application modes without
violating terminal cleanup or a frame transaction.

## Lifecycle transaction and cleanup

Every lifecycle mutation is serialized through one non-reentrant, cancellation-safe
transition gate. Actor isolation alone is not enough because a lifecycle write, flush, or
mode setter can suspend; the gate gives `enter`, application-mode reconciliation, cursor
changes, and `exit` one total order.

Before the first mutating byte for a mode can reach the terminal, Tessera registers
defensive cleanup for every requested/possibly-active mode. A successful write records the
mode as active. A partial write or flush failure is ambiguous: Tessera preserves modes
known to have completed, marks the affected slot possibly active, discards the stale
unwritten suffix where recovery requires it, and disables the defensive union of active,
requested, and possibly-active modes on cleanup. A Kitty push failure schedules a matching
pop; graphics cleanup failure discards retained stale bytes before mode teardown.

On a failed disable or exit, Tessera retains or reinstalls emergency cleanup and retains
the ambiguous lifecycle belief. It clears lifecycle state and cleanup registration only
after teardown succeeds. Repeated cleanup is idempotent. Startup—including session
construction, active reconciliation, initial application modes, and cursor restoration—is
inside the same cleanup transaction, so a failure before the application body cannot leak
raw mode, alternate screen, or an application protocol mode.

## Evidence, probes, and mode precedence

`TerminalCapabilities` is live evidence, not configuration. It records passive color and
identity hints, protocol-native events and query results, DEC private-mode observations,
and separate terminfo underline declarations. Identity/declarations are advisory; neither
is proof of active support. `TerminalProtocolModeReport` separately reports accepted
requested mode policy, lifecycle-effective modes, and modes that may be active after
ambiguous I/O.

Active detection is one bounded, permanently cached generation per session. Its serialized
rounds are DECRQM, Kitty keyboard with DA1, then Kitty Graphics `a=q` with a unique image
ID and DA1. Parsed events are observed by the existing input pump before their normal
single delivery to both public input APIs; probes do not create a second parser or consume
user input. Each round ends on its protocol-native evidence, a DA1 sentinel where defined,
or the configured deadline. A timed-out untagged DA1 round retires later untagged DA1
rounds so a late response cannot satisfy a newer generation.

The [color round](slice-06-terminal-capability-detection.md#terminal-color-reports)
amendment adds one DA1-terminated round and is the one exception to permanent caching:
color-scheme notifications and resume re-run it, and its late replies still apply, while
DECRQM, Kitty keyboard, and Kitty graphics evidence stays cached.

Public active-query entry points return the cached result once resolved, or an explicit
in-progress result while the one generation runs; they do not emit indistinguishable
repeated queries. This is why `.kittyIfAvailable` consults cached active keyboard evidence
instead of probing again. Kitty Graphics is part of active evidence, but its ordinary
query/transmit/place/delete operations remain operational rather than a persistent
setting. OSC 8 and OSC 52 remain `.notDetectable`: neither has a standard query.

Explicit application policy has the following precedence:

- `NO_COLOR` and dumb `TERM` pin effective color output to `.noColor`; otherwise the
  requested `ColorCapabilityOverride` resolves against detected color evidence.
- Explicit bracketed-paste, focus, and mouse requests remain application instructions.
  DECRQM evidence is displayed but never silently overrides them.
- `.kittyRequired` requests Kitty keyboard regardless of evidence; `.kittyIfAvailable`
  requires positive active keyboard evidence; `.legacyOnly` disables it.
- Synchronized output is explicit output policy; its DEC 2026 evidence is advisory.
- Underline defaults to `.extended`; `.terminfoDatabase` is explicit startup
  compatibility, declaration evidence is advisory, and the runtime underline setter wins.

## Draw commit points and runtime APIs

`TerminalSession.draw` awaits terminal size first, then commits effective color,
hyperlink, synchronized-output, and underline policies before the synchronous borrowed
frame body and byte encoding begin. A setter that runs while the size operation is
suspended may affect that frame; after this commit point, no setter can change its bytes.
A setter after encoding affects the next draw and leaves invalidation armed as
appropriate.

The session's public runtime policy setters are:

- `setColorCapability(_:)`
- `setHyperlinkRendering(_:)`
- `setSynchronizedOutput(_:)`
- `setUnderlineRendering(_:)`
- `setMouseTracking(_:)`
- `setFocusEvents(_:)`
- `setKeyboardProtocol(_:)`
- `setCursorStyle(_:)`

Color, hyperlink, and underline changes that alter effective output invalidate and repaint
an unchanged buffer. Hyperlink disablement repaints cells without OSC 8 metadata; every
frame still includes the terminal-state close sequence. A partial flush retains its
unwritten suffix, including that close, ahead of future frame bytes; Tessera does not
discard it or append a duplicate speculative close. Synchronized output is committed for
the whole frame: its enter byte precedes renderer encoding, cursor bytes remain inside the
wrapper, and its exit byte is the final frame byte. It changes no cell state and therefore
does not itself invalidate.

Mode setters either commit requested policy after successful lifecycle application or
throw while preserving the prior accepted request. In either outcome, effective and
possibly-active state are refreshed from lifecycle belief rather than claimed from an old
startup snapshot. Equal setters are no-ops. Fixed raw/alternate ownership and startup-only
bracketed paste are rejected rather than silently changed.

## Demo and operational boundaries

The Phase 3 protocols demo makes every live control observable. Panel-local controls are
`d` for detected/forced color cycling, `y` for synchronized output, `h` for OSC 8
rendering, `t` for actual mouse tracking, `f` for focus reporting, and `k` for keyboard
policy. Underline and cursor retain their panel-local `s`/`c` and `s`/`x` controls; the
clipboard panel's `c` is also panel-local. The global `m` remains a separately labeled
mouse logging filter, while global `q`, `g`, and `m` retain their quit, graphics, and
logging roles outside panel-local routing; numeric tab selection is global. Global and
panel-local actions accept press/repeat events and ignore key-release events. The demo
displays evidence, requested policy, effective state, and possibly-active state
separately; identity remains diagnostic.

Deliberate exclusions preserve safe ownership boundaries: raw mode and alternate screen
are fixed for the session; bracketed paste is startup-only; clipboard policy is
startup-fixed and security-sensitive; no terminal-name allowlist decides a protocol; and
graphics stays an explicit operation, not an enabled-mode toggle. Errors from lifecycle
I/O, probes, or reconciliation are surfaced to the caller while cleanup and public
effective/possible state remain truthful. The demo keeps graphics operational and does not
offer an unsafe repeated active-probe refresh.

## End of Slice 12

`TesseraTerminal` provides live, bounded, and inspectable protocol control without
conflating evidence with policy, changing a frame halfway through encoding, or abandoning
cleanup after ambiguous terminal I/O.

**End of Phase 3:** `TesseraTerminal` is feature-complete for a modern terminal app.
Everything above this is the view library.
