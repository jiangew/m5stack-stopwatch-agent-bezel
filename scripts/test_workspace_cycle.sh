#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH=/private/tmp/stopwatch-trim-swift-cache
export SWIFTPM_MODULECACHE_OVERRIDE="$CLANG_MODULE_CACHE_PATH"
out=$(mktemp -d /private/tmp/stopwatch-cycle-test.XXXXXX)
trap 'rm -rf "$out"' EXIT
sources=companion/Sources/CodexWatchCompanion
swiftc -parse-as-library \
  "$sources/WorkspaceAppProfile.swift" "$sources/HIDShortcutDecoder.swift" \
  "$sources/WorkspaceModeHIDWriter.swift" "$sources/WorkspaceModeCoordinator.swift" \
  "$sources/WorkspaceCycleController.swift" "$sources/SuperEngineeringToggler.swift" \
  companion/StandaloneTests/WorkspaceCycleRegression.swift -o "$out/regression"
"$out/regression"
