import TesseraCore

/// A direction in terminal-cell layout.
public enum Axis: Equatable, Sendable {
  case horizontal
  case vertical

  /// A set of enabled layout axes.
  public struct Set: OptionSet, Sendable {
    public static let all: Self = [.horizontal, .vertical]
    public static let horizontal = Self(rawValue: 1 << 0)
    public static let vertical = Self(rawValue: 1 << 1)

    public let rawValue: UInt8

    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }
  }
}

/// Horizontal placement inside retained layout slack.
public enum HorizontalAlignment: Equatable, Sendable {
  case center
  case leading
  case trailing
}

/// Vertical placement inside retained layout slack.
public enum VerticalAlignment: Equatable, Sendable {
  case bottom
  case center
  case top
}

/// Two-axis placement inside retained layout slack.
public struct Alignment: Equatable, Sendable {
  public static let topLeading = Self(horizontal: .leading, vertical: .top)
  public static let top = Self(horizontal: .center, vertical: .top)
  public static let topTrailing = Self(horizontal: .trailing, vertical: .top)
  public static let leading = Self(horizontal: .leading, vertical: .center)
  public static let center = Self(horizontal: .center, vertical: .center)
  public static let trailing = Self(horizontal: .trailing, vertical: .center)
  public static let bottomLeading = Self(horizontal: .leading, vertical: .bottom)
  public static let bottom = Self(horizontal: .center, vertical: .bottom)
  public static let bottomTrailing = Self(horizontal: .trailing, vertical: .bottom)

  public let horizontal: HorizontalAlignment
  public let vertical: VerticalAlignment

  public init(
    horizontal: HorizontalAlignment,
    vertical: VerticalAlignment
  ) {
    self.horizontal = horizontal
    self.vertical = vertical
  }
}

/// Nonnegative terminal-cell insets around a child view.
public struct EdgeInsets: Equatable, Sendable {
  public let top: Int
  public let leading: Int
  public let bottom: Int
  public let trailing: Int

  public init(top: Int, leading: Int, bottom: Int, trailing: Int) {
    precondition(top >= 0, "EdgeInsets.top must be nonnegative.")
    precondition(leading >= 0, "EdgeInsets.leading must be nonnegative.")
    precondition(bottom >= 0, "EdgeInsets.bottom must be nonnegative.")
    precondition(trailing >= 0, "EdgeInsets.trailing must be nonnegative.")
    self.top = top
    self.leading = leading
    self.bottom = bottom
    self.trailing = trailing
  }

  public init(_ all: Int) {
    self.init(top: all, leading: all, bottom: all, trailing: all)
  }
}

package enum _StackAxisKey: EnvironmentKey {
  package static let defaultValue: Axis? = nil
}

extension EnvironmentValues {
  package var _stackAxis: Axis? {
    get { self[_StackAxisKey.self] }
    set { self[_StackAxisKey.self] = newValue }
  }
}

package func _alignmentOffset(
  slack: Int,
  alignment: HorizontalAlignment
) -> Int {
  switch alignment {
  case .leading:
    0
  case .center:
    slack / 2
  case .trailing:
    slack
  }
}

package func _alignmentOffset(
  slack: Int,
  alignment: VerticalAlignment
) -> Int {
  switch alignment {
  case .top:
    0
  case .center:
    slack / 2
  case .bottom:
    slack
  }
}
