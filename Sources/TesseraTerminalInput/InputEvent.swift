import TesseraTerminalCore

/// DEC private mode status reported by DECRQM (`CSI ? Ps ; Pm $ y`).
public struct PrivateModeStatus: Equatable, Sendable {
  /// The DEC private mode number that was queried.
  public var mode: Int

  /// The terminal's status for `mode`.
  public var state: PrivateModeState

  /// Creates a DEC private mode status response.
  public init(mode: Int, state: PrivateModeState) {
    self.mode = mode
    self.state = state
  }
}

/// DEC private mode status values reported by DECRQM.
public enum PrivateModeState: Equatable, Sendable {
  /// The terminal does not recognize the queried mode.
  case notRecognized

  /// The mode is permanently reset.
  case permanentlyReset

  /// The mode is permanently set.
  case permanentlySet

  /// The mode is currently reset.
  case reset

  /// The mode is currently set.
  case set
}
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

  /// The terminal reported its current Kitty keyboard enhancement flags.
  case kittyKeyboardEnhancementFlags(Int)

  /// The terminal reported a mouse interaction in terminal coordinates.
  case mouse(MouseEvent)

  /// The terminal delivered text as one bracketed paste payload.
  case paste(String)

  /// The terminal responded to a primary device attributes query (`DA1`, `CSI c`).
  case primaryDeviceAttributes([Int])

  /// The terminal responded to a DEC private mode status query (`DECRQM`).
  case privateModeStatus(PrivateModeStatus)

  /// The terminal changed size.
  case resize(TerminalSize)

  /// The terminal sent an unrecognized input sequence.
  case unknown([UInt8])
}
