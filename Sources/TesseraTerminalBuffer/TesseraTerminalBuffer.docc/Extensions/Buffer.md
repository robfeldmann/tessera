# ``Buffer``

A fixed-size, row-major store of terminal cells. Buffer writes preserve grapheme widths: a wide grapheme occupies its leading cell and records ``Cell/Content/continuation`` in every trailing column it covers.

Use raw regions when terminal output belongs to an external payload rather than a printable grapheme. Their continuation cells preserve the occupied geometry, while their repaint policy communicates how they participate in damage tracking.

## Topics

### Creating a buffer

- ``init(size:fill:)``
- ``size``

### Accessing cells

- ``cell(row:column:)``
- ``subscript(_:_:)``

### Mutating cells

- ``clear(fill:)``
- ``write(_:at:style:)``
- ``write(grapheme:at:style:)``

### Managing raw regions

- ``writeRaw(_:at:occupying:repaintPolicy:)``
- ``markOpaque(_:)``
