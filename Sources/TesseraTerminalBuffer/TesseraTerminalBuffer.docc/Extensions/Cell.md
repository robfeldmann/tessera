# ``Cell``

A cell carries both terminal content and the state needed to compare it for damage. Printable graphemes retain the grapheme cluster supplied by Swift string iteration. Wide graphemes and raw regions use ``Cell/Content/continuation`` cells to represent every covered column explicitly.

## Topics

### Inspecting contents

- ``content``
- ``style``
- ``diffPolicy``
- ``width``

### Creating cells

- ``init(content:style:diffPolicy:)``
- ``init(character:style:)``
- ``blank``

### Understanding cell semantics

- ``Cell/Content``
- ``CellDiffPolicy``
