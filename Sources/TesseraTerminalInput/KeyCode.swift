/// A semantic terminal key code.
public enum KeyCode: Equatable, Sendable {
  /// The Backspace key.
  case backspace

  /// A printable character or composed Unicode grapheme.
  case character(Character)

  /// The Delete key.
  case delete

  /// The Down Arrow key.
  case down

  /// The End key.
  case end

  /// The Enter or Return key.
  case enter

  /// The Escape key.
  case escape

  /// A function key, such as F1 or F12.
  case function(Int)

  /// The Home key.
  case home

  /// The Insert key.
  case insert

  /// The Left Arrow key.
  case left

  /// The Page Down key.
  case pageDown

  /// The Page Up key.
  case pageUp

  /// The Right Arrow key.
  case right

  /// The Tab key.
  case tab

  /// The Up Arrow key.
  case up
}
