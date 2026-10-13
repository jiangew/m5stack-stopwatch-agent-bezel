# Task 1 report — eight-body Home roster

Implementation commit: `b3bc1b01128aec5657774537026ef7438529bb13` (parent `dea32ec5cd10f9ea2646a5a98d3fcc09d0dc3ea0`). This is source and build validation only: no flash, Companion or protocol change, upload, push, or merge occurred.

## Result and scope

The default Bumblebee portrait remains first. The swipe pool has eight full-body characters: Bumblebee full body, Optimus, Jazz, Hot Rod, Wheeljack, Hound, Ironhide, and Ratchet. `kCharacterCount=9`, `kFullbodyCount=8`; every successful up/down/right selection samples uniformly from eight candidates from the portrait or seven alternatives from a body. The existing uint64 rejection calculation remains intact. The RGB565 cache capacity is nine sprites (1,620,000 pixel bytes) with the existing single-sprite fallback. Ironhide adds bounded red/orange impact circles; Ratchet adds a bounded cyan scan and red diagnostic marker in the existing 420ms skill window.

The two fitted 300px PNGs supplied in the local task output were copied byte-for-byte to `assets/robot-home/`. The deterministic script generated their baseline JPEGs and embedded all nine images. Existing seven JPEG SHA-256 values match `preserved-assets.json` before and after serialization; no old image payload changed. The exact built-in imagegen prompts and full-resolution originals remain in ignored local task output. The two new README PNGs are actual native framebuffer idle frames and pixel-equal to their retained PPM sources. All 270 sequence frames are retained in the ignored `outputs/home-autobots-ironhide-ratchet/frames` directory.

## Red → green evidence

- The extended selector test failed against old production at `selected == sample + 1` for sample 6. The extended cache test failed at `Sprite::decodes == 9`. After the enum/count/cache changes both passed. The selector checks all three directions, every current body and alternative, ignored left/none entropy and timing, reset/wrap, `UINT32_MAX` accepted from the portrait in one call, and the top four values rejected for range seven.
- Before new assets, Python artwork tests failed on the missing Ironhide/Ratchet header identities and files; Swift ImageIO stopped on missing `ironhide-idle.jpg`. After adding the pipeline and inputs, all five Python tests and nine Swift decodes passed. Python checks all seven preserved digests, exact header bytes, dimensions, margins, file size, deterministic regeneration, distinct artwork, and compression-tolerant duplicate negative controls.
- The expanded UI bounds test initially failed because Ironhide's outer impact stroke could reach x=411 for an edge touch. Reducing its maximum radius to 58px keeps every tested press/skill effect inside x=64..402/y=64..398; the UI test then passed. Native sequence checks confirm the status and battery rows are byte-identical through press, skill, and end frames for all nine images. Visual inspection of Ironhide/Ratchet idle, press, skill, and end contact frames showed complete figures and matching style.

## Commands and results

Run from repository root; the Python invocations used the bundled Pillow/numpy runtime. Full raw logs are retained in the local task output's `validation` directory.

| Command | Result |
| --- | --- |
| `clang++ -std=c++17 -Iinclude simulator/robot_home_character_test.cpp -o /private/tmp/eight-body-selector && /private/tmp/eight-body-selector` | Initial expected assertion failure; final exit 0 |
| `clang++ -std=c++17 -Iinclude simulator/robot_home_cache_test.cpp -o /private/tmp/eight-body-cache && /private/tmp/eight-body-cache` | Initial expected assertion failure; final exit 0 |
| `clang++ -std=c++17 -Iinclude simulator/robot_home_frame_test.cpp -o /private/tmp/eight-body-frame && /private/tmp/eight-body-frame` | Exit 0 |
| `clang++ -std=c++17 -Iinclude simulator/robot_home_interaction_test.cpp -o /private/tmp/eight-body-interaction && /private/tmp/eight-body-interaction` | Exit 0 |
| `clang++ -std=c++17 -Iinclude -I.pio/libdeps/m5stack-stopwatch/M5GFX/src -I/opt/homebrew/include/SDL2 simulator/robot_home_ui_test.cpp -o /private/tmp/eight-body-ui && /private/tmp/eight-body-ui` | Initial bounds assertion failure, corrected; final exit 0 |
| `python3 scripts/prepare_robot_home_art.py` and `ruby scripts/embed_robot_home_art.rb assets/robot-home/generated include/RobotHomeArtData.h` | Nine JPEGs serialized and embedded; old seven digests unchanged |
| `python3 simulator/robot_home_art_test.py` | Initial missing-asset failures; final 5 tests passed |
| `swift -module-cache-path /private/tmp/eight-body-swift-cache simulator/robot_home_art_test.swift` | Initial missing Ironhide failure; final 9 ImageIO decodes passed |
| `ruby simulator/robot_home_swipe_test.rb` | Exit 0, actual gesture path reaches Ironhide/Ratchet |
| `ruby simulator/robot_speech_reaction_test.rb` | Exit 0 |
| `ruby simulator/workspace_launch_main_test.rb` | Exit 0 |
| `ruby simulator/codex_dashboard_draw_test.rb` | Exit 0 |
| `HOMEBREW_PREFIX=/opt/homebrew pio run -e native-preview` | Success; one pre-existing M5GFX Clang VLA-extension warning |
| `ruby simulator/robot_home_spacing_test.rb .pio/build/native-preview/program` | Nine sequences passed, 30 frames each |
| `.pio/build/native-preview/program --home-sequence OUTPUT_DIRECTORY` | 270 PPM frames retained |
| `pio run -e m5stack-stopwatch` | Success; flash 1,309,181 / 6,553,600 bytes |
| `pio run -d usb-mic -e m5stack-stopwatch-usb-mic` | Success; flash 1,698,763 / 6,553,600 bytes |
| `git diff --cached --check` | Exit 0 before implementation commit |

The first sandboxed PlatformIO invocation could not write its global cache; the same authorized native build passed using the existing cache with sandbox escalation. The only source defect found during final checks was Ironhide's effect radius, corrected before the native and firmware builds. The seven-image physical flash and source checks cited in older documents remain historical; the nine-image firmware awaits C152 physical acceptance, including touch latency and real haptic response.
