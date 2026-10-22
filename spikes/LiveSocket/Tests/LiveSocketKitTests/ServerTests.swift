import Foundation
import Testing

@testable import LiveSocketKit

private func serve(_ server: ControlServer) -> Task<Void, Never> {
  Task {
    for await request in server.requests {
      await server.reply(request.id, ControlProtocol.success(["echo": .string("\(request.operation)")]))
    }
  }
}

@Test
func `the server answers one request per connection and removes the socket on shutdown`() async throws {
  let path = TestSocket.path()
  let server = try await ControlServer.start(path: path)
  let responder = serve(server)

  let result = await TestSocket.send(#"{"op":"text"}"#, to: path)
  #expect(result.exitCode == 0)
  #expect(result.output == #"{"echo":"text","ok":true}"#)

  await server.shutdown()
  responder.cancel()
  #expect(!TestSocket.exists(path))
}

@Test
func `a request without a trailing newline is answered once the client half closes`() async throws {
  let path = TestSocket.path()
  let server = try await ControlServer.start(path: path)
  let responder = serve(server)

  // `ControlClient` appends the newline, so write the raw bytes through a second client path.
  let descriptor = try POSIXSocket.makeSocket(nonBlocking: false)
  let address = try POSIXSocket.address(for: path)
  #expect(POSIXSocket.connect(descriptor, to: address) == 0)
  _ = POSIXSocket.write(descriptor, Array(#"{"op":"tree"}"#.utf8)[...])
  shutdown(descriptor, SHUT_WR)
  var chunk = [UInt8](repeating: 0, count: 256)
  let count = read(descriptor, &chunk, chunk.count)
  close(descriptor)
  #expect(String(decoding: chunk[..<max(count, 0)], as: UTF8.self) == "{\"echo\":\"tree\",\"ok\":true}\n")

  await server.shutdown()
  responder.cancel()
}

@Test
func `the socket file is private and a missing parent directory is created as 0700`() async throws {
  let directory = "/tmp/lsk-dir-\(UUID().uuidString.prefix(8).lowercased())"
  let path = directory + "/live.sock"
  let server = try await ControlServer.start(path: path)

  var socketInfo = stat()
  var directoryInfo = stat()
  #expect(stat(path, &socketInfo) == 0)
  #expect(stat(directory, &directoryInfo) == 0)
  #expect(socketInfo.st_mode & 0o777 == 0o600)
  #expect(directoryInfo.st_mode & 0o777 == 0o700)

  await server.shutdown()
  try FileManager.default.removeItem(atPath: directory)
}

@Test
func `a world writable directory without the sticky bit is refused`() async throws {
  let directory = "/tmp/lsk-open-\(UUID().uuidString.prefix(8).lowercased())"
  try FileManager.default.createDirectory(
    atPath: directory,
    withIntermediateDirectories: false,
    attributes: [.posixPermissions: 0o777]
  )
  defer { try? FileManager.default.removeItem(atPath: directory) }

  await #expect(throws: SocketError.self) {
    _ = try await ControlServer.start(path: directory + "/live.sock")
  }
}

@Test
func `a stale socket file is replaced but a live one is refused`() async throws {
  let path = TestSocket.path()

  // Bind and close without unlinking: exactly what a killed app leaves behind.
  let stale = try POSIXSocket.makeSocket(nonBlocking: false)
  #expect(POSIXSocket.bind(stale, to: try POSIXSocket.address(for: path)) == 0)
  close(stale)
  #expect(TestSocket.exists(path))

  let server = try await ControlServer.start(path: path)
  await #expect(throws: SocketError.self) {
    _ = try await ControlServer.start(path: path)
  }
  await server.shutdown()
}

@Test
func `a regular file at the socket path is never deleted`() async throws {
  let path = TestSocket.path()
  try Data("keep".utf8).write(to: URL(fileURLWithPath: path))
  defer { try? FileManager.default.removeItem(atPath: path) }

  await #expect(throws: SocketError.self) {
    _ = try await ControlServer.start(path: path)
  }
  #expect(try String(contentsOfFile: path, encoding: .utf8) == "keep")
}

