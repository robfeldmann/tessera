import TesseraCore
import TesseraTerminalCore

/// Selects the glyph weight used for a scroll indicator thumb.
public enum ScrollIndicatorWeight: Equatable, Sendable {
  /// A solid-block thumb.
  case block
  /// A thin heavy-line thumb.
  case line
  /// A half-block thumb.
  case mid
}

/// Selects the treatment used for a scroll indicator track.
public enum ScrollIndicatorTrack: Equatable, Sendable {
  /// A dashed rule behind the thumb.
  case dashed
  /// No rule; only the thumb is painted.
  case none
  /// A continuous rule behind the thumb.
  case solid
}

private enum _ScrollIndicatorWeightKey: EnvironmentKey {
  static let defaultValue = ScrollIndicatorWeight.line
}

private enum _ScrollIndicatorTrackKey: EnvironmentKey {
  static let defaultValue = ScrollIndicatorTrack.solid
}

extension EnvironmentValues {
  /// The glyph weight used for scroll indicator thumbs in this subtree.
  public var scrollIndicatorWeight: ScrollIndicatorWeight {
    get { self[_ScrollIndicatorWeightKey.self] }
    set { self[_ScrollIndicatorWeightKey.self] = newValue }
  }

  /// The track treatment used for scroll indicators in this subtree.
  public var scrollIndicatorTrack: ScrollIndicatorTrack {
    get { self[_ScrollIndicatorTrackKey.self] }
    set { self[_ScrollIndicatorTrackKey.self] = newValue }
  }
}

/// Layout metrics supplied by a parent that mounts a shared scroll indicator.
package final class _ScrollIndicatorMetrics {
  package var contentExtent = 0
  package var viewportExtent = 0
  package var effectiveOffset = 0

  package init() {}

  package func update(
    contentExtent: Int,
    viewportExtent: Int,
    effectiveOffset: Int
  ) {
    self.contentExtent = contentExtent
    self.viewportExtent = viewportExtent
    self.effectiveOffset = effectiveOffset
  }
}

/// An output-only proportional overflow indicator.
public struct ScrollIndicator: LeafView {
  public typealias Body = Never

  private struct Metrics {
    let contentExtent: Int
    let viewportExtent: Int
    let effectiveOffset: Int

    var normalized: NormalizedMetrics {
      let content = max(contentExtent, 1)
      let viewport = min(max(viewportExtent, 0), content)
      let maximumOffset = content - viewport
      return NormalizedMetrics(
        contentExtent: content,
        viewportExtent: viewport,
        effectiveOffset: min(max(effectiveOffset, 0), maximumOffset),
        maximumOffset: maximumOffset
      )
    }
  }

  private struct NormalizedMetrics {
    let contentExtent: Int
    let viewportExtent: Int
    let effectiveOffset: Int
    let maximumOffset: Int
  }

  private struct Geometry {
    let trackLength: Int
    let thumbLength: Int
    let thumbStart: Int
  }

  private let axis: Axis
  private let metrics: Metrics
  private let liveMetrics: _ScrollIndicatorMetrics?

  private var resolvedMetrics: Metrics {
    guard let liveMetrics else {
      return metrics
    }

    return Metrics(
      contentExtent: liveMetrics.contentExtent,
      viewportExtent: liveMetrics.viewportExtent,
      effectiveOffset: liveMetrics.effectiveOffset
    )
  }

  /// Creates an output-only indicator for one scroll axis.
  public init(
    axis: Axis,
    contentExtent: Int,
    viewportExtent: Int,
    effectiveOffset: Int
  ) {
    self.axis = axis
    metrics = Metrics(
      contentExtent: contentExtent,
      viewportExtent: viewportExtent,
      effectiveOffset: effectiveOffset
    )
    liveMetrics = nil
  }

  package init(axis: Axis, metrics: _ScrollIndicatorMetrics) {
    self.axis = axis
    self.metrics = Metrics(contentExtent: 0, viewportExtent: 0, effectiveOffset: 0)
    liveMetrics = metrics
  }

