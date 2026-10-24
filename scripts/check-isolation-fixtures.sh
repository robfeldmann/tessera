#!/usr/bin/env bash
set -euo pipefail

# Pins the isolation rules of the application contract with compile-fail fixtures. Each
# fixture is typechecked against the current debug modules and must fail with its expected
# diagnostic; each has a positive control (the same file with -D CONTROL) that must compile,
# so a toolchain that stops diagnosing fails this check instead of passing it.
#
# 1. An actor host given an application with a main-actor isolated conformance.
# 2. A type from a module compiled with default main-actor isolation, adopted by another
#    module in plain Swift 6 mode without @MainActor on the conformance.

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

fixtures="Tests/CompileFailFixtures"
actor_fixture="$fixtures/ActorHostMainActorApp.swift"
journal_fixture="$fixtures/DefaultIsolationJournal.swift"
adopter_fixture="$fixtures/AdoptWithoutIsolation.swift"

# Swift 6.3 says "actor-isolated context" and Swift 6.4 adds "nonisolated context" for the
# same rule, so the expectation is the shared prefix.
actor_expected="main actor-isolated conformance of 'Browser' to 'Application' cannot be used in"
adopter_expected="crosses into main actor-isolated code and can cause data races"

# SwiftPM names a module's package after the root package's identity (the checkout
# directory's name), and `package` declarations are visible only to a client with the same
# package name.
package_name="$(
  swift package --only-use-versions-from-resolved-file show-dependencies --format json |
    python3 -c 'import json, re, sys; print(re.sub(r"[^A-Za-z0-9_]", "_", json.load(sys.stdin)["identity"]))'
)"

# Ask SwiftPM where the active toolchain puts debug products: the native build system
# writes modules to `<bin>/Modules`, Swift Build (the default from Swift 6.4) to `<bin>`.
bin_path="$(swift build --only-use-versions-from-resolved-file --show-bin-path)"
module_dirs=()
for candidate in "$bin_path/Modules" "$bin_path"; do
  if [[ -e "$candidate/TesseraRuntime.swiftmodule" ]]; then
    module_dirs+=("$candidate")
  fi
done
if [[ ${#module_dirs[@]} -eq 0 ]]; then
  echo "Isolation fixtures require the current debug build products." >&2
  exit 1
fi

scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

common=(-swift-version 6 -enable-experimental-feature Lifetimes)

# Whether a diagnostic says the module could not be loaded rather than the fixture failing.
is_unloadable() {
  [[ "$1" == *"cannot be imported by the"* ]] ||
    [[ "$1" == *"was created for incompatible target"* ]] ||
    [[ "$1" == *"could not find module"* ]]
}

# Typechecks `file` against `module_dir`, expecting `expected` in the diagnostics and a clean
# compile with -D CONTROL. Prints nothing on success; returns 2 when the modules are not
# loadable by this compiler so the caller can try the next directory.
check_fixture() {
  local label="$1" module_dir="$2" expected="$3" file="$4"
  shift 4
  local diagnostic
  if diagnostic="$(swiftc -typecheck "${common[@]}" "$@" -I "$module_dir" "$file" 2>&1)"; then
    echo "Expected the $label fixture to fail type checking." >&2
    exit 1
  fi
  if is_unloadable "$diagnostic"; then
    return 2
  fi
  if [[ "$diagnostic" != *"$expected"* ]]; then
    echo "The $label fixture failed with an unexpected diagnostic:" >&2
    echo "$diagnostic" >&2
    exit 1
  fi
  if ! diagnostic="$(swiftc -typecheck "${common[@]}" "$@" -D CONTROL -I "$module_dir" "$file" 2>&1)"; then
    echo "The $label control did not compile:" >&2
    echo "$diagnostic" >&2
    exit 1
  fi
  echo "$label probe passed"
}

passed=0
for module_dir in "${module_dirs[@]}"; do
  status=0
  check_fixture "Actor host with a main-actor application" "$module_dir" \
    "$actor_expected" "$actor_fixture" -package-name "$package_name" || status=$?
  if [[ $status -eq 2 ]]; then
    continue
  fi

  # The adopted type's module is compiled with default main-actor isolation; the adopting
  # module is typechecked in plain Swift 6 mode, with neither InferIsolatedConformances nor
  # default isolation, which the package's shared settings would otherwise add.
  journal_dir="$scratch/$(basename "$module_dir")-journal"
  mkdir -p "$journal_dir"
  if ! swiftc -emit-module -parse-as-library -module-name JournalModel \
    "${common[@]}" -default-isolation MainActor -I "$module_dir" \
    -emit-module-path "$journal_dir/JournalModel.swiftmodule" "$journal_fixture"; then
    echo "The JournalModel fixture module did not compile." >&2
    exit 1
  fi
  status=0
  check_fixture "Default-isolation type adopted without @MainActor" "$module_dir" \
    "$adopter_expected" "$adopter_fixture" -I "$journal_dir" || status=$?
  if [[ $status -eq 2 ]]; then
    continue
  fi
  passed=1
  break
done

if [[ $passed -ne 1 ]]; then
  echo "Isolation fixtures require compatible current-host debug build products." >&2
  exit 1
fi
