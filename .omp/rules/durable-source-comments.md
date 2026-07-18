---
name: durable-source-comments
description: "Keep Swift implementation comments independent of delivery plans"
condition: "(?://[/!]?|/\\*+|\\*)[^\\n]*\\b(?:Phase|phase|Slice|slice|Step|step)\\s+\\d+\\b"
scope: ["tool:write(*.swift)", "tool:edit(*.swift)"]
---

Do not add Swift implementation comments or DocC that refer to numbered plan phases,
slices, or steps. Replace roadmap language with the enduring behavior, ownership rule, or
invariant that makes the comment useful after the implementation plan is no longer active.
Keep delivery sequencing in planning and specification documents, not compiled source.
