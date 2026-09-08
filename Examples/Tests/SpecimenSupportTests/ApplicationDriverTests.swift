import SpecimenSupport
import Tessera
import TesseraTerminal
import TesseraTerminalTestSupport
import Testing

private struct DriverModeRoot: View {
  let interactive: Bool

  @ViewBuilder
  var body: some View {
    if interactive {
      Button("Go") {}
    } else {
      Text("Idle")
    }
  }
}

struct ApplicationDriverTests {
  @Test
  func `dynamic requirements preserve explicit terminal baseline modes`() async throws {
    var configuration = TerminalApplicationConfiguration(
      modes: [.rawMode, .altScreen],
      synchronizedOutput: .disabled,
      colorCapability: .force(.noColor)
    )
    configuration.enableFocusEvents = false
    configuration.mouseTracking = .disabled
    configuration.keyboardProtocol = .legacyOnly

    let session = InMemoryTerminalSession(size: TerminalSize(columns: 16, rows: 1))
    var interactive = false

    try await session.withApplicationTerminal(configuration: configuration) { terminal in
      let driver = ApplicationDriver(size: TerminalSize(columns: 16, rows: 1)) {
        DriverModeRoot(interactive: interactive)
      }
      let initialPresented = try await driver.present(to: terminal)
      let baselineFocusEvents = terminal.focusEventsEnabled
      #expect(initialPresented)
      #expect(terminal.mouseTracking == .disabled)
      #expect(terminal.keyboardProtocol == .legacyOnly)
      #expect(!baselineFocusEvents)
      #expect(terminal.protocolModeReport.requested.isEmpty)
      #expect(terminal.protocolModeReport.effective.contains(.rawMode))
      #expect(terminal.protocolModeReport.effective.contains(.altScreen))

      interactive = true
      driver.update()
      let demandedPresented = try await driver.present(to: terminal)
      let demandedFocusEvents = terminal.focusEventsEnabled
      #expect(demandedPresented)
      #expect(terminal.mouseTracking == .buttonEvents)
      #expect(terminal.keyboardProtocol == .kittyIfAvailable)
      #expect(demandedFocusEvents)
      #expect(terminal.protocolModeReport.requested.contains(.focusEvents))
      #expect(
        terminal.protocolModeReport.requested.contains(.mouseTracking(.buttonEvents)))

      interactive = false
      driver.update()
      let restoredPresented = try await driver.present(to: terminal)
      let restoredFocusEvents = terminal.focusEventsEnabled
      #expect(restoredPresented)
      #expect(terminal.mouseTracking == .disabled)
      #expect(terminal.keyboardProtocol == .legacyOnly)
      #expect(!restoredFocusEvents)
      #expect(terminal.protocolModeReport.requested.isEmpty)
      #expect(terminal.protocolModeReport.effective.contains(.rawMode))
      #expect(terminal.protocolModeReport.effective.contains(.altScreen))
    }
  }
}

@Test
func `strong baseline modes survive dynamic Button demand`() async throws {
  let configuration = TerminalApplicationConfiguration(
    modes: [
      .rawMode, .altScreen, .focusEvents, .mouseTracking(.anyEvent), .kittyKeyboard,
    ],
    synchronizedOutput: .disabled,
    colorCapability: .force(.noColor)
  )
  let session = InMemoryTerminalSession(size: TerminalSize(columns: 16, rows: 1))
  var interactive = false

  try await session.withApplicationTerminal(configuration: configuration) { terminal in
    let driver = ApplicationDriver(size: TerminalSize(columns: 16, rows: 1)) {
      DriverModeRoot(interactive: interactive)
    }
    _ = try await driver.present(to: terminal)
    #expect(terminal.mouseTracking == .anyEvent)
    #expect(terminal.keyboardProtocol == .kittyRequired)
    let initialFocusEvents = terminal.focusEventsEnabled
    #expect(initialFocusEvents)

    interactive = true
    driver.update()
    _ = try await driver.present(to: terminal)
    #expect(terminal.mouseTracking == .anyEvent)
    #expect(terminal.keyboardProtocol == .kittyRequired)
    let demandedFocusEvents = terminal.focusEventsEnabled
    #expect(demandedFocusEvents)

    interactive = false
    driver.update()
    _ = try await driver.present(to: terminal)
    #expect(terminal.mouseTracking == .anyEvent)
    #expect(terminal.keyboardProtocol == .kittyRequired)
    let restoredFocusEvents = terminal.focusEventsEnabled
    #expect(restoredFocusEvents)
  }
}
