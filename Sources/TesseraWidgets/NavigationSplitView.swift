import TesseraCore
import TesseraLayout
import TesseraTerminalCore

// swiftlint:disable sorted_enum_cases
// Semantic order is part of compact-role fallback; do not alphabetize.
/// The application-controlled columns in a ``NavigationSplitView``.
public enum NavigationSplitViewColumn: Hashable, Sendable {
  case sidebar
  case content
  case detail
}
// swiftlint:enable sorted_enum_cases

/// The columns an application permits a regular navigation split view to show.
public struct NavigationSplitViewVisibility: OptionSet, Hashable, Sendable {
  public static let sidebar = Self(rawValue: 1 << 0)
  public static let content = Self(rawValue: 1 << 1)
  public static let detail = Self(rawValue: 1 << 2)
  public static let all: Self = [.sidebar, .content, .detail]
  public static let doubleColumn: Self = [.sidebar, .detail]
  public static let detailOnly: Self = [.detail]

  public let rawValue: UInt8

  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  fileprivate static func bit(for column: NavigationSplitViewColumn) -> Self {
    switch column {
    case .sidebar: return .sidebar
    case .content: return .content
    case .detail: return .detail
    }
  }

  fileprivate func contains(_ column: NavigationSplitViewColumn) -> Bool {
    contains(Self.bit(for: column))
  }
}

/// A restrained divider treatment for a ``NavigationSplitView``.
public protocol NavigationSplitViewStyle {
  /// The divider style used between navigation roles.
  var dividerStyle: DividerStyle { get }
}

/// The default navigation split view treatment.
public struct AutomaticNavigationSplitViewStyle: NavigationSplitViewStyle, Sendable {
  public let dividerStyle: DividerStyle = .light

  public init() {}
}

extension NavigationSplitViewStyle where Self == AutomaticNavigationSplitViewStyle {
  /// The automatic role divider treatment.
  public static var automatic: Self { Self() }
}

extension View {
  /// Applies the divider treatment used by descendant navigation split views.
  public func navigationSplitViewStyle<S: NavigationSplitViewStyle>(_ style: S)
    -> some View
  {
    dividerStyle(style.dividerStyle)
  }
}

private final class _NavigationPresentationState {
  var isCompact = false
}

private struct _NavigationControlBar: View {
  let column: NavigationSplitViewColumn
  let visibility: Binding<NavigationSplitViewVisibility>
  let preferredCompactColumn: Binding<NavigationSplitViewColumn>
  let focus: Binding<FocusID?>
  let focusTargets: Binding<[NavigationSplitViewColumn: FocusID?]>
  let presentationState: _NavigationPresentationState

  var body: some View {
    HStack(spacing: 1) {
      Button(
        visibility.wrappedValue.contains(column) ? "Close \(label)" : "Open \(label)",
        action: toggle
      )
      .focusable(FocusID("navigation.toggle.\(label.lowercased())"))
    }
  }

  private var label: String {
    switch column {
    case .sidebar: return "Sidebar"
    case .content: return "Content"
    case .detail: return "Detail"
    }
  }

  private func toggle() {
    var next = visibility.wrappedValue
    if presentationState.isCompact {
      if preferredCompactColumn.wrappedValue != column {
        next.insert(NavigationSplitViewVisibility.bit(for: column))
        preferredCompactColumn.wrappedValue = column
      } else {
        next.remove(NavigationSplitViewVisibility.bit(for: column))
      }
    } else if next.contains(column) {
      next.remove(NavigationSplitViewVisibility.bit(for: column))
    } else {
      next.insert(NavigationSplitViewVisibility.bit(for: column))
    }
    visibility.wrappedValue = next
    if next.contains(column), let target = focusTargets.wrappedValue[column] {
      focus.wrappedValue = target
    } else if let current = focus.wrappedValue,
      let target = focusTargets.wrappedValue[column],
      current == target
    {
      focus.wrappedValue = nil
    }
  }
}

