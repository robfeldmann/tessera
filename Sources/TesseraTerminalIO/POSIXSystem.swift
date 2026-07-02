#if os(macOS) || os(Linux)

  #if os(macOS)
    @_exported import Darwin
  #elseif os(Linux)
    @_exported import Glibc
  #endif

  /// The injectable POSIX syscall surface used by platform I/O.
  ///
  /// This is the single place the platform C library is imported and `Darwin`/`Glibc` are
  /// disambiguated; the `@_exported import` re-exports the C symbols (`termios`, `pollfd`,
  /// `errno`, `STDIN_FILENO`, …) to the rest of the target, so no other file needs its
  /// own platform import block. Tests inject a stub through `$override`; production
  /// resolves to `live`.
  package struct POSIXSystem: Sendable {
    @TaskLocal package static var override: Self?

    /// The syscall surface in effect: a test override when present, otherwise `live`.
    package static var current: Self {
      override ?? live
    }

    /// The live syscall surface backed by the platform C library.
    ///
    /// The closures forward to file-scope wrappers rather than calling the C functions
    /// inline, because inside this initializer the bare names (`close`, `poll`, …) resolve
    /// to this type's own stored properties instead of the global syscalls.
    package static let live = Self(
      close: posixClose,
      fcntlGet: posixFcntlGet,
      fcntlSet: posixFcntlSet,
      pipe: posixPipe,
      poll: posixPoll,
      read: posixRead,
      write: posixWrite
    )

    package var close: @Sendable (CInt) -> CInt
    package var fcntlGet: @Sendable (CInt, CInt) -> CInt
    package var fcntlSet: @Sendable (CInt, CInt, CInt) -> CInt
    package var pipe: @Sendable (UnsafeMutablePointer<CInt>) -> CInt
    package var poll: @Sendable (UnsafeMutablePointer<pollfd>?, nfds_t, CInt) -> CInt
    package var read: @Sendable (CInt, UnsafeMutableRawPointer?, Int) -> Int
    package var write: @Sendable (CInt, UnsafeRawPointer?, Int) -> Int

    package init(
      close: @escaping @Sendable (CInt) -> CInt,
      fcntlGet: @escaping @Sendable (CInt, CInt) -> CInt,
      fcntlSet: @escaping @Sendable (CInt, CInt, CInt) -> CInt,
      pipe: @escaping @Sendable (UnsafeMutablePointer<CInt>) -> CInt,
      poll: @escaping @Sendable (UnsafeMutablePointer<pollfd>?, nfds_t, CInt) -> CInt,
      read: @escaping @Sendable (CInt, UnsafeMutableRawPointer?, Int) -> Int,
      write: @escaping @Sendable (CInt, UnsafeRawPointer?, Int) -> Int
    ) {
      self.close = close
      self.fcntlGet = fcntlGet
      self.fcntlSet = fcntlSet
      self.pipe = pipe
      self.poll = poll
      self.read = read
      self.write = write
    }
  }

  private func posixClose(_ descriptor: CInt) -> CInt {
    close(descriptor)
  }

  private func posixFcntlGet(_ descriptor: CInt, _ command: CInt) -> CInt {
    fcntl(descriptor, command)
  }

  private func posixFcntlSet(_ descriptor: CInt, _ command: CInt, _ value: CInt) -> CInt {
    fcntl(descriptor, command, value)
  }

  private func posixPipe(_ descriptors: UnsafeMutablePointer<CInt>) -> CInt {
    pipe(descriptors)
  }

  private func posixPoll(
    _ descriptors: UnsafeMutablePointer<pollfd>?,
    _ count: nfds_t,
    _ timeout: CInt
  ) -> CInt {
    poll(descriptors, count, timeout)
  }

  private func posixRead(
    _ descriptor: CInt,
    _ buffer: UnsafeMutableRawPointer?,
    _ count: Int
  ) -> Int {
    read(descriptor, buffer, count)
  }

  private func posixWrite(
    _ descriptor: CInt,
    _ buffer: UnsafeRawPointer?,
    _ count: Int
  ) -> Int {
    write(descriptor, buffer, count)
  }

#endif
