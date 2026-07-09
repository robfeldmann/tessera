import Testing

@testable import TesseraTerminalANSI

@Test(arguments: [ColorCapability.truecolor, .indexed256, .ansi16, .unknown, .noColor])
func `default color survives every capability`(_ capability: ColorCapability) {
  #expect(Color.default.resolved(for: capability) == .default)
}

@Test
func `truecolor capability keeps requested color forms`() {
  #expect(Color.rgb(1, 2, 3).resolved(for: .truecolor) == .rgb(1, 2, 3))
  #expect(Color.indexed(196).resolved(for: .truecolor) == .indexed(196))
  #expect(Color.ansi(.brightRed).resolved(for: .truecolor) == .ansi(.brightRed))
}

@Test
func `indexed capability keeps narrow forms and degrades RGB to xterm palette`() {
  #expect(Color.ansi(.red).resolved(for: .indexed256) == .ansi(.red))
  #expect(Color.indexed(42).resolved(for: .indexed256) == .indexed(42))
  #expect(Color.rgb(255, 0, 0).resolved(for: .indexed256) == .indexed(196))
  #expect(Color.rgb(0, 255, 0).resolved(for: .indexed256) == .indexed(46))
  #expect(Color.rgb(0, 0, 255).resolved(for: .indexed256) == .indexed(21))
  #expect(Color.rgb(95, 135, 175).resolved(for: .indexed256) == .indexed(67))
}

@Test
func `indexed RGB degradation searches deterministic xterm ramp entries`() {
  #expect(Color.rgb(128, 128, 128).resolved(for: .indexed256) == .indexed(244))
  #expect(Color.rgb(238, 238, 238).resolved(for: .indexed256) == .indexed(255))
  #expect(Color.rgb(8, 8, 8).resolved(for: .indexed256) == .indexed(232))
}

@Test(arguments: [ColorCapability.ansi16, .unknown])
func `ansi and unknown capabilities use ANSI sixteen fallback`(
  _ capability: ColorCapability
) {
  #expect(Color.ansi(.cyan).resolved(for: capability) == .ansi(.cyan))
  #expect(Color.rgb(255, 0, 0).resolved(for: capability) == .ansi(.brightRed))
  #expect(Color.rgb(0, 255, 0).resolved(for: capability) == .ansi(.brightGreen))
  #expect(Color.rgb(0, 0, 255).resolved(for: capability) == .ansi(.blue))
  #expect(Color.rgb(255, 255, 255).resolved(for: capability) == .ansi(.brightWhite))
  #expect(Color.rgb(0, 0, 0).resolved(for: capability) == .ansi(.black))
}

@Test(arguments: [ColorCapability.ansi16, .unknown])
func `ansi grayscale fallback follows pinned xterm palette distances`(
  _ capability: ColorCapability
) {
  #expect(Color.rgb(64, 64, 64).resolved(for: capability) == .ansi(.brightBlack))
  #expect(Color.rgb(127, 127, 127).resolved(for: capability) == .ansi(.brightBlack))
  #expect(Color.rgb(180, 180, 180).resolved(for: capability) == .ansi(.white))
  #expect(Color.rgb(255, 255, 255).resolved(for: capability) == .ansi(.brightWhite))
}

@Test(arguments: [ColorCapability.ansi16, .unknown])
func `indexed colors degrade to ANSI sixteen deterministically`(
  _ capability: ColorCapability
) {
  #expect(Color.indexed(0).resolved(for: capability) == .ansi(.black))
  #expect(Color.indexed(1).resolved(for: capability) == .ansi(.red))
  #expect(Color.indexed(8).resolved(for: capability) == .ansi(.brightBlack))
  #expect(Color.indexed(15).resolved(for: capability) == .ansi(.brightWhite))
  #expect(Color.indexed(196).resolved(for: capability) == .ansi(.brightRed))
  #expect(Color.indexed(21).resolved(for: capability) == .ansi(.blue))
}

@Test
func `no-color capability resolves every color to default`() {
  #expect(Color.ansi(.red).resolved(for: .noColor) == .default)
  #expect(Color.indexed(196).resolved(for: .noColor) == .default)
  #expect(Color.rgb(255, 0, 0).resolved(for: .noColor) == .default)
}
