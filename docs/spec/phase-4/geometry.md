---
type: spec
description: "Geometry"
---

# Geometry

These types live in `TesseraTerminalCore` (the rendering and view layers both need them;
Phase 2 Slice 4's `writeRaw`/`markOpaque` introduce `Rect`, and Phase 4 adds `EdgeInsets`
and any helpers it needs):

```swift
public struct Rect: Sendable, Hashable {
    public var origin: TerminalPosition
    public var size: TerminalSize

    public init(origin: TerminalPosition, size: TerminalSize)
    public init(column: Int, row: Int, columns: Int, rows: Int)

    public static let zero: Rect
    public func intersection(_ other: Rect) -> Rect   // empty-safe
    public func contains(_ position: TerminalPosition) -> Bool
    public func inset(by edges: EdgeInsets) -> Rect   // clamps at zero size
}

public struct EdgeInsets: Sendable, Hashable {
    public var top, leading, bottom, trailing: Int
    public init(top: Int = 0, leading: Int = 0, bottom: Int = 0, trailing: Int = 0)
    public init(_ all: Int)
}
```

All geometry is integer cells. There are no fractional points anywhere in the view layer;
every rounding decision is explicit and documented at the algorithm that makes it.