  /// Computes `floor(lhs * rhs / divisor)` without overflowing its intermediate product.
  private static func floorProduct(_ lhs: Int, _ rhs: Int, _ divisor: Int) -> Int {
    guard lhs > 0, rhs > 0 else {
      return 0
    }

    let product = lhs.multipliedFullWidth(by: rhs)
    return divisor.dividingFullWidth(product).quotient
  }

  public func sizeThatFits(
    _ proposal: ProposedSize,
    state: inout Void,
    environment: EnvironmentValues
  ) -> TerminalSize {
    let naturalTrackLength = resolvedMetrics.normalized.viewportExtent

    switch axis {
    case .vertical:
      return TerminalSize(
        columns: crossAxisLength(proposal.width),
        rows: primaryAxisLength(proposal.height, natural: naturalTrackLength)
      )
    case .horizontal:
      return TerminalSize(
        columns: primaryAxisLength(proposal.width, natural: naturalTrackLength),
        rows: crossAxisLength(proposal.height)
      )
    }
  }

  public func render(
    in region: inout RenderRegion,
    state: inout Void,
    environment: EnvironmentValues
  ) {
    guard !region.bounds.isEmpty else {
      return
    }

    let trackLength =
      switch axis {
      case .vertical: max(region.bounds.size.rows, 0)
      case .horizontal: max(region.bounds.size.columns, 0)
      }
    let geometry = geometry(trackLength: trackLength)
    guard geometry.trackLength > 0 else {
      return
    }

    let thumbStyle =
      environment.isFocused
      ? Style(foreground: environment.semanticStyles.focus.background).bold()
      : environment.semanticStyles.accent
    let thumbGlyph = thumbGlyph(for: environment.scrollIndicatorWeight)
    let trackGlyph = trackGlyph(for: environment.scrollIndicatorTrack)
    let thumbEnd = geometry.thumbStart + geometry.thumbLength

    for primary in 0..<geometry.trackLength {
      let position =
        switch axis {
        case .vertical:
          TerminalPosition(column: 0, row: primary)
        case .horizontal:
          TerminalPosition(column: primary, row: 0)
        }

      if primary >= geometry.thumbStart && primary < thumbEnd {
        region.write(thumbGlyph, at: position, style: thumbStyle)
      } else if let trackGlyph {
        region.write(trackGlyph, at: position, style: environment.semanticStyles.secondary)
      }
    }
  }

  private func geometry(trackLength: Int) -> Geometry {
    let trackLength = max(trackLength, 0)
    guard trackLength > 0 else {
      return Geometry(trackLength: 0, thumbLength: 0, thumbStart: 0)
    }

    let metrics = resolvedMetrics.normalized
    let thumbLength = min(
      max(
        1, Self.floorProduct(trackLength, metrics.viewportExtent, metrics.contentExtent)),
      trackLength
    )
    let thumbStart = Self.floorProduct(
      metrics.effectiveOffset,
      trackLength - thumbLength,
      max(metrics.maximumOffset, 1)
    )

    return Geometry(
      trackLength: trackLength,
      thumbLength: thumbLength,
      thumbStart: thumbStart
    )
  }

  private func primaryAxisLength(_ proposal: Int?, natural: Int) -> Int {
    max(proposal ?? natural, 0)
  }

  private func crossAxisLength(_ proposal: Int?) -> Int {
    guard proposal ?? 1 > 0 else {
      return 0
    }

    return 1
  }

  private func thumbGlyph(for weight: ScrollIndicatorWeight) -> String {
    switch (axis, weight) {
    case (.vertical, .line): "┃"
    case (.vertical, .mid): "▐"
    case (.vertical, .block): "█"
    case (.horizontal, .line): "━"
    case (.horizontal, .mid): "▄"
    case (.horizontal, .block): "■"
    }
  }

  private func trackGlyph(for track: ScrollIndicatorTrack) -> String? {
    switch (axis, track) {
    case (_, .none): nil
    case (.vertical, .solid): "│"
    case (.vertical, .dashed): "╎"
    case (.horizontal, .solid): "─"
    case (.horizontal, .dashed): "╌"
    }
  }

}
