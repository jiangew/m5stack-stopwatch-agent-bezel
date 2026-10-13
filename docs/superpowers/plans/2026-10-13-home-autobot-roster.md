# Home Autobot Roster Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Retain the default Bumblebee portrait and randomly cycle six recognizable full-body Autobots.

**Architecture:** Extend the existing CharacterSelector and shared PortraitCanvas to seven images while restricting random navigation to six bodies. Preserve the established interaction/frame clock and bounded fallback; serialize generated artwork with the existing deterministic baseline JPEG path.

**Tech Stack:** C++17 firmware/native simulator, M5GFX, Ruby regression fixtures, Python Pillow/numpy, Swift ImageIO, PlatformIO.

## Global Constraints

- Seven characters: Bumblebee (existing portrait), BumblebeeFullbody, Optimus, Jazz, Hotrod, Wheeljack, Hound, in that enum order.
- Default/reset is Bumblebee; first up/down/right samples all six bodies uniformly; subsequent swipes sample the other five bodies uniformly. Never swipe to the portrait or repeat the current body.
- Preserve left cycling, wake-only touch, cancellation, haptic timings, 420ms interruptible skills and existing 320ms transition.
- Seven 300x300 baseline JPEGs, each below 50KiB; original Bumblebee generated JPEG bytes unchanged.
- Cache all seven in PSRAM (1,260,000 bytes), preserve one-buffer fallback and no per-frame decode/allocation retries.
- Preserve status/battery pixels and all other workspaces. No Companion/protocol changes.
- C152 only. No device write without fresh exact-port approval. No private identifiers, personal absolute paths, recordings, credentials, push or merge in tracked work.

### Task 1: Seven-character navigation and bounded rendering

**Files:** `include/RobotHomeCharacter.h`, `include/RobotHomeUi.h`, `include/RobotHomeCharacters.h`, `include/RobotHomeEffects.h`, `include/RobotHomePortraitCache.h`, `include/RobotHomePortraitCanvas.h`, `simulator/robot_home_character_test.cpp`, `simulator/robot_home_swipe_test.rb`, `simulator/robot_home_cache_test.cpp`, `simulator/robot_home_ui_test.cpp`, `simulator/preview_main.cpp`, `simulator/robot_home_spacing_test.rb` and directly affected firmware-function fixtures.

**Interfaces:** Keep `CharacterSelector::select(Direction,uint32_t,RandomFn)`, `reset()`, `character()`, `transitionProgress(uint32_t)`. Expose `kCharacterCount=7` and `kFullbodyCount=6` with the roster if useful. `character_art::assetFor(Character)` maps to the seven corresponding `art_data::k<Name>Jpg` symbols produced in Task 2. Keep the existing drawPortrait interface. Asset headers will be supplied in Task 2; before then run tests that do not consume the old header.

- [ ] Write behavioral tests first. For every direction in Up/Down/Right and sample in 0..5, assert a fresh selector reaches the corresponding body, never the default portrait. For every current body and sample in 0..4, assert every other body is reachable exactly once, never portrait/current. Verify Left/None consume no entropy or change transition timing. Verify rejection of excess uint32 samples for range6 and range5, reset and unsigned uptime wraparound. Run:
  ```sh
  clang++ -std=c++17 -Iinclude simulator/robot_home_character_test.cpp -o /private/tmp/autobot-character-test
  /private/tmp/autobot-character-test
  ```
  Confirm the new behavior fails against old code.
