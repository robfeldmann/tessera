import Tessera

/// The content height a demo asks for at a given width when offered far more rows.
public struct NaturalHeight: Equatable, Sendable {
  /// The rows the root node measured to under the tall proposal.
  public var rows: Int

  /// The size the graph was laid out at while measuring.
  public var probe: TerminalSize

  /// Whether the root grew to the whole proposal, so `rows` is the probe, not a natural height.
  ///
  /// A `ScrollView` or `SplitView` takes the proposed height, and so does any stack that
  /// contains one; `GraphDiagnostics` cannot tell greedy from exactly-tall.
  public var fillsProposal: Bool {
    rows >= probe.rows
  }
}

/// Why a scenario's app or viewport could not be set up.
struct HostError: Error {
  var verb: String
  var message: String
}

/// The single selection point from app name to driver.
public enum DemoRegistry {
  public static let names = ["stack", "workspace"]
  public static let defaultName = WorkspaceApp.name

  /// Rows offered while measuring natural height; content taller than this is clamped.
  public static let probeRows = 500

  static func makeHost(app: String, viewport: Viewport) throws(HostError) -> any ScenarioHost {
    switch app {
    case StackApp.name: try makeHost(StackApp.self, viewport: viewport)
    case WorkspaceApp.name: try makeHost(WorkspaceApp.self, viewport: viewport)
    default:
      throw HostError(verb: "app", message: "app `\(app)` is not registered")
    }
  }

  public static func naturalHeight(app: String, width: Int) -> NaturalHeight? {
    switch app {
    case StackApp.name: naturalHeight(StackApp.self, width: width)
    case WorkspaceApp.name: naturalHeight(WorkspaceApp.self, width: width)
    default: nil
    }
  }

  private static func makeHost<A: DemoApp>(
    _ app: A.Type,
    viewport: Viewport
  ) throws(HostError) -> any ScenarioHost {
    let size: TerminalSize
    switch viewport {
    case .desktop: size = TerminalSize(columns: 80, rows: 24)
    case .mobileScreen: size = TerminalSize(columns: 40, rows: 16)
    case .custom(let columns, let rows): size = TerminalSize(columns: columns, rows: rows)
    case .mobile:
      let natural = naturalHeight(app, width: 40)
      guard !natural.fillsProposal else {
        throw HostError(
          verb: "size",
          message:
            "`\(A.name)` fills a \(natural.probe.rows)-row proposal, so it has no natural "
            + "height; use `size mobileScreen` or an explicit WxH")
      }
      size = TerminalSize(columns: 40, rows: natural.rows)
    }
    return Driver<A>(size: size)
  }

  private static func naturalHeight<A: DemoApp>(_ app: A.Type, width: Int) -> NaturalHeight {
    let probe = TerminalSize(columns: width, rows: probeRows)
    let driver = Driver<A>(size: probe)
    let root = driver.diagnostics.nodes.first { $0.parentIdentity == nil }
    return NaturalHeight(rows: root?.measuredSize?.rows ?? 0, probe: probe)
  }
}
