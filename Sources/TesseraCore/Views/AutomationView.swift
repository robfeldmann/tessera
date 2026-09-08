/// A metadata-only structural annotation. It never participates in reconciliation keys.
package protocol _AutomationView: View {
  var automationIdentifier: String { get }
  var automationRole: AutomationRole { get }
}

private struct _AutomationModifier<Content: View>: View, _AutomationView, _StructuralView {
  typealias Body = Never

  let content: Content
  let automationIdentifier: String
  let automationRole: AutomationRole

  func _visitChildren(
    in environment: EnvironmentValues,
    environmentOverrides: [String],
    _ visit: (_ViewChild) -> Void
  ) {
    visit(
      _ViewChild(
        slot: .index(0),
        view: content,
        environment: environment,
        environmentOverrides: environmentOverrides
      )
    )
  }
}

extension View {
  /// Names a surface for explicit local automation without changing its reconciliation
  /// key, focus identity, or input routing. Roles describe the annotated subtree; they
  /// do not add behavior. Changing the identifier leaves existing runtime state intact.
  ///
  /// Duplicate identifiers are allowed in the view tree but fail exact selector lookup.
  /// No label, text, or application value is exported implicitly.
  public func automationID(_ identifier: String, role: AutomationRole) -> some View {
    _AutomationModifier(
      content: self, automationIdentifier: identifier, automationRole: role
    )
  }
}
