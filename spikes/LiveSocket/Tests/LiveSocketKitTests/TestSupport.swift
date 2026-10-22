import Foundation
import Tessera
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport

@testable import LiveSocketKit

enum TestSocket {
  /// Short enough for `sockaddr_un` (103 bytes) and unique per call.
  static func path() -> String {
    "/tmp/lsk-\(UUID().uuidString.prefix(8).lowercased()).sock"
  }

  /// Runs the blocking client on a dispatch queue. `ctl` is a separate process in real use;
  /// blocking cooperative threads here would starve the server under test.
  static func send(
    _ request: String,
    to path: String,
    timeout: TimeInterval = 10
  ) async -> (output: String, exitCode: Int32) {
    await withCheckedContinuation { continuation in
      DispatchQueue.global().async {
        continuation.resume(returning: ControlClient.run(request: request, path: path, timeout: timeout))
      }
    }
  }

  /// Sends a request and decodes the reply object.
  static func reply(_ request: String, to path: String) async throws -> JSONValue {
    let result = await send(request, to: path)
    return try JSONValue.parse(result.output)
  }

  static func exists(_ path: String) -> Bool {
    FileManager.default.fileExists(atPath: path)
  }

  static func waitForSocket(_ path: String) async throws {
    for _ in 0..<250 {
      if exists(path) {
        return
      }
      try await Task.sleep(for: .milliseconds(20))
    }
    throw SocketError("socket \(path) never appeared")
  }
}

/// A live-loop run against an in-memory terminal: no pty, same loop code.
struct LoopRun {
  let path: String
  let session: InMemoryTerminalSession
  let task: Task<Void, any Error>

  /// - Parameter waitForSocket: `false` for runs that may finish before the socket is observed.
  static func start(
    inputBytes: [UInt8] = [],
    exitWhenInputCloses: Bool = false,
    waitForSocket: Bool = true
  ) async throws -> LoopRun {
    let path = TestSocket.path()
    let session = InMemoryTerminalSession(
      size: TerminalSize(columns: 80, rows: 24),
      inputBytes: inputBytes
    )
    let task = Task {
      try await session.withApplicationTerminal { terminal in
        try await LiveRunner.loop(
          app: CounterApp(),
          options: LiveRunner.Options(
            socketPath: path,
            exitWhenInputCloses: exitWhenInputCloses
          ),
          terminal: terminal
        )
      }
    }
    if waitForSocket {
      try await TestSocket.waitForSocket(path)
    }
    return LoopRun(path: path, session: session, task: task)
  }

  func text() async throws -> JSONValue {
    try await TestSocket.reply(#"{"op":"text"}"#, to: path)
  }

  func key(_ name: String) async throws -> JSONValue {
    try await TestSocket.reply(#"{"op":"key","key":"\#(name)"}"#, to: path)
  }

  func quit() async throws {
    _ = try await TestSocket.reply(#"{"op":"quit"}"#, to: path)
    try await task.value
  }

  /// Polls `text` until `predicate` accepts the screen text.
  func waitForText(_ predicate: (String) -> Bool) async throws -> String {
    for _ in 0..<100 {
      let text = try await text()["text"]?.stringValue ?? ""
      if predicate(text) {
        return text
      }
      try await Task.sleep(for: .milliseconds(20))
    }
    throw SocketError("screen never matched")
  }

  /// What a real terminal would show: every byte the session wrote, fed to a fresh Ghostty VT.
  func terminalRows() async -> [String] {
    let terminal = VirtualTerminal.ghostty(cols: 80, rows: 24)
    terminal.feed(await session.bytes)
    return Projection.rows(of: terminal.snapshot())
  }
}
