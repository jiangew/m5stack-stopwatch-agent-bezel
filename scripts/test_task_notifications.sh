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
TASK_NOTIFICATION_TEST_BINARY="$output/regression" python3 -m unittest discover -s scripts/tests -p test_stopwatch_notify.py -v