/// Composes application-owned sidebar, content, and detail roles in regular or compact space.
///
/// Regular space lays out all supplied and visible roles with one-cell dividers. Compact space
/// presents exactly one available role, selected by `preferredCompactColumn` and falling back
/// in semantic order. Selection, destinations, history, and business state remain application-owned.
public struct NavigationSplitView<Sidebar: View, Content: View, Detail: View>: View,
  _LayoutView
{
  public typealias Body = Never

  private let columnVisibility: Binding<NavigationSplitViewVisibility>
  private let preferredCompactColumn: Binding<NavigationSplitViewColumn>
  private let focus: Binding<FocusID?>
  private let focusTargets: Binding<[NavigationSplitViewColumn: FocusID?]>
  private let sidebar: Sidebar
  private let content: Content
  private let presentationState: _NavigationPresentationState
  private let detail: Detail

  private var layout: _NavigationSplitLayout {
    _NavigationSplitLayout(
      visibility: columnVisibility.wrappedValue,
      preferredCompactColumn: preferredCompactColumn.wrappedValue,
      presentationState: presentationState
    )
  }
  /// Creates a three-role navigation split view.
  public init(
    columnVisibility: Binding<NavigationSplitViewVisibility> = .constant(.all),
    preferredCompactColumn: Binding<NavigationSplitViewColumn> = .constant(.content),
    focus: Binding<FocusID?> = .constant(nil),
    focusTargets: Binding<[NavigationSplitViewColumn: FocusID?]> = .constant([:]),
    @ViewBuilder sidebar: () -> Sidebar,
    @ViewBuilder content: () -> Content,
    @ViewBuilder detail: () -> Detail
  ) {
    self.columnVisibility = columnVisibility
    self.preferredCompactColumn = preferredCompactColumn
    self.focus = focus
    self.focusTargets = focusTargets
    self.sidebar = sidebar()
    self.content = content()
    self.presentationState = _NavigationPresentationState()
    self.detail = detail()
  }

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    visitControlBar(
      .sidebar, in: environment, overrides: environmentOverrides, visit: visit)
    visitColumn(
      .sidebar, content: sidebar, in: environment, overrides: environmentOverrides,
      visit: visit)
    visitDivider(
      .sidebar, .content, in: environment, overrides: environmentOverrides, visit: visit)
    visitColumn(
      .content, content: content, in: environment, overrides: environmentOverrides,
      visit: visit)
    visitDivider(
      .content, .detail, in: environment, overrides: environmentOverrides, visit: visit)
    visitColumn(
      .detail, content: detail, in: environment, overrides: environmentOverrides,
      visit: visit)
    visitControlBar(
      .detail, in: environment, overrides: environmentOverrides, visit: visit)
  }

  package func _sizeThatFits(
    _ proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) -> TerminalSize {
    layout.sizeThatFits(proposal, subviews: Subviews(subviews))
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    layout.placeSubviews(in: bounds, proposal: proposal, subviews: Subviews(subviews))
  }

  private func visitColumn<Column: View>(
    _ column: NavigationSplitViewColumn,
    content: Column,
    in environment: EnvironmentValues,
    overrides: [String],
    visit: (_ViewChild) -> Void
  ) {
    var childEnvironment = environment
    if !columnVisibility.wrappedValue.contains(column) {
      childEnvironment.isEnabled = false
    }
    let columnView: any View
    if let storedTarget = focusTargets.wrappedValue[column], let target = storedTarget {
      columnView = _NavigationColumn(content: content).focused(focus, equals: target)
    } else {
      columnView = _NavigationColumn(content: content)
    }
    visit(
      _ViewChild(
        slot: .id(column),
        view: columnView,
        environment: childEnvironment,
        environmentOverrides: overrides
      ))
  }

  private func visitDivider(
    _ leading: NavigationSplitViewColumn,
    _ trailing: NavigationSplitViewColumn,
    in environment: EnvironmentValues,
    overrides: [String],
    visit: (_ViewChild) -> Void
  ) {
    var childEnvironment = environment
    childEnvironment._stackAxis = .horizontal
    visit(
      _ViewChild(
        slot: .explicit(
          AnyHashable(
            "divider.\(String(describing: leading)).\(String(describing: trailing))")),
        view: Divider(),
        environment: childEnvironment,
        environmentOverrides: overrides + ["stackAxis"]
      ))
  }

  private func visitControlBar(
    _ column: NavigationSplitViewColumn,
    in environment: EnvironmentValues,
    overrides: [String],
    visit: (_ViewChild) -> Void
  ) {
    visit(
      _ViewChild(
        slot: .explicit(AnyHashable("control.\(String(describing: column))")),
        view: _NavigationControlBar(
          column: column,
          visibility: columnVisibility,
          preferredCompactColumn: preferredCompactColumn,
          focus: focus,
          focusTargets: focusTargets,
          presentationState: presentationState
        ),
        environment: environment,
        environmentOverrides: overrides
      ))
  }
}

