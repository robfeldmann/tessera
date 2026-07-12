#if canImport(CGhosttyVT)

  import CGhosttyVT

#endif

/// A test-support wrapper around Ghostty's Kitty keyboard encoder.
enum GhosttyKittyKeyEncoder {
  // swiftlint:disable sorted_enum_cases
  /// A Ghostty key action.
  enum Action: Equatable, Sendable {
    case press
    case release
    case `repeat`
  }
  // swiftlint:enable sorted_enum_cases

  /// Ghostty key raw values used by input-parser oracle tests.
  enum KeyRawValue {
    #if canImport(CGhosttyVT)
      static let arrowDown = UInt32(GHOSTTY_KEY_ARROW_DOWN.rawValue)
      static let arrowLeft = UInt32(GHOSTTY_KEY_ARROW_LEFT.rawValue)
      static let arrowRight = UInt32(GHOSTTY_KEY_ARROW_RIGHT.rawValue)
      static let arrowUp = UInt32(GHOSTTY_KEY_ARROW_UP.rawValue)
      static let backspace = UInt32(GHOSTTY_KEY_BACKSPACE.rawValue)
      static let delete = UInt32(GHOSTTY_KEY_DELETE.rawValue)
      static let enter = UInt32(GHOSTTY_KEY_ENTER.rawValue)
      static let escape = UInt32(GHOSTTY_KEY_ESCAPE.rawValue)
      static let f1 = UInt32(GHOSTTY_KEY_F1.rawValue)
      static let f2 = UInt32(GHOSTTY_KEY_F2.rawValue)
      static let f5 = UInt32(GHOSTTY_KEY_F5.rawValue)
      static let home = UInt32(GHOSTTY_KEY_HOME.rawValue)
      static let k = UInt32(GHOSTTY_KEY_K.rawValue)
      static let pageDown = UInt32(GHOSTTY_KEY_PAGE_DOWN.rawValue)
      static let pageUp = UInt32(GHOSTTY_KEY_PAGE_UP.rawValue)
      static let tab = UInt32(GHOSTTY_KEY_TAB.rawValue)
    #else
      static let arrowDown: UInt32 = 0
      static let arrowLeft: UInt32 = 0
      static let arrowRight: UInt32 = 0
      static let arrowUp: UInt32 = 0
      static let backspace: UInt32 = 0
      static let delete: UInt32 = 0
      static let enter: UInt32 = 0
      static let escape: UInt32 = 0
      static let f1: UInt32 = 0
      static let f2: UInt32 = 0
      static let f5: UInt32 = 0
      static let home: UInt32 = 0
      static let k: UInt32 = 0
      static let pageDown: UInt32 = 0
      static let pageUp: UInt32 = 0
      static let tab: UInt32 = 0
    #endif
  }

  /// Ghostty modifier raw values used by input-parser oracle tests.
  enum ModRawValue {
    #if canImport(CGhosttyVT)
      static let alt = UInt16(GHOSTTY_MODS_ALT)
      static let capsLock = UInt16(GHOSTTY_MODS_CAPS_LOCK)
      static let control = UInt16(GHOSTTY_MODS_CTRL)
      static let numLock = UInt16(GHOSTTY_MODS_NUM_LOCK)
      static let shift = UInt16(GHOSTTY_MODS_SHIFT)
      static let `super` = UInt16(GHOSTTY_MODS_SUPER)
    #else
      static let alt: UInt16 = 0
      static let capsLock: UInt16 = 0
      static let control: UInt16 = 0
      static let numLock: UInt16 = 0
      static let shift: UInt16 = 0
      static let `super`: UInt16 = 0
    #endif
  }

