import Foundation

/// A socket setup or transport failure with an operator-readable message.
public struct SocketError: Error, Equatable, Sendable, CustomStringConvertible {
  public let message: String

  public var description: String { message }

  public init(_ message: String) {
    self.message = message
  }

  static func errno(_ action: String) -> SocketError {
    SocketError("\(action): \(String(cString: strerror(Foundation.errno)))")
  }
}

/// Thin POSIX helpers shared by the server and the `ctl` client.
enum POSIXSocket {
  /// The longest path `sockaddr_un` can hold, excluding its NUL terminator.
  static let maximumPathBytes = MemoryLayout.size(ofValue: sockaddr_un().sun_path) - 1

  static func address(for path: String) throws -> sockaddr_un {
    let bytes = Array(path.utf8)
    guard bytes.count <= maximumPathBytes else {
      throw SocketError(
        "socket path is \(bytes.count) bytes; the limit is \(maximumPathBytes). "
          + "Use a shorter path such as /tmp/tessera-NAME.sock"
      )
    }
    var address = sockaddr_un()
    address.sun_family = sa_family_t(AF_UNIX)
    #if canImport(Darwin)
      address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
    #endif
    withUnsafeMutableBytes(of: &address.sun_path) { raw in
      raw.copyBytes(from: bytes)
      raw[bytes.count] = 0
    }
    return address
  }

  static func makeSocket(nonBlocking: Bool) throws -> Int32 {
    let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
    guard descriptor >= 0 else {
      throw SocketError.errno("socket")
    }
    configure(descriptor, nonBlocking: nonBlocking)
    return descriptor
  }

  static func configure(_ descriptor: Int32, nonBlocking: Bool) {
    _ = fcntl(descriptor, F_SETFD, FD_CLOEXEC)
    if nonBlocking {
      _ = fcntl(descriptor, F_SETFL, fcntl(descriptor, F_GETFL) | O_NONBLOCK)
    }
    #if canImport(Darwin)
      // A client that disconnects mid-reply must never raise SIGPIPE in the app.
      var enabled: Int32 = 1
      setsockopt(
        descriptor, SOL_SOCKET, SO_NOSIGPIPE, &enabled, socklen_t(MemoryLayout<Int32>.size))
    #endif
  }

  static func connect(_ descriptor: Int32, to address: sockaddr_un) -> Int32 {
    withUnsafePointer(to: address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Foundation.connect(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
  }

  static func bind(_ descriptor: Int32, to address: sockaddr_un) -> Int32 {
    withUnsafePointer(to: address) { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        Foundation.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
      }
    }
  }

  /// One `write` attempt that retries `EINTR`; returns bytes written or `-1` with `errno` set.
  static func write(_ descriptor: Int32, _ bytes: ArraySlice<UInt8>) -> Int {
    while true {
      let written = bytes.withUnsafeBytes { raw in
        #if canImport(Darwin)
          Foundation.write(descriptor, raw.baseAddress, raw.count)
        #else
          send(descriptor, raw.baseAddress, raw.count, Int32(MSG_NOSIGNAL))
        #endif
      }
      if written < 0, Foundation.errno == EINTR {
        continue
      }
      return written
    }
  }

  /// Whether the peer on `descriptor` runs as the current effective user.
  static func peerIsCurrentUser(_ descriptor: Int32) -> Bool {
    #if canImport(Darwin)
      var uid: uid_t = 0
      var gid: gid_t = 0
      return getpeereid(descriptor, &uid, &gid) == 0 && uid == geteuid()
    #else
      var credentials = ucred()
      var length = socklen_t(MemoryLayout<ucred>.size)
      return getsockopt(descriptor, SOL_SOCKET, SO_PEERCRED, &credentials, &length) == 0
        && credentials.uid == geteuid()
    #endif
  }
}
