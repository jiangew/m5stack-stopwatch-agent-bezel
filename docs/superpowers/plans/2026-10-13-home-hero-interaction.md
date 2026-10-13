# Home Hero Interaction Implementation Plan

> **For agentic workers:** Use subagent-driven-development for independent asset/state work and execute integration in this session. Steps use checkbox syntax for tracking.

**Goal:** Replace Home blinking with immediate press/release skills for Bumblebee, Optimus, Iron Man and Spider-Man, with random non-repeating swipe selection.

**Architecture:** Keep selection and interaction deterministic, hardware-independent headers. Render cached RGB565 portraits plus procedural skills; firmware owns touch arbitration, cache lifetime, frame scheduling and haptics.

**Tech Stack:** C++17, M5GFX, M5Unified, PlatformIO, native framebuffer preview, Ruby/Python asset tooling.

## Global Constraints

- C152 only; build, flash and physical acceptance reported separately.
- No Companion/protocol/microphone behavior change, speech, USB output or network dependency.
- Awake press responds immediately; short release emits one 25ms haptic and 420ms skill.
- Up/down/right choose uniformly from other three; left keeps workspace cycling.
- Sleep first-touch wakes only; leaving Home and power overlays cancel.
- Preserve existing power hold; taps expire at 500ms and movement cancels at 52px.
- No deployment until exact device/recovery and flashing confirmation.

### Task 1: Hero assets

**Files:** assets/robot-home/ironman.png, spiderman.png, generated/*, scripts/embed_robot_home_art.rb, scripts/prepare_robot_home_art.py, include/RobotHomeArtData.h, simulator/robot_home_art_test.*.

**Interfaces:** Embedded assets `kBumblebeeJpg`, `kOptimusJpg`, `kIronmanJpg`, `kSpidermanJpg`; each 300×300 black-background baseline JPEG. Keep original Bumblebee/Optimus source artwork and ring-free idle images.

- [ ] Generate Iron Man and Spider-Man using built-in imagegen and existing portrait as style reference; inspect all outputs.
- [ ] Add a real image/embedding test checking the four assets decode to 300×300 with black edge margins and distinct identity; observe old asset set fail.
- [ ] Normalize new portraits, update scripts to embed only four idle assets, regenerate header. Preserve generation prompts in a portable project file.
- [ ] Run image tests and inspect thumbnails; commit explicit asset/tool paths after verification.

### Task 2: Deterministic selection and interaction

**Files:** include/RobotHomeCharacter.h, include/RobotHomeInteraction.h, simulator/robot_home_character_test.cpp, simulator/robot_home_interaction_test.cpp.

**Interfaces:** `Character {Bumblebee, Optimus, Ironman, Spiderman}`. `CharacterSelector::select(direction, nowMs, randomFn)` consumes a callable returning uint32_t. `Animation::press(now)`, `release(now)`, `cancel()`, `mood(now)`, `elapsed(now)`, `active(now)`; `Mood {Idle, Happy, Surprise, Sleep, Connect, Press, Skill}`. Existing `react`, `Tap::begin/move/finish/cancel` remain usable; Tap gains `eligible()` so gesture movement cancels press promptly.

- [ ] Write regression tests for all current characters/directions and random streams: no self-repeat, all other candidates reachable, rejected out-of-range entropy resampled, left/none no entropy call, transition wraparound.
- [ ] Write press/release/cancel tests: press immediately visible, release skill lasts 420ms, a new press interrupts, press times out at 500ms, cancellation and uint32 wraparound, movement/drag out invalidate release.
- [ ] Run failing tests against old headers, retain failure evidence in local outputs.
- [ ] Implement state transitions and selector using unbiased rejection sampling (`sample == UINT32_MAX` rejected for range three); retain 320ms character transition.
- [ ] Run tests, inspect interfaces and commit explicit paths after verification.

### Task 3: Renderer, caching and firmware integration

**Files:** include/RobotHomeCharacters.h, include/RobotHomeEffects.h, include/RobotHomeUi.h, include/RobotHomePortraitCache.h, src/main.cpp, simulator/preview_main.cpp, simulator/robot_home_ui_test.cpp, simulator/robot_home_swipe_test.rb, simulator/robot_home_spacing_test.rb, README.md, README.zh-CN.md, docs/HOME_HERO_INTERACTION.md.

**Interfaces:** `State::touchX/touchY` carry clamped skill origin. Firmware `PortraitCache` acts as a surface adapter overriding drawJpg to use predecoded RGB565 sprite pixels; native render remains actual JPEG decode. One render scheduler prioritizes press/release/selection and sleeps when idle.

- [ ] Write native effect bounds tests, production gesture press/release tests and scheduler/cache tests with allocation failures. Run old implementation and record failure.
- [ ] Implement four procedural skills within portrait-safe y=64..398, spring scale/tilt; preserve status/battery layout and overlay order.
- [ ] Implement PSRAM cached portraits with per-character lazy fallback; cache misses never stall an input action decoding an uncached asset repeatedly. Full-cache failure falls back to current portrait; free all cache on leaving Home/sleep.
- [ ] Wire raw touch updates into press cancellation and swipe classification; valid short release triggers skill and one short haptic. No blocking animation or repeated JPEG decoding.
- [ ] Update native preview scenarios for each character at press/skill/idle/transition and produce animated preview using native renderer.
- [ ] Run native suites and actual production-function regressions; build native-preview, default m5stack-stopwatch, explicitly selected existing five-screen USB-mic variant. Verify no environment changes beyond builds.
- [ ] Synchronize README/input tables/curated previews and validation record; report hardware latency as pending until measured.
- [ ] Whole-change review, fix regressions, verify clean diff, commit explicit paths. Keep feature branch local pending integration choice.

## Device acceptance remaining

Confirm exact C152 device and factory recovery before user-approved flash. Measure per-character response latency (target P95≤80ms, 30 trials each), repeated taps, random swipes, long hold, wake and existing Agent/microphone functionality. Builds and previews cannot satisfy this step.
