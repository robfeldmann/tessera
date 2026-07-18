// This file is intentionally ill-typed. Scripts/check-frame-region-ownership.sh
// verifies that a borrowed render region cannot escape its synchronous callback.

import TesseraTerminalBuffer
import TesseraTerminalCore

func requireEscapable<Value: ~Copyable>(_ value: borrowing Value) {}

func passRenderRegionToEscapableContext(_ region: borrowing FrameRegion) {
  requireEscapable(region)
}
