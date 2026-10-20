import Foundation
import TesseraTerminalCore
import TesseraTerminalInput

/// A terminal size request from a `size` or `resize` statement.
public enum Viewport: Equatable, Sendable {
  /// 40 columns by 16 rows, for screen-filling demos.
  case mobileScreen

  /// 80x24.
  case desktop

  /// 40 columns at the natural height the driver measures.
  case mobile

  /// An explicit size.
  case custom(columns: Int, rows: Int)
}

/// A rectangle written as `x,y,wxh` in `expect node … frame`.
public struct FrameExpectation: Equatable, Sendable {
  public var column: Int
  public var row: Int
  public var columns: Int
  public var rows: Int

  var description: String {
    "\(column),\(row),\(columns)x\(rows)"
  }
}

/// One executable scenario statement.
public enum Statement: Equatable, Sendable {
  case expectNode(Locator, FrameExpectation)
  case expectText(row: Int?, text: String)
  case key(Key)
  case resize(columns: Int, rows: Int)
  case shot(name: String)
  case tree
  case type(String)

  /// The verb as it appears in reports.
  public var verb: String {
    switch self {
    case .expectNode: "expect node"
    case .expectText: "expect text"
    case .key: "key"
    case .resize: "resize"
    case .shot: "shot"
    case .tree: "tree"
    case .type: "type"
    }
  }
}

/// A statement with its source position.
public struct ScenarioLine: Equatable, Sendable {
  public var number: Int
  public var source: String
  public var statement: Statement
}

/// A parsed scenario: a header followed by an ordered list of statements.
public struct Scenario: Equatable, Sendable {
  /// The registered app name; defaults to ``DemoRegistry/defaultName``.
  public var app: String
  public var viewport: Viewport
  public var lines: [ScenarioLine]
}

/// A fail-fast parse error that renders as `FILE:LINE: error: message`.
public struct ScenarioParseError: Error, Equatable, Sendable, CustomStringConvertible {
  public var file: String
  public var line: Int
  public var message: String

  public var description: String {
    "\(file):\(line): error: \(message)"
  }
}

/// Parses the v0 scenario grammar.
///
/// ```text
/// # header (before the first body statement)
/// app NAME                    size WxH | desktop | mobile | mobileScreen
/// # world and input
/// resize WxH                  key Tab | key Shift+Tab | key Ctrl+C     type "hi"
/// # observation
/// shot NAME                   tree
/// # expectation
/// expect text ["ROW"] "…"     expect node SEL frame X,Y,WxH
/// ```
public enum ScenarioParser {
  /// Verbs the plan reserves for later phases; named so the error is specific.
  static let deferredVerbs: Set<String> = [
    "bytes", "check", "dump", "focus", "mouse", "paste", "wait",
  ]

  static let acceptedVerbs =
    "app, size, resize, key, type, shot, tree, expect text, expect node"

  public static func parse(
    _ source: String,
    file: String,
    knownApps: [String] = DemoRegistry.names
  ) throws -> Scenario {
    var app = DemoRegistry.defaultName
    var viewport = Viewport.desktop
    var lines: [ScenarioLine] = []
    var shotNames: Set<String> = []
    var sawApp = false
    var sawSize = false

    let rawLines = source.split(separator: "\n", omittingEmptySubsequences: false)
    for (offset, rawLine) in rawLines.enumerated() {
      let number = offset + 1
      func fail(_ message: String) -> ScenarioParseError {
        ScenarioParseError(file: file, line: number, message: message)
      }

      let tokens: [String]
      do {
        tokens = try Tokenizer.tokens(in: String(rawLine))
      } catch let error as Tokenizer.Failure {
        throw fail(error.message)
      }
      guard let verb = tokens.first else {
        continue
      }
      let arguments = Array(tokens.dropFirst())
      let text = String(rawLine).trimmingCharacters(in: .whitespaces)

      switch verb {
      case "app":
        guard lines.isEmpty else {
          throw fail("`app` is a header statement and must precede the first body statement")
        }
        guard !sawApp else { throw fail("duplicate `app` header") }
        guard arguments.count == 1 else { throw fail("usage: app NAME") }
        guard knownApps.contains(arguments[0]) else {
          throw fail(
            "unknown app `\(arguments[0])`; accepted: \(knownApps.joined(separator: ", "))")
        }
        sawApp = true
        app = arguments[0]

      case "size":
        guard lines.isEmpty else {
          throw fail("`size` is a header statement; use `resize WxH` after the first body statement")
        }
        guard !sawSize else { throw fail("duplicate `size` header") }
        guard arguments.count == 1 else {
          throw fail("usage: size WxH | desktop | mobile | mobileScreen")
        }
        sawSize = true
        switch arguments[0] {
        case "desktop": viewport = .desktop
        case "mobile": viewport = .mobile
        case "mobileScreen": viewport = .mobileScreen
        default:
          guard let (columns, rows) = parseDimensions(arguments[0]) else {
            throw fail(
              "bad size `\(arguments[0])`; expected WxH, desktop, mobile, or mobileScreen")
          }
          viewport = .custom(columns: columns, rows: rows)
        }

      case "resize":
        guard arguments.count == 1, let (columns, rows) = parseDimensions(arguments[0]) else {
          throw fail("usage: resize WxH (both at least 1)")
        }
        lines.append(
          ScenarioLine(
            number: number, source: text, statement: .resize(columns: columns, rows: rows)))

      case "key":
        guard arguments.count == 1 else { throw fail("usage: key NAME (e.g. key Shift+Tab)") }
        do {
          let key = try KeyName.parse(arguments[0])
          lines.append(ScenarioLine(number: number, source: text, statement: .key(key)))
        } catch let error as KeyName.Failure {
          throw fail(error.message)
        }

      case "type":
        guard arguments.count == 1 else { throw fail("usage: type \"text\"") }
        lines.append(ScenarioLine(number: number, source: text, statement: .type(arguments[0])))

      case "shot":
        guard arguments.count == 1, isShotName(arguments[0]) else {
          throw fail("usage: shot NAME (letters, digits, `.`, `_`, `-`)")
        }
        guard shotNames.insert(arguments[0]).inserted else {
          throw fail("duplicate shot name `\(arguments[0])`")
        }
        lines.append(
          ScenarioLine(number: number, source: text, statement: .shot(name: arguments[0])))

      case "tree":
        guard arguments.isEmpty else {
          throw fail("`tree` takes no selector in v0")
        }
        lines.append(ScenarioLine(number: number, source: text, statement: .tree))

      case "expect":
        let statement = try parseExpect(arguments, fail: fail)
        lines.append(ScenarioLine(number: number, source: text, statement: statement))

      default:
        if deferredVerbs.contains(verb) {
          throw fail("`\(verb)` is not yet expressible in v0; accepted: \(acceptedVerbs)")
        }
        throw fail("unknown statement `\(verb)`; accepted: \(acceptedVerbs)")
      }
    }

    return Scenario(app: app, viewport: viewport, lines: lines)
  }

