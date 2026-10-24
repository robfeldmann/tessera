import TesseraHarness

/// Tessera's own demos, registered into one ``ApplicationRegistry``.
public enum Demos {
  /// A registry holding every demo and every fixture of every demo.
  ///
  /// Add a demo by adding one line here. The `tessera` executable, the headless snapshot
  /// tests, and the scenario corpus all select demos from this registry, so a demo that is not
  /// registered here cannot be launched or checked.
  @MainActor
  public static func registry() -> ApplicationRegistry {
    var registry = ApplicationRegistry()
    register(Counter.self, into: &registry)
    register(Stack.self, into: &registry)
    register(Workspace.self, into: &registry)
    return registry
  }

  @MainActor
  private static func register<D: Demo>(
    _ demo: D.Type, into registry: inout ApplicationRegistry
  ) {
    registry.register(D.name, minimum: D.minimum, viewports: D.viewports) { D() }
    for fixture in D.fixtures {
      registry.register(
        fixture.name, minimum: D.minimum, viewports: D.viewports, make: fixture.make)
    }
  }
}
