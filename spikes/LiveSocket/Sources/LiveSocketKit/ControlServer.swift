import Foundation

/// A decoded request waiting for the app loop to answer it through `ControlServer.reply`.
public struct ControlRequest: Sendable {
  public let id: Int
  public let operation: ControlOperation
}

/// A Unix-domain NDJSON endpoint: one request line in, one reply line out, then close.
///
/// All shared state lives on this actor. Descriptors are non-blocking and observed through
/// dispatch read sources, so no thread ever blocks on I/O and no lock is needed. The server
/// never touches the app: decoded requests leave through `requests`, and the owner answers
/// each with `reply(_:_:)` from its own isolation domain.
public actor ControlServer {
  private enum RequestRead {
    case closed
    case line(String)
    case tooLong
  }

  static let idleReadTimeout: Duration = .seconds(10)
  static let maximumConnections = 8
  static let maximumRequestBytes = 1 << 20

  public nonisolated let path: String

  /// Decoded requests in arrival order. Finishes when the server shuts down.
  public nonisolated let requests: AsyncStream<ControlRequest>

  private var acceptTask: Task<Void, Never>?
  private var connections: [Int: Task<Void, Never>] = [:]
  private var idleConnections: Set<Int> = []
  private var isStopped = false
  private let listener: DescriptorEvents
  private var nextConnectionID = 0
  private var nextRequestID = 0
  private var pending: [Int: CheckedContinuation<String, Never>] = [:]
  private let requestContinuation: AsyncStream<ControlRequest>.Continuation
  private let requestTimeout: Duration
  private var timeouts: [Int: Task<Void, Never>] = [:]

  /// Binds `path` (mode 0600, current-user peers only) and starts accepting.
  public static func start(
    path: String,
    requestTimeout: Duration = .seconds(5)
  ) async throws -> ControlServer {
    try prepareParentDirectory(of: path)
    try removeStaleSocket(at: path)
    let descriptor = try bindListener(at: path)
    let server = ControlServer(
      path: path,
      listenerDescriptor: descriptor,
      requestTimeout: requestTimeout
    )
    await server.beginAccepting()
    return server
  }

  private init(path: String, listenerDescriptor: Int32, requestTimeout: Duration) {
    let (requests, requestContinuation) = AsyncStream<ControlRequest>.makeStream()
    self.listener = DescriptorEvents(descriptor: listenerDescriptor)
    self.path = path
    self.requestContinuation = requestContinuation
    self.requestTimeout = requestTimeout
    self.requests = requests
  }

  private func beginAccepting() {
    acceptTask = Task { await self.acceptLoop() }
  }

  /// Answers request `id`. A second reply for the same id, or one after a timeout, is ignored.
  public func reply(_ id: Int, _ line: String) {
    timeouts.removeValue(forKey: id)?.cancel()
    pending.removeValue(forKey: id)?.resume(returning: line)
  }

  /// Stops accepting and removes the socket file. Replies already pending still go out.
  public func stopListening() {
    guard !isStopped else {
      return
    }
    isStopped = true
    unlink(path)
    acceptTask?.cancel()
    listener.cancel()
  }

  /// Stops listening, fails unanswered requests, and waits for in-flight replies to be written.
  public func shutdown() async {
    stopListening()
    requestContinuation.finish()
    for (id, continuation) in pending {
      timeouts.removeValue(forKey: id)?.cancel()
      continuation.resume(returning: ControlProtocol.failure("app is shutting down"))
    }
    pending.removeAll()
    for id in idleConnections {
      connections[id]?.cancel()
    }
    for task in Array(connections.values) {
      await task.value
    }
  }

  // MARK: Accepting

  private func acceptLoop() async {
    for await _ in listener.readable {
      while true {
        let client = accept(listener.descriptor, nil, nil)
        if client < 0 {
          if Foundation.errno == EINTR {
            continue
          }
          break
        }
        admit(client)
      }
    }
  }

  private func admit(_ client: Int32) {
    POSIXSocket.configure(client, nonBlocking: true)
    guard !isStopped, POSIXSocket.peerIsCurrentUser(client) else {
      close(client)
      return
    }
    guard connections.count < Self.maximumConnections else {
      _ = POSIXSocket.write(client, Array((ControlProtocol.failure("too many connections") + "\n").utf8)[...])
      close(client)
      return
    }
    let id = nextConnectionID
    nextConnectionID += 1
    idleConnections.insert(id)
    connections[id] = Task { await self.serve(client, id: id) }
  }

  // MARK: Serving

  private func serve(_ descriptor: Int32, id: Int) async {
    let events = DescriptorEvents(descriptor: descriptor)
    defer {
      events.cancel()
      connections.removeValue(forKey: id)
      idleConnections.remove(id)
    }

    let watchdog = Task {
      try? await Task.sleep(for: Self.idleReadTimeout)
      events.finish()
    }
    let request = await readRequest(from: events)
    watchdog.cancel()
    idleConnections.remove(id)

    let reply: String
    switch request {
    case .closed:
      return
    case .tooLong:
      reply = ControlProtocol.failure("request exceeds \(Self.maximumRequestBytes) bytes")
    case .line(let line):
      switch ControlProtocol.decode(line) {
      case .failure(let error):
        reply = ControlProtocol.failure(error.message)
      case .success(let operation):
        reply = await dispatch(operation)
      }
    }
    await write(reply + "\n", to: descriptor)
  }

  private func readRequest(from events: DescriptorEvents) async -> RequestRead {
    var buffer: [UInt8] = []
    var chunk = [UInt8](repeating: 0, count: 4_096)
    for await _ in events.readable {
      while true {
        let count = chunk.withUnsafeMutableBytes { read(events.descriptor, $0.baseAddress, $0.count) }
        if count > 0 {
          buffer.append(contentsOf: chunk[..<count])
          if let newline = buffer.firstIndex(of: 0x0A) {
            return .line(String(decoding: buffer[..<newline], as: UTF8.self))
          }
          if buffer.count > Self.maximumRequestBytes {
            return .tooLong
          }
        } else if count == 0 {
          // EOF: `printf '{"op":"text"}' | nc -U` half-closes without a trailing newline.
          return buffer.isEmpty ? .closed : .line(String(decoding: buffer, as: UTF8.self))
        } else if Foundation.errno == EINTR {
          continue
        } else if Foundation.errno == EAGAIN || Foundation.errno == EWOULDBLOCK {
          break
        } else {
          return .closed
        }
      }
    }
    return .closed
  }

  private func dispatch(_ operation: ControlOperation) async -> String {
    let id = nextRequestID
    nextRequestID += 1
    return await withCheckedContinuation { continuation in
      pending[id] = continuation
      if case .terminated = requestContinuation.yield(ControlRequest(id: id, operation: operation)) {
        pending.removeValue(forKey: id)?.resume(returning: ControlProtocol.failure("app is not running"))
        return
      }
      timeouts[id] = Task {
        try? await Task.sleep(for: requestTimeout)
        expire(id)
      }
    }
  }

  private func expire(_ id: Int) {
    timeouts.removeValue(forKey: id)
    pending.removeValue(forKey: id)?.resume(
      returning: ControlProtocol.failure("the app did not answer within \(requestTimeout)")
    )
  }

  /// Writes with a bounded `EAGAIN` backoff so a stalled client never holds a thread.
  private func write(_ text: String, to descriptor: Int32) async {
    let bytes = Array(text.utf8)
    var offset = 0
    let deadline = ContinuousClock.now + .seconds(5)
    while offset < bytes.count {
      let written = POSIXSocket.write(descriptor, bytes[offset...])
      if written >= 0 {
        offset += written
        continue
      }
      guard Foundation.errno == EAGAIN || Foundation.errno == EWOULDBLOCK,
        ContinuousClock.now < deadline, !Task.isCancelled
      else {
        return
      }
      try? await Task.sleep(for: .milliseconds(5))
    }
  }
}

