import TesseraTerminalANSI
import TesseraTerminalCore
import TesseraTerminalSnapshotSupport
import TesseraTerminalTestSupport
import Testing

@testable import TesseraTerminal
@testable import TesseraTerminalIO

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `initial screen is blank`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 4, rows: 2)

  #expect(terminal.text(row: 0) == "    ")
  #expect(terminal.text(row: 1) == "    ")
  #expect(terminal.snapshot().cells.count == 2)
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `characters write into visible cells`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 2)

  terminal.feed("Hi")

  #expect(terminal.text(row: 0) == "Hi   ")
  #expect(terminal.cell(row: 0, column: 0).character == "H")
  #expect(terminal.cell(row: 0, column: 1).character == "i")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `cursor movement writes at requested position`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 3)

  terminal.feed("\u{1B}[2;3HX")

  #expect(terminal.text(row: 1) == "  X  ")
  #expect(terminal.cell(row: 1, column: 2).character == "X")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `erase in line clears visible cells`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 5, rows: 1)

  terminal.feed("Hello")
  terminal.feed("\u{1B}[1;2H\u{1B}[K")

  #expect(terminal.text(row: 0) == "H    ")
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `sgr styles colors and underline extensions are inspectable`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 4, rows: 1)

  terminal.feed("\u{1B}[1;2;3;4:2;7;9;38;5;196;48;2;1;2;3;58:2::4:5:6mX")
  let cell = terminal.cell(row: 0, column: 0)

  #expect(cell.character == "X")
  #expect(cell.bold)
  #expect(cell.dim)
  #expect(cell.italic)
  #expect(cell.underlineStyle == .double)
  #expect(cell.underlineColor == .rgb(4, 5, 6))
  #expect(cell.reverse)
  #expect(cell.strikethrough)
  #expect(cell.foreground == RenderedColor.indexed(196))
  #expect(cell.background == RenderedColor.rgb(1, 2, 3))
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `Ghostty exposes every underline variant`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 6, rows: 1)

  terminal.feed("\u{1B}[4mS\u{1B}[4:2mD\u{1B}[4:3mC\u{1B}[4:4mO\u{1B}[4:5mA\u{1B}[24mN")

  #expect(terminal.cell(row: 0, column: 0).underlineStyle == .single)
  #expect(terminal.cell(row: 0, column: 1).underlineStyle == .double)
  #expect(terminal.cell(row: 0, column: 2).underlineStyle == .curly)
  #expect(terminal.cell(row: 0, column: 3).underlineStyle == .dotted)
  #expect(terminal.cell(row: 0, column: 4).underlineStyle == .dashed)
  #expect(terminal.cell(row: 0, column: 5).underlineStyle == .none)
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `Ghostty exposes RGB indexed and reset underline colors`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 3, rows: 1)

  terminal.feed("\u{1B}[4:3;58:2::1:2:3mR\u{1B}[58:5:1mP\u{1B}[59mD")

  #expect(terminal.cell(row: 0, column: 0).underlineColor == .rgb(1, 2, 3))
  #expect(terminal.cell(row: 0, column: 1).underlineColor == .indexed(1))
  #expect(terminal.cell(row: 0, column: 2).underlineColor == .default)
  #expect(terminal.cell(row: 0, column: 2).underlineStyle == .curly)
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `cursor position is inspectable`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 8, rows: 3)

  terminal.feed("\u{1B}[3;5H")

  #expect(terminal.cursorPosition() == TerminalPosition(column: 4, row: 2))
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `kitty graphics transmit and place are inspectable`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 8, rows: 4)
  let imageID = KittyImageID(rawValue: 101)
  let placementID = KittyPlacementID(rawValue: 7)

  terminal.feed(
    ControlSequence.kittyGraphics(
      .transmit(
        KittyGraphicsTransmission(
          id: imageID,
          format: .rgb(width: 2, height: 2),
          data: twoByTwoRGBPixels()
        )
      )
    ).bytes
  )
  terminal.feed(ControlSequence.cursorPosition(TerminalPosition(column: 2, row: 1)).bytes)
  terminal.feed(
    ControlSequence.kittyGraphics(
      .place(
        KittyGraphicsPlacement(
          id: imageID,
          placement: placementID,
          columns: 3,
          rows: 2,
          zIndex: 4
        )
      )
    ).bytes
  )

  #expect(
    terminal.kittyImages() == [
      RenderedKittyImage(format: .rgb, height: 2, id: 101, width: 2)
    ]
  )
  let expectedPlacement = RenderedKittyPlacement(
    column: 2,
    columns: 3,
    imageID: 101,
    placementID: 7,
    row: 1,
    rows: 2,
    zIndex: 4
  )
  #expect(terminal.kittyPlacements() == [expectedPlacement])
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `Kitty graphics accepts the demo RGBA image and placement`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 20, rows: 10)
  let imageID = KittyImageID(rawValue: 1)
  let placementID = KittyPlacementID(rawValue: 1)
  let pixels = [UInt8](repeating: 255, count: 32 * 32 * 4)

  terminal.feed(
    ControlSequence.kittyGraphics(
      .transmit(
        KittyGraphicsTransmission(
          id: imageID,
          format: .rgba(width: 32, height: 32),
          data: pixels
        )
      )
    ).bytes
  )
  terminal.feed(ControlSequence.cursorPosition(TerminalPosition(column: 2, row: 3)).bytes)
  terminal.feed(
    ControlSequence.kittyGraphics(
      .place(
        KittyGraphicsPlacement(
          id: imageID,
          placement: placementID,
          columns: 8,
          rows: 4
        )
      )
    ).bytes
  )

  #expect(
    terminal.kittyImages() == [
      RenderedKittyImage(
        format: .rgba,
        height: 32,
        id: 1,
        width: 32
      )
    ]
  )
  #expect(
    terminal.kittyPlacements() == [
      RenderedKittyPlacement(
        column: 2,
        columns: 8,
        imageID: 1,
        placementID: 1,
        row: 3,
        rows: 4,
        zIndex: 0
      )
    ]
  )
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `Ghostty screen erase removes transmitted Kitty image data`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 8, rows: 4)
  let imageID = KittyImageID(rawValue: 1)
  let pixels = [UInt8](repeating: 255, count: 32 * 32 * 4)

  terminal.feed(
    ControlSequence.kittyGraphics(
      .transmit(
        KittyGraphicsTransmission(
          id: imageID,
          format: .rgba(width: 32, height: 32),
          data: pixels
        )
      )
    ).bytes
  )
  terminal.feed(
    ControlSequence.kittyGraphics(
      .place(
        KittyGraphicsPlacement(
          id: imageID,
          placement: KittyPlacementID(rawValue: 1),
          columns: 2,
          rows: 2
        )
      )
    ).bytes
  )
  #expect(terminal.kittyImages().count == 1)
  #expect(terminal.kittyPlacements().count == 1)

  terminal.feed(ControlSequence.eraseInDisplay(.all).bytes)

  #expect(terminal.kittyImages().isEmpty)
  #expect(terminal.kittyPlacements().isEmpty)
}
@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `kitty graphics delete all clears images and placements`() {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 4, rows: 2)
  let imageID = KittyImageID(rawValue: 202)
  let placementID = KittyPlacementID(rawValue: 8)

  terminal.feed(
    ControlSequence.kittyGraphics(
      .transmit(
        KittyGraphicsTransmission(
          id: imageID,
          format: .rgb(width: 2, height: 2),
          data: twoByTwoRGBPixels()
        )
      )
    ).bytes
  )
  terminal.feed(
    ControlSequence.kittyGraphics(
      .place(
        KittyGraphicsPlacement(
          id: imageID,
          placement: placementID,
          columns: 2,
          rows: 1,
          zIndex: 1
        )
      )
    ).bytes
  )

  #expect(terminal.kittyImages().isEmpty == false)
  #expect(terminal.kittyPlacements().isEmpty == false)

  terminal.feed(ControlSequence.kittyGraphics(.delete(.all)).bytes)

  #expect(terminal.kittyImages().isEmpty)
  #expect(terminal.kittyPlacements().isEmpty)
}

