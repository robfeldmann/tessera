# ``Toggle``

`Toggle` renders an application-owned `Binding<Bool>` as an ASCII checkbox and label.
It composes the established Button input lifecycle: phased key/pointer input writes the
inverse only on matching release, while legacy press-only input activates immediately. An
outside or invalid release cancels without writing the binding.

The binding is read on reconciliation and is the only source of truth. Focus is explicit at the
call site; disabled state changes rendering and bubbling but does not mutate focus or the bound
value.