// MARK: - Socket file setup

extension ControlServer {
  /// Creates the parent directory as `0700` when missing; refuses directories other users can
  /// replace entries in (sticky world-writable directories such as `/tmp` are accepted).
  static func prepareParentDirectory(of path: String) throws {
    let parent = (path as NSString).deletingLastPathComponent
    let directory = parent.isEmpty ? "." : parent
    var info = stat()
    if stat(directory, &info) != 0 {
      guard Foundation.errno == ENOENT, mkdir(directory, 0o700) == 0 else {
        throw SocketError.errno("socket directory \(directory)")
      }
      return
    }
    guard (info.st_mode & S_IFMT) == S_IFDIR else {
      throw SocketError("\(directory) is not a directory")
    }
    let othersCanWrite = info.st_mode & 0o022 != 0
    let sticky = info.st_mode & S_ISVTX != 0
    let ownedByUs = info.st_uid == geteuid()
    guard sticky || (ownedByUs && !othersCanWrite) else {
      throw SocketError(
        "\(directory) is writable by other users; use a directory with mode 0700 that you own"
      )
    }
  }

  /// Removes `path` when it is a dead socket we own; refuses anything else that exists.
  static func removeStaleSocket(at path: String) throws {
    var info = stat()
    if lstat(path, &info) != 0 {
      guard Foundation.errno == ENOENT else {
        throw SocketError.errno("socket path \(path)")
      }
      return
    }
    guard (info.st_mode & S_IFMT) == S_IFSOCK else {
      throw SocketError("\(path) exists and is not a socket")
    }
    guard info.st_uid == geteuid() else {
      throw SocketError("\(path) is a socket owned by another user")
    }
    let probe = try POSIXSocket.makeSocket(nonBlocking: false)
    defer { close(probe) }
    let address = try POSIXSocket.address(for: path)
    if POSIXSocket.connect(probe, to: address) == 0 {
      throw SocketError("\(path) is already served by a running app")
    }
    guard Foundation.errno == ECONNREFUSED else {
      throw SocketError.errno("probing existing socket \(path)")
    }
    unlink(path)
  }

  static func bindListener(at path: String) throws -> Int32 {
    let address = try POSIXSocket.address(for: path)
    let descriptor = try POSIXSocket.makeSocket(nonBlocking: true)
    let previousMask = umask(0o077)
    let bound = POSIXSocket.bind(descriptor, to: address)
    let bindError = Foundation.errno
    umask(previousMask)
    guard bound == 0 else {
      close(descriptor)
      Foundation.errno = bindError
      throw SocketError.errno("bind \(path)")
    }
    chmod(path, 0o600)
    // macOS answers ECONNREFUSED, not a retry, once the backlog is full, so keep it deep: a
    // refused connect is also how `ControlClient` recognises a stale socket file.
    guard listen(descriptor, SOMAXCONN) == 0 else {
      let listenError = SocketError.errno("listen \(path)")
      close(descriptor)
      unlink(path)
      throw listenError
    }
    return descriptor
  }
}