extension NavigationSplitView where Content == EmptyView {
  /// Creates a two-role navigation split view with sidebar and detail columns.
  public init(
    columnVisibility: Binding<NavigationSplitViewVisibility> = .constant(.doubleColumn),
    preferredCompactColumn: Binding<NavigationSplitViewColumn> = .constant(.detail),
    focus: Binding<FocusID?> = .constant(nil),
    focusTargets: Binding<[NavigationSplitViewColumn: FocusID?]> = .constant([:]),
    @ViewBuilder sidebar: () -> Sidebar,
    @ViewBuilder detail: () -> Detail
  ) {
    self.columnVisibility = columnVisibility
    self.preferredCompactColumn = preferredCompactColumn
    self.focus = focus
    self.focusTargets = focusTargets
    self.sidebar = sidebar()
    self.content = EmptyView()
    self.presentationState = _NavigationPresentationState()
    self.detail = detail()
  }
}

private struct _NavigationColumn<Content: View>: View, _LayoutView {
  typealias Body = Never
  let content: Content

  package func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    visit(
      _ViewChild(
        slot: .index(0),
        view: content,
        environment: environment,
        environmentOverrides: environmentOverrides
      ))
  }

  package func _sizeThatFits(_ proposal: ProposedSize, subviews: _LayoutSubviewsProxy)
    -> TerminalSize
  {
    guard let child = subviews.first else {
      return TerminalSize(columns: proposal.width ?? 2, rows: proposal.height ?? 0)
    }
    let measured = child.measure(proposal)
    return TerminalSize(
      columns: proposal.width ?? Swift.max(measured.columns, 2),
      rows: proposal.height ?? measured.rows
    )
  }

  package func _placeSubviews(
    in bounds: Rect,
    proposal: ProposedSize,
    subviews: _LayoutSubviewsProxy
  ) {
    subviews.first?.place(
      bounds.origin,
      ProposedSize(width: bounds.size.columns, height: bounds.size.rows)
    )
  }
}

