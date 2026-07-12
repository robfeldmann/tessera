/// A semantic terminal key code.
public enum KeyCode: Equatable, Sendable {
  /// The Backspace key.
  case backspace

  /// The Caps Lock key.
  case capsLock

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

  /// A function key.
  ///
  /// The parser emits values 1 through 35: F1-F12 from legacy encodings and
  /// F13-F35 from Kitty keyboard protocol codes 57376 through 57398.
  /// Values outside that range can be constructed by clients but are not
  /// emitted by Tessera's parser.
  case function(Int)

  /// The Home key.
  case home

  /// The Insert key.
  case insert

  /// A keypad key.
  case keypad(Keypad)

  /// The Left Arrow key.
  case left

  /// A media or volume key.
  case media(Media)

  /// The Menu key.
  case menu

  /// A physical modifier key.
  case modifier(Modifier)

  /// The Num Lock key.
  case numLock

  /// The Page Down key.
  case pageDown

  /// The Page Up key.
  case pageUp

  /// The Pause key.
  case pause

  /// The Print Screen key.
  case printScreen

  /// The Right Arrow key.
  case right

  /// The Scroll Lock key.
  case scrollLock

  /// The Tab key.
  case tab

  /// A well-formed Kitty key code Tessera does not identify by name.
  ///
  /// The payload is the raw Kitty key code. Tessera emits this for key number
  /// 0 when associated text is present and for unassigned Private Use Area
  /// codes in Kitty reports. Invalid scalars and syntactically malformed
  /// reports remain `InputEvent.unknown`.
  case unidentified(Int)

  /// The Up Arrow key.
  case up
}

extension KeyCode {
  /// A Kitty keypad key.
  public enum Keypad: Equatable, Sendable {
    case add, begin, decimal, delete, divide, down, eight, end, enter, equal,
      five, four, home, insert, left, multiply, nine, one, pageDown, pageUp,
      right, separator, seven, six, subtract, three, two, up, zero
  }

  /// A Kitty media or volume key.
  public enum Media: Equatable, Sendable {
    case fastForward, lowerVolume, muteVolume, pause, play, playPause,
      raiseVolume, record, reverse, rewind, stop, trackNext, trackPrevious
  }

  /// A physical modifier key reported as its own key press.
  public enum Modifier: Equatable, Sendable {
    case isoLevel3Shift, isoLevel5Shift, leftAlt, leftControl, leftHyper,
      leftMeta, leftShift, leftSuper, rightAlt, rightControl, rightHyper,
      rightMeta, rightShift, rightSuper
  }
}
