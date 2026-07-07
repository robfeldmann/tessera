import TesseraTerminalANSI
import TesseraTerminalBuffer

package func sgrDelta(
  from oldStyle: Style?,
  to newStyle: Style,
  into bytes: inout [UInt8]
) {
  guard let oldStyle else {
    ControlSequence.resetAttributes.encode(into: &bytes)
    encodeFullStyle(newStyle, into: &bytes)
    return
  }

  guard oldStyle.sgrAttributes != newStyle.sgrAttributes else {
    return
  }

  if requiresReset(from: oldStyle, to: newStyle) {
    ControlSequence.resetAttributes.encode(into: &bytes)
    encodeFullStyle(newStyle, into: &bytes)
    return
  }

  if oldStyle.foreground != newStyle.foreground {
    ControlSequence.setForeground(newStyle.foreground).encode(into: &bytes)
  }
  if oldStyle.background != newStyle.background {
    ControlSequence.setBackground(newStyle.background).encode(into: &bytes)
  }

  encodeAddedAttributes(from: oldStyle.attributes, to: newStyle.attributes, into: &bytes)
}

package func encodeFullStyle(_ style: Style, into bytes: inout [UInt8]) {
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
}

private struct SGRAttributes: Equatable {
  var foreground: Color
  var background: Color
  var attributes: TextAttributes
}