private struct _NavigationSplitLayout: Layout {
  private struct Allocation {
    let extents: [Int]
    let dividerAfter: Set<Int>
    let total: Int
    let cross: Int
  }
  let visibility: NavigationSplitViewVisibility
  let preferredCompactColumn: NavigationSplitViewColumn
  let presentationState: _NavigationPresentationState

  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    let allocation = allocations(proposal: proposal, subviews: subviews)
    return TerminalSize(
      columns: proposal.width ?? allocation.total, rows: allocation.cross + 2)
  }

  func placeSubviews(in bounds: Rect, proposal: ProposedSize, subviews: Subviews) {
    let allocation = allocations(
      proposal: ProposedSize(width: bounds.size.columns, height: proposal.height),
      subviews: subviews
    )
    let roleIndices = [1, 3, 5]
    let crossOrigin = bounds.origin.row + 1
    let crossSize = Swift.max(bounds.size.rows - 2, 0)
    let controlHeight = bounds.size.rows >= 2 ? 1 : 0

    let top = Rect(
      origin: bounds.origin,
      size: TerminalSize(columns: Swift.max(bounds.size.columns, 0), rows: controlHeight)
    )
    subviews[0].place(
      at: top.origin,
      proposal: ProposedSize(width: top.size.columns, height: top.size.rows), clip: top)

    var origin = bounds.origin.column
    for rolePosition in roleIndices.indices {
      let subviewIndex = roleIndices[rolePosition]
      let extent = allocation.extents[subviewIndex]
      let roleFrame = Rect(
        origin: TerminalPosition(column: origin, row: crossOrigin),
        size: TerminalSize(columns: extent, rows: crossSize)
      )
      subviews[subviewIndex].place(
        at: roleFrame.origin,
        proposal: ProposedSize(width: roleFrame.size.columns, height: roleFrame.size.rows),
        clip: roleFrame
      )
      origin += extent
      guard allocation.dividerAfter.contains(rolePosition) else { continue }
      let dividerFrame = Rect(
        origin: TerminalPosition(column: origin, row: crossOrigin),
        size: TerminalSize(columns: 1, rows: crossSize)
      )
      subviews[subviewIndex + 1].place(
        at: dividerFrame.origin,
        proposal: ProposedSize(width: 1, height: crossSize),
        clip: dividerFrame
      )
      origin += 1
    }

    for rolePosition in 0..<2 where !allocation.dividerAfter.contains(rolePosition) {
      let dividerIndex = roleIndices[rolePosition] + 1
      let zero = Rect(
        origin: TerminalPosition(column: origin, row: crossOrigin),
        size: TerminalSize(columns: 0, rows: 0)
      )
      subviews[dividerIndex].place(
        at: zero.origin, proposal: ProposedSize(width: 0, height: 0), clip: zero)
    }
    let bottomOrigin = TerminalPosition(
      column: bounds.origin.column,
      row: bounds.size.rows >= 2
        ? bounds.origin.row + bounds.size.rows - 1 : bounds.origin.row
    )
    let bottom = Rect(
      origin: bottomOrigin,
      size: TerminalSize(columns: Swift.max(bounds.size.columns, 0), rows: controlHeight)
    )
    subviews[6].place(
      at: bottom.origin,
      proposal: ProposedSize(width: bottom.size.columns, height: bottom.size.rows),
      clip: bottom)
  }

  private func allocations(proposal: ProposedSize, subviews: Subviews) -> Allocation {
    let roles = [1, 3, 5]
    let natural = roles.map {
      subviews[$0].sizeThatFits(ProposedSize(width: nil, height: proposal.height))
    }
    let naturalMain = natural.map { Swift.max($0.columns, 2) }
    let availableColumns = [NavigationSplitViewColumn.sidebar, .content, .detail]
    let available = proposal.width
    let visibleIndices = availableColumns.indices.filter {
      visibility.contains(availableColumns[$0])
    }
    let regularNatural =
      visibleIndices.reduce(0) { $0 + naturalMain[$1] }
      + (visibleIndices.count > 1 ? visibleIndices.count - 1 : 0)
    let compact = available.map { $0 < regularNatural } ?? false
    presentationState.isCompact = compact
    let selected: [Int]
    if compact {
      let preferred = visibleIndices.first {
        availableColumns[$0] == preferredCompactColumn
      }
      selected = [preferred ?? visibleIndices.first].compactMap(\.self)
    } else {
      selected = visibleIndices
    }
    var extents = Array(repeating: 0, count: subviews.count)
    guard selected.isEmpty == false else {
      return Allocation(extents: extents, dividerAfter: [], total: 0, cross: 0)
    }
    let cross = natural.map(\.rows).max() ?? 0
    if selected.count == 1 {
      let width = Swift.max(available ?? naturalMain[selected[0]], 0)
      extents[selected[0] * 2 + 1] = width
      return Allocation(extents: extents, dividerAfter: [], total: width, cross: cross)
    }
    var items: [_FlexResolverItem] = []
    for (offset, index) in selected.enumerated() {
      items.append(
        .range(minimum: 0, ideal: naturalMain[index], maximum: nil, priority: 0))
      if offset < selected.count - 1 { items.append(.fixed(1)) }
    }
    let resolved = _FlexResolver.resolve(available: available, spacing: 0, items: items)
    var dividerAfter: Set<Int> = []
    var itemIndex = 0
    for (offset, index) in selected.enumerated() {
      extents[index * 2 + 1] = resolved.allocations[itemIndex]
      itemIndex += 1
      if offset < selected.count - 1 {
        dividerAfter.insert(offset)
        extents[index * 2 + 2] = 1
        itemIndex += 1
      }
    }
    return Allocation(
      extents: extents, dividerAfter: dividerAfter, total: resolved.total, cross: cross)
  }
}
