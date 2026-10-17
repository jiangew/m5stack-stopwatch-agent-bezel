#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
export PYTHONDONTWRITEBYTECODE=1
export CLANG_MODULE_CACHE_PATH=/private/tmp/stopwatch-swift-module-cache
export SWIFTPM_MODULECACHE_OVERRIDE=/private/tmp/stopwatch-swift-module-cache
output=$(mktemp -d /private/tmp/stopwatch-adapter-tests.XXXXXX)
trap 'rm -rf "$output"' EXIT HUP INT TERM
swiftc -parse-as-library companion/Sources/CodexWatchCompanion/TaskNotificationModel.swift \
  companion/Sources/CodexWatchCompanion/TaskNotificationStore.swift \
  companion/Sources/CodexWatchCompanion/TaskNotificationBroker.swift \
  companion/StandaloneTests/TaskNotificationRegression.swift -o "$output/bridge"
TASK_NOTIFICATION_TEST_BINARY="$output/bridge" python3 -m unittest discover -s notifications/tests -p 'test_*.py' -v
node --test notifications/tests/deepseek.test.mjs
