import Foundation

/// The blocking `livesocket ctl` client. One short-lived process, so it uses plain syscalls.
public enum ControlClient {
  /// Why a request never produced a reply line.
  public enum Failure: Error, Equatable, Sendable {
    /// No socket file exists at the path.
    case missing(String)

    /// The path exists but nothing is listening, or the connection broke.
    case unreachable(String)

    /// No reply arrived before the deadline.
    case timedOut(String)

    /// The text for the JSON error envelope.
    public var message: String {
      switch self {
      case .missing(let path):
        "no socket at \(path); start the app with TESSERA_DEBUG_SOCKET=\(path)"
      case .unreachable(let detail), .timedOut(let detail):
        detail
      }
    }
  }

  /// Exit status contract shared with plan 033 Phase F.
  public enum ExitCode {
    public static let success: Int32 = 0
    public static let serverError: Int32 = 1
    public static let usage: Int32 = 2
    public static let connection: Int32 = 3
  }

  /// Sends one request line and returns the one reply line (without its newline).
  public static func send(
    _ request: String,
    to path: String,
    timeout: TimeInterval = 10
  ) -> Result<String, Failure> {
    var info = stat()
    guard stat(path, &info) == 0 else {
      return .failure(.missing(path))
    }
    let address: sockaddr_un
    let descriptor: Int32
    do {
      address = try POSIXSocket.address(for: path)
      descriptor = try POSIXSocket.makeSocket(nonBlocking: false)
    } catch {
      return .failure(.unreachable("\(error)"))
    }
    defer { close(descriptor) }

    guard POSIXSocket.connect(descriptor, to: address) == 0 else {
      let reason = String(cString: strerror(Foundation.errno))
      return .failure(.unreachable("cannot connect to \(path): \(reason) (stale socket file?)"))
    }

    let payload = Array((request.hasSuffix("\n") ? request : request + "\n").utf8)
    var offset = 0
    while offset < payload.count {
      let written = POSIXSocket.write(descriptor, payload[offset...])
      guard written >= 0 else {
        return .failure(.unreachable("write to \(path) failed"))
      }
      offset += written
    }
    shutdown(descriptor, SHUT_WR)

    var buffer: [UInt8] = []
    var chunk = [UInt8](repeating: 0, count: 4_096)
    let deadline = Date().addingTimeInterval(timeout)
    while true {
      let remaining = deadline.timeIntervalSinceNow
      guard remaining > 0 else {
        return .failure(.timedOut("no reply from \(path) within \(Int(timeout))s"))
      }
      var poller = pollfd(fd: descriptor, events: Int16(POLLIN), revents: 0)
      let ready = poll(&poller, 1, Int32(min(remaining * 1_000, 60_000)))
      if ready < 0, Foundation.errno == EINTR {
        continue
      }
      guard ready > 0 else {
        continue
      }
      let count = chunk.withUnsafeMutableBytes { read(descriptor, $0.baseAddress, $0.count) }
      if count > 0 {
        buffer.append(contentsOf: chunk[..<count])
        if let newline = buffer.firstIndex(of: 0x0A) {
          return .success(String(decoding: buffer[..<newline], as: UTF8.self))
        }
      } else if count == 0 {
        guard !buffer.isEmpty else {
          return .failure(.unreachable("\(path) closed the connection without a reply"))
        }
        return .success(String(decoding: buffer, as: UTF8.self))
      } else if Foundation.errno != EINTR {
        return .failure(.unreachable("read from \(path) failed"))
      }
    }
  }

  /// Runs the client and returns the line to print on stdout plus the process exit code.
  public static func run(request: String, path: String, timeout: TimeInterval = 10)
    -> (output: String, exitCode: Int32)
  {
    switch send(request, to: path, timeout: timeout) {
    case .success(let reply):
      let ok = (try? JSONValue.parse(reply))?["ok"] == .bool(true)
      return (reply, ok ? ExitCode.success : ExitCode.serverError)
    case .failure(let failure):
      return (ControlProtocol.failure(failure.message), ExitCode.connection)
    }
  }
}
