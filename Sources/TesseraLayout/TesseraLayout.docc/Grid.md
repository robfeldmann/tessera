# ``Grid``

`Grid` is a row-major terminal layout that resolves each declared column with Tessera's
shared `FlexConstraint` allocator. Children occupy one source-order cell; spanning and
implicit sorting are intentionally not part of this surface.

Grid measures the largest child in each column for the column's ideal and minimum input,
resolves columns against the proposed width, then uses the largest child in each row as the
row height. Placement is clipped to the grid bounds and remains source ordered. Empty and
incomplete final rows do not create phantom children. A nonnegative cell spacing is applied
between resolved columns and rows.

Use `Grid(columns:spacing:)` when the content is a fixed collection of direct children or a
keyed `ForEach`. Identity and controlled state belong to those children and are not copied or
reordered by Grid.
