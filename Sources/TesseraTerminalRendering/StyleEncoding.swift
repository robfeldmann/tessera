import TesseraTerminalANSI
import TesseraTerminalBuffer

package func sgrDelta(
  from oldStyle: Style?,
  to newStyle: Style,
  colorCapability: ColorCapability,
  into bytes: inout [UInt8]
) {
  let resolvedNewStyle = newStyle.resolvedForSGR(colorCapability: colorCapability)
  guard let oldStyle else {
    ControlSequence.resetAttributes.encode(into: &bytes)
    encodeFullStyle(resolvedNewStyle, into: &bytes)
    return
  }

  let resolvedOldStyle = oldStyle.resolvedForSGR(colorCapability: colorCapability)
  guard resolvedOldStyle.sgrAttributes != resolvedNewStyle.sgrAttributes else {
    return
  }

  if requiresReset(from: resolvedOldStyle, to: resolvedNewStyle) {
    ControlSequence.resetAttributes.encode(into: &bytes)
    encodeFullStyle(resolvedNewStyle, into: &bytes)
    return
  }

  if resolvedOldStyle.foreground != resolvedNewStyle.foreground {
    ControlSequence.setForeground(resolvedNewStyle.foreground).encode(into: &bytes)
  }
  if resolvedOldStyle.background != resolvedNewStyle.background {
    ControlSequence.setBackground(resolvedNewStyle.background).encode(into: &bytes)
  }

  encodeAddedAttributes(
    from: resolvedOldStyle.attributes,
    to: resolvedNewStyle.attributes,
    into: &bytes
  )
}

/// Emits every non-default SGR facet of `style` from a clean reset state.
///
/// - Precondition: `style` colors must already be degraded to the terminal's
///   `ColorCapability` (call `Style.resolvedForSGR` first). `sgrDelta` resolves
///   both styles once at the top, so this function never re-resolves.
package func encodeFullStyle(
  _ style: Style,
  into bytes: inout [UInt8]
) {
  if style.foreground != .default {
    ControlSequence.setForeground(style.foreground).encode(into: &bytes)
  }
  if style.background != .default {
    ControlSequence.setBackground(style.background).encode(into: &bytes)
  }
  encodeAddedAttributes(from: [], to: style.attributes, into: &bytes)
}

private func requiresReset(from oldStyle: Style, to newStyle: Style) -> Bool {
  oldStyle.attributes.subtracting(newStyle.attributes).isEmpty == false
    || (oldStyle.foreground != .default && newStyle.foreground == .default)
    || (oldStyle.background != .default && newStyle.background == .default)
}

private func encodeAddedAttributes(
  from oldAttributes: TextAttributes,
  to newAttributes: TextAttributes,
  into bytes: inout [UInt8]
) {
  let addedAttributes = newAttributes.subtracting(oldAttributes)

  if addedAttributes.contains(.bold) {
    ControlSequence.setBold(true).encode(into: &bytes)
  }
  if addedAttributes.contains(.dim) {
    ControlSequence.setDim(true).encode(into: &bytes)
  }
  if addedAttributes.contains(.italic) {
    ControlSequence.setItalic(true).encode(into: &bytes)
  }
  if addedAttributes.contains(.reverse) {
    ControlSequence.setReverse(true).encode(into: &bytes)
  }
  if addedAttributes.contains(.strikethrough) {
    ControlSequence.setStrikethrough(true).encode(into: &bytes)
  }
  if addedAttributes.contains(.underline) {
    ControlSequence.setUnderline(true).encode(into: &bytes)
  }
}

extension Style {
  fileprivate var sgrAttributes: SGRAttributes {
    SGRAttributes(foreground: foreground, background: background, attributes: attributes)
  }

  fileprivate func resolvedForSGR(colorCapability: ColorCapability) -> Style {
    Style(
      foreground: foreground.resolved(for: colorCapability),
      background: background.resolved(for: colorCapability),
      attributes: attributes,
      hyperlink: hyperlink
    )
  }
}

private struct SGRAttributes: Equatable {
  var foreground: Color
  var background: Color
  var attributes: TextAttributes
}
