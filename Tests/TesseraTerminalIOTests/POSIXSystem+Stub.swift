#if os(macOS) || os(Linux)
  @testable import TesseraTerminalIO

  extension POSIXSystem {
    /// A syscall surface whose calls default to harmless no-ops for tests.
    static func stub(
      close: @escaping @Sendable (CInt) -> CInt = { _ in 0 },
      fcntlGet: @escaping @Sendable (CInt, CInt) -> CInt = { _, _ in -1 },
      fcntlSet: @escaping @Sendable (CInt, CInt, CInt) -> CInt = { _, _, _ in 0 },
      pipe: @escaping @Sendable (UnsafeMutablePointer<CInt>) -> CInt = { descriptors in
        descriptors[0] = 100
        descriptors[1] = 101
        return 0
      },
      poll: @escaping @Sendable (UnsafeMutablePointer<pollfd>?, nfds_t, CInt) -> CInt = {
        _, _, _ in 0
      },
      read: @escaping @Sendable (CInt, UnsafeMutableRawPointer?, Int) -> Int = { _, _, _ in 0 },
      write: @escaping @Sendable (CInt, UnsafeRawPointer?, Int) -> Int = { _, _, count in count }
    ) -> Self {
      Self(
        close: close,
        fcntlGet: fcntlGet,
        fcntlSet: fcntlSet,
        pipe: pipe,
        poll: poll,
        read: read,
        write: write
      )
    }
  }
#endif
