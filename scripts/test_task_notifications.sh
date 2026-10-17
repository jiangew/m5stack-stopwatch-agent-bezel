#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export PYTHONDONTWRITEBYTECODE=1
export CLANG_MODULE_CACHE_PATH=/private/tmp/stopwatch-swift-module-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/stopwatch-swift-module-cache
output=$(mktemp -d /private/tmp/stopwatch-notification-check.XXXXXX)
trap 'rm -rf "$output"' EXIT HUP INT TERM
swiftc -parse-as-library \
  companion/Sources/CodexWatchCompanion/TaskNotificationModel.swift \
  companion/Sources/CodexWatchCompanion/TaskNotificationStore.swift \
  companion/Sources/CodexWatchCompanion/TaskNotificationBroker.swift \
  companion/StandaloneTests/TaskNotificationRegression.swift -o "$output/regression"
"$output/regression"
swiftc -parse-as-library \
  companion/Sources/CodexWatchCompanion/TaskNotificationModel.swift \
  companion/Sources/CodexWatchCompanion/TaskNotificationStore.swift \
  companion/Sources/CodexWatchCompanion/TaskNotificationBroker.swift \
  companion/StandaloneTests/TaskNotificationReviewRegression.swift -o "$output/review-regression"
"$output/review-regression"
# Compile the real transport against a narrow CoreBluetooth double; this
# verifies discovery decisions without starting a radio, pairing or device I/O.
swiftc -emit-library -emit-module -module-name CoreBluetooth \
  companion/StandaloneTests/CoreBluetoothTestDouble.swift \
  -o "$output/libCoreBluetooth.dylib" -emit-module-path "$output/CoreBluetooth.swiftmodule"
swiftc -parse-as-library -I "$output" -L "$output" -lCoreBluetooth -Xlinker -rpath -Xlinker "$output" \
  companion/Sources/CodexWatchCompanion/TaskNotificationModel.swift \
  companion/Sources/CodexWatchCompanion/TaskNotificationTransport.swift \
  companion/StandaloneTests/TaskNotificationTransportRegression.swift -o "$output/transport-regression"
"$output/transport-regression"
TASK_NOTIFICATION_TEST_BINARY="$output/regression" python3 -m unittest discover -s scripts/tests -p test_stopwatch_notify.py -v
