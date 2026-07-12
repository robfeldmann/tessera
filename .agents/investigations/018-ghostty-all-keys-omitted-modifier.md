---
name: Ghostty all-keys omitted modifier parsing
date: 2026-07-11
status: resolved
---

# Ghostty all-keys omitted modifier parsing

## Question

Why does `Phase3ProtocolsDemo` stop responding to text controls and numeric tabs in
vanilla Ghostty after requesting Kitty keyboard mask 31, while mask 7, herdr, and Apple
Terminal remain responsive?

## Findings

- Ghostty 1.3.2 at commit `160c3c69e` emits ordinary text through legacy bytes under mask
  7, but mask 31 enables report-all plus associated text.
- A mask-31 unmodified `q` press is `CSI 113;;113u`; digit `7` is `CSI 55;;55u`. Ghostty
  intentionally omits the default modifier/event parameter, preserves its empty field, and
  writes associated text in parameter three.
- `CSIParameters` correctly decodes `CSI 113;;113u` as `[[113], [nil], [113]]`.
  `InputParser.kittyKey` correctly decodes the primary key and associated text, but
  `parseModifierAndKind` rejected the empty second parameter. The complete sequence became
  `InputEvent.unknown` immediately rather than buffering.
- Every demo global action, panel action, and numeric tab uses a printable character. This
  made the application appear completely unresponsive. Arrow reports remained valid but
  only have an action on the Cursor panel.
- Ghostty emits populated modifier/event fields for repeats and releases: q repeat is
  `CSI 113;1:2;113u`, and q release is `CSI 113;1:3u`. Physical modifier reports were
  already parsed correctly.
- The valid omission must be accepted only for Kitty CSI-u reports that contain the third
  associated-text parameter. Broadly accepting empty modifiers would also admit malformed
  legacy modified-CSI input such as `CSI 1;;A`.

## Conclusion

Allow `kittyKey` to treat an exactly empty second parameter as the default no-modifier
press when and only when parameter three is present. Preserve strict validation for legacy
CSI keys and Kitty reports without associated text. Fixed-byte parser tests cover Ghostty
q, all ten numeric tabs, explicit empty associated text, and malformed omitted-modifier
forms. The demo support tests feed the exact Ghostty mask-31 bytes through `InputParser`
and verify that q quits and digits select their declared tabs.
