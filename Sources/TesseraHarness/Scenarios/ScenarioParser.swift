import Foundation
import TesseraTerminalCore
import TesseraTerminalInput

/// Parses the scenario grammar in `Examples/Scenarios/README.md`.
///
/// The parser is header-binding and fail-fast: `app`, `size`, and `term` must precede the
/// first body statement, and the first line it cannot accept ends the parse with a
/// ``ScenarioParseError``. An unknown statement is an error, so a scenario written for a
/// newer harness fails loudly on an older one instead of running with a statement ignored.
/// Lines end at `\n`, and a `\r` before it is whitespace, so a CRLF checkout parses as an LF
/// one does.
package enum ScenarioParser {
  package static func parse(
    _ source: String,
    file: String,
    knownApps: [String]
  ) throws -> Scenario {
    var parse = Parse(file: file, knownApps: knownApps, lines: sourceLines(of: source))
    return try parse.run()
  }

  /// The lines of `source`, split at `\n` alone: Swift reads `"\r\n"` as one character, so
  /// splitting on characters would not see a CRLF line end.
  static func sourceLines(of source: String) -> [String] {
    source.unicodeScalars.split(
      separator: "\n", omittingEmptySubsequences: false
    ).map { String($0) }
  }

  static func parseDimensions(_ token: String, allowingZero: Bool = false) -> (Int, Int)?
  {
    let parts = token.split(separator: "x", omittingEmptySubsequences: false)
    let minimum = allowingZero ? 0 : 1
    guard parts.count == 2, let columns = Int(parts[0]), let rows = Int(parts[1]),
      columns >= minimum, rows >= minimum
    else {
      return nil
    }
    return (columns, rows)
  }

  /// The viewport a `size` header or a command's size argument spells, or `nil`.
  static func viewport(spelled token: String) -> Viewport? {
    switch token {
    case "desktop": .desktop
    case "mobile": .mobile
    case "mobileScreen": .mobileScreen
    default:
      parseDimensions(token).map { .custom(TerminalSize(columns: $0.0, rows: $0.1)) }
    }
  }

  /// Accepts `X,Y,WxH` (one token) or `X,Y WxH` (two tokens).
  static func parseFrame(_ tokens: [String]) -> FrameExpectation? {
    let parts = tokens.joined(separator: ",").split(
      separator: ",", omittingEmptySubsequences: false)
    guard parts.count == 3,
      let column = Int(parts[0]), let row = Int(parts[1]),
      let size = parseDimensions(String(parts[2]), allowingZero: true)
    else {
      return nil
    }
    return FrameExpectation(column: column, row: row, columns: size.0, rows: size.1)
  }

  static func isShotName(_ name: String) -> Bool {
    !name.isEmpty
      && name.allSatisfy {
        $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0))
      }
  }
}

/// One parse in progress: the header as it binds, then the body.
private struct Parse {
  let file: String
  let knownApps: [String]
  let rawLines: [String]

  private var app: String?
  private var appLine: SourceLine?
  private var viewport = Viewport.desktop
  private var sizeLine: SourceLine?
  private var sawTerm = false
  private var profile = TerminalProfile()
  private var body: [ScenarioLine] = []
  private var shotNames: Set<String> = []

  init(file: String, knownApps: [String], lines: [String]) {
    self.file = file
    self.knownApps = knownApps
    rawLines = lines
  }

  mutating func run() throws -> Scenario {
    var offset = 0
    while offset < rawLines.count {
      offset += try parseLine(at: offset)
    }
    guard let app, let appLine else {
      throw ScenarioParseError(
        file: file, line: 1,
        message:
          "a scenario names its app with an `app NAME` header; accepted: "
          + knownApps.joined(separator: ", ")
      )
    }
    return Scenario(
      app: app, appLine: appLine, viewport: viewport, sizeLine: sizeLine,
      terminal: profile, lines: body)
  }

  /// Parses the statement at `offset` and returns how many lines it used.
  private mutating func parseLine(at offset: Int) throws -> Int {
    let number = offset + 1
    let raw = rawLines[offset]
    let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    let file = file
    func fail(_ message: String) -> ScenarioParseError {
      ScenarioParseError(file: file, line: number, source: text, message: message)
    }

    let tokens: [String]
    do {
      tokens = try Tokenizer.tokens(in: raw)
    } catch let error as Tokenizer.Failure {
      throw fail(error.message)
    }
    guard let verb = tokens.first else {
      return 1
    }
    let arguments = Array(tokens.dropFirst())
    let source = SourceLine(number: number, text: text)

    switch verb {
    case "app", "size", "term":
      try parseHeader(verb, arguments, source: source, fail: fail)
    case "expect" where arguments.first == "screen":
      return try parseExpectScreen(arguments, at: offset, fail: fail)
    default:
      let statement = try parseBody(verb, arguments, fail: fail)
      body.append(ScenarioLine(number: number, source: text, statement: statement))
    }
    return 1
  }

