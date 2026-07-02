/// A POSIX file descriptor capability.
package struct FileDescriptor: ~Copyable {
  package let rawValue: CInt

  package init(rawValue: CInt) {
    self.rawValue = rawValue
  }
}
