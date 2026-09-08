# ``SplitView``

`SplitView` places a fixed number of application-supplied child panes along a bound
horizontal or vertical axis. The `Binding<[SplitViewPane]>` is the source of truth; each pane
uses a stable `id`, a `SplitViewPaneSizing` min/ideal/max range, and an optional
`isCollapsed` flag. The configuration count and IDs must match the content children.

Visible panes are negotiated in integer cells. Minimum extents are protected first, requested
ideals are honored when space permits, and remaining cells are distributed deterministically
within maxima. Collapsed panes are omitted from the visible sequence; one-cell dividers occur
only between adjacent visible panes.

When `keyboardResizingEnabled` is true, the focused divider accepts the documented key
resize commands. A primary pointer drag on a divider updates the pane sizing binding. Pane
content retains its own identity, focus, environment, and controlled values across negotiation;
SplitView owns no business state.
