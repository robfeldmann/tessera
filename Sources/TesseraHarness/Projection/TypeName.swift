/// Short, stable names for the reflected type names a node reports.
///
/// `NodeDiagnostics.viewType` is `String(reflecting:)` of the view type, which is right for a
/// debugger and wrong for a golden: `TesseraLayout.(unknown context at $104f0c1a8)._FrameLayout`
/// names a private type by a build-specific address, and a generic view carries all its
/// arguments. The projection reports the short `type` (`Text`, `VStack`, `_LayoutContainer`)
/// and, for a `_LayoutContainer`, the short `layout` of its algorithm (`_FrameLayout`,
/// `_PaddingLayout`, or the name of an app's own `Layout`), and never the reflected name.
enum TypeName {
  /// The generic-free, module-qualified names of the view lists: the structural views that
  /// `_ViewList` marks in `TesseraCore`, and the `Optional` an `if` without an `else` builds.
  private static let viewLists: Set<String> = [
    "TesseraCore.ConditionalView", "TesseraCore.EmptyView", "TesseraCore.ForEach",
    "TesseraCore.TupleView", "Swift.Optional",
  ]

  /// `TesseraLayout.VStack<TesseraCore.TupleView<…>>` becomes `VStack`.
  static func short(_ reflected: String) -> String {
    lastComponent(of: genericFree(reflected))
  }

  /// Whether the reflected type is one of the library's view lists, which layout looks through.
  ///
  /// The module-qualified name decides, before it is shortened: a view of an app's own that
  /// happens to be called `ForEach` or `TupleView` is a composite with one child, not a list.
  static func isViewList(_ reflected: String) -> Bool {
    viewLists.contains(genericFree(reflected))
  }

  /// The short name of the algorithm of a `_LayoutContainer<Algorithm, Content>`, or `nil`
  /// for any other type.
  static func layout(of reflected: String) -> String? {
    guard short(reflected) == "_LayoutContainer", let open = reflected.firstIndex(of: "<")
    else {
      return nil
    }
    var depth = 0
    var argument = ""
    for character in reflected[reflected.index(after: open)...] {
      switch character {
      case "<", "(":
        depth += 1
      case ">", ")":
        if depth == 0 {
          return finish(argument)
        }
        depth -= 1
      case "," where depth == 0:
        return finish(argument)
      default:
        break
      }
      argument.append(character)
    }
    return finish(argument)
  }

  private static func finish(_ argument: String) -> String? {
    let name = short(argument.trimmingSpaces())
    return name.isEmpty ? nil : name
  }

  /// The name without its generic argument lists, so `A.B<C>.D<E>` is `A.B.D`. Angle brackets
  /// inside a parenthesised context stay with it.
  private static func genericFree(_ name: String) -> String {
    var result = ""
    var parentheses = 0
    var angles = 0
    for character in name {
      if character == "(" {
        parentheses += 1
      } else if character == ")" {
        parentheses -= 1
      } else if character == "<", parentheses == 0 {
        angles += 1
        continue
      } else if character == ">", parentheses == 0, angles > 0 {
        angles -= 1
        continue
      }
      if angles == 0 {
        result.append(character)
      }
    }
    return result
  }

  /// The last `.`-separated component, where a parenthesised context such as
  /// `(unknown context at $…)` is one component whatever it contains.
  private static func lastComponent(of name: String) -> String {
    var components: [String] = []
    var current = ""
    var parentheses = 0
    for character in name {
      if character == "(" {
        parentheses += 1
      } else if character == ")" {
        parentheses -= 1
      }
      if character == ".", parentheses == 0 {
        components.append(current)
        current = ""
      } else {
        current.append(character)
      }
    }
    components.append(current)
    return components.last { !$0.isEmpty } ?? name
  }
}

extension String {
  /// The string without leading or trailing spaces.
  fileprivate func trimmingSpaces() -> String {
    var scalars = Substring(self)
    while scalars.first == " " {
      scalars.removeFirst()
    }
    while scalars.last == " " {
      scalars.removeLast()
    }
    return String(scalars)
  }
}
