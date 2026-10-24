import TesseraTerminalCore
import TesseraTerminalIO

/// The terminal device under a headless session: it reports a size, accepts writes, and
/// answers the terminal queries a session sends.
///
/// Nothing is kept: the session's output tap hands every drawn frame to the virtual terminal
/// before the write, and input reaches the application through the driver, not through the
/// device. What the device reads is the answer to a query, produced by its
/// ``TerminalAnswerer`` from the profile's theme, so the colours a session learns come from
/// the scenario and never from the virtual terminal's own defaults. A resize changes the size
/// the next frame is drawn at.
///
/// This type stands in for `InMemoryTerminalDevice` because that device lives in a module
/// that links the snapshot-testing library, and a library that links it cannot be loaded by
/// an executable.
actor HeadlessTerminalDevice {
  private let answerer: TerminalAnswerer
  private let replies: AsyncStream<[UInt8]>
  private let repliesContinuation: AsyncStream<[UInt8]>.Continuation
  private var size: TerminalSize

  /// The device seam a `PlatformIO` is built over.
  nonisolated var seam: TerminalDevice {
    TerminalDevice(
      bytes: { self.replies },
      size: { await self.size },
      write: { bytes in
        await self.answer(bytes)
        return bytes.count
      }
    )
  }

  /// Creates a device that reports `size` and answers colour queries from `theme`.
  init(size: TerminalSize, theme: TerminalTheme? = nil) {
    self.size = size
    answerer = TerminalAnswerer(theme: theme)
    (replies, repliesContinuation) = AsyncStream.makeStream(of: [UInt8].self)
  }

  /// Changes the size the session reports from now on.
  func resize(to size: TerminalSize) {
    self.size = size
  }

  /// Ends the device's input, once the session that read it has closed.
  func finish() {
    repliesContinuation.finish()
  }

  private func answer(_ written: ArraySlice<UInt8>) {
    let reply = answerer.replies(to: written)
    if !reply.isEmpty {
      repliesContinuation.yield(reply)
    }
  }
}
