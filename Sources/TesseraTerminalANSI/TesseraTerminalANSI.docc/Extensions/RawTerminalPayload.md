# ``RawTerminalPayload``

A byte-for-byte escape hatch for terminal output that Tessera does not semantically
model. Encode it explicitly with ``ControlSequence/raw(_:)``. For safe frame-scoped
use, write the payload through a frame's raw-output API so the frame records its
position, occupied region, and repaint policy.

## Topics

### Creating payloads

- ``init(bytes:declaredWidth:)``

### Inspecting payloads

- ``bytes``
- ``declaredWidth``

### Encoding raw bytes

- ``ControlSequence/raw(_:)``

### Frame-scoped output

Use a frame's raw-output API to attach display metadata to raw payloads.
