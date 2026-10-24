import Tessera

/// Whether `key` is the key every demo quits on: an unmodified press of `q`.
///
/// The match is on the key's code, modifiers, and kind, never on `Key` equality, because a
/// terminal that reports enriched keys (the Kitty keyboard protocol) fills in shifted and
/// base-layout codes and associated text, and none of those make it a different key. A
/// release or a repeat does not quit.
public func isQuitKey(_ key: Key) -> Bool {
  key.kind == .press && key.modifiers.isEmpty && key.code == .character("q")
}
