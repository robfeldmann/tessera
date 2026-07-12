import Testing

@testable import TesseraTerminalANSI

@Test
func `clipboard text encodes exact OSC 52 bytes`() {
  expectBytes(
    .copyToClipboard(ClipboardWrite(text: "hello")),
    esc("]52;c;aGVsbG8=") + esc("\\")
  )
}

@Test
func `primary selection uses p Pc`() {
  expectBytes(
    .copyToClipboard(ClipboardWrite(selection: .primary, text: "hello")),
    esc("]52;p;aGVsbG8=") + esc("\\")
  )
}

@Test
func `clipboard and primary selection preserves cp order`() {
  expectBytes(
    .copyToClipboard(ClipboardWrite(selection: .clipboardAndPrimary, text: "hello")),
    esc("]52;cp;aGVsbG8=") + esc("\\")
  )
}

@Test
func `control and non UTF8 bytes are only emitted as base64 in OSC body`() {
  let payload: [UInt8] = [0x07, 0x1B, 0x00, 0x0A, 0xFF]
  let encoded = ControlSequence.copyToClipboard(ClipboardWrite(bytes: payload)).bytes

  expectBytes(encoded, esc("]52;c;BxsACv8=") + esc("\\"))

  let oscBody = encoded.dropFirst(2).dropLast(2)
  #expect(
    oscBody.allSatisfy { byte in
      byte >= 0x20 && byte != 0x7F
    })
}

@Test
func `empty payload encodes empty base64 field`() {
  expectBytes(
    .copyToClipboard(ClipboardWrite(bytes: [])),
    esc("]52;c;") + esc("\\")
  )
}

@Test
func `clipboard selection rejects empty duplicates and invalid cut buffers`() throws {
  #expect(ClipboardSelection([]) == nil)
  #expect(ClipboardSelection([.clipboard, .clipboard]) == nil)
  #expect(ClipboardSelection([.cutBuffer(8)]) == nil)

  let selection = try #require(ClipboardSelection([.cutBuffer(7)]))
  expectBytes(
    .copyToClipboard(ClipboardWrite(selection: selection, text: "x")),
    esc("]52;7;eA==") + esc("\\")
  )
}

@Test
func `string and byte payloads preserve caller data before base64`() {
  let textWrite = ClipboardWrite(text: "héllo")
  #expect(textWrite.selection == .clipboard)
  #expect(textWrite.bytes == Array("héllo".utf8))

  let bytePayload: [UInt8] = [0x00, 0x01, 0x02, 0xFF]
  let byteWrite = ClipboardWrite(selection: .primary, bytes: bytePayload)
  #expect(byteWrite.selection == .primary)
  #expect(byteWrite.bytes == bytePayload)
}
