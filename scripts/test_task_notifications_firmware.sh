#!/bin/sh
# Host regressions using existing PlatformIO dependencies; never builds/flashes hardware.
set -eu
cd "$(dirname "$0")/.."
json=.pio/libdeps/m5stack-stopwatch/ArduinoJson/src
gfx=.pio/libdeps/m5stack-stopwatch/M5GFX/src
brew=${HOMEBREW_PREFIX:-/opt/homebrew}
sdl=$brew/include/SDL2
gfx_archive=$(rg --files --no-ignore .pio/build/native-preview -g libM5GFX.a | head -1)
if [ ! -f "$gfx_archive" ]; then echo "Build native-preview before CJK rendering tests." >&2; exit 1; fi
if [ ! -f "$json/ArduinoJson.h" ] || [ ! -f "$gfx/M5GFX.h" ]; then
  echo 'Build the documented native-preview environment to populate dependencies first.' >&2
  exit 1
fi
output=$(mktemp -d /private/tmp/stopwatch-firmware-tests.XXXXXX)
trap 'rm -rf "$output"' EXIT HUP INT TERM
c++ -std=c++17 -fsanitize=address,undefined -Iinclude -isystem "$json" \
  simulator/task_notification_test.cpp -o "$output/core"
"$output/core"
c++ -std=c++17 -fsanitize=address,undefined -Iinclude -isystem "$json" simulator/task_notification_content_test.cpp -o "$output/content"
"$output/content"
c++ -std=c++17 -fsanitize=address,undefined -Iinclude -isystem "$json" \
  -isystem "$gfx" -isystem "$sdl" simulator/task_notification_ui_test.cpp "$gfx_archive" -L"$brew/lib" -lSDL2 -o "$output/ui"
"$output/ui"
ruby simulator/task_notification_main_test.rb
ruby simulator/task_notification_legacy_test.rb
