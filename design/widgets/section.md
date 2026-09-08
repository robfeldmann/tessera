---
kind: widget
status: specified
---

# Section

`Section` is a structural grouping view for a header and content. It owns no collection,
selection, sorting, scroll, or focus state. Application bindings and descendant identity
pass through unchanged.

## Public boundary

```swift
Section(spacing: 0, header: { Header() }) {
  Content()
}

Section("Title") {
  Content()
}
```

## Behavioral contract

Header and content are measured as separate structural children and placed as one grouped
region with the declared nonnegative spacing. Empty content, long headers, adjacent
sections, constrained proposals, and zero-height proposals remain deterministic.
Environment and style values pass through both children; Section does not intercept
descendant keyboard or pointer input.

The dedicated collection regressions cover adjacent sections and an empty section while
the layout implementation preserves child boundaries for keyed descendants.
