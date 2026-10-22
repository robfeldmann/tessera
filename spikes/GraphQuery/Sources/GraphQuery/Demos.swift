import Tessera

/// Places two children on one row with the second shifted into the first, so siblings
/// overlap on purpose.
struct StaggerLayout: Layout {
  func sizeThatFits(_ proposal: ProposedSize, subviews: Subviews) -> TerminalSize {
    TerminalSize(
      columns: subviews.map { $0.sizeThatFits(.unspecified).columns }.max() ?? 0,
      rows: 1
    )
  }

  func placeSubviews(in bounds: Rect, proposal: ProposedSize, subviews: Subviews) {
    for (index, subview) in subviews.enumerated() {
      subview.place(
        at: TerminalPosition(column: bounds.origin.column + index * 3, row: bounds.origin.row),
        proposal: .unspecified
      )
    }
  }
}

/// A named fixture app for the `graphquery` executable and the tests.
public struct Demo: Sendable {
  public let defaultSize: TerminalSize
  public let makeSession: @Sendable (TerminalSize) -> GraphSession
  public let name: String
  public let summary: String

  public static let all: [Demo] = [clipped, hello, ids, nestedForEach, overlap, scroll, wide]

  public static func named(_ name: String) -> Demo? {
    all.first { $0.name == name }
  }

  /// A long `Text` squeezed into an 8-column frame: its frame outgrows its clip.
  public static let clipped = Demo(
    defaultSize: TerminalSize(columns: 40, rows: 8),
    makeSession: { size in
      GraphSession(size: size) {
        VStack(alignment: .leading) {
          Text("This line is far too long").frame(width: 8)
          Text("fits")
        }
      }
    },
    name: "clipped",
    summary: "a Text wider than its fixed frame (frame-inside-clip, measured-within-proposal)"
  )

  /// `Hello`, a row that spreads with the width, and `World`.
  public static let hello = Demo(
    defaultSize: TerminalSize(columns: 80, rows: 24),
    makeSession: { size in
      GraphSession(size: size) {
        VStack(alignment: .leading) {
          Text("Hello")
          HStack(spacing: 1) {
            Text("Left")
            Spacer()
            Text("Right")
          }
          Text("World")
        }
      }
    },
    name: "hello",
    summary: "Text, VStack and HStack with a Spacer; frames change on resize"
  )

  /// Explicit `.id` values, the only user-supplied identities besides `ForEach` keys.
  public static let ids = Demo(
    defaultSize: TerminalSize(columns: 20, rows: 4),
    makeSession: { size in
      GraphSession(size: size) {
        VStack(alignment: .leading) {
          Text("Submit").id("submit")
          Text("Cancel").id("cancel")
        }
      }
    },
    name: "ids",
    summary: "explicit identities; `id=` matches them"
  )

  /// A keyed `ForEach` inside a stack. At the commit this spike ran against, the stack
  /// does not flatten it, so its items share one frame.
  public static let nestedForEach = Demo(
    defaultSize: TerminalSize(columns: 20, rows: 4),
    makeSession: { size in
      GraphSession(size: size) {
        VStack(alignment: .leading) {
          Text("Submit")
          ForEach(["a", "b"], id: \.self) { key in
            Text("item \(key)")
          }
        }
      }
    },
    name: "nested-foreach",
    summary: "ForEach inside a VStack: its items overlay each other (siblings-disjoint)"
  )

  /// A custom layout that overlaps its children (a bug) beside a `ZStack` (by design).
  public static let overlap = Demo(
    defaultSize: TerminalSize(columns: 40, rows: 8),
    makeSession: { size in
      GraphSession(size: size) {
        VStack(alignment: .leading) {
          StaggerLayout() {
            Text("AAAAAA")
            Text("BBBB")
          }
          ZStack {
            Text("base....")
            Text("top")
          }
        }
      }
    },
    name: "overlap",
    summary: "overlapping siblings under a custom Layout; legitimate overlap under ZStack"
  )

  /// Content taller than its viewport, clipped by design.
  public static let scroll = Demo(
    defaultSize: TerminalSize(columns: 20, rows: 4),
    makeSession: { size in
      GraphSession(size: size) {
        ScrollView {
          VStack(alignment: .leading) {
            Text("row 0")
            Text("row 1")
            Text("row 2")
            Text("row 3")
            Text("row 4")
            Text("row 5")
          }
        }
      }
    },
    name: "scroll",
    summary: "ScrollView content that is clipped by design (frame-inside-clip exempt)"
  )

  /// Wide graphemes, whose second cell is a blank spacer on the screen.
  public static let wide = Demo(
    defaultSize: TerminalSize(columns: 20, rows: 3),
    makeSession: { size in
      GraphSession(size: size) {
        VStack(alignment: .leading) {
          Text("日本語 ok")
          Text("👍 done")
        }
      }
    },
    name: "wide",
    summary: "double-width graphemes; text attribution elides spacer cells"
  )
}
