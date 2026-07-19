import TesseraCore
import TesseraTerminalCore

/// A one-cell rule oriented across its enclosing stack's cross axis.
public struct Divider: LeafView {
  public typealias Body = Never

  /// Creates a light divider whose orientation follows the nearest linear stack.
  public init() {}

  public func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    switch environment._stackAxis {
    case .horizontal:
      TerminalSize(columns: 1, rows: proposal.height ?? 1)
    case .vertical, nil:
      TerminalSize(columns: proposal.width ?? 1, rows: 1)
    }
  }

  public func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {
    switch environment._stackAxis {
    case .horizontal:
      for row in 0..<region.bounds.size.rows {
        region.write("│", at: TerminalPosition(column: 0, row: row))
      }
    case .vertical, nil:
      region.write(
        String(repeating: "─", count: max(region.bounds.size.columns, 0)),
        at: TerminalPosition(column: 0, row: 0)
      )
    }
  }
}
