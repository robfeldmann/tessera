# ``NavigationSplitView``

`NavigationSplitView` composes sidebar, content, and detail roles from application-owned
views. `columnVisibility` controls which roles are permitted, while
preferred compact column selects the role to present when space is compact. Selection,
destinations, navigation history, and business state remain outside the view.

In regular space, every permitted role is laid out in semantic sidebar/content/detail order
with dividers between visible roles. In compact space, exactly one permitted role is presented;
when the preferred role is unavailable, the implementation falls back in semantic order.
Application-provided focus targets are restored when a role opens.

The default `AutomaticNavigationSplitViewStyle` supplies a restrained divider treatment.
Custom navigation styles can change that presentation role but cannot change role visibility,
compact selection, identity, or controlled state.
