import TesseraTerminalCore
import TesseraTerminalIO

/// An event recorded by an in-memory terminal device.
public enum InMemoryTerminalDeviceEvent: Equatable, Sendable {
  /// The terminal entered its alternate screen buffer.
  case enterAltScreen

  /// The terminal entered raw input mode.
  case enterRawMode

  /// The terminal left its alternate screen buffer.
  case exitAltScreen

  /// The terminal restored its previous input mode.
  case exitRawMode

  /// The terminal flushed bytes to output.
  case flush([UInt8])
}

/// An in-memory terminal device for deterministic terminal I/O tests.
public actor InMemoryTerminalDevice {
  private var inputContinuations: [AsyncStream<[UInt8]>.Continuation] = []
  private var isInputClosed = false
  private let keepsInputOpen: Bool
  private let replies: (@Sendable (ArraySlice<UInt8>) -> [UInt8])?
  private var recordedEvents: [InMemoryTerminalDeviceEvent] = []
  private var sizeContinuations: [AsyncStream<TerminalSize>.Continuation] = []
  private var storedBytes: [UInt8] = []
  private var storedInputBytes: [UInt8]
  private var storedCellPixelSize: CellPixelSize?
  private var storedSize: TerminalSize

  /// The bytes written to the device so far.
  public var bytes: [UInt8] {
    storedBytes
  }

  /// The terminal lifecycle events recorded so far.
  public var events: [InMemoryTerminalDeviceEvent] {
    recordedEvents
  }

  /// A terminal device seam backed by this actor's in-memory state.
  ///
  /// A device that keeps its input open registers one byte stream and one size-change
  /// stream with each read of this property, before the seam is returned, so a resize
  /// delivered afterwards reaches the stream even if the reader subscribes later. Each
  /// call of the seam's `bytes` or `sizeChanges` then returns that same single-reader
  /// stream.
  package var terminalDevice: TerminalDevice {
    let inputBytes = storedInputBytes
    let openStreams = keepsInputOpen ? makeOpenStreams(inputBytes: inputBytes) : nil

    return TerminalDevice(
      bytes: {
        openStreams?.bytes
          ?? AsyncStream { continuation in
            if !inputBytes.isEmpty {
              continuation.yield(inputBytes)
            }
            continuation.finish()
          }
      },
      cellPixelSize: { await self.storedCellPixelSize },
      enterAltScreen: { await self.enterAltScreen() },
      enterRawMode: { await self.enterRawMode() },
      exitAltScreen: { await self.exitAltScreen() },
      exitRawMode: { await self.exitRawMode() },
      size: { await self.storedSize },
      sizeChanges: {
        openStreams?.sizeChanges ?? AsyncStream { $0.finish() }
      },
      write: { try await self.write($0) }
    )
  }

  /// Creates an in-memory terminal device with an initial terminal size and input bytes.
  public init(
    size: TerminalSize = TerminalSize(columns: 1, rows: 1),
    cellPixelSize: CellPixelSize? = nil,
    inputBytes: [UInt8] = []
  ) {
    self.init(
      size: size,
      cellPixelSize: cellPixelSize,
      inputBytes: inputBytes,
      keepsInputOpen: false
    )
  }

  /// Creates a device whose input and size-change streams stay open until `closeInput()`.
  ///
  /// An open device can deliver `.resize` mid-session through `deliverResize(to:)`.
  ///
  /// A device given `replies` answers what is written to it: each write is passed to the
  /// closure, and a non-empty result is delivered on the byte streams of an open device, as
  /// a terminal answers a query. A closed device has no byte streams to deliver on, so it
  /// drops the reply.
  package init(
    size: TerminalSize,
    cellPixelSize: CellPixelSize?,
    inputBytes: [UInt8],
    keepsInputOpen: Bool,
    replies: (@Sendable (ArraySlice<UInt8>) -> [UInt8])? = nil
  ) {
    self.keepsInputOpen = keepsInputOpen
    self.replies = replies
    self.storedInputBytes = inputBytes
    self.storedCellPixelSize = cellPixelSize
    self.storedSize = size
  }

  /// Changes the size reported by the device without emitting a resize event.
  public func resize(to size: TerminalSize) {
    self.storedSize = size
  }

  /// Finishes the input and size-change streams of an open device.
  package func closeInput() {
    isInputClosed = true
    for continuation in inputContinuations {
      continuation.finish()
    }
    inputContinuations = []
    for continuation in sizeContinuations {
      continuation.finish()
    }
    sizeContinuations = []
  }

  /// Reports a new size and emits it on the size-change streams of an open device.
  ///
  /// Unlike `resize(to:)`, which changes only the size the device reports, this also
  /// delivers a `.resize` event, so the reported size and the event stream agree. A closed
  /// device has no size-change streams, so there it matches `resize(to:)`.
  package func deliverResize(to size: TerminalSize) {
    storedSize = size
    for continuation in sizeContinuations {
      continuation.yield(size)
    }
  }

  private func makeOpenStreams(
    inputBytes: [UInt8]
  ) -> (bytes: AsyncStream<[UInt8]>, sizeChanges: AsyncStream<TerminalSize>) {
    let bytes = AsyncStream.makeStream(of: [UInt8].self)
    let sizeChanges = AsyncStream.makeStream(of: TerminalSize.self)
    if !inputBytes.isEmpty {
      bytes.continuation.yield(inputBytes)
    }
    if isInputClosed {
      bytes.continuation.finish()
      sizeChanges.continuation.finish()
    } else {
      inputContinuations.append(bytes.continuation)
      sizeContinuations.append(sizeChanges.continuation)
    }
    return (bytes.stream, sizeChanges.stream)
  }

  private func enterAltScreen() {
    recordedEvents.append(.enterAltScreen)
    storedBytes.append(contentsOf: "\u{1B}[?1049h".utf8)
  }

  private func enterRawMode() {
    recordedEvents.append(.enterRawMode)
  }

  private func exitAltScreen() {
    recordedEvents.append(.exitAltScreen)
    storedBytes.append(contentsOf: "\u{1B}[?1049l".utf8)
  }

  private func exitRawMode() {
    recordedEvents.append(.exitRawMode)
  }

  private func write(_ bytes: ArraySlice<UInt8>) throws -> Int {
    let count = bytes.count
    recordedEvents.append(.flush(Array(bytes)))
    storedBytes.append(contentsOf: bytes)
    if let reply = replies?(bytes), !reply.isEmpty {
      for continuation in inputContinuations {
        continuation.yield(reply)
      }
    }
    return count
  }
}