  /// Kitty keyboard protocol flag raw values from Ghostty.
  enum KittyFlag {
    #if canImport(CGhosttyVT)
      static let all = UInt8(
        GHOSTTY_KITTY_KEY_DISAMBIGUATE | GHOSTTY_KITTY_KEY_REPORT_EVENTS
          | GHOSTTY_KITTY_KEY_REPORT_ALTERNATES | GHOSTTY_KITTY_KEY_REPORT_ALL
          | GHOSTTY_KITTY_KEY_REPORT_ASSOCIATED
      )
      static let tesseraDefault = UInt8(
        GHOSTTY_KITTY_KEY_DISAMBIGUATE | GHOSTTY_KITTY_KEY_REPORT_EVENTS
          | GHOSTTY_KITTY_KEY_REPORT_ALTERNATES
      )
    #else
      static let all: UInt8 = 0
      static let tesseraDefault: UInt8 = 0
    #endif
  }

  /// Whether Ghostty key encoder support is absent from this build.
  static var isUnavailable: Bool {
    #if canImport(CGhosttyVT)
      false
    #else
      true
    #endif
  }

  /// Encodes one Ghostty key event using Kitty keyboard protocol flags.
  static func encode(
    keyRawValue: UInt32,
    action: Action = .press,
    mods: UInt16 = 0,
    utf8: String? = nil,
    unshiftedCodepoint: UInt32 = 0,
    kittyFlags: UInt8
  ) throws -> [UInt8] {
    #if canImport(CGhosttyVT)
      var encoder: CGhosttyVT.GhosttyKeyEncoder?
      try ghosttyCheck(ghostty_key_encoder_new(nil, &encoder), "ghostty_key_encoder_new")
      defer { ghostty_key_encoder_free(encoder) }

      var flags = GhosttyKittyKeyFlags(kittyFlags)
      ghostty_key_encoder_setopt(
        encoder,
        GHOSTTY_KEY_ENCODER_OPT_KITTY_FLAGS,
        &flags
      )

      var event: GhosttyKeyEvent?
      try ghosttyCheck(ghostty_key_event_new(nil, &event), "ghostty_key_event_new")
      defer { ghostty_key_event_free(event) }

      ghostty_key_event_set_key(event, GhosttyKey(rawValue: numericCast(keyRawValue)))
      ghostty_key_event_set_action(event, action.ghosttyAction)
      ghostty_key_event_set_mods(event, GhosttyMods(mods))
      ghostty_key_event_set_unshifted_codepoint(event, unshiftedCodepoint)
      if let utf8 {
        utf8.withCString { pointer in
          ghostty_key_event_set_utf8(event, pointer, utf8.utf8.count)
        }
      }

      var bytes = [CChar](repeating: 0, count: 128)
      var written = 0
      let result = ghostty_key_encoder_encode(
        encoder,
        event,
        &bytes,
        bytes.count,
        &written
      )
      if result == GHOSTTY_OUT_OF_SPACE {
        bytes = [CChar](repeating: 0, count: written)
        try ghosttyCheck(
          ghostty_key_encoder_encode(encoder, event, &bytes, bytes.count, &written),
          "ghostty_key_encoder_encode"
        )
      } else {
        try ghosttyCheck(result, "ghostty_key_encoder_encode")
      }
      return bytes.prefix(written).map { UInt8(bitPattern: $0) }
    #else
      throw GhosttyKittyKeyEncoderError.unavailable
    #endif
  }
}

enum GhosttyKittyKeyEncoderError: Error, Equatable, Sendable {
  case operationFailed(String, Int32)
  case unavailable
}

#if canImport(CGhosttyVT)

  extension GhosttyKittyKeyEncoder.Action {
    fileprivate var ghosttyAction: GhosttyKeyAction {
      switch self {
      case .press:
        GHOSTTY_KEY_ACTION_PRESS
      case .repeat:
        GHOSTTY_KEY_ACTION_REPEAT
      case .release:
        GHOSTTY_KEY_ACTION_RELEASE
      }
    }
  }

  private func ghosttyCheck(_ result: GhosttyResult, _ operation: String) throws {
    guard result == GHOSTTY_SUCCESS else {
      throw GhosttyKittyKeyEncoderError.operationFailed(operation, Int32(result.rawValue))
    }
  }

#endif
