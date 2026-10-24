import TesseraTerminal
import TesseraTerminalCore
import Testing

@testable import TesseraHarness

private func bytes(_ text: String) -> ArraySlice<UInt8> {
  ArraySlice(text.utf8)
}

private func text(_ bytes: [UInt8]) -> String {
  String(validating: bytes, as: UTF8.self) ?? ""
}

/// The bytes a session writes for one colour round: OSC 10, OSC 11, OSC 4 for slots 0
/// through 15, then the round's single DA1.
private let colourRound: String =
  "\u{1B}]10;?\u{1B}\\\u{1B}]11;?\u{1B}\\"
  + (0..<16).map { "\u{1B}]4;\($0);?\u{1B}\\" }.joined() + "\u{1B}[c"

struct TerminalAnswererTests {
  @Test
  func `a dark theme answers every query of a round in order and DA1 last`() {
    let reply = text(TerminalAnswerer(theme: .dark).replies(to: bytes(colourRound)))

    var expected = "\u{1B}]10;rgb:d4d4/d4d4/d4d4\u{1B}\\"
    expected += "\u{1B}]11;rgb:1e1e/1e1e/1e1e\u{1B}\\"
    let slots = [
      "0000/0000/0000", "cdcd/0000/0000", "0000/cdcd/0000", "cdcd/cdcd/0000",
      "0000/0000/eeee", "cdcd/0000/cdcd", "0000/cdcd/cdcd", "e5e5/e5e5/e5e5",
      "7f7f/7f7f/7f7f", "ffff/0000/0000", "0000/ffff/0000", "ffff/ffff/0000",
      "5c5c/5c5c/ffff", "ffff/0000/ffff", "0000/ffff/ffff", "ffff/ffff/ffff",
    ]
    for (slot, value) in slots.enumerated() {
      expected += "\u{1B}]4;\(slot);rgb:\(value)\u{1B}\\"
    }
    expected += "\u{1B}[?62;22c"
    #expect(reply == expected)
  }

  @Test
  func `a light theme reports the opposite foreground and background`() {
    let reply = text(
      TerminalAnswerer(theme: .light).replies(
        to: bytes("\u{1B}]10;?\u{1B}\\\u{1B}]11;?\u{1B}\\")))

    #expect(
      reply == "\u{1B}]10;rgb:1e1e/1e1e/1e1e\u{1B}\\\u{1B}]11;rgb:ffff/ffff/ffff\u{1B}\\")
  }

  @Test
  func `unknown colours answer DA1 alone, so the round ends at once`() {
    let reply = text(TerminalAnswerer(theme: nil).replies(to: bytes(colourRound)))

    #expect(reply == "\u{1B}[?62;22c")
  }

  @Test
  func `a background-only round gets the background and DA1`() {
    let reply = text(
      TerminalAnswerer(theme: .dark).replies(to: bytes("\u{1B}]11;?\u{1B}\\\u{1B}[c")))

    #expect(reply == "\u{1B}]11;rgb:1e1e/1e1e/1e1e\u{1B}\\\u{1B}[?62;22c")
  }

  @Test
  func `a reply ends the way its query did`() {
    let reply = text(
      TerminalAnswerer(theme: .dark).replies(to: bytes("\u{1B}]11;?\u{07}")))

    #expect(reply == "\u{1B}]11;rgb:1e1e/1e1e/1e1e\u{07}")
  }

  @Test
  func `one OSC 4 query can ask for several slots, and only slots 0 through 15 answer`() {
    let reply = text(
      TerminalAnswerer(theme: .dark).replies(to: bytes("\u{1B}]4;1;?;2;?;16;?\u{1B}\\")))

    #expect(
      reply
        == "\u{1B}]4;1;rgb:cdcd/0000/0000\u{1B}\\\u{1B}]4;2;rgb:0000/cdcd/0000\u{1B}\\")
  }

  @Test
  func `a request to set a colour is not a query and gets no answer`() {
    let reply = text(
      TerminalAnswerer(theme: .dark).replies(
        to: bytes("\u{1B}]4;1;rgb:ff/00/00\u{1B}\\\u{1B}]10;#ffffff\u{07}")))

    #expect(reply.isEmpty)
  }

  @Test
  func `a frame's own sequences are ignored, hyperlinks and colours included`() {
    let frame =
      "\u{1B}[0m\u{1B}[38;5;196mred\u{1B}[0m\u{1B}]8;;https://example.com\u{1B}\\link"
      + "\u{1B}]8;;\u{1B}\\\u{1B}[2;1H\u{1B}[?25l\u{1B}_Ga=d,d=A\u{1B}\\"

    #expect(TerminalAnswerer(theme: .dark).replies(to: bytes(frame)).isEmpty)
  }

  @Test
  func `only the primary device attributes query gets the DA1 reply`() {
    let answerer = TerminalAnswerer(theme: nil)

    #expect(text(answerer.replies(to: bytes("\u{1B}[0c"))) == "\u{1B}[?62;22c")
    #expect(answerer.replies(to: bytes("\u{1B}[>c")).isEmpty)
    #expect(answerer.replies(to: bytes("\u{1B}[1c")).isEmpty)
    #expect(answerer.replies(to: bytes("\u{1B}[=c")).isEmpty)
  }

  @Test
  func `a sequence cut off by the end of a write is not answered`() {
    let answerer = TerminalAnswerer(theme: .dark)

    #expect(answerer.replies(to: bytes("\u{1B}]11;?")).isEmpty)
    #expect(answerer.replies(to: bytes("\u{1B}[")).isEmpty)
    #expect(answerer.replies(to: bytes("\u{1B}")).isEmpty)
  }
}

