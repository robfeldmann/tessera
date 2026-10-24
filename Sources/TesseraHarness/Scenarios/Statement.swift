import TesseraTerminalCore
import TesseraTerminalInput

/// A rectangle written as `x,y,wxh` in `expect node … frame`.
package struct FrameExpectation: CustomStringConvertible, Equatable, Sendable {
  package var column: Int
  package var row: Int
  package var columns: Int
  package var rows: Int

  package var description: String {
    "\(column),\(row),\(columns)x\(rows)"
  }
}

/// One bound of an `expect cost` statement: `bodies<=5`.
package struct CostBound: CustomStringConvertible, Equatable, Sendable {
  /// The counter, one of ``StepCost/names``.
  package var counter: String

  /// The most the counter may be.
  package var limit: Int

  package var description: String {
    "\(counter)<=\(limit)"
  }
}

/// One executable scenario statement.
package enum Statement: Equatable, Sendable {
  case bytes([UInt8])

  /// `check [RULE...]`; an empty list runs every rule.
  case check(rules: [CheckRule])
  case dump
  case expectCost([CostBound])
  case expectNode(Locator, FrameExpectation)
  case expectScreen(rows: [String])
  case expectText(row: Int?, text: String)
  case key(Key)
  case paste(String)
  case resize(columns: Int, rows: Int)
  case shot(name: String)
  case tree
  case type(String)

  /// The verb as it appears in reports.
  package var verb: String {
    switch self {
    case .bytes: "bytes"
    case .check: "check"
    case .dump: "dump"
    case .expectCost: "expect cost"
    case .expectNode: "expect node"
    case .expectScreen: "expect screen"
    case .expectText: "expect text"
    case .key: "key"
    case .paste: "paste"
    case .resize: "resize"
    case .shot: "shot"
    case .tree: "tree"
    case .type: "type"
    }
  }
}

/// A line of a scenario file: its number (from 1) and its text, without the line ending.
package struct SourceLine: Equatable, Sendable {
  package var number: Int
  package var text: String
}

/// A statement with its source position.
package struct ScenarioLine: Equatable, Sendable {
  package var number: Int
  package var source: String
  package var statement: Statement
}

/// A parsed scenario: a header followed by an ordered list of statements.
package struct Scenario: Equatable, Sendable {
  /// The registered app name, from the `app NAME` header.
  package var app: String

  /// The `app` header's line, where a failure to set the app up is reported.
  package var appLine: SourceLine

  /// The size the app starts at, from the `size` header.
  package var viewport: Viewport

  /// The `size` header's line, if there is one; a size the app cannot take is reported there.
  package var sizeLine: SourceLine?

  /// The terminal the app runs on, from the `term` header.
  package var terminal: TerminalProfile

  /// The body, in order.
  package var lines: [ScenarioLine]

  package init(
    app: String,
    appLine: SourceLine = SourceLine(number: 1, text: ""),
    viewport: Viewport = .desktop,
    sizeLine: SourceLine? = nil,
    terminal: TerminalProfile = TerminalProfile(),
    lines: [ScenarioLine] = []
  ) {
    self.app = app
    self.appLine = appLine
    self.viewport = viewport
    self.sizeLine = sizeLine
    self.terminal = terminal
    self.lines = lines
  }
}

/// A fail-fast parse error that renders as `FILE:LINE: error: message`.
package struct ScenarioParseError: CustomStringConvertible, Equatable, Error, Sendable {
  package var file: String
  package var line: Int

  /// The offending line's text, empty when the error is about the file as a whole.
  package var source: String
  package var message: String

  package var description: String {
    "\(file):\(line): error: \(message)"
  }

  package init(file: String, line: Int, source: String = "", message: String) {
    self.file = file
    self.line = line
    self.source = source
    self.message = message
  }
}
