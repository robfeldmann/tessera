import Testing

@testable import TesseraHarness

struct TypeNameTests {
  @Test
  func `a short name drops the module and every generic argument`() {
    #expect(TypeName.short("TesseraCore.Text") == "Text")
    #expect(
      TypeName.short(
        "TesseraLayout.VStack<TesseraCore.TupleView<(TesseraCore.Text, Int)>>")
        == "VStack")
    #expect(TypeName.short("MyApp.Outer<Int>.Inner<String>") == "Inner")
    #expect(TypeName.short("Text") == "Text")
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
    #expect(TypeName.layout(of: frame) == "_FrameLayout")
    #expect(TypeName.layout(of: padding) == "_PaddingLayout")
    #expect(TypeName.layout(of: custom) == "Stagger")
  }

  @Test
  func `only a layout container has a layout`() {
    #expect(TypeName.layout(of: "TesseraLayout.HStack<TesseraCore.Text>") == nil)
    #expect(TypeName.layout(of: "TesseraCore.Text") == nil)
    #expect(TypeName.layout(of: "TesseraCore._LayoutContainer") == nil)
  }

  @Test
  func `the library's view lists are lists whatever they hold`() {
    #expect(
      TypeName.isViewList(
        "TesseraCore.ForEach<Swift.Array<Swift.String>, TesseraCore.Text>"))
    #expect(
      TypeName.isViewList("TesseraCore.TupleView<(TesseraCore.Text, TesseraCore.Text)>"))
    #expect(
      TypeName.isViewList(
        "TesseraCore.ConditionalView<TesseraCore.Text, TesseraCore.Text>"))
    #expect(TypeName.isViewList("TesseraCore.EmptyView"))
    #expect(TypeName.isViewList("Swift.Optional<TesseraCore.Text>"))
  }

  @Test
  func `a view of an app's own with a list's name is not a list`() {
    #expect(!TypeName.isViewList("MyApp.ForEach"))
    #expect(!TypeName.isViewList("MyApp.TupleView<Swift.Int>"))
    #expect(!TypeName.isViewList("MyApp.Optional<TesseraCore.Text>"))
    #expect(!TypeName.isViewList("MyApp.Outer.EmptyView"))
    #expect(!TypeName.isViewList("ForEach"))
  }

  @Test
  func `a view that only has a list inside its arguments is not a list`() {
    #expect(
      !TypeName.isViewList("TesseraLayout.VStack<TesseraCore.TupleView<(Int, Int)>>"))
    #expect(!TypeName.isViewList("TesseraCore.Text"))
    #expect(!TypeName.isViewList("Swift.Array<TesseraCore.ForEach<Int, Int>>"))
  }
}
