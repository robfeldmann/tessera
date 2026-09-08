# ``TesseraWidgets``

@Metadata {
    @PageImage(purpose: icon, source: "widgets-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "widgets-card", alt: "Module card.")
}

Reusable controls and view primitives built on Tessera's core and layout systems.

## Button

``Button`` owns only its action and label configuration. The action is application-owned;
the responder retains only ephemeral press state and projects ``ButtonStyleConfiguration``
to its rendered style. Legacy and `TesseraTerminalInput/KeyEventSource/kittyPressOnly` Enter/Space reports
activate immediately on press. Explicit `TesseraTerminalInput/KeyEventSource/kitty` phases show pressed state
from down through repeat until the matching release, then invoke the action once if the
button is still enabled and focused. Primary pointer down/up activation likewise requires
the graph's same-node capture; outside release cancels without invoking the action.

``ButtonStyleConfiguration/isPressed`` is visual feedback only. The current built-in
``CompactButtonStyle`` and ``PlainButtonStyle`` preserve the resolved role/focus/disabled
`TesseraTerminalBuffer/Style` and add reverse video while pressed. That reverse-video projection is a
provisional implementation rule, not a new activation or styling API; custom styles
receive the same ``ButtonStyleConfiguration/isPressed`` value and must not redefine activation semantics.

Pointer activation and hover are separate contracts. Button uses same-node primary pointer
capture for activation; `TesseraCore/View/onHover(perform:)` reports motion enter/exit and does not
activate controls. Broad gesture recognition is not part of the widget layer. A bordered
button appearance and other custom styles remain catalog-defined presentation choices;
style configuration cannot change activation semantics.

## Controlled controls

``Toggle`` renders the application-owned `TesseraCore/Binding` value as an ASCII checkbox (`[x]` or
`[ ]`) followed by its required generic label. It composes ``Button`` for the established
Enter/Space and primary-pointer press/release lifecycle: phased input activates on matching
release, legacy press-only input activates immediately, and outside release cancels. The
binding is read on each reconciliation and only a valid activation writes its inverse.
Focus is explicit at the call site with `TesseraCore/View/focusable(_:)` and `TesseraCore/View/focused(_:equals:)`.

``Stepper`` renders one focused node as `[-] value [+]`. Its `TesseraCore/Binding` remains the source
of truth; values are formatted for display, valid Up/Right or Down/Left steps clamp to the
configured closed range, and out-of-range values remain visible until a user step repairs
them. Pointer presses are limited to the corresponding affordance and activate on a matching
same-affordance release. Endpoint affordances remain visible but inert.

``Picker`` renders the selected application-owned option inline as `‹ value ›`. Arrow keys
cycle without wrapping; an absent bound value remains an em-dash until the first valid cycle
chooses the first supplied option. Pointer activation is limited to the value slot and moves
forward, while chevrons remain visual affordances. Empty options and endpoint cycles bubble.

All three controls consume the inherited complete semantic `TesseraTerminalBuffer/Style` roles and enabled
environment. Disabled controls render with the disabled semantic style role, leave focusability
and bound values unchanged, and bubble keyboard/pointer input. Labels and option collections
are immutable configuration; application state is never copied into node state.

## Viewport and panes

- ``ScrollView`` presents content in a clamped cell-based viewport. An optional offset
  binding is the source of truth; keyboard and wheel/track input change that binding only
  while the viewport is focused and enabled. Focus reveal keeps the focused target visible,
  and overflow indicators occupy their reserved edge without obscuring content.
- ``SplitView`` consumes an application-owned array of keyed ``SplitViewPane`` values.
  Min/ideal/max sizing is negotiated in integer cells; collapsed panes are omitted from
  the visible sequence, and visible panes receive one-cell dividers. Keyboard resize and
  pointer divider drag update the pane binding rather than hidden widget state.
- ``NavigationSplitView`` composes sidebar, content, and detail roles. In regular space it
  lays out all visible roles; in compact space it presents one permitted role selected by
  the application-owned visibility and preferred-column bindings.

## Collections and editing

- ``List`` and ``Section`` derive keyed rows from the current collection. Selection is an
  application-owned identity binding; row focus, scroll offset, and indicator metrics are
  ephemeral graph state.
- ``Table`` derives keyed rows and measured columns. A sort descriptor records header intent;
  the application sorts its data and supplies the next collection. Selection and optional
  activation remain controlled bindings/closures.
- ``TextField`` is a controlled single-line editor. The binding owns text; the editor owns
  only disposable grapheme-local cursor, selection, and horizontal reveal state. It accepts
  committed input and bracketed paste, supports click-to-caret, and does not implement IME
  pre-edit or secure-entry masking.

All widgets preserve structural identity and controlled values across reconciliation.

### Topics

- ``Button``
- ``ButtonStyle``
- ``ButtonStyleConfiguration``
- ``CompactButtonStyle``
- ``PlainButtonStyle``
- ``Toggle``
- ``Stepper``
- ``Picker``
- ``ScrollView``
- ``SplitView``
- ``SplitViewPane``
- ``SplitViewPaneSizing``
- ``NavigationSplitView``
- ``NavigationSplitViewColumn``
- ``NavigationSplitViewVisibility``
- ``List``
- ``Section``
- ``Table``
- ``TableColumn``
- ``SortDescriptor``
- ``TableStyle``
- ``NavigationSplitViewStyle``
- ``AutomaticNavigationSplitViewStyle``
- ``TextField``