  // MARK: Header

  private mutating func parseHeader(
    _ verb: String,
    _ arguments: [String],
    source: SourceLine,
    fail: (String) -> ScenarioParseError
  ) throws {
    guard body.isEmpty else {
      throw fail(
        verb == "size"
          ? "`size` is a header statement; use `resize WxH` after the first body statement"
          : "`\(verb)` is a header statement and must precede the first body statement")
    }
    switch verb {
    case "app":
      guard app == nil else { throw fail("duplicate `app` header") }
      guard arguments.count == 1 else { throw fail("usage: app NAME") }
      guard knownApps.contains(arguments[0]) else {
        throw fail(
          "unknown app `\(arguments[0])`; accepted: \(knownApps.joined(separator: ", "))")
      }
      app = arguments[0]
      appLine = source

    case "size":
      guard sizeLine == nil else { throw fail("duplicate `size` header") }
      guard arguments.count == 1 else {
        throw fail("usage: size WxH | desktop | mobile | mobileScreen")
      }
      guard let spelled = ScenarioParser.viewport(spelled: arguments[0]) else {
        throw fail(
          "bad size `\(arguments[0])`; expected WxH, desktop, mobile, or mobileScreen")
      }
      sizeLine = source
      viewport = spelled

    default:
      guard !sawTerm else { throw fail("duplicate `term` header") }
      sawTerm = true
      profile = try parseTerm(arguments, fail: fail)
    }
  }

  private func parseTerm(
    _ options: [String], fail: (String) -> ScenarioParseError
  ) throws -> TerminalProfile {
    var profile = TerminalProfile()
    var seen: Set<String> = []
    for option in options {
      guard let equals = option.firstIndex(of: "=") else {
        throw fail(
          "term option `\(option)` is not key=value; accepted keys: colors, theme")
      }
      let key = String(option[..<equals])
      let value = String(option[option.index(after: equals)...])
      guard seen.insert(key).inserted else {
        throw fail("duplicate `term` option `\(key)`")
      }
      switch (key, value) {
      case ("colors", _):
        guard let colors = TerminalColors(rawValue: value) else {
          throw fail(
            "bad colors `\(value)`; expected \(TerminalColors.spellings.joined(separator: ", "))"
          )
        }
        profile.colors = colors
      case ("theme", "probe"):
        throw fail(ScenarioGrammar.refusal("term theme=probe"))
      case ("theme", _):
        guard let theme = TerminalTheme(rawValue: value) else {
          throw fail(
            "bad theme `\(value)`; expected \(TerminalTheme.spellings.joined(separator: ", "))"
          )
        }
        profile.theme = theme
      case ("glyphs", _):
        throw fail(ScenarioGrammar.refusal("term glyphs="))
      case ("keyboard", _):
        throw fail(ScenarioGrammar.refusal("term keyboard="))
      default:
        throw fail("unknown term option `\(key)`; accepted keys: colors, theme")
      }
    }
    return profile
  }

  // MARK: Body

