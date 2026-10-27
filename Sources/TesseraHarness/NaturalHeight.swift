import TesseraCore
import TesseraRuntime
import TesseraTerminalCore

/// Why an application's viewport could not be set up.
struct HostError: Error {
  var verb: String
  var message: String
}

/// How an application's root measures when it is offered no height, and whether it fills
/// the height it is offered instead.
struct NaturalHeight: Equatable {
  /// The shorter probe height.
  static let shortProbe = 500

  /// The taller probe height; a view that fills its proposal follows it.
  static let tallProbe = 1_000

  /// The rows the root measures to when no height is proposed.
  var rows: Int

  /// The rows the root measured to at the shorter probe height.
  var shortRows: Int

  /// The rows the root measured to at the taller probe height.
  var tallRows: Int

  /// Whether the root grew with the proposal, so it has no natural height of its own.
  ///
  /// A scrolling viewport, a split, a spacer, and any stack that contains one answer with
  /// the height they are offered. Two different offers give two different answers; content
  /// of a fixed height gives the same answer to both.
  var fillsProposal: Bool {
    shortRows != tallRows
  }

  /// Measures `app` at `columns` without drawing it.
  ///
  /// Reads `app.body` and nothing else: the application receives no event and keeps its
  /// state, so the same instance can be run afterwards.
  @MainActor
  static func measure<App: Application>(_ app: App, columns: Int) -> Self {
    let graph = ViewGraph(
      root: { app.body },
      size: TerminalSize(columns: columns, rows: tallProbe)
    )
    func rows(proposing height: Int?) -> Int {
      graph.measuredRootSize(proposing: ProposedSize(width: columns, height: height)).rows
    }
    return Self(
      rows: rows(proposing: nil),
      shortRows: rows(proposing: shortProbe),
      tallRows: rows(proposing: tallProbe)
    )
  }
}

extension Viewport {
  /// The terminal size this viewport names for `app`.
  ///
  /// `mobile` is 40 columns at the height the content needs. An application that fills any
  /// height has no such height, so the error says which viewport to use instead.
  @MainActor
  func size<App: Application>(for app: App, named name: String) throws(HostError)
    -> TerminalSize
  {
    if let fixed = fixedSize {
      return fixed
    }
    let natural = NaturalHeight.measure(app, columns: Self.mobileColumns)
    guard !natural.fillsProposal else {
      throw HostError(
        verb: "size",
        message:
          "`\(name)` has no natural height: it measured \(natural.shortRows) rows when "
          + "offered \(NaturalHeight.shortProbe) and \(natural.tallRows) when offered "
          + "\(NaturalHeight.tallProbe). Use `size mobileScreen` (40x16) or an explicit WxH"
      )
    }
    return TerminalSize(columns: Self.mobileColumns, rows: max(1, natural.rows))
  }
}
