/// Answers the queries a session writes to its terminal, as a terminal with a known colour
/// scheme would.
///
/// A session asks for the terminal's colours with OSC 10 (foreground), OSC 11 (background),
/// and OSC 4 (palette slots), ending the round with one DA1. The answerer replies to each
/// colour query with the profile's fixed colours, echoing the query's terminator, and to
/// DA1 last, so a round ends at once instead of at its timeout. With no theme it answers DA1
/// only, as a terminal that cannot report colours does. Every other byte, a frame's among
/// them, is ignored.
///
/// A query is recognised when it is whole within one write, which is how a session emits it.
struct TerminalAnswerer: Sendable {
  private static let bell: UInt8 = 0x07
  private static let escape: UInt8 = 0x1B

  /// The scheme to report, or `nil` for a terminal whose colours are unknown.
  var theme: TerminalTheme?

  /// `rgb:RRRR/GGGG/BBBB`, each channel as 16 bits, as xterm reports it.
  private static func report(_ color: TerminalTheme.RGB) -> String {
    func channel(_ value: UInt8) -> String {
      let hex = String(Int(value) * 0x101, radix: 16)
      return String(repeating: "0", count: 4 - hex.count) + hex
    }
    return "rgb:\(channel(color.red))/\(channel(color.green))/\(channel(color.blue))"
  }

  /// The bytes a terminal would send back for the queries in `written`, in query order.
  func replies(to written: ArraySlice<UInt8>) -> [UInt8] {
    var replies: [UInt8] = []
    var index = written.startIndex
    while index < written.endIndex {
      guard written[index] == Self.escape, index + 1 < written.endIndex else {
        index += 1
        continue
      }
      switch written[index + 1] {
      case UInt8(ascii: "]"):
        guard let end = oscEnd(in: written, from: index + 2) else {
          return replies
        }
        replies += answer(
          osc: written[(index + 2)..<end.bodyEnd], terminator: end.terminator)
        index = end.next
      case UInt8(ascii: "["):
        guard let final = csiFinal(in: written, from: index + 2) else {
          return replies
        }
        if written[final] == UInt8(ascii: "c"),
          isPrimaryDeviceAttributesQuery(written[(index + 2)..<final])
        {
          replies += Array("\u{1B}[?62;22c".utf8)
        }
        index = final + 1
      default:
        index += 1
      }
    }
    return replies
  }

  /// Where an OSC sequence that starts at `start` ends: its body, its terminator (BEL or
  /// `ESC \`), and the index after it.
  private func oscEnd(in bytes: ArraySlice<UInt8>, from start: Int)
    -> (bodyEnd: Int, terminator: [UInt8], next: Int)?
  {
    var index = start
    while index < bytes.endIndex {
      if bytes[index] == Self.bell {
        return (index, [Self.bell], index + 1)
      }
      if bytes[index] == Self.escape {
        guard index + 1 < bytes.endIndex else {
          return nil
        }
        if bytes[index + 1] == UInt8(ascii: "\\") {
          return (index, [Self.escape, UInt8(ascii: "\\")], index + 2)
        }
        return nil
      }
      index += 1
    }
    return nil
  }

  /// The index of the final byte of a CSI sequence whose parameters start at `start`.
  private func csiFinal(in bytes: ArraySlice<UInt8>, from start: Int) -> Int? {
    var index = start
    while index < bytes.endIndex {
      let byte = bytes[index]
      if (0x40...0x7E).contains(byte) {
        return index
      }
      guard (0x20...0x3F).contains(byte) else {
        return nil
      }
      index += 1
    }
    return nil
  }

  /// `CSI c` and `CSI 0 c` ask for the primary device attributes.
  private func isPrimaryDeviceAttributesQuery(_ parameters: ArraySlice<UInt8>) -> Bool {
    parameters.isEmpty || parameters.elementsEqual([UInt8(ascii: "0")])
  }

  private func answer(osc body: ArraySlice<UInt8>, terminator: [UInt8]) -> [UInt8] {
    guard let theme, let text = String(validating: body, as: UTF8.self) else {
      return []
    }
    let parts = text.split(separator: ";", omittingEmptySubsequences: false)
    guard let selector = parts.first else {
      return []
    }
    var replies: [UInt8] = []
    func reply(_ prefix: String, _ color: TerminalTheme.RGB) {
      replies += Array("\u{1B}]\(prefix);\(Self.report(color))".utf8) + terminator
    }
    switch selector {
    case "10" where parts.count == 2 && parts[1] == "?":
      reply("10", theme.foreground)
    case "11" where parts.count == 2 && parts[1] == "?":
      reply("11", theme.background)
    case "4":
      var pairs = parts.dropFirst()
      while pairs.count >= 2 {
        let slot = pairs.removeFirst()
        let query = pairs.removeFirst()
        if query == "?", let number = Int(slot),
          TerminalTheme.palette.indices.contains(number)
        {
          reply("4;\(number)", TerminalTheme.palette[number])
        }
      }
    default:
      break
    }
    return replies
  }
}