  private mutating func parseBody(
    _ verb: String,
    _ arguments: [String],
    fail: (String) -> ScenarioParseError
  ) throws -> Statement {
    switch verb {
    case "resize":
      guard arguments.count == 1,
        let (columns, rows) = ScenarioParser.parseDimensions(arguments[0])
      else {
        throw fail("usage: resize WxH (both at least 1)")
      }
      return .resize(columns: columns, rows: rows)

    case "key":
      guard arguments.count == 1 else {
        throw fail("usage: key NAME (e.g. key Shift+Tab)")
      }
      do {
        return .key(try KeyName.parse(arguments[0]))
      } catch let error as KeyName.Failure {
        throw fail(error.message)
      }

    case "type":
      guard arguments.count == 1 else { throw fail("usage: type \"text\"") }
      return .type(arguments[0])

    case "paste":
      guard arguments.count == 1 else { throw fail("usage: paste \"text\"") }
      return .paste(arguments[0])

    case "bytes":
      guard arguments.count == 1 else { throw fail(#"usage: bytes "\x1b[A""#) }
      return .bytes(Array(arguments[0].utf8))

    case "shot":
      guard arguments.count <= 1 else {
        throw fail(ScenarioGrammar.refusal("shot NAME SEL"))
      }
      guard arguments.count == 1, ScenarioParser.isShotName(arguments[0]) else {
        throw fail("usage: shot NAME (letters, digits, `.`, `_`, `-`)")
      }
      guard shotNames.insert(arguments[0]).inserted else {
        throw fail("duplicate shot name `\(arguments[0])`")
      }
      return .shot(name: arguments[0])

    case "tree":
      guard arguments.isEmpty else {
        throw fail(ScenarioGrammar.refusal("tree SEL"))
      }
      return .tree

    case "expect":
      return try parseExpect(arguments, fail: fail)

    default:
      if ScenarioGrammar.notYetExpressible.contains(where: { $0.form == verb }) {
        throw fail(ScenarioGrammar.refusal(verb))
      }
      throw fail(
        "unknown statement `\(verb)`; accepted: \(ScenarioGrammar.acceptedStatements)")
    }
  }

  private func parseExpect(
    _ arguments: [String],
    fail: (String) -> ScenarioParseError
  ) throws -> Statement {
    guard let kind = arguments.first else {
      throw fail(
        "usage: expect text … | expect screen <<EOF | expect node SEL frame X,Y,WxH")
    }
    let rest = Array(arguments.dropFirst())
    switch kind {
    case "text":
      switch rest.count {
      case 1:
        return .expectText(row: nil, text: rest[0])
      case 2:
        guard let row = Int(rest[0]), row >= 0 else {
          throw fail("expect text ROW must be a non-negative integer, got `\(rest[0])`")
        }
        return .expectText(row: row, text: rest[1])
      default:
        throw fail("usage: expect text [ROW] \"…\"")
      }

    case "node":
      return try parseExpectNode(rest, fail: fail)

    default:
      if ScenarioGrammar.notYetExpressible.contains(where: { $0.form == "expect \(kind)" }
      ) {
        throw fail(ScenarioGrammar.refusal("expect \(kind)"))
      }
      throw fail("unknown expectation `\(kind)`; accepted: text, screen, node")
    }
  }

  private func parseExpectNode(
    _ rest: [String],
    fail: (String) -> ScenarioParseError
  ) throws -> Statement {
    guard let frameIndex = rest.firstIndex(of: "frame") else {
      for kind in ["visible", "clipped", "count"] where rest.contains(kind) {
        throw fail(
          ScenarioGrammar.refusal(
            "expect node SEL \(kind)\(kind == "count" ? " N" : "")"))
      }
      throw fail("expect node needs `frame X,Y,WxH`")
    }
    let selectorTokens = Array(rest[..<frameIndex])
    let frameTokens = Array(rest[(frameIndex + 1)...])
    guard !selectorTokens.isEmpty else {
      throw fail("expect node needs a locator (\(Locator.accepted))")
    }
    let locator: Locator
    do {
      locator = try Locator.parse(selectorTokens)
    } catch let error as Locator.Failure {
      throw fail(error.message)
    }
    guard let frame = ScenarioParser.parseFrame(frameTokens) else {
      throw fail("bad frame; expected `X,Y,WxH` or `X,Y WxH`")
    }
    return .expectNode(locator, frame)
  }

  /// `expect screen <<WORD`, the rows up to a line that is exactly `WORD`, and no more.
  private mutating func parseExpectScreen(
    _ arguments: [String],
    at offset: Int,
    fail: (String) -> ScenarioParseError
  ) throws -> Int {
    guard arguments.count == 2, arguments[1].hasPrefix("<<"), arguments[1].count > 2
    else {
      throw fail(
        "usage: expect screen <<EOF, then the rows, then a line holding only EOF")
    }
    let delimiter = String(arguments[1].dropFirst(2))
    guard
      delimiter.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_") })
    else {
      throw fail(
        "the delimiter after `<<` is letters, digits, and `_`, got `\(delimiter)`")
    }
    var rows: [String] = []
    var cursor = offset + 1
    while cursor < rawLines.count {
      var row = rawLines[cursor]
      if row.hasSuffix("\r") {
        row.removeLast()
      }
      if row == delimiter {
        let text = rawLines[offset].trimmingCharacters(in: .whitespacesAndNewlines)
        body.append(
          ScenarioLine(
            number: offset + 1, source: text, statement: .expectScreen(rows: rows)))
        return cursor - offset + 1
      }
      rows.append(row)
      cursor += 1
    }
    throw fail("`expect screen` is missing its closing `\(delimiter)` line")
  }
}
