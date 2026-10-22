/// A POSIX file descriptor capability.
///
/// The wrapper does not own the descriptor: it is never closed here, and `rawValue` is
/// freely copied into `@Sendable` closures. The standard descriptors it wraps are
/// borrowed from the process for its whole lifetime.
package struct FileDescriptor {
  package let rawValue: CInt

  package init(rawValue: CInt) {
    self.rawValue = rawValue
  }
}
