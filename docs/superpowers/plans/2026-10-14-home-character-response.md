# Home character response implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Replace central-tap energy skills with distinct character responses for the portrait and eight full-body Autobots, matching the two accepted motion pilots.

**Architecture:** Preserve the nine idle assets, eight-member random selector and touch routing. Register real edited poses to each idle transform; use a shared 600ms motion timeline. Keep idle caching independent from optional action caching so action allocation failure retains the base artwork without per-frame JPEG decoding.

**Tech Stack:** ESP32-S3 C152, Arduino C++, M5GFX RGB565 sprites, native renderer, Pillow serialization, built-in imagegen.

## Global Constraints

- User accepted Bumblebee full-body wave and Optimus fist/nod pilots on 2026-10-14; keep their captured poses and rhythm.
- Default Bumblebee portrait and all nine accepted idle JPEGs remain byte-identical.
- Up/down/right select among eight full bodies with no immediate repeat; left, wake, status, battery, BLE and input-only USB microphone retain their behavior.
- Press responds immediately with 3% compression. Valid release runs a 600ms response and one 25ms haptic after the first rendered frame. New press interrupts; swipe/leave/sleep/power cancel; 500ms short-tap and 2s power-hold boundaries stay unchanged.
- No sound. No firmware flash, push, merge, or Companion restart in this implementation phase.
- Artwork copies must live in the workspace. No personal paths or device identifiers in tracked files.
- Optional actions use ten 300x300 RGB565 sprites (1,800,000 bytes); nine idle sprites remain 1,620,000 bytes. Failed action allocation releases the action bank and remembers failure; the idle image with motion remains available.

### Task 1: Complete action artwork

**Files:** Add `assets/robot-home/actions/{jazz,hotrod,wheeljack,hound,ironhide,ratchet}-1.jpg`, the four accepted pilot JPEGs, and a provenance manifest/prompt set.

**Interface:** Ten baseline 300px JPEGs, each under 50 KiB; naming `<hero>-<pose>.jpg`. Pilot heroes have poses 1 and 2; other full bodies have pose 1. Portrait uses native tilt/nod without extra artwork.

- [x] Generate one clear signature pose for each remaining hero: Jazz thumbs-up; Hot Rod lively forward lean; Wheeljack raises wrench; Hound chest acknowledgement returning to salute; Ironhide strong fist/palm; Ratchet OK gesture. Inspect every edit target before imagegen, preserve identity, body scale, feet and black canvas. Save exact prompts and source hashes.
- [x] Fit using the original idle bounding box/transform, never a new per-pose silhouette fit. Copy the accepted pilot JPEGs unchanged. Decode all ten JPEGs and compare contact sheets against idle; confirm the nine idle SHA256 hashes unchanged.

### Task 2: Shared motion and bounded caches

**Files:** `include/RobotHomeInteraction.h`, new `RobotHomeMotion.h`, new `RobotHomeActionArtData.h`, `RobotHomeCharacters.h`, `RobotHomePortraitCache.h`, `RobotHomePortraitCanvas.h`, `RobotHomeUi.h`; new embed script; host interaction/cache/UI/motion tests.

**Interface:** `motionFor(Character,Mood,uint32_t)` returns pose index, compression, vertical offset and angle. `actionFor(Character,unsigned)` returns a pose JPEG or idle. Idle and action caches prepare once; action cache has no single-buffer fallback.

- [x] First update interaction tests to assert release remains active through 599ms and becomes idle at 600ms, including uint32 rollover and repeat interruption; watch the old 420ms implementation fail. Change `Animation` skill duration to a shared 600ms constant.
- [x] First test optional-cache allocation failure at every slot, no decode/allocation retry during repeated animation draws, idle cache survival and decode failure. Extend `PortraitCache` with a capacity template parameter and opt-out single-buffer fallback; keep its existing default behavior for idle callers.
- [x] Write motion tests covering every hero, idle/press identity, the accepted pilot key-pose boundaries, action end returning exactly to idle, and finite bounded transforms. Implement timelines matching the pilots, with one signature pose plus small motion for the other six; portrait nods/tilts.
- [x] Embed ten action assets deterministically; render the selected action and transform in the real Home renderer. If action drawing fails, draw its own idle asset using the idle cache. Remove tap energy effects; preserve real status/battery and cancellation plumbing.

### Task 3: Integrate, verify and archive candidate

**Files:** `simulator/preview_main.cpp`, artwork/UI/cache tests, `README.md`, `README.zh-CN.md`, `docs/HOME_HERO_INTERACTION.md`; local ignored candidate output.

- [x] Run focused C++ interaction/motion/cache/UI tests, existing gesture/source-path tests and Python/Swift image decoding checks. Change sequence capture to cover the complete 600ms response and exact return for all nine heroes.
- [x] Render actual native frames/contact sheets/GIF; compare idle to the accepted baseline, check status/battery pixels throughout and inspect all gestures at actual size. The native check cannot establish hardware touch latency or motor response.
- [x] Build default and explicitly selected USB-mic targets. Archive binaries, SHA256 manifests, logs and previews to a new output directory, leaving the previous flashed candidate immutable.
- [x] Review the whole change, address material findings, update docs with measured static memory costs/build evidence and clearly pending physical acceptance. Commit explicit paths; leave the candidate ready for a separately confirmed flash.


## Completion evidence — 2026-10-14

The source candidate passed eleven C++ executable checks, seven Python artwork
checks, nineteen ImageIO decodes, actual gesture/reaction/launch/draw tests,
and all nine 54-frame native sequences. Default, native and selected USB-mic
builds passed. Every idle JPEG and accepted pilot JPEG stayed unchanged.
The independent whole-change review approved with no actionable findings.

Local output `home-character-response` contains 486 native frames, an interactive
nine-role viewer, GIF/PNG previews, exact prompts/source provenance, build and
host logs, binaries and a SHA256 candidate manifest. The response source is
kept on `codex/home-tap-motion-pilot`. At source-candidate completion no flash, push, merge or Companion restart
was performed. Device acceptance of the new responses and physical PSRAM,
latency, frame rate and motor timing remain pending.


## Subsequent physical deployment — 2026-10-14

After the user confirmed the exact current target, source `4b1b6e9` was flashed
only to app0 after a new 16MB backup and identity/partition/OTA checks. Tool and
independent ROM digest verification passed; protected first 64KB stayed byte-identical.
USB/CoreAudio input-only 48kHz, BLE HID transport, fresh Companion connection,
read-only device.status RPC and 3.008s microphone validation passed. Temporary
audio was removed. No Companion restart, push or merge occurred. New gesture
acceptance, physical PSRAM, measured latency, frame rate and motor timing remain
pending. See `docs/HOME_HERO_INTERACTION.md` for the deployment scope.