@Test(
  .disabled(
    if: VirtualTerminal.isGhosttyUnavailable,
    "Ghostty virtual terminal support is unavailable in this build."
  )
)
func `text outside frame image region remains visible on same row`() async throws {
  let terminal = VirtualTerminal.ghosttyOrUnavailable(cols: 6, rows: 1)
  let imageID = KittyImageID(rawValue: 303)
  let placementID = KittyPlacementID(rawValue: 9)
  let device = InMemoryTerminalDevice(size: TerminalSize(columns: 6, rows: 1))
  let session = TerminalSession(
    io: PlatformIO(terminalDevice: await device.terminalDevice),
    synchronizedOutput: .disabled
  )
  try await session.draw { _ in }
  let primingBytes = await device.bytes
  terminal.feed(primingBytes)

  terminal.feed(
    ControlSequence.kittyGraphics(
      .transmit(
        KittyGraphicsTransmission(
          id: imageID,
          format: .rgb(width: 1, height: 1),
          data: [0xFF, 0x00, 0x00]
        )
      )
    ).bytes
  )
  let imageFrameStart = primingBytes.count

  try await session.draw { frame in
    frame.write("L", at: TerminalPosition(column: 0, row: 0))
    frame.placeImage(
      KittyGraphicsPlacement(
        id: imageID,
        placement: placementID,
        columns: 3,
        rows: 1,
        zIndex: 2
      ),
      at: TerminalPosition(column: 1, row: 0),
      occupying: Rect(column: 1, row: 0, columns: 3, rows: 1)
    )
    frame.write("R", at: TerminalPosition(column: 4, row: 0))
  }

  terminal.feed(Array((await device.bytes).dropFirst(imageFrameStart)))

  #expect(terminal.cell(row: 0, column: 0).character == "L")
  #expect(terminal.cell(row: 0, column: 4).character == "R")
  #expect(terminal.text(row: 0) == "L   R ")
  let expectedPlacement = RenderedKittyPlacement(
    column: 1,
    columns: 3,
    imageID: 303,
    placementID: 9,
    row: 0,
    rows: 1,
    zIndex: 2
  )
  #expect(terminal.kittyPlacements() == [expectedPlacement])
}

private func twoByTwoRGBPixels() -> [UInt8] {
  [
    0xFF, 0x00, 0x00,
    0x00, 0xFF, 0x00,
    0x00, 0x00, 0xFF,
    0xFF, 0xFF, 0xFF,
  ]
}
