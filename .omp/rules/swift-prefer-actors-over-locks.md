---
name: swift-prefer-actors-over-locks
description:
  "Do not introduce lock-based synchronization in Swift; prefer actor isolation first"
condition: "\\b(NSLock|NSAllocatedUnfairLock|OSAllocatedUnfairLock|Mutex)\\b"
scope: ["tool:write(*.swift)", "tool:edit(*.swift)"]
---

Do not introduce lock-based synchronization in this Swift project unless it is explicitly
justified as unavoidable. This includes `NSLock`, `NSAllocatedUnfairLock`,
`OSAllocatedUnfairLock`, `Mutex`, serial queues used as locks, and similar wrappers.
Prefer modern Swift 6 concurrency tools first, especially actor isolation for shared
mutable state. Before using any lock, read
`skill://swift6-concurrency-migration/playbooks/actor-migration.md` and confirm why an
actor-based design is not suitable.
