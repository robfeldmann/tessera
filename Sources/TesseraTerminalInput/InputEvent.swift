import TesseraTerminalCore

/// A terminal input event parsed from raw terminal bytes.
public enum InputEvent: Equatable, Sendable {
  /// The terminal reported that the application gained focus.
  case focusGained

  /// The terminal reported that the application lost focus.
  case focusLost

  /// The user pressed a key.
  case key(Key)

  /// The terminal responded to a Kitty Graphics Protocol command.
  case kittyGraphicsResponse(KittyGraphicsResponse)

  /// The terminal reported a mouse interaction in terminal coordinates.
  case mouse(MouseEvent)

  /// The terminal delivered text as one bracketed paste payload.
  case paste(String)

  /// The terminal responded to a primary device attributes query (`DA1`, `CSI c`).
  case primaryDeviceAttributes([Int])

  /// The terminal changed size.
  case resize(TerminalSize)

  /// The terminal sent an unrecognized input sequence.
  case unknown([UInt8])
}
