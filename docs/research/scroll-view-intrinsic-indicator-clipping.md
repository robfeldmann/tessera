---
type: research
observed: 2026-08-26
status: resolved
description: ScrollView intrinsic indicator clipping
---

# ScrollView intrinsic indicator clipping

## Question

Why did the responder gallery's launcher row disappear as soon as its horizontal history began overflowing?

## Findings

- `ScrollView._sizeThatFits` returned the content's ideal height unchanged when its parent proposed a fixed width and an unspecified height.
- During placement, horizontal overflow correctly reserved a bottom indicator row inside that unchanged height. The viewport therefore became one row shorter than the measured content and clipped its final row. The responder gallery exposed this when its fifth content row, the focused launcher, disappeared behind the new indicator.
- A focused `ScrollViewTests` regression reproduced the mismatch: content measured `5x2` under `(3,nil)`, but the viewport measured only `3x2`; placement clipped content to `3x1` and put the indicator on row 1.
- The symmetric vertical case had the same latent defect when a parent supplied a fixed height and left width unspecified.

## Conclusion

`ScrollView` now includes the one-cell indicator edge in its natural cross-axis size when that axis is unspecified. Fixed proposals remain fixed and continue reserving indicators inside their assigned rectangle. Exhaustive horizontal and vertical regression snapshots confirm that content retains its full measured rows or columns and the indicator occupies the additional intrinsic edge.
