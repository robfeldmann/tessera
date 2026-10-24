/// The vocabulary the parser accepts and the forms it names but refuses.
///
/// `Examples/Scenarios/README.md` is the grammar's single source; a test holds its "Not yet
/// expressible" table to ``notYetExpressible``, so the two cannot drift.
package enum ScenarioGrammar {
  /// A form the grammar names that the harness cannot honour yet.
  package struct Deferred: Equatable, Sendable {
    /// The form as the README's table writes it.
    package var form: String

    /// What the form waits for.
    package var needs: String
  }

  /// Every statement form that parses as "not yet expressible", never as a silent no-op.
  package static let notYetExpressible: [Deferred] = [
    Deferred(form: "wait", needs: "the schedulable clock"),
    Deferred(form: "settle", needs: "the schedulable clock"),
    Deferred(form: "focus", needs: "focus tracking and role and label locators"),
    Deferred(form: "mouse", needs: "pointer input and hit testing"),
    Deferred(form: "hit", needs: "pointer input and hit testing"),
    Deferred(form: "dump", needs: "the projection"),
    Deferred(form: "check", needs: "the invariant rules, which read the projection"),
    Deferred(form: "expect cell", needs: "style and role assertions on cells"),
    Deferred(form: "expect cost", needs: "the per-step cost counters"),
    Deferred(form: "expect focused", needs: "focus tracking"),
    Deferred(form: "expect wireframe", needs: "catalog conformance"),
    Deferred(form: "expect node SEL visible", needs: "the projection"),
    Deferred(form: "expect node SEL clipped", needs: "the projection"),
    Deferred(form: "expect node SEL count N", needs: "the projection"),
    Deferred(form: "shot NAME SEL", needs: "selectors over the projection"),
    Deferred(form: "tree SEL", needs: "selectors over the projection"),
    Deferred(form: "term glyphs=", needs: "ASCII glyph fallbacks in the views"),
    Deferred(form: "term keyboard=", needs: "key routing that depends on the protocol"),
    Deferred(form: "term theme=probe", needs: "semantic roles"),
  ]

  /// The statements a scenario may use, for the error that names the vocabulary.
  static let acceptedStatements =
    "app, size, term, resize, key, type, paste, bytes, shot, tree, "
    + "expect text, expect screen, expect node"

  /// The refusal for a form that is named but not yet expressible.
  static func refusal(_ form: String) -> String {
    let needs = notYetExpressible.first { $0.form == form }?.needs ?? "a later release"
    return
      "`\(form)` is not yet expressible: it needs \(needs). "
      + "See the \"Not yet expressible\" table in Examples/Scenarios/README.md; "
      + "accepted: \(acceptedStatements)"
  }
}