  private static func parseExpect(
    _ arguments: [String],
    fail: (String) -> ScenarioParseError
  ) throws -> Statement {
    guard let kind = arguments.first else {
      throw fail("usage: expect text … | expect node SEL frame X,Y,WxH")
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
      guard let frameIndex = rest.firstIndex(of: "frame") else {
        throw fail("expect node needs `frame X,Y,WxH`; visible|clipped|count are not yet expressible")
      }
      let selectorTokens = Array(rest[..<frameIndex])
      let frameTokens = Array(rest[(frameIndex + 1)...])
      guard !selectorTokens.isEmpty else {
        throw fail("expect node needs a locator (type= id= text= nth=)")
      }
      let locator: Locator
      do {
        locator = try Locator.parse(selectorTokens)
      } catch let error as Locator.Failure {
        throw fail(error.message)
      }
      guard let frame = parseFrame(frameTokens) else {
        throw fail("bad frame; expected `X,Y,WxH` or `X,Y WxH`")
      }
      return .expectNode(locator, frame)

    default:
      throw fail("unknown expectation `\(kind)`; accepted: text, node")
    }
  }

  static func parseDimensions(_ token: String) -> (Int, Int)? {
    let parts = token.split(separator: "x", omittingEmptySubsequences: false)
    guard parts.count == 2, let columns = Int(parts[0]), let rows = Int(parts[1]),
      columns >= 1, rows >= 1
    else {
      return nil
    }
    return (columns, rows)
  }

  /// Accepts `X,Y,WxH` (one token) or the plan's `X,Y WxH` (two tokens).
  static func parseFrame(_ tokens: [String]) -> FrameExpectation? {
    let joined = tokens.joined(separator: ",")
    let parts = joined.split(separator: ",", omittingEmptySubsequences: false)
    guard parts.count == 3,
      let column = Int(parts[0]), let row = Int(parts[1]),
      let size = parseDimensionsAllowingZero(String(parts[2]))
    else {
      return nil
    }
    return FrameExpectation(
      column: column, row: row, columns: size.0, rows: size.1)
  }

  private static func parseDimensionsAllowingZero(_ token: String) -> (Int, Int)? {
    let parts = token.split(separator: "x", omittingEmptySubsequences: false)
    guard parts.count == 2, let columns = Int(parts[0]), let rows = Int(parts[1]),
      columns >= 0, rows >= 0
    else {
      return nil
    }
    return (columns, rows)
  }

  private static func isShotName(_ name: String) -> Bool {
    !name.isEmpty
      && name.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || "._-".contains($0)) }
  }
}

/// Shell-style tokenizer: whitespace separated, `"…"` with escapes, `'…'` literal,
/// `#` starts a comment at a token boundary.
enum Tokenizer {
  struct Failure: Error {
    var message: String
  }

  static func tokens(in line: String) throws -> [String] {
    var tokens: [String] = []
    var current = ""
    var inToken = false
    var iterator = line.makeIterator()
    var pending = iterator.next()

    func flush() {
      if inToken {
        tokens.append(current)
        current = ""
        inToken = false
      }
    }

    while let character = pending {
      pending = iterator.next()
      switch character {
      case " ", "\t", "\r":
        flush()
      case "#" where !inToken:
        pending = nil
      case "\"":
        inToken = true
        var closed = false
        while let next = pending {
          pending = iterator.next()
          if next == "\"" {
            closed = true
            break
          }
          if next == "\\" {
            guard let escaped = pending else {
              throw Failure(message: "dangling backslash in quoted string")
            }
            pending = iterator.next()
            switch escaped {
            case "n": current.append("\n")
            case "t": current.append("\t")
            case "\"", "\\": current.append(escaped)
            default:
              throw Failure(
                message: "unknown escape `\\\(escaped)`; accepted: \\n \\t \\\" \\\\")
            }
          } else {
            current.append(next)
          }
        }
        guard closed else { throw Failure(message: "unterminated double quote") }
      case "'":
        inToken = true
        var closed = false
        while let next = pending {
          pending = iterator.next()
          if next == "'" {
            closed = true
            break
          }
          current.append(next)
        }
        guard closed else { throw Failure(message: "unterminated single quote") }
      default:
        inToken = true
        current.append(character)
      }
    }
    flush()
    return tokens
  }
}