- [ ] Update enum/selection with unbiased rejection sampling. Compute the exclusive accepted bound in uint64 as `(uint64_t{1} << 32) / range * range`; redraw while sample >= bound. For portrait use range6 and map index to enum1..6. For body use range5 and skip the current body's zero-based index. No entropy for ignored directions.
- [ ] Add seven-image cache tests before expanding capacity. Test a full budget7, repeated draws of all seven without further decoding; partial budget4 and budget1 fallback; unavailable buffers; a failed seventh image; switching after fallback decode failure; freeing all seven. Preserve current allocation/failure contract. Update PortraitCanvas to prepare all seven and generic cache capacity accordingly.
- [ ] Update UI/firmware gesture fixtures to prove portrait is default/wake-only and both first/next swipes select bodies with one haptic and no Mac controls. Add all seven identities to native scenario names/sequence output and spacing checks.
- [ ] Map the seven assets and accents. Bumblebee/body yellow sparks, Optimus cyan scan, Jazz blue expanding sound rings, Hotrod orange speed streaks, Wheeljack green engineering sparks, Hound green radar. Use existing bounded 420ms spring transforms. No retired web rendering or Marvel enum/asset symbols in active code.
- [ ] Run selector/cache/frame/interaction tests and real gesture/main-function regressions, record commands/output. Self-review, commit explicit code/test files, and write task report. Native/art-dependent verification completes in Task 2.

### Task 2: Seven production assets, native acceptance and documentation

**Files:** `assets/robot-home/` new six full-body PNGs and provenance, `assets/robot-home/generated/` seven JPEGs, `include/RobotHomeArtData.h`, `scripts/prepare_robot_home_art.py`, `scripts/embed_robot_home_art.rb`, `simulator/robot_home_art_test.py`, `simulator/robot_home_art_test.swift`, `README.md`, `README.zh-CN.md`, `docs/HOME_HERO_INTERACTION.md`, `artifacts/robot-home-*.png`.

**Interfaces:** Consume Task 1's exact enum/symbol roster. Source filenames `bumblebeefullbody.png`, `optimus.png`, `jazz.png`, `hotrod.png`, `wheeljack.png`, `hound.png`; existing `bumblebee.jpg` retains its established radial crop. Generated slugs are lowercase enum names and suffix `-idle.jpg`. The controller supplies fitted 300px source PNGs for all six bodies in the workspace output directory recorded in the dispatch.

- [ ] Update artwork tests before generation. Expect exactly seven header payloads matching JPEG bytes, 300x300 baseline decode, <50KiB, black outer18px (JPEG tolerance12), unique artwork. Preserve only Bumblebee source/crop comparison and additionally assert its known pre-change JPEG digest. Distinct-identity checks must remain meaningful for yellow portrait/body and white Jazz/Wheeljack without imposing an arbitrary mean-difference threshold inappropriate to different silhouette widths.
- [ ] Copy supplied fitted source PNGs into the six named production paths. Keep all raw full-resolution sources local, record truthful built-in imagegen provenance and prompt briefs without home paths. Remove retired Iron Man/Spider-Man SVG/PNG/JPEG/artifact assets; retain historical docs with clear historical status.
- [ ] Update deterministic preparation/embedding to seven. For Bumblebee preserve the accepted radial math and JPEG encoder settings; for full-body sources use the existing black-backed 300px PNG serialization. Run:
  ```sh
  python3 scripts/prepare_robot_home_art.py
  ruby scripts/embed_robot_home_art.rb assets/robot-home/generated include/RobotHomeArtData.h
  python3 simulator/robot_home_art_test.py
  swift -module-cache-path /private/tmp/autobot-swift-cache simulator/robot_home_art_test.swift
  ```
  Use the available bundled Python with Pillow/numpy if system Python lacks dependencies.
- [ ] Build native and inspect all seven idle/press/skill/end frames. Generate individual README previews from the real renderer. Run spacing checks and real production draw/gesture/main tests; verify final idle equality, status/battery protection, unchanged Codex pixels. Build both `m5stack-stopwatch` and the previously selected `m5stack-stopwatch-usb-mic`; no upload.
- [ ] Synchronize both README rosters, random-pool behavior, PSRAM count and previews; update Home verification/provenance. Keep earlier flash record explicitly tied to its old SHA, state current seven-character build is not deployed, and record earlier user's interaction acceptance without claiming measured latency.
- [ ] Run `git diff --check`, review explicit changed files for private data, commit assets/scripts/docs/verified artifacts and record build/test output in the task report. Do not push, merge, deploy Companion or write device.
