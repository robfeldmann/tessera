// This file is intentionally ill-typed in plain Swift 6 mode. scripts/check-isolation-fixtures.sh
// typechecks it as a second module that imports `JournalModel`, a module compiled with default
// main-actor isolation, and adopts `Journal` without `@MainActor` on the conformance. The
// control (-D CONTROL) writes `@MainActor` on the conformance and compiles.

import JournalModel
import TesseraRuntime

#if CONTROL
  extension Journal: @MainActor Application {}
#else
  extension Journal: Application {}
#endif