@Test
func `a path longer than sockaddr_un allows is reported with the limit`() async {
  let path = "/tmp/" + String(repeating: "a", count: 120) + ".sock"
  do {
    _ = try await ControlServer.start(path: path)
    Issue.record("expected the long path to be refused")
  } catch let error as SocketError {
    #expect(error.message.contains("limit is \(POSIXSocket.maximumPathBytes)"))
  } catch {
    Issue.record("unexpected error \(error)")
  }
}

@Test
func `an app that never answers produces a timeout error reply`() async throws {
  let path = TestSocket.path()
  let server = try await ControlServer.start(path: path, requestTimeout: .milliseconds(200))

  let result = await TestSocket.send(#"{"op":"text"}"#, to: path)
  #expect(result.exitCode == ControlClient.ExitCode.serverError)
  let reply = try JSONValue.parse(result.output)
  #expect(reply["ok"] == .bool(false))
  #expect(reply["error"]?.stringValue?.contains("did not answer") == true)

  await server.shutdown()
}

@Test
func `shutdown answers requests the app never reached`() async throws {
  let path = TestSocket.path()
  let server = try await ControlServer.start(path: path)

  async let pending = TestSocket.send(#"{"op":"text"}"#, to: path)
  for await request in server.requests {
    _ = request
    break
  }
  await server.shutdown()
  let result = await pending
  #expect(result.output == #"{"error":"app is shutting down","ok":false}"#)
}

@Test
func `the client reports a missing socket as a JSON error with exit 3`() throws {
  let result = ControlClient.run(request: #"{"op":"text"}"#, path: "/tmp/lsk-missing.sock")
  #expect(result.exitCode == 3)
  let reply = try JSONValue.parse(result.output)
  #expect(reply["ok"] == .bool(false))
  #expect(reply["error"]?.stringValue?.contains("no socket at /tmp/lsk-missing.sock") == true)
}

@Test
func `the client reports a stale socket file as unreachable with exit 3`() throws {
  let path = TestSocket.path()
  let stale = try POSIXSocket.makeSocket(nonBlocking: false)
  #expect(POSIXSocket.bind(stale, to: try POSIXSocket.address(for: path)) == 0)
  close(stale)
  defer { unlink(path) }

  let result = ControlClient.run(request: #"{"op":"text"}"#, path: path)
  #expect(result.exitCode == 3)
  #expect(result.output.contains("Connection refused"))
}

@Test
func `a client that disconnects before its reply arrives does not raise SIGPIPE in the app`() async throws {
  let path = TestSocket.path()
  let server = try await ControlServer.start(path: path)
  let responder = Task {
    for await request in server.requests {
      try? await Task.sleep(for: .milliseconds(100))
      await server.reply(request.id, ControlProtocol.success())
    }
  }

  // If the reply write raised SIGPIPE, the whole test process would die here.
  for _ in 0..<10 {
    let descriptor = try POSIXSocket.makeSocket(nonBlocking: false)
    #expect(POSIXSocket.connect(descriptor, to: try POSIXSocket.address(for: path)) == 0)
    _ = POSIXSocket.write(descriptor, Array("{\"op\":\"text\"}\n".utf8)[...])
    close(descriptor)
  }
  try await Task.sleep(for: .milliseconds(400))

  let result = await TestSocket.send(#"{"op":"text"}"#, to: path)
  #expect(result.output == #"{"ok":true}"#)

  await server.shutdown()
  responder.cancel()
}

@Test
func `a burst of connections deeper than the connection cap is answered or refused cleanly`() async throws {
  let path = TestSocket.path()
  let server = try await ControlServer.start(path: path)
  let responder = Task {
    for await request in server.requests {
      await server.reply(request.id, ControlProtocol.success())
    }
  }

  let outputs = await withTaskGroup(of: String.self) { group in
    for _ in 0..<40 {
      group.addTask { await TestSocket.send(#"{"op":"text"}"#, to: path).output }
    }
    return await group.reduce(into: [String]()) { $0.append($1) }
  }
  let accepted = outputs.filter { $0 == #"{"ok":true}"# }.count
  let capped = outputs.filter { $0.contains("too many connections") }.count
  #expect(accepted + capped == 40)
  #expect(accepted >= 1)

  await server.shutdown()
  responder.cancel()
}
