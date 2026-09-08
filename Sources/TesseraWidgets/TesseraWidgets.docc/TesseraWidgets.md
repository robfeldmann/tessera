# ``TesseraWidgets``

@Metadata {
    @PageImage(purpose: icon, source: "widgets-icon", alt: "Module icon.")
    @PageImage(purpose: card, source: "widgets-card", alt: "Module card.")
}

Reusable controls and view primitives built on Tessera's core and layout systems.

## Button

``Button`` owns only its action and label configuration. The action is application-owned;
the responder retains only ephemeral press state and projects ``ButtonStyleConfiguration``
to its rendered style. Legacy and `KeyEventSource.kittyPressOnly` Enter/Space reports
activate immediately on press. Explicit `KeyEventSource.kitty` phases show pressed state
from down through repeat until the matching release, then invoke the action once if the
button is still enabled and focused. Primary pointer down/up activation likewise requires
the graph's same-node capture; outside release cancels without invoking the action.

``ButtonStyleConfiguration/isPressed`` is visual feedback only. The current built-in
``CompactButtonStyle`` and ``PlainButtonStyle`` preserve the resolved role/focus/disabled
`Style` and add reverse video while pressed. That reverse-video projection is a
provisional implementation rule, not a new activation or styling API; custom styles
receive the same ``ButtonStyleConfiguration/isPressed`` value and must not redefine activation semantics.

The P4.3 implementation boundary does not claim hover, broad gestures, ScrollView or
TextField pointer behavior, or a bordered Button style. Those remain separate catalog
acceptance work. The design catalog therefore remains the authority for the larger Button
surface rather than graduating the whole mouse API from this focused slice.

### Topics

- ``Button``
- ``ButtonStyle``
- ``ButtonStyleConfiguration``
- ``CompactButtonStyle``
- ``PlainButtonStyle``
