/// The vocabulary the parser accepts and the forms it names but refuses.
///
/// The grammar's source document keeps a table of the forms a scenario may not use; a test
/// holds it to ``notYetExpressible``, so the two cannot drift.
package enum ScenarioGrammar {
  /// A form the grammar names that the harness cannot honour yet.
  package struct Deferred: Equatable, Sendable {
    /// The form as the README's table writes it.
    package var form: String
  }

  /// Every statement form that parses as "not yet expressible", never as a silent no-op.
  package static let notYetExpressible: [Deferred] = [
    Deferred(form: "wait"),
    Deferred(form: "settle"),
    Deferred(form: "focus"),
    Deferred(form: "mouse"),
    Deferred(form: "hit"),
    Deferred(form: "dump"),
    Deferred(form: "check"),
    Deferred(form: "expect cell"),
    Deferred(form: "expect cost"),
    Deferred(form: "expect focused"),
    Deferred(form: "expect wireframe"),
    Deferred(form: "expect node SEL visible"),
    Deferred(form: "expect node SEL clipped"),
    Deferred(form: "expect node SEL count N"),
    Deferred(form: "shot NAME SEL"),
    Deferred(form: "tree SEL"),
    Deferred(form: "term glyphs="),
    Deferred(form: "term keyboard="),
    Deferred(form: "term theme=probe"),
  ]

  /// The statements a scenario may use, for the error that names the vocabulary.
  static let acceptedStatements =
    "app, size, term, resize, key, type, paste, bytes, shot, tree, "
    + "expect text, expect screen, expect node"

  /// The refusal for a form that is named and not supported.
  static func refusal(_ form: String) -> String {
    "`\(form)` is not a statement a scenario can use; accepted: \(acceptedStatements)"
  }
}
