# ``Picker``

`Picker` renders the selected application-owned option inline with forward/backward
affordances. Arrow-key cycles do not wrap. An absent bound value renders an em dash until the
first valid cycle selects the first supplied option.

Pointer activation is scoped to the value slot and moves forward; chevrons are visual
affordances. Empty options and endpoint cycles bubble rather than mutating the binding.
