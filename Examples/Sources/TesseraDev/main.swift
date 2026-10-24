import DemoSupport
import TesseraHarness

// `tessera`: Tessera's own executable. It registers Tessera's demos and hands the command
// line to the harness; an app author's executable does the same over the app's own registry.
await HarnessCLI.main(registry: Demos.registry())
