import Foundation
import TesseraCore
import TesseraLayout
import TesseraTerminalCore
import TesseraTerminalInput

/// A controlled, single-line text editor.
///
/// The application owns `text`. Editing writes accepted changes through that binding;
/// caret, selection, and horizontal reveal are disposable view state. This editor accepts
/// committed terminal input and bracketed paste, but it does not implement an IME pre-edit
/// buffer or secure-entry masking.
public struct TextField<Label: View>: View, _FocusAppearanceResponder {
  private let text: Binding<String>
  private let prompt: Text?
  private let onSubmit: ((String) -> Void)?
  private let label: Label

  public var body: some View {
    EnvironmentReader { environment in
      VStack(alignment: .leading, spacing: 0) {
        label
        _TextFieldEditor(
          text: text,
          prompt: prompt,
          onSubmit: onSubmit,
          isEnabled: environment.isEnabled
        )
      }
    }
  }

  private init(
    text: Binding<String>,
    prompt: Text?,
    onSubmit: ((String) -> Void)?,
    label: Label
  ) {
    self.text = text
    self.prompt = prompt
    self.onSubmit = onSubmit
    self.label = label
  }

  /// Creates a controlled text field with a custom label view.
  public init(
    text: Binding<String>,
    prompt: Text? = nil,
    onSubmit: ((String) -> Void)? = nil,
    @ViewBuilder label: () -> Label
  ) {
    self.init(text: text, prompt: prompt, onSubmit: onSubmit, label: label())
  }
}

extension TextField where Label == Text {
  /// Creates a controlled text field with a text label.
  public init(
    _ title: String,
    text: Binding<String>,
    prompt: Text? = nil,
    onSubmit: ((String) -> Void)? = nil
  ) {
    self.init(text: text, prompt: prompt, onSubmit: onSubmit, label: Text(title))
  }
}

extension TextField where Label == EmptyView {
  /// Creates a controlled text field without a label.
  public init(
    text: Binding<String>,
    prompt: Text? = nil,
    onSubmit: ((String) -> Void)? = nil
  ) {
    self.init(text: text, prompt: prompt, onSubmit: onSubmit, label: EmptyView())
  }
}
