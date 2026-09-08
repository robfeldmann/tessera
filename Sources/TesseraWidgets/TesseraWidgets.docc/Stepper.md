# ``Stepper``

`Stepper` renders a focused value with decrement and increment affordances. Its binding
remains the source of truth. Valid Up/Right and Down/Left actions clamp to the configured
closed range; an out-of-range bound value remains visible until a valid user step repairs it.

Pointer input is scoped to the corresponding affordance and requires a matching same-affordance
release. Endpoint affordances remain visible but are inert. The control owns no duplicate value
or range state in the graph.
