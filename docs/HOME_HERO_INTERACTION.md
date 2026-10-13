# Home hero interaction — 2026-10-13

This source update replaces the former triple blink with press/release skills
for **Bumblebee portrait, Bumblebee full body, Optimus Prime, Jazz, Hot Rod, Wheeljack and Hound**. It requires the
five-screen `m5stack-stopwatch-usb-mic` firmware; the default wireless image
remains the Codex dashboard. The existing Companion and protocol are unchanged.

## Behavior

| Gesture | Home result |
| --- | --- |
| Awake portrait press | Immediately compress the portrait 3% and show energy at the touch point |
| Release before 500ms, remaining inside the portrait area | Release one 420ms skill and request one short 25ms haptic |
| New press during a skill | Interrupt and immediately begin new energy feedback |
| Move outside portrait area or at least 52px from start | Cancel the tap; a classified swipe may select a hero or cycle workspaces |
| Up / down / right | From the default portrait, uniformly choose one of six full-body heroes; thereafter choose among the other five full bodies, with one existing 40ms swipe haptic |
| Left | Existing workspace cycle; no new Mac action is attached to skills |
| First touch while asleep | Wake only; no skill or hero change |
| Leave Home / sleep / power overlay | Cancel the reaction; existing long-hold power flow remains |

The portrait hit area is x=64..402, y=64..398. Effect origins are clamped inward
so every spark, pulse and scan stays inside that area. Selection defaults to
Bumblebee when Home is re-entered. Directions no longer map to fixed heroes.
The portrait is excluded from the random pool. Choices may return to a
previously seen full-body hero after an intervening change; only immediate
repetition is forbidden. One held swipe never repeats selection.

| Hero | Skill |
| --- | --- |
| Bumblebee portrait | Yellow shoulder sparks and a small spring rebound |
| Bumblebee full body | Yellow shoulder sparks and a small spring rebound |
| Optimus Prime | Cyan faceplate scan and armor highlights |
| Jazz | Blue concentric energy pulse |
| Hot Rod | Orange speed streaks |
| Wheeljack | Green electrical arcs |
| Hound | Green scanning rings |

All skills are silent. State and battery retain their existing positions and
real data sources. Preview values are fixtures, not device telemetry.

## Rendering and failure behavior

- Seven 300×300 RGB565 sprites require approximately 1,260,000 bytes and are
  predecoded in PSRAM on entering Home. Animation reuses these pixels instead
  of repeatedly decoding JPEGs.
- Allocation failure frees the partial set and attempts one reusable buffer.
  Selecting a different hero may decode once in this fallback. If even that
  buffer or an asset decode fails, a neutral face still answers input;
  failures are not retried every frame. Leaving Home or sleeping frees caches.
- One `FrameClock` drives animation at a nominal 34ms cadence; input requests
  bypass the cadence. The final resting state is explicitly repainted. Idle
  Home redraws only for state changes.
- Scheduling records the animation state of the pixels rendered, so crossing
  an expiry during panel transfer cannot strand an effect. Cadence counts
  rendering time rather than adding a second delay after transfer.
- Portrait rasterization is clipped to its safe area, protecting status and
  battery from JPEG edge artifacts. Native previews use the same cache,
  transform and clip path as firmware.
- The release haptic begins after its first frame is drawn. Pulse widths are
  requested software durations; actual motor timing, frame rate and latency
  still require physical C152 measurements.

The original Bumblebee portrait source and accepted idle JPEG are preserved;
the idle JPEG SHA-256 is
`f1bb7e24fe30631b15e1999c35a0b8d4024d3fc52b222aa0ad6c5d6676a9d191`.
The six full-body PNGs come from built-in imagegen output and are fitted to the
300px black-backed source tiles. The earlier Optimus portrait has been retired
from the active Home roster. Generation briefs and reproduction details are in
[artwork provenance](../assets/robot-home/GENERATION.md). This is unofficial
fan artwork, not licensed character art.

## Verification

The implementation includes:

- Selection tests for all three directions, all current heroes, every candidate,
  rejected entropy, non-repeat, no entropy for left/none and uptime wraparound.
- Press/release, interruption, expiry, bounds, movement, cancellation and wake
  tests using the real interaction state machine.
- Cache tests for full reuse, partial-allocation fallback, complete allocation
  failure, bad decode and recovery after overwriting the fallback buffer.
- Actual firmware-function tests for immediate press/release drawing, haptic
  ordering, wake/hold isolation, random swipes and existing Agent controls.
