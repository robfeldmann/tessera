import TesseraTerminalCore
import TesseraTerminalIO

/// The terminal device under a headless session: it reports a size and accepts writes.
///
/// Nothing is read from it and nothing is kept: the session's output tap hands every drawn
/// frame to the virtual terminal before the write, and input reaches the application through
/// the driver, not through the device. A resize changes the size the next frame is drawn at.
///
/// This type stands in for `InMemoryTerminalDevice` because that device lives in a module
/// that links the snapshot-testing library, and a library that links it cannot be loaded by
/// an executable.
actor HeadlessTerminalDevice {
  private var size: TerminalSize

  /// The device seam a `PlatformIO` is built over.
  nonisolated var seam: TerminalDevice {
    TerminalDevice(
      size: { await self.size },
      write: { $0.count }
    )
  }

  /// Creates a device that reports `size`.
  init(size: TerminalSize) {
    self.size = size
  }

  /// Changes the size the session reports from now on.
  func resize(to size: TerminalSize) {
    self.size = size
  }
}
