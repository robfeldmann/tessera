import Tessera

/// Playwright-style key names (`Enter`, `ArrowLeft`, `Shift+Tab`, `Ctrl+C`, `Meta+k`).
enum KeyName {
  struct Failure: Error {
    var message: String
  }

  static let named: [String: KeyCode] = [
    "ArrowDown": .down,
    "ArrowLeft": .left,
    "ArrowRight": .right,
    "ArrowUp": .up,
    "Backspace": .backspace,
    "Delete": .delete,
    "End": .end,
    "Enter": .enter,
    "Escape": .escape,
    "Home": .home,
    "PageDown": .pageDown,
    "PageUp": .pageUp,
    "Space": .character(" "),
    "Tab": .tab,
  ]

  static let modifiers: [String: Modifiers] = [
    "Alt": .alt,
    "Control": .control,
    "Ctrl": .control,
    "Meta": .meta,
    "Shift": .shift,
    "Super": .super,
  ]

  static var accepted: String {
    let names = named.keys.sorted() + (1...12).map { "F\($0)" }
    return
      "\(names.joined(separator: ", ")), a single character; "
      + "modifiers: \(modifiers.keys.sorted().joined(separator: ", ")) joined with `+`"
  }

  static func parse(_ token: String) throws -> Key {
    var rest = Substring(token)
    var active: Modifiers = []
    while let plus = rest.firstIndex(of: "+"), plus != rest.startIndex,
      rest.index(after: plus) != rest.endIndex,
      let modifier = modifiers[String(rest[..<plus])]
    {
      active.insert(modifier)
      rest = rest[rest.index(after: plus)...]
    }

    let name = String(rest)
    if let code = named[name] {
      return Key(code: code, modifiers: active)
    }
    if name.hasPrefix("F"), let number = Int(name.dropFirst()), (1...12).contains(number) {
      return Key(code: .function(number), modifiers: active)
    }
    if name.count == 1, let character = name.first {
      // Terminals report Ctrl/Alt/Meta chords with the unshifted base letter.
      let isChord = !active.isDisjoint(with: [.control, .alt, .meta, .super])
      let code: Character =
        isChord && character.isASCII && character.isLetter
        ? Character(character.lowercased()) : character
      return Key(code: .character(code), modifiers: active)
    }
    throw Failure(message: "unknown key `\(token)`; accepted: \(accepted)")
  }

  /// A stable, human-readable rendering used by the demo's status line.
  static func describe(_ key: Key) -> String {
    var parts: [String] = []
    for (name, flag) in [
      ("Ctrl", Modifiers.control), ("Alt", .alt), ("Meta", .meta), ("Shift", .shift),
    ] where key.modifiers.contains(flag) {
      parts.append(name)
    }
    switch key.code {
    case .character(let character):
      parts.append(character == " " ? "Space" : String(character))
    case .tab: parts.append("Tab")
    case .enter: parts.append("Enter")
    case .escape: parts.append("Escape")
    case .backspace: parts.append("Backspace")
    case .delete: parts.append("Delete")
    case .up: parts.append("ArrowUp")
    case .down: parts.append("ArrowDown")
    case .left: parts.append("ArrowLeft")
    case .right: parts.append("ArrowRight")
    case .home: parts.append("Home")
    case .end: parts.append("End")
    case .pageUp: parts.append("PageUp")
    case .pageDown: parts.append("PageDown")
    case .function(let number): parts.append("F\(number)")
    default: parts.append("?")
    }
    return parts.joined(separator: "+")
  }
}