struct TerminalProfileTests {
  @Test
  func `colour levels map to the session's forced capability`() {
    #expect(TerminalColors.none.override == .force(.noColor))
    #expect(TerminalColors.ansi16.override == .force(.ansi16))
    #expect(TerminalColors.indexed256.override == .force(.indexed256))
    #expect(TerminalColors.truecolor.override == .force(.truecolor))
    #expect(TerminalColors(rawValue: "16") == .ansi16)
    #expect(TerminalColors(rawValue: "256") == .indexed256)
    #expect(TerminalColors(rawValue: "true") == .truecolor)
    #expect(TerminalColors(rawValue: "none") == TerminalColors.none)
    #expect(Set(TerminalColors.spellings) == Set(TerminalColors.allCases.map(\.rawValue)))
    #expect(Set(TerminalTheme.spellings) == Set(TerminalTheme.allCases.map(\.rawValue)))
  }

  @Test
  func `a profile with no arguments is plain cells and unknown colours`() {
    #expect(TerminalProfile() == TerminalProfile(colors: .none, theme: nil))
  }
}

@MainActor
struct HeadlessDeviceTests {
  @Test
  func `the device answers a colour round written through its seam`() async throws {
    let device = HeadlessTerminalDevice(
      size: TerminalSize(columns: 20, rows: 4), theme: .dark)
    let seam = device.seam
    var replies = seam.bytes().makeAsyncIterator()

    let written = try await seam.write(bytes(colourRound))
    let reply = await replies.next()

    #expect(written == colourRound.utf8.count)
    #expect(reply.map(text)?.hasPrefix("\u{1B}]10;rgb:d4d4/d4d4/d4d4\u{1B}\\") == true)
    #expect(reply.map(text)?.hasSuffix("\u{1B}[?62;22c") == true)
  }

  @Test
  func `a frame written through the seam draws no reply, and finishing ends the input`()
    async throws
  {
    let device = HeadlessTerminalDevice(
      size: TerminalSize(columns: 20, rows: 4), theme: .light)
    let seam = device.seam
    var replies = seam.bytes().makeAsyncIterator()

    _ = try await seam.write(bytes("\u{1B}[2;1Hhello"))
    await device.finish()

    #expect(await replies.next() == nil)
  }

  @Test
  func `the device reports its size and a resize changes it`() async throws {
    let device = HeadlessTerminalDevice(size: TerminalSize(columns: 20, rows: 4))

    #expect(try await device.seam.size() == TerminalSize(columns: 20, rows: 4))
    await device.resize(to: TerminalSize(columns: 30, rows: 5))
    #expect(try await device.seam.size() == TerminalSize(columns: 30, rows: 5))
  }

  @Test
  func `a headless run takes the profile's colour level and theme and still draws`()
    async throws
  {
    let registry = Fixtures.registry()
    let drawsStack: @MainActor (any ScenarioHost) async throws -> Void = { host in
      #expect(host.screenRows.first == "Stack demo")
    }
    for profile in [
      TerminalProfile(colors: .truecolor, theme: .dark),
      TerminalProfile(colors: .ansi16, theme: .light),
      TerminalProfile(colors: .indexed256),
    ] {
      try await registry.withHeadlessHost(
        "stack", at: .desktop, terminal: profile, drawsStack)
    }
  }
}