- Actual `drawScreen` tests for crossing reaction/transition expiry during a
  simulated panel transfer and Codex dashboard pixel equality.
- Decoded native sequence checks for all seven choices: immediate visible press
  and skill, identical status/battery pixels and final idle-frame equality.
- Real JPEG/header-byte/determinism checks through Python and independent
  ImageIO decoding through Swift.
- Compression-tolerant artwork identity checks reject re-encoded duplicates
  of all seven images while accepting the distinct shipped figures.

Validation record for the seven-choice source build: **5 Python artwork tests**,
**7 ImageIO decodes**, seven native spacing sequences, real gesture and production
draw regressions passed. Native preview, default firmware and five-screen USB-mic
firmware built successfully. Exact commands and outputs are recorded in the local
Task 2 validation report. One upstream M5GFX Clang VLA-extension
warning remains in native compilation; no new source compile errors occurred.

Run the core checks from the repository root:

```sh
clang++ -std=c++17 -Iinclude simulator/robot_home_character_test.cpp -o /private/tmp/home-character-test
/private/tmp/home-character-test
clang++ -std=c++17 -Iinclude simulator/robot_home_interaction_test.cpp -o /private/tmp/home-interaction-test
/private/tmp/home-interaction-test
clang++ -std=c++17 -Iinclude simulator/robot_home_frame_test.cpp -o /private/tmp/home-frame-test
/private/tmp/home-frame-test
clang++ -std=c++17 -Iinclude simulator/robot_home_cache_test.cpp -o /private/tmp/home-cache-test
/private/tmp/home-cache-test
python3 simulator/robot_home_art_test.py
swift -module-cache-path /private/tmp/home-swift-cache simulator/robot_home_art_test.swift
ruby simulator/robot_home_swipe_test.rb
ruby simulator/robot_speech_reaction_test.rb
ruby simulator/workspace_launch_main_test.rb
ruby simulator/codex_dashboard_draw_test.rb
HOMEBREW_PREFIX=/opt/homebrew pio run -e native-preview
ruby simulator/robot_home_spacing_test.rb .pio/build/native-preview/program
pio run -e m5stack-stopwatch
pio run -d usb-mic -e m5stack-stopwatch-usb-mic
```

Python artwork checks require Pillow and numpy. Existing dependency caches are
used; builds do not upload or change Companion installation. For a batch of
native animation frames, create an output directory then run
`.pio/build/native-preview/program --home-sequence OUTPUT_DIRECTORY`.

## Deployment and remaining physical acceptance

On 2026-10-13, the user confirmed download mode and explicitly approved the
identified upload port. The earlier four-hero five-screen application built from `3a0e2cf` was
written to app0 at `0x10000` after a complete 16MB private backup and confirmation
that the device/candidate partition tables match and OTA selects app0.

The write tool verified its data hash, then an independent ROM verification
matched the firmware digest. A separate readback confirmed the first 64KB,
including bootloader, partition table, NVS and OTA metadata, remained byte-identical
to the pre-update backup. No Companion deployment, restart, push or merge was
performed. The device restarted with the tool's watchdog reset; USB and CoreAudio
again enumerated `Codex StopWatch Mic` as one 48kHz USB input, and a new Companion
HID-connected log was observed. A compiled version of the existing capture helper
then recorded 3.008 seconds of 48kHz, mono, 16-bit PCM (144,384 frames). Validation
found no discontinuities, long zero runs, repeated adjacent blocks or clipping.
The temporary recording was deleted. Connection and this short capture do not
establish every control/RPC action or long-duration audio reliability.

Before any future upload or rollback, follow the
[official M5Stack factory-recovery procedure](https://docs.m5stack.com/en/guide/stopwatch/restore_factory),
resolve and report the current exact download-mode port and obtain upload approval.
Private backups, firmware and detailed device logs stay local.

The user later confirmed the earlier interaction felt normal in use; that was
subjective acceptance, not a measured response-latency result. The current
seven-choice source build has not been written to hardware. Physical acceptance
for this build must cover each choice's perceived response, repeated taps,
random swipes, wake/long hold, left cycling, Agent navigation and microphone
streaming. Measure at least 30 responses per hero, with a target P95 of 80ms or
less from recognized touch to first feedback; also check touch-to-visible latency
using high-frame-rate video. The target has **not** been measured or achieved
on hardware in this source-only verification.
