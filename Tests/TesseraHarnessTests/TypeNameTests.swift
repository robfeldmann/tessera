import CustomDump
import Testing

@testable import TesseraHarness

struct TypeNameTests {
  @Test
  func `a short name drops the module and every generic argument`() {
    let reflected = [
      "TesseraCore.Text",
      "TesseraLayout.VStack<TesseraCore.TupleView<(TesseraCore.Text, Int)>>",
      "MyApp.Outer<Int>.Inner<String>", "Text",
    ]

    expectNoDifference(
      reflected.map(TypeName.short), ["Text", "VStack", "Inner", "Text"])
  }

  @Test
  func `a private type in another module keeps its name and loses its build address`() {
    let reflected = "TesseraLayout.(unknown context at $104f0c1a8)._FrameLayout"

    #expect(TypeName.short(reflected) == "_FrameLayout")
    #expect(!TypeName.short(reflected).contains("$"))
  }

  @Test
  func `a layout container reports the short name of its algorithm`() {
    let frame =
      "TesseraCore._LayoutContainer<TesseraLayout.(unknown context at $104f0c1a8)._FrameLayout, "
      + "TesseraCore.Text>"
    let padding =
      "TesseraCore._LayoutContainer<TesseraLayout.(unknown context at $1051d2e00)."
      + "_PaddingLayout, TesseraCore.ModifiedContent<TesseraCore.Text, Int>>"
    let custom = "TesseraCore._LayoutContainer<MyApp.Stagger<Int>, TesseraCore.Text>"

    #expect(TypeName.short(frame) == "_LayoutContainer")
    expectNoDifference(
      [frame, padding, custom].map(TypeName.layout(of:)),
      ["_FrameLayout", "_PaddingLayout", "Stagger"])
  }

  @Test
  func `only a layout container has a layout`() {
    let reflected = [
      "TesseraLayout.HStack<TesseraCore.Text>", "TesseraCore.Text",
      "TesseraCore._LayoutContainer",
    ]

    expectNoDifference(reflected.map(TypeName.layout(of:)), [nil, nil, nil])
  }

  @Test
  func `the library's view lists are lists whatever they hold`() {
    let lists = [
      "TesseraCore.ForEach<Swift.Array<Swift.String>, TesseraCore.Text>",
      "TesseraCore.TupleView<(TesseraCore.Text, TesseraCore.Text)>",
      "TesseraCore.ConditionalView<TesseraCore.Text, TesseraCore.Text>",
      "TesseraCore.EmptyView", "Swift.Optional<TesseraCore.Text>",
    ]

    expectNoDifference(lists.map(TypeName.isViewList), Array(repeating: true, count: 5))
  }

  @Test
  func `a view of an app's own with a list's name is not a list`() {
    let views = [
      "MyApp.ForEach", "MyApp.TupleView<Swift.Int>", "MyApp.Optional<TesseraCore.Text>",
      "MyApp.Outer.EmptyView", "ForEach",
    ]

    expectNoDifference(views.map(TypeName.isViewList), Array(repeating: false, count: 5))
  }

  @Test
  func `a view that only has a list inside its arguments is not a list`() {
    let views = [
      "TesseraLayout.VStack<TesseraCore.TupleView<(Int, Int)>>", "TesseraCore.Text",
      "Swift.Array<TesseraCore.ForEach<Int, Int>>",
    ]

    expectNoDifference(views.map(TypeName.isViewList), Array(repeating: false, count: 3))
  }
}
