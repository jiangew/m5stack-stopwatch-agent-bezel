# Eight Autobot Bodies Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this single integrated task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Add Ironhide and Ratchet to the existing six-body Home pool while preserving the default portrait.

**Architecture:** Append two identities/assets to existing selector/cache/pipeline contracts. Maintain the current 64-bit rejection sampling and shared native/firmware canvas, extending meaningful tests to the new range8/range7 boundaries.

**Tech Stack:** C++17/M5GFX, Ruby fixtures, Python Pillow/numpy, Swift ImageIO, PlatformIO.

## Global Constraints

- Nine enum values in order: Bumblebee, BumblebeeFullbody, Optimus, Jazz, Hotrod, Wheeljack, Hound, Ironhide, Ratchet.
- Default/reset Bumblebee portrait; Up/Down/Right initial uniform8 bodies, subsequent other7. Never portrait/current; left/wake/held/cancellation/haptics420ms skills320ms transition unchanged.
- Preserve all existing seven generated JPEG digests, not only Bumblebee. New sources ironhide.png/ratchet.png; generated ironhide-idle.jpg/ratchet-idle.jpg; exact symbols kIronhideJpg/kRatchetJpg.
- Nine300x300 baseline JPEGs below50KiB; cache1,620,000 bytes PSRAM with existing one-buffer fallback and no per-frame retries. Status/battery and Agent workspaces unchanged.
- No flash, Companion/protocol changes, credentials, private identifiers/paths/audio, push or merge. Existing selected USB-mic target remains selected.

### Task 1: Integrate and verify the eight-body roster

**Files:** `include/RobotHomeCharacter.h`, `RobotHomeCharacters.h`, `RobotHomeEffects.h`, `RobotHomePortraitCache.h`, `RobotHomePortraitCanvas.h`, `RobotHomeArtData.h`; `simulator/robot_home_character_test.cpp`, `robot_home_cache_test.cpp`, `robot_home_ui_test.cpp`, `robot_home_swipe_test.rb`, `robot_home_art_test.py`, `robot_home_art_test.swift`, `robot_home_spacing_test.rb`, `preview_main.cpp`; `scripts/prepare_robot_home_art.py`, `embed_robot_home_art.rb`; `assets/robot-home/` new two sources/generated JPEGs/provenance; `README.md`, `README.zh-CN.md`, `docs/HOME_HERO_INTERACTION.md`, `docs/DEEPSEEK_BLINK.md`, `artifacts/robot-home-ironhide.png`, `robot-home-ratchet.png`.

**Interfaces:** Retain `CharacterSelector::select(Direction,uint32_t,RandomFn)` and existing render/cache interfaces. Set kCharacterCount9/kFullbodyCount8; append Ironhide/Ratchet. Full-body fitting is supplied by controller as two300px PNGs; the production serialization must preserve all seven old JPEGs.

- [x] Update behavioral tests first. All3 directions: eight initial candidates, every other seven from every body; ignored Left/None no entropy/timing change; UINT32_MAX accepted in initial range8 with exactly one entropy call; body range7 rejects 0xfffffffc..0xffffffff before accepting0xfffffffb. Retain wrap/reset and actual gesture checks. Expand cache budget to9 and test drawing the eighth/ninth images without new decodes; partial budget7 and1 fallback, no buffer, ninth decode failure and recovery. Run selector/cache tests against old production and record expected assertion failures.
  ```sh
  clang++ -std=c++17 -Iinclude simulator/robot_home_character_test.cpp -o /private/tmp/eight-body-selector
  /private/tmp/eight-body-selector
  clang++ -std=c++17 -Iinclude simulator/robot_home_cache_test.cpp -o /private/tmp/eight-body-cache
  /private/tmp/eight-body-cache
  ```
- [x] Extend artwork tests first to exact9payloads, all old7digests, dimensions/margins/size, deterministic pipeline and existing compression-tolerant duplicate predicate/negative controls. Run Python/Swift before adding new assets and record expected missing identities/files.
- [x] Implement the enum/count/cache/canvas/asset mappings; preserve existing unbiased uint64 calculation. At range8 the exclusive bound is2^32 and no sample should be rejected. Add bounded Ironhide red/orange impact circles and Ratchet cyan/red scan using existing420ms effects primitives. Extend native scenario/sequence and spacing/UI coverage to9.
- [x] Copy supplied fitted PNGs to production, serialize and embed exactly9images. Verify old7digests unchanged before/after. Document truthful builtin imagegen prompts/style/provenance without raw home paths. Keep full-resolution originals in ignored workspace outputs.
  ```sh
  python3 scripts/prepare_robot_home_art.py
  ruby scripts/embed_robot_home_art.rb assets/robot-home/generated include/RobotHomeArtData.h
  python3 simulator/robot_home_art_test.py
  swift -module-cache-path /private/tmp/eight-body-swift-cache simulator/robot_home_art_test.swift
  ```
- [x] Run selector/cache/frame/interaction/UI C++ tests and actual swipe/reaction/main/draw Ruby regressions. Build native then run nine spacing sequences, retain270frames and export the two README PNGs from actual framebuffer. Inspect new figures at idle/press/skill/end with unchanged protected rows. Build default and selected five-screen USB-mic firmware without upload:
  ```sh
  HOMEBREW_PREFIX=/opt/homebrew pio run -e native-preview
  ruby simulator/robot_home_spacing_test.rb .pio/build/native-preview/program
  pio run -e m5stack-stopwatch
  pio run -d usb-mic -e m5stack-stopwatch-usb-mic
  ```
- [x] Update current docs to9images/8bodypool/7alternatives and1,620,000 pixel bytes. Earlier3a0e2cf physicalflash and07297e0 seven-image source verification stay historical; new9image firmware is not deployed. Current README roster/previews include Ironhide/Ratchet and retain prior7artifacts. Force-add only the two named preview PNGs if ignored. Check changed-file paths/privacy and `git diff --check`, commit explicit task files, record commands/results/SHAs/concerns in task report. No extra build repetitions for test/doc-only changes.
